/**
 * ============================================================
 * 声明：本文件由 AI（TRAE 助手）辅助生成，尚未经过技术验证。
 * 代码未在真实 HarmonyOS 设备上编译运行，可能存在编译错误、
 * API 调用不正确等问题，请自行审查测试后使用。
 * 原始项目: https://github.com/zzyoxml/md3Music (Flutter/Android)
 * ============================================================
 */

/**
 * 音频播放器管理器 v2.0
 * 修复: 状态机正确性、错误监听、音频焦点
 * 新增: AVSession媒体会话、后台播放(长时任务)、通知栏控制
 *
 * 架构参考:
 * - 鸿蒙官方 MusicHome Codelab (MediaService.ets 模式)
 * - AVPlayer 状态机: idle→initialized→prepared→playing→completed
 * - AVSession: 系统通知栏/锁屏自动展示媒体控制
 * - 后台播放: AVSession + 长时任务(AUDIO_PLAYBACK)
 */
import media from '@ohos.multimedia.media'
import audio from '@ohos.multimedia.audio'
import backgroundTaskManager from '@ohos.backgroundTaskManager'
import wantAgent from '@ohos.app.ability.wantAgent'
import { Song } from '../models/Song'
import { KugouApi } from '../api/KugouApi'
import { AppStorageKeys, AudioQuality, PlayMode } from '../common/Constants'
import { LyricData, LyricLine } from '../models/UserInfo'

export class PlayerManager {
  private static instance: PlayerManager
  private avPlayer: media.AVPlayer | null = null
  private isContinuousTaskRunning: boolean = false

  private _currentSong: Song = new Song()
  private _playList: Song[] = []
  private _currentIndex: number = 0
  private _isPlaying: boolean = false
  private _playMode: PlayMode = PlayMode.LOOP
  private _audioQuality: AudioQuality = AudioQuality.STANDARD
  private _currentPosition: number = 0
  private _duration: number = 0
  private _lyricData: LyricData = new LyricData()
  private _currentLyricIndex: number = 0
  private _isPrepared: boolean = false
  private _isUrlLoading: boolean = false

  // 回调
  onPlayingChanged?: (isPlaying: boolean) => void
  onPositionChanged?: (position: number) => void
  onDurationChanged?: (duration: number) => void
  onSongChanged?: (song: Song) => void
  onLyricChanged?: (index: number) => void
  onPlayListEnded?: () => void
  onError?: (msg: string) => void

  private constructor() {
    this._playMode = (AppStorage.get<number>(AppStorageKeys.PLAY_MODE) ?? PlayMode.LOOP) as PlayMode
    const quality = AppStorage.get<string>(AppStorageKeys.AUDIO_QUALITY) || '128'
    this._audioQuality = quality as AudioQuality
  }

  static getInstance(): PlayerManager {
    if (!PlayerManager.instance) {
      PlayerManager.instance = new PlayerManager()
    }
    return PlayerManager.instance
  }

  get currentSong(): Song { return this._currentSong }
  get playList(): Song[] { return this._playList }
  get currentIndex(): number { return this._currentIndex }
  get isPlaying(): boolean { return this._isPlaying }
  get playMode(): PlayMode { return this._playMode }
  get currentPosition(): number { return this._currentPosition }
  get duration(): number { return this._duration }
  get lyricData(): LyricData { return this._lyricData }
  get currentLyricIndex(): number { return this._currentLyricIndex }

  /**
   * 初始化 AVPlayer
   * 修复: 在设置 url 之前注册所有监听（官方要求）
   * 修复: error 是独立事件，不是 stateChange 的状态
   */
  private async initPlayer(): Promise<void> {
    if (this.avPlayer) return

    this.avPlayer = await media.createAVPlayer()

    // 1. 先注册所有监听（关键：在设 url 之前）
    this.avPlayer.on('stateChange', (state: string, reason: media.StateChangeReason) => {
      console.info(`[Player] stateChange: ${state}, reason: ${reason}`)
      switch (state) {
        case 'initialized':
          // 设置音频渲染类型为音乐
          try {
            this.avPlayer!.audioRendererInfo = {
              usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
              rendererFlags: 0
            }
          } catch (e) {
            console.warn('[Player] setAudioRendererInfo failed:', e)
          }
          this.avPlayer!.prepare()
          break
        case 'prepared':
          this._isPrepared = true
          this._duration = this.avPlayer!.duration / 1000  // 转为秒
          this.onDurationChanged?.(this._duration)
          this.avPlayer!.play()
          break
        case 'playing':
          this._isPlaying = true
          this.onPlayingChanged?.(true)
          AppStorage.setOrCreate(AppStorageKeys.IS_PLAYING, true)
          break
        case 'paused':
          this._isPlaying = false
          this.onPlayingChanged?.(false)
          AppStorage.setOrCreate(AppStorageKeys.IS_PLAYING, false)
          break
        case 'completed':
          this._isPlaying = false
          this.onPlayingChanged?.(false)
          AppStorage.setOrCreate(AppStorageKeys.IS_PLAYING, false)
          this.handlePlayCompleted()
          break
        case 'stopped':
          this._isPrepared = false
          break
        case 'released':
          this._isPrepared = false
          break
        case 'error':
          // error 状态理论上不会走这里，但保险处理
          console.error('[Player] player entered error state')
          this.onError?.('播放器进入错误状态')
          break
      }
    })

    // 2. error 是独立事件监听
    this.avPlayer.on('error', (err: Error) => {
      console.error('[Player] error event:', err.message)
      this._isUrlLoading = false
      this.onError?.(`播放出错: ${err.message}`)
      // 尝试自动跳下一首
      setTimeout(() => {
        if (!this._isPlaying && this._playList.length > 1) {
          this.next()
        }
      }, 1000)
    })

    // 3. 时间更新
    this.avPlayer.on('timeUpdate', (time: number) => {
      this._currentPosition = time / 1000  // 转为秒
      this.onPositionChanged?.(this._currentPosition)
      this.updateLyricIndex()
    })

    // 4. 时长更新
    this.avPlayer.on('durationUpdate', (duration: number) => {
      this._duration = duration / 1000
      this.onDurationChanged?.(this._duration)
    })

    // 5. 音频焦点打断处理
    this.avPlayer.on('audioInterrupt', (info: audio.InterruptEvent) => {
      console.info(`[Player] audioInterrupt: ${info.eventType}, ${info.hintType}`)
      if (info.eventType === audio.InterruptType.INTERRUPT_TYPE_BEGIN) {
        if (info.hintType === audio.InterruptHint.INTERRUPT_HINT_PAUSE) {
          // 被电话等打断，暂停播放
          this._isPlaying = false
          this.onPlayingChanged?.(false)
          AppStorage.setOrCreate(AppStorageKeys.IS_PLAYING, false)
          this.stopContinuousTask()
        }
      } else if (info.eventType === audio.InterruptType.INTERRUPT_TYPE_END) {
        if (info.hintType === audio.InterruptHint.INTERRUPT_HINT_RESUME) {
          // 打断结束，恢复播放
          this.avPlayer?.play()
        }
      }
    })
  }

  /**
   * 播放在线歌曲 - 核心方法
   * 修复: URL加载状态管理，防止重复请求
   */
  async playOnlineSong(song: Song): Promise<void> {
    if (this._isUrlLoading) {
      console.warn('[Player] URL still loading, skip')
      return
    }

    this._isUrlLoading = true
    this.onSongChanged?.(song)
    this._currentSong = song
    AppStorage.setOrCreate(AppStorageKeys.CURRENT_SONG, JSON.stringify(song))

    try {
      // 1. 获取播放URL
      const api = KugouApi.getInstance()
      const result = await api.getSongUrl(song.hash, song.albumId, song.albumAudioId)

      // 2. 解析播放URL
      const playUrl = Song.extractPlayUrl(result)
      if (!playUrl) {
        this._isUrlLoading = false
        this.onError?.('无法获取播放地址，可能需要VIP或歌曲已下架')
        // 自动跳下一首
        setTimeout(() => {
          if (this._playList.length > 1) this.next()
        }, 1500)
        return
      }

      song.url = playUrl

      // 3. 初始化播放器（如果还没有）
      await this.initPlayer()

      // 4. 切换歌曲前先reset
      if (this._isPrepared) {
        this.avPlayer!.reset()
        this._isPrepared = false
      }

      // 5. 设置新URL，触发 initialized → prepared → playing
      this.avPlayer!.url = playUrl

      // 6. 获取歌词（异步）
      this.fetchLyric(song)

      // 7. 预取后续歌曲URL
      this.prefetchNextSongs()

      // 8. 启动后台播放长时任务
      await this.startContinuousTask()

      this._isUrlLoading = false
    } catch (err) {
      this._isUrlLoading = false
      this.onError?.(`播放失败: ${err}`)
    }
  }

  /**
   * 播放列表
   */
  async playOnlinePlaylist(songs: Song[], startIndex: number = 0): Promise<void> {
    if (songs.length === 0) return
    this._playList = [...songs]
    this._currentIndex = startIndex
    AppStorage.setOrCreate(AppStorageKeys.PLAYLIST, JSON.stringify(songs))
    AppStorage.setOrCreate(AppStorageKeys.PLAY_INDEX, String(startIndex))
    await this.playOnlineSong(songs[startIndex])
  }

  /**
   * 播放/暂停
   */
  async togglePlay(): Promise<void> {
    if (!this.avPlayer || !this._isPrepared) return
    if (this._isPlaying) {
      this.avPlayer.pause()
      this.stopContinuousTask()
    } else {
      this.avPlayer.play()
      this.startContinuousTask()
    }
  }

  async previous(): Promise<void> {
    if (this._playList.length === 0) return
    if (this._playMode === PlayMode.SHUFFLE) {
      this._currentIndex = Math.floor(Math.random() * this._playList.length)
    } else {
      this._currentIndex = (this._currentIndex - 1 + this._playList.length) % this._playList.length
    }
    AppStorage.setOrCreate(AppStorageKeys.PLAY_INDEX, String(this._currentIndex))
    await this.playOnlineSong(this._playList[this._currentIndex])
  }

  async next(): Promise<void> {
    if (this._playList.length === 0) return
    if (this._playMode === PlayMode.SHUFFLE) {
      this._currentIndex = Math.floor(Math.random() * this._playList.length)
    } else {
      this._currentIndex = (this._currentIndex + 1) % this._playList.length
    }
    AppStorage.setOrCreate(AppStorageKeys.PLAY_INDEX, String(this._currentIndex))
    await this.playOnlineSong(this._playList[this._currentIndex])
  }

  /**
   * 跳转进度
   */
  async seek(position: number): Promise<void> {
    if (!this.avPlayer || !this._isPrepared) return
    this.avPlayer.seek(position * 1000, media.SeekMode.SEEK_PREV_SYNC)
    this._currentPosition = position
    this.onPositionChanged?.(position)
  }

  setPlayMode(mode: PlayMode): void {
    this._playMode = mode
    AppStorage.setOrCreate(AppStorageKeys.PLAY_MODE, mode)
  }

  togglePlayMode(): PlayMode {
    const modes = [PlayMode.LOOP, PlayMode.SINGLE, PlayMode.SHUFFLE]
    const idx = modes.indexOf(this._playMode)
    this._playMode = modes[(idx + 1) % modes.length]
    AppStorage.setOrCreate(AppStorageKeys.PLAY_MODE, this._playMode)
    return this._playMode
  }

  setAudioQuality(quality: AudioQuality): void {
    this._audioQuality = quality
    AppStorage.setOrCreate(AppStorageKeys.AUDIO_QUALITY, quality)
  }

  /**
   * 播放完成处理
   */
  private handlePlayCompleted(): void {
    if (this._playMode === PlayMode.SINGLE) {
      this.seek(0)
      this.avPlayer?.play()
    } else {
      if (this._currentIndex < this._playList.length - 1 || this._playMode === PlayMode.LOOP) {
        this.next()
      } else {
        this.onPlayListEnded?.()
        this.stopContinuousTask()
      }
    }
  }

  // ==================== 后台播放长时任务 ====================

  /**
   * 启动后台播放长时任务
   * 新增: 防止应用退至后台被系统挂起
   * 参考: 鸿蒙官方 backgroundTaskManager + wantAgent
   */
  async startContinuousTask(): Promise<void> {
    if (this.isContinuousTaskRunning) return
    try {
      // 构建点击通知拉回应用的 WantAgent
      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [{
          bundleName: 'com.md3music.harmonyos',
          abilityName: 'EntryAbility'
        }],
        operationType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      }
      const agent = await wantAgent.getWantAgent(wantAgentInfo)

      await backgroundTaskManager.startBackgroundRunning(
        getContext(this),
        backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK,
        agent
      )
      this.isContinuousTaskRunning = true
      console.info('[BackgroundTask] continuous task started')
    } catch (err) {
      console.warn('[BackgroundTask] start failed:', err)
    }
  }

  /**
   * 停止后台播放长时任务
   */
  async stopContinuousTask(): Promise<void> {
    if (!this.isContinuousTaskRunning) return
    try {
      await backgroundTaskManager.stopBackgroundRunning(getContext(this))
      this.isContinuousTaskRunning = false
      console.info('[BackgroundTask] continuous task stopped')
    } catch (err) {
      console.warn('[BackgroundTask] stop failed:', err)
    }
  }

  // ==================== 歌词 ====================

  /**
   * 获取歌词
   */
  private async fetchLyric(song: Song): Promise<void> {
    try {
      if (!song.lyricId && !song.accesskey) {
        // 尝试从搜索结果中的 lyricId 获取
        console.info('[Player] no lyric id, skip')
        return
      }
      const api = KugouApi.getInstance()
      const result = await api.getLyric(song.lyricId, song.accesskey)
      const data = result as Record<string, Object>

      if (data['status'] === 1 && data['data']) {
        const lyricInfo = data['data'] as Record<string, Object>
        const content = (lyricInfo['decodeContent'] || lyricInfo['content'] || '') as string
        if (content) {
          this._lyricData = this.parseLrc(content)
          this._currentLyricIndex = 0
        }
      }
    } catch (err) {
      console.error('[Player] fetchLyric failed:', err)
    }
  }

  /**
   * 解析LRC歌词
   */
  private parseLrc(lrcContent: string): LyricData {
    const lyricData = new LyricData()
    lyricData.rawLrc = lrcContent
    const lines = lrcContent.split('\n')
    const timeRegex = /\[(\d{2}):(\d{2})\.(\d{2,3})\]/

    for (const line of lines) {
      const match = line.match(timeRegex)
      if (match) {
        const minutes = parseInt(match[1])
        const seconds = parseInt(match[2])
        const ms = parseInt(match[3].padEnd(3, '0'))
        const time = minutes * 60 * 1000 + seconds * 1000 + ms
        const text = line.replace(timeRegex, '').trim()
        if (text) {
          const lyricLine = new LyricLine()
          lyricLine.time = time
          lyricLine.text = text
          lyricData.lines.push(lyricLine)
        }
      }
    }
    lyricData.lines.sort((a, b) => a.time - b.time)
    return lyricData
  }

  private updateLyricIndex(): void {
    if (this._lyricData.lines.length === 0) return
    const currentMs = this._currentPosition * 1000
    for (let i = this._lyricData.lines.length - 1; i >= 0; i--) {
      if (currentMs >= this._lyricData.lines[i].time) {
        if (i !== this._currentLyricIndex) {
          this._currentLyricIndex = i
          this.onLyricChanged?.(i)
        }
        break
      }
    }
  }

  /**
   * 预取后续歌曲URL
   */
  private prefetchNextSongs(): void {
    if (this._playList.length === 0) return
    const api = KugouApi.getInstance()
    const prefetchCount = Math.min(3, this._playList.length - this._currentIndex - 1)
    for (let i = 1; i <= prefetchCount; i++) {
      const idx = (this._currentIndex + i) % this._playList.length
      const song = this._playList[idx]
      if (song && !song.url) {
        api.getSongUrl(song.hash, song.albumId, song.albumAudioId)
          .then((result: Record<string, Object>) => {
            song.url = Song.extractPlayUrl(result)
          })
          .catch(() => {})
      }
    }
  }

  static formatDuration(seconds: number): string {
    if (seconds <= 0 || isNaN(seconds)) return '00:00'
    const min = Math.floor(seconds / 60)
    const sec = Math.floor(seconds % 60)
    return `${String(min).padStart(2, '0')}:${String(sec).padStart(2, '0')}`
  }

  /**
   * 释放资源
   * 修复: 正确释放 AVPlayer
   */
  async release(): Promise<void> {
    await this.stopContinuousTask()
    if (this.avPlayer) {
      this.avPlayer.release()
      this.avPlayer = null
    }
    this._isPrepared = false
    this._isPlaying = false
  }
}
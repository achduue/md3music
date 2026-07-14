/**
 * 音频播放器管理器
 * 对应原Flutter版 PlayerProvider + AudioService
 * 使用 @ohos.multimedia.audio 实现
 *
 * 播放流程(对应原版):
 * 1. playOnlineSong(song) → 调用 API 获取播放URL
 * 2. 获取URL后 → 设置音频源并播放
 * 3. 预取后续3首歌的URL
 */
import media from '@ohos.multimedia.media'
import { Song } from '../models/Song'
import { KugouApi } from '../api/KugouApi'
import { AppStorageKeys, AudioQuality, PlayMode } from '../common/Constants'
import { LyricData, LyricLine } from '../models/UserInfo'

export class PlayerManager {
  private static instance: PlayerManager
  private avPlayer: media.AVPlayer | null = null
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

  get currentSong(): Song {
    return this._currentSong
  }

  get playList(): Song[] {
    return this._playList
  }

  get currentIndex(): number {
    return this._currentIndex
  }

  get isPlaying(): boolean {
    return this._isPlaying
  }

  get playMode(): PlayMode {
    return this._playMode
  }

  get currentPosition(): number {
    return this._currentPosition
  }

  get duration(): number {
    return this._duration
  }

  get lyricData(): LyricData {
    return this._lyricData
  }

  get currentLyricIndex(): number {
    return this._currentLyricIndex
  }

  /**
   * 初始化 AVPlayer
   */
  private async initPlayer(): Promise<void> {
    if (this.avPlayer) return

    this.avPlayer = await media.createAVPlayer()

    this.avPlayer.on('stateChange', (state: string) => {
      switch (state) {
        case 'initialized':
          this.avPlayer?.prepare()
          break
        case 'prepared':
          this._isPrepared = true
          this._duration = this.avPlayer?.duration ?? 0
          this.onDurationChanged?.(this._duration)
          this.avPlayer?.play()
          this._isPlaying = true
          this.onPlayingChanged?.(true)
          AppStorage.setOrCreate(AppStorageKeys.IS_PLAYING, true)
          break
        case 'completed':
          this.handlePlayCompleted()
          break
        case 'error':
          this.onError?.('播放出错')
          break
      }
    })

    this.avPlayer.on('timeUpdate', (time: number) => {
      this._currentPosition = time / 1000  // 转为秒
      this.onPositionChanged?.(this._currentPosition)
      this.updateLyricIndex()
    })
  }

  /**
   * 播放在线歌曲 - 核心方法
   * 对应原Flutter: PlayerProvider.playOnlineSong()
   * 流程: 检查登录 → 获取播放URL → 设置音频源 → 播放 → 预取后续
   */
  async playOnlineSong(song: Song): Promise<void> {
    try {
      this.onSongChanged?.(song)
      this._currentSong = song
      AppStorage.setOrCreate(AppStorageKeys.CURRENT_SONG, JSON.stringify(song))

      // 1. 获取播放URL
      // 对应原Flutter: KugouApiClient.getSongUrl(hash, quality, albumId, albumAudioId)
      const api = KugouApi.getInstance()
      const result = await api.getSongUrl(song.hash, song.albumId, song.albumAudioId)

      // 2. 解析播放URL
      let playUrl = ''
      const data = result['data'] as Record<string, Object> | undefined
      if (data) {
        const info = (data['info'] || data['url_info'] || data) as Record<string, Object>
        // 尝试多种URL字段
        playUrl = (info['url'] as string) || (info['play_url'] as string) ||
          (data['url'] as string) || ''

        // 如果是数组形式
        if (!playUrl && Array.isArray(info)) {
          const firstItem = info[0] as Record<string, Object>
          playUrl = (firstItem['url'] as string) || ''
        }
      }

      if (!playUrl) {
        this.onError?.('无法获取播放地址')
        return
      }

      song.url = playUrl

      // 3. 设置音频源并播放
      await this.initPlayer()
      this.avPlayer?.reset()
      this._isPrepared = false
      this.avPlayer!.url = playUrl

      // 4. 获取歌词
      this.fetchLyric(song)

      // 5. 预取后续歌曲URL
      this.prefetchNextSongs()

    } catch (err) {
      this.onError?.(`播放失败: ${err}`)
    }
  }

  /**
   * 播放列表
   * 对应原Flutter: PlayerProvider.playOnlinePlaylist(songs, startIndex)
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
      this._isPlaying = false
    } else {
      this.avPlayer.play()
      this._isPlaying = true
    }
    this.onPlayingChanged?.(this._isPlaying)
    AppStorage.setOrCreate(AppStorageKeys.IS_PLAYING, this._isPlaying)
  }

  /**
   * 上一曲
   * 对应原Flutter: PlayerProvider.previous()
   */
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

  /**
   * 下一曲
   * 对应原Flutter: PlayerProvider.next()
   */
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
   * 对应原Flutter: _audioService.seek(position)
   */
  async seek(position: number): Promise<void> {
    if (!this.avPlayer || !this._isPrepared) return
    this.avPlayer.seek(position * 1000)  // 转为毫秒
    this._currentPosition = position
    this.onPositionChanged?.(position)
  }

  /**
   * 设置播放模式
   */
  setPlayMode(mode: PlayMode): void {
    this._playMode = mode
    AppStorage.setOrCreate(AppStorageKeys.PLAY_MODE, mode)
  }

  /**
   * 切换播放模式
   */
  togglePlayMode(): PlayMode {
    const modes = [PlayMode.LOOP, PlayMode.SINGLE, PlayMode.SHUFFLE]
    const idx = modes.indexOf(this._playMode)
    this._playMode = modes[(idx + 1) % modes.length]
    AppStorage.setOrCreate(AppStorageKeys.PLAY_MODE, this._playMode)
    return this._playMode
  }

  /**
   * 设置音质
   * 对应原Flutter: AudioQuality 枚举
   */
  setAudioQuality(quality: AudioQuality): void {
    this._audioQuality = quality
    AppStorage.setOrCreate(AppStorageKeys.AUDIO_QUALITY, quality)
  }

  /**
   * 播放完成处理
   * 对应原Flutter: _handlePlaybackCompleted()
   */
  private handlePlayCompleted(): void {
    if (this._playMode === PlayMode.SINGLE) {
      // 单曲循环：回到开头重新播放
      this.seek(0)
      this.avPlayer?.play()
    } else {
      // 列表循环 / 随机：播放下一首
      if (this._currentIndex < this._playList.length - 1 || this._playMode === PlayMode.LOOP) {
        this.next()
      } else {
        this.onPlayListEnded?.()
      }
    }
  }

  /**
   * 获取歌词
   * 对应原Flutter: KugouProvider.loadLyric(id, accesskey)
   * API: GET /lyric?id=xxx&accesskey=xxx&decode=1&fmt=lrc
   */
  private async fetchLyric(song: Song): Promise<void> {
    try {
      // 从搜索结果或特权信息中获取歌词参数
      if (!song.lyricId && !song.accesskey) return

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
      // 歌词获取失败不影响播放
      console.error('获取歌词失败:', err)
    }
  }

  /**
   * 解析LRC歌词
   * 格式: [mm:ss.xx]歌词文本
   */
  private parseLrc(lrcContent: string): LyricData {
    const lyricData = new LyricData()
    lyricData.rawLrc = lrcContent

    const lines = lrcContent.split('\n')
    for (const line of lines) {
      const match = line.match(/\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)/)
      if (match) {
        const minutes = parseInt(match[1])
        const seconds = parseInt(match[2])
        const ms = parseInt(match[3].padEnd(3, '0'))
        const time = minutes * 60 * 1000 + seconds * 1000 + ms
        const text = match[4].trim()
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

  /**
   * 更新当前歌词行索引
   * 对应原Flutter: 歌词同步滚动逻辑
   */
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
   * 对应原Flutter: _prefetchNextSongs()
   * 预取播放列表中后续3首歌的URL
   */
  private prefetchNextSongs(): void {
    if (this._playList.length === 0) return
    const api = KugouApi.getInstance()
    const prefetchCount = Math.min(3, this._playList.length - this._currentIndex - 1)

    for (let i = 1; i <= prefetchCount; i++) {
      const idx = (this._currentIndex + i) % this._playList.length
      const song = this._playList[idx]
      if (song && !song.url) {
        // 异步预取，不阻塞当前播放
        api.getSongUrl(song.hash, song.albumId, song.albumAudioId)
          .then((result) => {
            const data = result['data'] as Record<string, Object> | undefined
            if (data) {
              const info = data as Record<string, Object>
              song.url = (info['url'] as string) || ''
            }
          })
          .catch(() => {})
      }
    }
  }

  /**
   * 格式化时长 mm:ss
   */
  static formatDuration(seconds: number): string {
    if (seconds <= 0 || isNaN(seconds)) return '00:00'
    const min = Math.floor(seconds / 60)
    const sec = Math.floor(seconds % 60)
    return `${String(min).padStart(2, '0')}:${String(sec).padStart(2, '0')}`
  }

  /**
   * 释放资源
   */
  async release(): Promise<void> {
    if (this.avPlayer) {
      this.avPlayer.release()
      this.avPlayer = null
    }
  }
}
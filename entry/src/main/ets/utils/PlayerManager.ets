import media from '@ohos.multimedia.media';
import audio from '@ohos.multimedia.audio';
import backgroundTaskManager from '@ohos.backgroundTaskManager';
import wantAgent from '@ohos.wantAgent';
import { common } from '@ohos.app.ability.common';
import { Song } from '../models/Song';
import { PlayMode, AppStorageKeys } from '../common/Constants';
import { KugouApi } from '../api/KugouApi';

export class PlayerManager {
  private static instance: PlayerManager = new PlayerManager();
  private api: KugouApi = KugouApi.getInstance();

  public currentSong: Song | null = null;
  public playList: Song[] = [];
  public currentIndex: number = 0;
  public isPlaying: boolean = false;
  public playMode: PlayMode = PlayMode.LOOP;
  public currentPosition: number = 0;
  public duration: number = 0;
  public appContext: common.Context | null = null;

  public onSongChanged: ((song: Song | null) => void) | null = null;
  public onPlayingChanged: ((playing: boolean) => void) | null = null;
  public onPositionChanged: ((pos: number, dur: number) => void) | null = null;
  public onError: ((msg: string) => void) | null = null;

  private avPlayer: media.AVPlayer | null = null;
  private isManualStop: boolean = false;

  private constructor() {
    const savedMode: number = AppStorage.get<number>(AppStorageKeys.PLAY_MODE) || 0;
    this.playMode = savedMode as PlayMode;
  }

  public static getInstance(): PlayerManager {
    return PlayerManager.instance;
  }

  public setContext(context: common.Context): void {
    this.appContext = context;
  }

  public async initPlayer(): Promise<void> {
    if (this.avPlayer) {
      await this.release();
    }

    try {
      this.avPlayer = await media.createAVPlayer();
      this.avPlayer.audioRendererInfo = {
        usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
        rendererFlags: 0
      };

      this.avPlayer.on('stateChange', (state: string): void => {
        if (state === 'playing') {
          this.isPlaying = true;
          if (this.onPlayingChanged) {
            this.onPlayingChanged(true);
          }
          if (this.onSongChanged && this.currentSong) {
            this.onSongChanged(this.currentSong);
          }
          AppStorage.setOrCreate(AppStorageKeys.IS_PLAYING, true);
        } else if (state === 'paused') {
          this.isPlaying = false;
          if (this.onPlayingChanged) {
            this.onPlayingChanged(false);
          }
          AppStorage.setOrCreate(AppStorageKeys.IS_PLAYING, false);
        } else if (state === 'stopped') {
          this.isPlaying = false;
          if (this.onPlayingChanged) {
            this.onPlayingChanged(false);
          }
          AppStorage.setOrCreate(AppStorageKeys.IS_PLAYING, false);
          if (!this.isManualStop) {
            this.playNext();
          }
        }
      });

      this.avPlayer.on('timeUpdate', (time: number): void => {
        this.currentPosition = Math.floor(time / 1000);
        if (this.onPositionChanged) {
          this.onPositionChanged(this.currentPosition, this.duration);
        }
      });

      this.avPlayer.on('durationUpdate', (dur: number): void => {
        this.duration = Math.floor(dur / 1000);
      });

      this.avPlayer.on('error', (err: Error): void => {
        console.error('PlayerManager AVPlayer error: ' + JSON.stringify(err));
        if (this.onError) {
          this.onError('播放器错误: ' + JSON.stringify(err));
        }
      });
    } catch (e) {
      console.error('PlayerManager initPlayer failed: ' + String(e));
      if (this.onError) {
        this.onError('播放器初始化失败: ' + String(e));
      }
    }
  }

  public async playSong(song: Song): Promise<void> {
    if (!this.avPlayer) {
      if (this.onError) {
        this.onError('播放器未初始化');
      }
      return;
    }

    try {
      this.isManualStop = true;
      const result: Record<string, Object> = await this.api.getSongUrl(song.hash, song.albumId, song.albumAudioId);
      const url: string = Song.extractUrl(result);

      if (!url) {
        this.isManualStop = false;
        if (this.onError) {
          this.onError('歌曲暂时无法播放');
        }
        return;
      }

      song.url = url;
      this.currentSong = song;

      this.avPlayer.url = url;
      await this.avPlayer.prepare();
      this.isManualStop = false;
      await this.avPlayer.play();
    } catch (e) {
      this.isManualStop = false;
      console.error('PlayerManager playSong failed: ' + String(e));
      if (this.onError) {
        this.onError('播放失败: ' + String(e));
      }
    }
  }

  public async playList(songs: Song[], startIndex: number): Promise<void> {
    if (songs.length === 0) return;

    this.playList = songs;
    this.currentIndex = startIndex;

    if (startIndex >= 0 && startIndex < songs.length) {
      await this.playSong(songs[startIndex]);
    }
  }

  public togglePlay(): void {
    if (!this.avPlayer) return;

    if (this.isPlaying) {
      this.avPlayer.pause();
    } else {
      this.avPlayer.play();
    }
  }

  public async previous(): Promise<void> {
    if (this.playList.length === 0) return;

    const prevIndex: number = this.getPreviousIndex();
    if (prevIndex < 0) return;

    this.currentIndex = prevIndex;
    this.isManualStop = true;
    if (this.avPlayer) {
      this.avPlayer.reset();
    }
    this.isManualStop = false;
    await this.playSong(this.playList[prevIndex]);
  }

  public async next(): Promise<void> {
    if (this.playList.length === 0) return;

    const nextIndex: number = this.getNextIndex();
    if (nextIndex < 0) return;

    this.currentIndex = nextIndex;
    this.isManualStop = true;
    if (this.avPlayer) {
      this.avPlayer.reset();
    }
    this.isManualStop = false;
    await this.playSong(this.playList[nextIndex]);
  }

  public seek(position: number): void {
    if (!this.avPlayer) return;
    this.avPlayer.seek(position * 1000);
  }

  public togglePlayMode(): void {
    const current: number = this.playMode as number;
    const next: number = (current + 1) % 3;
    this.playMode = next as PlayMode;
    AppStorage.setOrCreate(AppStorageKeys.PLAY_MODE, next);
  }

  public async startContinuousTask(): Promise<void> {
    if (!this.appContext) return;

    try {
      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [
          {
            bundleName: this.appContext.bundleName,
            abilityName: 'EntryAbility'
          }
        ],
        operationType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      const agent: wantAgent.WantAgent = await wantAgent.getWantAgent(wantAgentInfo);
      await backgroundTaskManager.startBackgroundRunning(this.appContext,
        backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, agent);
    } catch (e) {
      console.error('PlayerManager startContinuousTask failed: ' + String(e));
    }
  }

  public async stopContinuousTask(): Promise<void> {
    if (!this.appContext) return;

    try {
      await backgroundTaskManager.stopBackgroundRunning(this.appContext,
        backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK);
    } catch (e) {
      console.error('PlayerManager stopContinuousTask failed: ' + String(e));
    }
  }

  public release(): void {
    if (this.avPlayer) {
      this.isManualStop = true;
      this.avPlayer.release();
      this.avPlayer = null;
      this.isManualStop = false;
    }
    this.currentSong = null;
    this.isPlaying = false;
    this.currentPosition = 0;
    this.duration = 0;
    AppStorage.setOrCreate(AppStorageKeys.IS_PLAYING, false);
  }

  public static formatDuration(seconds: number): string {
    if (seconds < 0 || isNaN(seconds)) {
      return '00:00';
    }
    const mins: number = Math.floor(seconds / 60);
    const secs: number = Math.floor(seconds % 60);
    const minStr: string = mins < 10 ? '0' + String(mins) : String(mins);
    const secStr: string = secs < 10 ? '0' + String(secs) : String(secs);
    return minStr + ':' + secStr;
  }

  private getNextIndex(): number {
    if (this.playList.length === 0) return -1;

    switch (this.playMode) {
      case PlayMode.SHUFFLE: {
        return Math.floor(Math.random() * this.playList.length);
      }
      case PlayMode.SINGLE: {
        return this.currentIndex;
      }
      case PlayMode.LOOP:
      default: {
        return (this.currentIndex + 1) % this.playList.length;
      }
    }
  }

  private getPreviousIndex(): number {
    if (this.playList.length === 0) return -1;

    switch (this.playMode) {
      case PlayMode.SHUFFLE: {
        return Math.floor(Math.random() * this.playList.length);
      }
      case PlayMode.SINGLE: {
        return this.currentIndex;
      }
      case PlayMode.LOOP:
      default: {
        return (this.currentIndex - 1 + this.playList.length) % this.playList.length;
      }
    }
  }
}
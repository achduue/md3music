/**
 * 应用常量定义
 */
export class AppStorageKeys {
  static readonly TOKEN: string = 'kugou_token'
  static readonly USER_ID: string = 'kugou_userid'
  static readonly VIP_TOKEN: string = 'kugou_vip_token'
  static readonly VIP_TYPE: string = 'kugou_vip_type'
  static readonly DFID: string = 'kugou_dfid'
  static readonly IS_LOGGED_IN: string = 'is_logged_in'
  static readonly USER_AVATAR: string = 'user_avatar'
  static readonly USER_NICKNAME: string = 'user_nickname'
  static readonly AUDIO_QUALITY: string = 'audio_quality'
  static readonly CURRENT_SONG: string = 'current_song'
  static readonly PLAYLIST: string = 'playlist'
  static readonly PLAY_INDEX: string = 'play_index'
  static readonly IS_PLAYING: string = 'is_playing'
  static readonly PLAY_MODE: string = 'play_mode'  // 0=列表循环 1=单曲循环 2=随机
}

/**
 * 音质枚举
 * 对应原Flutter: AudioQuality
 * standard(128kbps) / high(320kbps) / flac(无损)
 */
export enum AudioQuality {
  STANDARD = '128',
  HIGH = '320',
  FLAC = 'flac'
}

/**
 * 播放模式
 */
export enum PlayMode {
  LOOP = 0,      // 列表循环
  SINGLE = 1,    // 单曲循环
  SHUFFLE = 2    // 随机播放
}

/**
 * MD3 设计色值 - 基于Material Design 3规范
 * 对应原Flutter版主题配色
 */
export class MD3Colors {
  static readonly Primary: string = '#6750A4'
  static readonly OnPrimary: string = '#FFFFFF'
  static readonly PrimaryContainer: string = '#EADDFF'
  static readonly OnPrimaryContainer: string = '#21005D'
  static readonly Secondary: string = '#625B71'
  static readonly OnSecondary: string = '#FFFFFF'
  static readonly SecondaryContainer: string = '#E8DEF8'
  static readonly Surface: string = '#F8FDFA'
  static readonly OnSurface: string = '#1C1B1F'
  static readonly OnSurfaceVariant: string = '#49454F'
  static readonly Outline: string = '#79747E'
  static readonly OutlineVariant: string = '#CAC4D0'
  static readonly SurfaceVariant: string = '#E7E0EC'
  static readonly Error: string = '#B3261E'
  static readonly Background: string = '#FDFBFF'
  static readonly SurfaceContainer: string = '#F3EDF7'
  static readonly SurfaceContainerLow: string = '#F7F2FA'
  static readonly SurfaceContainerHigh: string = '#ECE6F0'
  static readonly InverseSurface: string = '#313033'
  static readonly InverseOnSurface: string = '#F4EFF4'
  // 播放器页面 - 深色背景
  static readonly PlayerBackground: string = '#1B1B2E'
  static readonly PlayerSurface: string = '#2D2B55'
  static readonly PlayerOnSurface: string = '#E6E1E5'
}
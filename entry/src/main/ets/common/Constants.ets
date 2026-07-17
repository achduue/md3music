/**
 * 应用常量定义
 * 集中管理 API 地址、错误码、存储键、枚举与 MD3 配色
 */

/**
 * API 基础地址（云端服务器，所有请求均走此地址）
 */
export const API_BASE_URL: string = 'http://115.29.236.96:5621'

/**
 * 错误码常量
 */
export class ErrorCode {
    static readonly SUCCESS: number = 0
    static readonly NETWORK_ERROR: number = -1
    static readonly TIMEOUT: number = -2
    static readonly PARSE_ERROR: number = -3
    static readonly UNAUTHORIZED: number = 401
    static readonly FORBIDDEN: number = 403
    static readonly NOT_FOUND: number = 404
    static readonly SERVER_ERROR: number = 500
    static readonly SERVICE_UNAVAILABLE: number = 503
}

/**
 * 应用存储键名
 * 统一管理 AppStorage / preferences 的 key，避免散落的字符串
 */
export class AppStorageKeys {
    static readonly TOKEN: string = 'kugou_token'
    static readonly USER_ID: string = 'kugou_userid'
    static readonly VIP_TOKEN: string = 'kugou_vip_token'
    static readonly VIP_TYPE: string = 'kugou_vip_type'
    static readonly IS_LOGGED_IN: string = 'is_logged_in'
    static readonly USER_AVATAR: string = 'user_avatar'
    static readonly USER_NICKNAME: string = 'user_nickname'
    static readonly AUDIO_QUALITY: string = 'audio_quality'
    static readonly CURRENT_SONG: string = 'current_song'
    static readonly PLAYLIST: string = 'playlist'
    static readonly PLAY_INDEX: string = 'play_index'
    static readonly IS_PLAYING: string = 'is_playing'
    static readonly PLAY_MODE: string = 'play_mode' // 0=列表循环 1=单曲循环 2=随机
    static readonly SEARCH_KEYWORD: string = 'search_keyword'
    static readonly RANK_ID: string = 'rank_id'
    static readonly RANK_NAME: string = 'rank_name'
}

/**
 * 音质枚举
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
    LOOP = 0,
    SINGLE = 1,
    SHUFFLE = 2
}

/**
 * 排行榜信息接口
 */
export interface RankInfo {
    id: string
    name: string
    coverImg: string
    intro: string
    updateFrequency: string
}

/**
 * MD3 设计色值 - 基于 Material Design 3 规范
 * 使用 8 位十六进制（前两位为不透明度，便于直接在 ArkUI 中使用）
 */
export class MD3Colors {
    static readonly Primary: string = '#FF6750A4'
    static readonly OnPrimary: string = '#FFFFFFFF'
    static readonly PrimaryContainer: string = '#FFEADDFF'
    static readonly OnPrimaryContainer: string = '#FF21005D'
    static readonly Secondary: string = '#FF625B71'
    static readonly OnSecondary: string = '#FFFFFFFF'
    static readonly SecondaryContainer: string = '#FFE8DEF8'
    static readonly Tertiary: string = '#FF7D5260'
    static readonly OnTertiary: string = '#FFFFFFFF'
    static readonly TertiaryContainer: string = '#FFFFD8E4'
    static readonly Surface: string = '#FFF8FDFA'
    static readonly OnSurface: string = '#FF1C1B1F'
    static readonly OnSurfaceVariant: string = '#FF49454F'
    static readonly Outline: string = '#FF79747E'
    static readonly OutlineVariant: string = '#FFCAC4D0'
    static readonly SurfaceVariant: string = '#FFE7E0EC'
    static readonly Error: string = '#FFB3261E'
    static readonly OnError: string = '#FFFFFFFF'
    static readonly ErrorContainer: string = '#FFF9DEDC'
    static readonly Background: string = '#FFFDFBFF'
    static readonly SurfaceContainer: string = '#FFF3EDF7'
    static readonly SurfaceContainerLow: string = '#FFF7F2FA'
    static readonly SurfaceContainerHigh: string = '#FFECE6F0'
    static readonly InverseSurface: string = '#FF313033'
    static readonly InverseOnSurface: string = '#FFF4EFF4'
    static readonly PlayerBackground: string = '#FF1B1B2E'
    static readonly PlayerSurface: string = '#FF2D2B55'
    static readonly PlayerOnSurface: string = '#FFE6E1E5'
}

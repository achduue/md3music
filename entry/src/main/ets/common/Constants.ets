export const API_BASE_URL: string = 'http://115.29.236.96:5621'

export class AppStorageKeys {
  static readonly TOKEN: string = 'md3_token'
  static readonly USER_ID: string = 'md3_userid'
  static readonly VIP_TOKEN: string = 'md3_vip_token'
  static readonly IS_LOGGED_IN: string = 'md3_is_logged_in'
  static readonly USER_NICKNAME: string = 'md3_nickname'
  static readonly USER_AVATAR: string = 'md3_avatar'
  static readonly AUDIO_QUALITY: string = 'md3_quality'
  static readonly PLAY_MODE: string = 'md3_play_mode'
  static readonly CURRENT_SONG: string = 'md3_current_song'
  static readonly IS_PLAYING: string = 'md3_is_playing'
  static readonly SEARCH_KEYWORD: string = 'md3_search_keyword'
  static readonly RANK_ID: string = 'md3_rank_id'
  static readonly RANK_NAME: string = 'md3_rank_name'
}

export enum AudioQuality {
  STANDARD = '128',
  HIGH = '320',
  FLAC = 'flac'
}

export enum PlayMode {
  LOOP = 0,
  SINGLE = 1,
  SHUFFLE = 2
}

export class MD3Colors {
  static readonly PRIMARY: string = '#FF6750A4'
  static readonly ON_PRIMARY: string = '#FFFFFFFF'
  static readonly PRIMARY_CONTAINER: string = '#FFEADDFF'
  static readonly SURFACE: string = '#FFFFFBFE'
  static readonly ON_SURFACE: string = '#FF1C1B1F'
  static readonly ON_SURFACE_VARIANT: string = '#FF49454F'
  static readonly BACKGROUND: string = '#FFFFFBFE'
  static readonly ERROR: string = '#FFB3261E'
  static readonly PLAYER_BG: string = '#FF1A1A2E'
  static readonly SURFACE_DIM: string = '#FFDED8E1'
  static readonly SECONDARY: string = '#FF625B71'
  static readonly OUTLINE: string = '#FF79747E'
  static readonly SURFACE_CONTAINER: string = '#FFF3EDF7'
  static readonly SURFACE_CONTAINER_HIGH: string = '#FFECE6F0'
}

export class RankInfo {
  id: string = ''
  name: string = ''
  coverImg: string = ''
  intro: string = ''
  updateFrequency: string = ''
}
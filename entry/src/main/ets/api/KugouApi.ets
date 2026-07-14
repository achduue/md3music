/**
 * 酷狗音乐 API 客户端
 * 直接与云端API服务器通信（鸿蒙无本地Node.js，所有请求走云端）
 * 云端服务器地址: 115.29.236.96:5621
 *
 * 架构说明：
 * - 登录相关API → 直接走云端 115.29.236.96:5621
 * - 搜索/播放等API → 也走云端（鸿蒙无本地Node.js代理）
 * - 通过 Authorization 头传递认证信息
 */
import http from '@ohos.net.http'
import { Song } from '../models/Song'
import { UserInfo } from '../models/UserInfo'
import { AppStorageKeys } from '../common/Constants'

const CLOUD_BASE_URL = 'http://115.29.236.96:5621'
const LOCAL_BASE_URL = 'http://127.0.0.1:8080'  // 预留本地代理

// 是否使用本地代理（当用户自建Node.js服务器时）
let useLocalProxy: boolean = false

export class KugouApi {
  private static instance: KugouApi

  private constructor() {}

  static getInstance(): KugouApi {
    if (!KugouApi.instance) {
      KugouApi.instance = new KugouApi()
    }
    return KugouApi.instance
  }

  /**
   * 获取基础URL
   */
  private getBaseUrl(path: string): string {
    // 登录相关路径始终走云端
    if (path.startsWith('/login') || path.startsWith('/captcha') || path.startsWith('/register')) {
      return CLOUD_BASE_URL
    }
    return useLocalProxy ? LOCAL_BASE_URL : CLOUD_BASE_URL
  }

  /**
   * 构建认证头
   */
  private buildAuthHeaders(): Record<string, string> {
    const token = AppStorage.get<string>(AppStorageKeys.TOKEN) || ''
    const userid = AppStorage.get<string>(AppStorageKeys.USER_ID) || ''
    const vipToken = AppStorage.get<string>(AppStorageKeys.VIP_TOKEN) || ''

    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    }

    if (token) {
      const authParts: string[] = [`token=${token}`]
      if (userid) authParts.push(`userid=${userid}`)
      if (vipToken) authParts.push(`vip_token=${vipToken}`)
      headers['Authorization'] = authParts.join(';')
    }

    return headers
  }

  /**
   * 通用 GET 请求
   */
  private async get<T>(path: string, params?: Record<string, string>): Promise<T> {
    const baseUrl = this.getBaseUrl(path)
    let url = `${baseUrl}${path}`
    if (params) {
      const query = Object.entries(params)
        .filter(([_, v]) => v !== undefined && v !== '')
        .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
        .join('&')
      if (query) url += `?${query}`
    }

    const httpRequest = http.createHttp()
    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: this.buildAuthHeaders(),
        readTimeout: 15000,
        connectTimeout: 10000,
      })
      return JSON.parse(response.result as string) as T
    } finally {
      httpRequest.destroy()
    }
  }

  /**
   * 通用 POST 请求
   */
  private async post<T>(path: string, data?: Record<string, Object>): Promise<T> {
    const baseUrl = this.getBaseUrl(path)
    const url = `${baseUrl}${path}`

    const httpRequest = http.createHttp()
    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: this.buildAuthHeaders(),
        extraData: data ? JSON.stringify(data) : undefined,
        readTimeout: 15000,
        connectTimeout: 10000,
      })
      return JSON.parse(response.result as string) as T
    } finally {
      httpRequest.destroy()
    }
  }

  // ==================== 登录相关 API ====================

  /**
   * 获取二维码Key
   * 原始Flutter调用链: GET /login/qr/key → 云端 → login-user.kugou.com/v2/qrcode
   */
  async getQrKey(): Promise<Record<string, Object>> {
    return this.get('/login/qr/key')
  }

  /**
   * 生成二维码（含base64图片）
   * 原始: GET /login/qr/create?key=xxx&qrimg=1 → 本地qrcode库生成
   */
  async getQrCreate(key: string, qrimg: boolean = true): Promise<Record<string, Object>> {
    return this.get('/login/qr/create', { key, qrimg: String(qrimg) })
  }

  /**
   * 检查二维码扫码状态
   * 原始: GET /login/qr/check?key=xxx → 云端 → login-user.kugou.com/v2/get_userinfo_qrcode
   * 返回status: 0=等待, 1=已扫码, 2=已过期, 4=确认成功
   */
  async checkQrCode(key: string): Promise<Record<string, Object>> {
    return this.get('/login/qr/check', { key })
  }

  /**
   * 发送手机验证码
   * 原始: POST /captcha/sent → 云端 → login.user.kugou.com/v7/send_mobile_code
   */
  async sendCaptcha(mobile: string): Promise<Record<string, Object>> {
    return this.post('/captcha/sent', { mobile })
  }

  /**
   * 手机验证码登录
   * 原始: POST /login/cellphone → 云端 → loginserviceretry.kugou.com/v7/login_by_verifycode
   * 内部: AES加密手机号和验证码, RSA加密AES密钥
   */
  async loginByPhone(mobile: string, code: string): Promise<Record<string, Object>> {
    return this.post('/login/cellphone', { mobile, code })
  }

  /**
   * 获取用户详情
   * 原始: POST /user/detail → usercenter.kugou.com
   */
  async getUserDetail(): Promise<Record<string, Object>> {
    return this.post('/user/detail')
  }

  /**
   * 获取VIP详情
   * 原始: GET /user/vip/detail → kugouvip.kugou.com
   */
  async getVipDetail(): Promise<Record<string, Object>> {
    return this.get('/user/vip/detail')
  }

  /**
   * 设备注册
   * 原始: POST /register/dev → userservice.kugou.com
   */
  async registerDevice(): Promise<Record<string, Object>> {
    return this.post('/register/dev')
  }

  // ==================== 搜索相关 API ====================

  /**
   * 搜索歌曲
   * 原始: GET /search?keywords=xxx → kugou_api_server → songsearch.kugou.com/song_search_v2
   */
  async searchSongs(keyword: string, page: number = 1, pageSize: number = 30): Promise<Record<string, Object>> {
    return this.get('/search', { keyword, page: String(page), pagesize: String(pageSize) })
  }

  /**
   * 综合搜索（歌曲+专辑+歌手+歌单）
   * 原始: GET /search/complex → complexsearch.kugou.com/v6/search/complex
   */
  async searchComplex(keyword: string, page: number = 1, pageSize: number = 30): Promise<Record<string, Object>> {
    return this.get('/search/complex', { keyword, page: String(page), pagesize: String(pageSize) })
  }

  /**
   * 获取热搜列表
   * 原始: GET /search/hot → msearch.kugou.com/api/v3/search/hot_tab
   */
  async getHotSearch(): Promise<Record<string, Object>> {
    return this.get('/search/hot')
  }

  // ==================== 播放相关 API ====================

  /**
   * 获取歌曲播放URL
   * 原始调用链:
   *   1. POST /privilege/lite → media.store.kugou.com/v2/get_res_privilege/lite (获取权限)
   *   2. POST /audio → kmr.service.kugou.com/v1/audio/audio (获取CDN URL)
   * 鸿蒙版: 直接调用 /audio 接口，云端代理处理权限检查
   */
  async getSongUrl(hash: string, albumId: string = '', albumAudioId: string = ''): Promise<Record<string, Object>> {
    return this.post('/audio', {
      hash: hash,
      album_id: albumId,
      album_audio_id: albumAudioId,
    })
  }

  /**
   * 获取播放权限信息
   * 原始: POST /privilege/lite → media.store.kugou.com
   */
  async getPrivilege(hash: string, albumId: string = ''): Promise<Record<string, Object>> {
    return this.post('/privilege/lite', { hash, album_id: albumId })
  }

  /**
   * 获取歌词
   * 原始: GET /lyric?id=xxx&accesskey=xxx&decode=1&fmt=lrc → lyrics.kugou.com/download
   */
  async getLyric(id: number, accesskey: string): Promise<Record<string, Object>> {
    return this.get('/lyric', {
      id: String(id),
      accesskey,
      decode: '1',
      fmt: 'lrc',
    })
  }

  // ==================== 排行榜/推荐 API ====================

  /**
   * 获取排行榜列表
   * 原始: GET /rank/list → kugou_api_server
   */
  async getRankList(): Promise<Record<string, Object>> {
    return this.get('/rank/list')
  }

  /**
   * 获取排行榜歌曲
   * 原始: GET /rank/audio?rankid=xxx
   */
  async getRankSongs(rankId: string, page: number = 1): Promise<Record<string, Object>> {
    return this.get('/rank/audio', { rankid: rankId, page: String(page) })
  }

  /**
   * 每日推荐
   * 原始: GET /everyday/recommend
   */
  async getDailyRecommend(): Promise<Record<string, Object>> {
    return this.get('/everyday/recommend')
  }

  /**
   * 获取歌单详情
   * 原始: GET /playlist/detail
   */
  async getPlaylistDetail(id: string): Promise<Record<string, Object>> {
    return this.get('/playlist/detail', { id })
  }

  /**
   * 获取歌单所有歌曲
   * 原始: GET /playlist/track/all
   */
  async getPlaylistTracks(id: string, page: number = 1): Promise<Record<string, Object>> {
    return this.get('/playlist/track/all', { id, page: String(page) })
  }
}
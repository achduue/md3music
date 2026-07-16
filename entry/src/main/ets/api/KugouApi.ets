/**
 * ============================================================
 * 声明：本文件由 AI（TRAE 助手）辅助生成，尚未经过技术验证。
 * 代码未在真实 HarmonyOS 设备上编译运行，可能存在编译错误、
 * API 调用不正确等问题，请自行审查测试后使用。
 * 原始项目: https://github.com/zzyoxml/md3Music (Flutter/Android)
 * ============================================================
 */

/**
 * 酷狗音乐 API 客户端 v2.0
 * 修复: HTTP响应码检查、错误重试机制、超时优化
 *
 * 架构说明:
 * - 所有请求直连云端 115.29.236.96:5621
 * - 通过 Authorization 头传递认证信息
 * - 登录路径自动路由到云端
 */
import http from '@ohos.net.http'
import { Song } from '../models/Song'
import { AppStorageKeys } from '../common/Constants'

const CLOUD_BASE_URL = 'http://115.29.236.96:5621'
const REQUEST_TIMEOUT = 15000
const CONNECT_TIMEOUT = 10000
const MAX_RETRY = 2

export class KugouApi {
  private static instance: KugouApi
  private dfid: string = ''

  private constructor() {}

  static getInstance(): KugouApi {
    if (!KugouApi.instance) {
      KugouApi.instance = new KugouApi()
    }
    return KugouApi.instance
  }

  /**
   * 获取基础URL
   * 登录相关路径始终走云端
   */
  private getBaseUrl(path: string): string {
    if (path.startsWith('/login') || path.startsWith('/captcha') || path.startsWith('/register') ||
        path.startsWith('/user') || path.startsWith('/youth')) {
      return CLOUD_BASE_URL
    }
    return CLOUD_BASE_URL
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
      'Accept': 'application/json',
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
   * 修复: 响应码检查、重试机制
   */
  private async get<T>(path: string, params?: Record<string, string>, retryCount: number = 0): Promise<T> {
    const baseUrl = this.getBaseUrl(path)
    let url = `${baseUrl}${path}`
    if (params) {
      const query = Object.entries(params)
        .filter((entry: [string, string]) => entry[1] !== undefined && entry[1] !== '')
        .map((entry: [string, string]) => `${encodeURIComponent(entry[0])}=${encodeURIComponent(entry[1])}`)
        .join('&')
      if (query) url += `?${query}`
    }

    const httpRequest = http.createHttp()
    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: this.buildAuthHeaders(),
        readTimeout: REQUEST_TIMEOUT,
        connectTimeout: CONNECT_TIMEOUT,
      })

      // 检查HTTP响应码
      if (response.responseCode !== 200) {
        throw new Error(`HTTP ${response.responseCode}`)
      }

      const resultStr = response.result as string
      if (!resultStr) {
        throw new Error('Empty response')
      }

      return JSON.parse(resultStr) as T
    } catch (err) {
      // 重试逻辑
      if (retryCount < MAX_RETRY) {
        console.warn(`[API] GET ${path} failed (attempt ${retryCount + 1}), retrying...`)
        await new Promise<void>((resolve: () => void) => setTimeout(resolve, 500 * (retryCount + 1)))
        return this.get<T>(path, params, retryCount + 1)
      }
      throw new Error(`GET ${path} failed: ${(err as Error).message}`)
    } finally {
      httpRequest.destroy()
    }
  }

  /**
   * 通用 POST 请求
   * 修复: 响应码检查、重试机制
   */
  private async post<T>(path: string, data?: Record<string, string>, retryCount: number = 0): Promise<T> {
    const baseUrl = this.getBaseUrl(path)
    const url = `${baseUrl}${path}`

    const httpRequest = http.createHttp()
    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: this.buildAuthHeaders(),
        extraData: data ? JSON.stringify(data) : undefined,
        readTimeout: REQUEST_TIMEOUT,
        connectTimeout: CONNECT_TIMEOUT,
      })

      if (response.responseCode !== 200) {
        throw new Error(`HTTP ${response.responseCode}`)
      }

      const resultStr = response.result as string
      if (!resultStr) {
        throw new Error('Empty response')
      }

      return JSON.parse(resultStr) as T
    } catch (err) {
      if (retryCount < MAX_RETRY) {
        console.warn(`[API] POST ${path} failed (attempt ${retryCount + 1}), retrying...`)
        await new Promise<void>((resolve: () => void) => setTimeout(resolve, 500 * (retryCount + 1)))
        return this.post<T>(path, data, retryCount + 1)
      }
      throw new Error(`POST ${path} failed: ${(err as Error).message}`)
    } finally {
      httpRequest.destroy()
    }
  }

  // ==================== 登录相关 API ====================

  async getQrKey(): Promise<Record<string, Object>> {
    return this.get('/login/qr/key')
  }

  async getQrCreate(key: string, qrimg: boolean = true): Promise<Record<string, Object>> {
    const params: Record<string, string> = { 'key': key, 'qrimg': String(qrimg) }
    return this.get('/login/qr/create', params)
  }

  async checkQrCode(key: string): Promise<Record<string, Object>> {
    const params: Record<string, string> = { 'key': key }
    return this.get('/login/qr/check', params)
  }

  async sendCaptcha(mobile: string): Promise<Record<string, Object>> {
    const data: Record<string, string> = { 'mobile': mobile }
    return this.post('/captcha/sent', data)
  }

  async loginByPhone(mobile: string, code: string): Promise<Record<string, Object>> {
    const data: Record<string, string> = { 'mobile': mobile, 'code': code }
    return this.post('/login/cellphone', data)
  }

  async getUserDetail(): Promise<Record<string, Object>> {
    return this.post('/user/detail')
  }

  async getVipDetail(): Promise<Record<string, Object>> {
    return this.get('/user/vip/detail')
  }

  async registerDevice(): Promise<Record<string, Object>> {
    return this.post('/register/dev')
  }

  // ==================== 搜索相关 API ====================

  async searchSongs(keyword: string, page: number = 1, pageSize: number = 30): Promise<Record<string, Object>> {
    const params: Record<string, string> = {
      'keyword': keyword,
      'keywords': keyword,
      'page': String(page),
      'pagesize': String(pageSize)
    }
    return this.get('/search', params)
  }

  async searchComplex(keyword: string, page: number = 1, pageSize: number = 30): Promise<Record<string, Object>> {
    const params: Record<string, string> = {
      'keyword': keyword,
      'page': String(page),
      'pagesize': String(pageSize)
    }
    return this.get('/search/complex', params)
  }

  async getHotSearch(): Promise<Record<string, Object>> {
    return this.get('/search/hot')
  }

  // ==================== 播放相关 API ====================

  async getSongUrl(hash: string, albumId: string = '', albumAudioId: string = ''): Promise<Record<string, Object>> {
    const data: Record<string, string> = { 'hash': hash }
    if (albumId) data['album_id'] = albumId
    if (albumAudioId) data['album_audio_id'] = albumAudioId
    return this.post('/audio', data)
  }

  async getPrivilege(hash: string, albumId: string = ''): Promise<Record<string, Object>> {
    const data: Record<string, string> = { 'hash': hash, 'album_id': albumId }
    return this.post('/privilege/lite', data)
  }

  async getLyric(id: number, accesskey: string): Promise<Record<string, Object>> {
    const params: Record<string, string> = {
      'id': String(id),
      'accesskey': accesskey,
      'decode': '1',
      'fmt': 'lrc'
    }
    return this.get('/lyric', params)
  }

  // ==================== 排行榜/推荐 API ====================

  async getRankList(): Promise<Record<string, Object>> {
    return this.get('/rank/list')
  }

  async getRankSongs(rankId: string, page: number = 1): Promise<Record<string, Object>> {
    const params: Record<string, string> = {
      'rankid': rankId,
      'page': String(page),
      'pagesize': '30'
    }
    return this.get('/rank/audio', params)
  }

  async getDailyRecommend(): Promise<Record<string, Object>> {
    return this.get('/everyday/recommend')
  }

  async getPlaylistDetail(id: string): Promise<Record<string, Object>> {
    const params: Record<string, string> = { 'id': id }
    return this.get('/playlist/detail', params)
  }

  async getPlaylistTracks(id: string, page: number = 1): Promise<Record<string, Object>> {
    const params: Record<string, string> = {
      'id': id,
      'page': String(page),
      'pagesize': '30'
    }
    return this.get('/playlist/track/all', params)
  }

  // ==================== 用户歌单 API ====================

  async getUserPlaylists(): Promise<Record<string, Object>> {
    return this.post('/user/playlist')
  }

  // ==================== 个人 FM API ====================

  async getPersonalFm(): Promise<Record<string, Object>> {
    return this.get('/personal/fm')
  }
}
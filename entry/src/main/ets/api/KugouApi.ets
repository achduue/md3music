/**
 * 酷狗音乐 API 客户端
 * 所有请求通过云端服务器 http://115.29.236.96:5621 转发
 * 使用 @ohos.net.http 实现，超时 15s，失败自动重试 2 次
 */
import http from '@ohos.net.http'
import { AppStorageKeys } from '../common/Constants'

const CLOUD_BASE_URL: string = 'http://115.29.236.96:5621'
const REQUEST_TIMEOUT: number = 15000
const CONNECT_TIMEOUT: number = 10000
const MAX_RETRY: number = 2

export class KugouApi {
    private static instance: KugouApi

    private constructor() {
    }

    static getInstance(): KugouApi {
        if (!KugouApi.instance) {
            KugouApi.instance = new KugouApi()
        }
        return KugouApi.instance
    }

    /**
     * 从 AppStorage 读取 token/userid/vip_token 构建认证头
     */
    private buildAuthHeaders(): Record<string, string> {
        const token: string = AppStorage.get<string>(AppStorageKeys.TOKEN) || ''
        const userid: string = AppStorage.get<string>(AppStorageKeys.USER_ID) || ''
        const vipToken: string = AppStorage.get<string>(AppStorageKeys.VIP_TOKEN) || ''

        const headers: Record<string, string> = {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }

        if (token) {
            const authParts: string[] = [`token=${token}`]
            if (userid) {
                authParts.push(`userid=${userid}`)
            }
            if (vipToken) {
                authParts.push(`vip_token=${vipToken}`)
            }
            headers['Authorization'] = authParts.join(';')
        }

        return headers
    }

    /**
     * 拼接查询字符串（过滤空值）
     */
    private buildQueryString(params: Record<string, string>): string {
        const parts: string[] = []
        const keys: string[] = Object.keys(params)
        for (const key of keys) {
            const val: string = params[key]
            if (val !== undefined && val !== '') {
                parts.push(`${encodeURIComponent(key)}=${encodeURIComponent(val)}`)
            }
        }
        return parts.join('&')
    }

    /**
     * 通用 GET 请求（带重试）
     */
    private async get<T>(path: string, params?: Record<string, string>, retryCount: number = 0): Promise<T> {
        let url: string = `${CLOUD_BASE_URL}${path}`
        if (params) {
            const query: string = this.buildQueryString(params)
            if (query) {
                url += `?${query}`
            }
        }

        const httpRequest: http.HttpRequest = http.createHttp()
        try {
            const response: http.HttpResponse = await httpRequest.request(url, {
                method: http.RequestMethod.GET,
                header: this.buildAuthHeaders(),
                readTimeout: REQUEST_TIMEOUT,
                connectTimeout: CONNECT_TIMEOUT
            })

            if (response.responseCode !== 200) {
                throw new Error(`HTTP ${response.responseCode}`)
            }

            const resultStr: string = response.result as string
            if (!resultStr) {
                throw new Error('Empty response')
            }

            return JSON.parse(resultStr) as T
        } catch (err) {
            if (retryCount < MAX_RETRY) {
                console.warn(`[API] GET ${path} failed (attempt ${retryCount + 1}), retrying...`)
                await new Promise<void>((resolve: () => void) => {
                    setTimeout(() => {
                        resolve()
                    }, 500 * (retryCount + 1))
                })
                return this.get<T>(path, params, retryCount + 1)
            }
            throw new Error(`GET ${path} failed: ${(err as Error).message}`)
        } finally {
            httpRequest.destroy()
        }
    }

    /**
     * 通用 POST 请求（带重试）
     */
    private async post<T>(path: string, data?: Record<string, string>, retryCount: number = 0): Promise<T> {
        const url: string = `${CLOUD_BASE_URL}${path}`

        const httpRequest: http.HttpRequest = http.createHttp()
        try {
            const response: http.HttpResponse = await httpRequest.request(url, {
                method: http.RequestMethod.POST,
                header: this.buildAuthHeaders(),
                extraData: data ? JSON.stringify(data) : '',
                readTimeout: REQUEST_TIMEOUT,
                connectTimeout: CONNECT_TIMEOUT
            })

            if (response.responseCode !== 200) {
                throw new Error(`HTTP ${response.responseCode}`)
            }

            const resultStr: string = response.result as string
            if (!resultStr) {
                throw new Error('Empty response')
            }

            return JSON.parse(resultStr) as T
        } catch (err) {
            if (retryCount < MAX_RETRY) {
                console.warn(`[API] POST ${path} failed (attempt ${retryCount + 1}), retrying...`)
                await new Promise<void>((resolve: () => void) => {
                    setTimeout(() => {
                        resolve()
                    }, 500 * (retryCount + 1))
                })
                return this.post<T>(path, data, retryCount + 1)
            }
            throw new Error(`POST ${path} failed: ${(err as Error).message}`)
        } finally {
            httpRequest.destroy()
        }
    }

    // ==================== 登录相关 API ====================

    /** 获取二维码 key */
    async getQrKey(): Promise<Record<string, Object>> {
        return this.get<Record<string, Object>>('/login/qr/key')
    }

    /** 生成二维码图片（base64） */
    async getQrCreate(key: string, qrimg: boolean = true): Promise<Record<string, Object>> {
        const params: Record<string, string> = {
            'key': key,
            'qrimg': String(qrimg)
        }
        return this.get<Record<string, Object>>('/login/qr/create', params)
    }

    /** 轮询二维码扫码状态 */
    async checkQrCode(key: string): Promise<Record<string, Object>> {
        const params: Record<string, string> = { 'key': key }
        return this.get<Record<string, Object>>('/login/qr/check', params)
    }

    /** 发送手机验证码 */
    async sendCaptcha(mobile: string): Promise<Record<string, Object>> {
        const data: Record<string, string> = { 'mobile': mobile }
        return this.post<Record<string, Object>>('/captcha/sent', data)
    }

    /** 手机验证码登录 */
    async loginByPhone(mobile: string, code: string): Promise<Record<string, Object>> {
        const data: Record<string, string> = { 'mobile': mobile, 'code': code }
        return this.post<Record<string, Object>>('/login/cellphone', data)
    }

    /** 获取用户详情 */
    async getUserDetail(): Promise<Record<string, Object>> {
        return this.post<Record<string, Object>>('/user/detail')
    }

    /** 获取 VIP 详情 */
    async getVipDetail(): Promise<Record<string, Object>> {
        return this.get<Record<string, Object>>('/user/vip/detail')
    }

    /** 注册设备 */
    async registerDevice(): Promise<Record<string, Object>> {
        return this.post<Record<string, Object>>('/register/dev')
    }

    // ==================== 搜索相关 API ====================

    /** 搜索歌曲 */
    async searchSongs(keyword: string, page: number = 1, pageSize: number = 30): Promise<Record<string, Object>> {
        const params: Record<string, string> = {
            'keyword': keyword,
            'keywords': keyword,
            'page': String(page),
            'pagesize': String(pageSize)
        }
        return this.get<Record<string, Object>>('/search', params)
    }

    /** 获取热搜词 */
    async getHotSearch(): Promise<Record<string, Object>> {
        return this.get<Record<string, Object>>('/search/hot')
    }

    /** 搜索建议 */
    async getSearchSuggest(keyword: string): Promise<Record<string, Object>> {
        const params: Record<string, string> = { 'keyword': keyword }
        return this.get<Record<string, Object>>('/search/suggest', params)
    }

    // ==================== 播放相关 API ====================

    /** 获取歌曲播放地址 */
    async getSongUrl(hash: string, albumId: string = '', albumAudioId: string = ''): Promise<Record<string, Object>> {
        const data: Record<string, string> = { 'hash': hash }
        if (albumId) {
            data['album_id'] = albumId
        }
        if (albumAudioId) {
            data['album_audio_id'] = albumAudioId
        }
        return this.post<Record<string, Object>>('/audio', data)
    }

    /** 获取歌词 */
    async getLyric(id: number, accesskey: string): Promise<Record<string, Object>> {
        const params: Record<string, string> = {
            'id': String(id),
            'accesskey': accesskey,
            'decode': '1',
            'fmt': 'lrc'
        }
        return this.get<Record<string, Object>>('/lyric', params)
    }

    // ==================== 排行榜 / 推荐 API ====================

    /** 获取排行榜列表 */
    async getRankList(): Promise<Record<string, Object>> {
        return this.get<Record<string, Object>>('/rank/list')
    }

    /** 获取排行榜歌曲 */
    async getRankSongs(rankId: string, page: number = 1): Promise<Record<string, Object>> {
        const params: Record<string, string> = {
            'rankid': rankId,
            'page': String(page),
            'pagesize': '30'
        }
        return this.get<Record<string, Object>>('/rank/audio', params)
    }

    /** 每日推荐 */
    async getDailyRecommend(): Promise<Record<string, Object>> {
        return this.get<Record<string, Object>>('/everyday/recommend')
    }

    // ==================== 歌单 API ====================

    /** 获取歌单详情 */
    async getPlaylistDetail(id: string): Promise<Record<string, Object>> {
        const params: Record<string, string> = { 'id': id }
        return this.get<Record<string, Object>>('/playlist/detail', params)
    }

    /** 获取用户歌单 */
    async getUserPlaylists(): Promise<Record<string, Object>> {
        return this.post<Record<string, Object>>('/user/playlist')
    }

    // ==================== 个人 FM API ====================

    /** 获取个人 FM 歌曲 */
    async getPersonalFm(): Promise<Record<string, Object>> {
        return this.get<Record<string, Object>>('/personal/fm')
    }
}

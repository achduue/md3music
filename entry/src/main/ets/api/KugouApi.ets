/**
 * 酷狗音乐 API 客户端
 *
 * 架构说明：
 * - 登录相关 API 继续走远程代理服务器 LOGIN_BASE_URL（即 API_BASE_URL）。
 * - 搜索 / 排行榜 / 歌曲URL / 歌词 等核心 API 直连酷狗官方端点，无需签名。
 *
 * 使用 @ohos.net.http 发起请求，超时 15s，失败自动重试 2 次。
 * ArkTS 严格模式：所有响应统一为 Record<string, Object>，禁止 any/unknown，
 * 禁止 Object.entries()。
 */
import http from '@ohos.net.http'
import util from '@ohos.util'
import { API_BASE_URL, AppStorageKeys } from '../common/Constants'

const REQUEST_TIMEOUT: number = 15000
const CONNECT_TIMEOUT: number = 10000
const MAX_RETRY: number = 2

export class KugouApi {
    private static instance: KugouApi

    /** 酷狗官方搜索接口 */
    private readonly KUGOU_SEARCH_URL: string = 'https://songsearch.kugou.com/song_search_v2'
    /** 酷狗官方排行榜列表接口（URL 中已含 &json=true） */
    private readonly KUGOU_RANK_LIST_URL: string = 'https://m.kugou.com/rank/list&json=true'
    /** 酷狗官方排行榜详情接口 */
    private readonly KUGOU_RANK_INFO_URL: string = 'https://m.kugou.com/rank/info'
    /** 酷狗官方歌曲播放信息接口 */
    private readonly KUGOU_SONG_URL: string = 'https://m.kugou.com/app/i/getSongInfo.php'
    /** 酷狗官方歌词搜索接口 */
    private readonly KUGOU_LRC_SEARCH_URL: string = 'https://lyrics.kugou.com/search'
    /** 酷狗官方歌词下载接口 */
    private readonly KUGOU_LRC_DOWNLOAD_URL: string = 'https://lyrics.kugou.com/download'
    /** 登录相关 API 仍使用远程代理服务器 */
    private readonly LOGIN_BASE_URL: string = API_BASE_URL

    /** 直连酷狗官方接口时使用的请求头（模拟浏览器） */
    private readonly WEB_HEADERS: Record<string, string> = {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 12; HarmonyOS) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Mobile Safari/537.36',
        'Accept': 'application/json, text/plain, */*',
        'Referer': 'https://www.kugou.com/',
        'Content-Type': 'application/json'
    }

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
     * 仅用于调用登录代理服务器的接口
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
     * 使用 Object.keys() 迭代，避免使用 Object.entries()
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
     * 通用 HTTP 请求
     *
     * 自动根据 URL 选择请求头：
     * - URL 以 LOGIN_BASE_URL 开头 → 使用 buildAuthHeaders()（携带 token）
     * - 其他 URL（酷狗官方直连） → 使用 WEB_HEADERS（模拟浏览器 UA）
     *
     * @param method HTTP 方法，'GET' 或 'POST'
     * @param url    完整 URL
     * @param params GET 查询参数，会拼接到 URL 后
     * @param body   POST 请求体（JSON）
     * @returns 解析后的 JSON 对象
     */
    private async request(
        method: string,
        url: string,
        params?: Record<string, string>,
        body?: Record<string, string>
    ): Promise<Record<string, Object>> {
        let fullUrl: string = url
        if (params) {
            const query: string = this.buildQueryString(params)
            if (query) {
                fullUrl += (url.indexOf('?') >= 0 ? '&' : '?') + query
            }
        }

        // 登录代理服务器使用认证头，酷狗官方直连使用浏览器 UA
        const isLoginApi: boolean = url.indexOf(this.LOGIN_BASE_URL) === 0
        const finalHeaders: Record<string, string> = isLoginApi ? this.buildAuthHeaders() : this.WEB_HEADERS
        const isPost: boolean = method === 'POST'
        const postBody: string = body ? JSON.stringify(body) : ''

        let retryCount: number = 0
        let lastError: Error = new Error('Unknown error')

        while (retryCount <= MAX_RETRY) {
            const httpRequest: http.HttpRequest = http.createHttp()
            try {
                let response: http.HttpResponse
                if (isPost) {
                    response = await httpRequest.request(fullUrl, {
                        method: http.RequestMethod.POST,
                        header: finalHeaders,
                        extraData: postBody,
                        readTimeout: REQUEST_TIMEOUT,
                        connectTimeout: CONNECT_TIMEOUT
                    })
                } else {
                    response = await httpRequest.request(fullUrl, {
                        method: http.RequestMethod.GET,
                        header: finalHeaders,
                        readTimeout: REQUEST_TIMEOUT,
                        connectTimeout: CONNECT_TIMEOUT
                    })
                }

                if (response.responseCode !== 200) {
                    throw new Error(`HTTP ${response.responseCode}`)
                }

                const resultStr: string = response.result as string
                if (!resultStr) {
                    throw new Error('Empty response')
                }

                return JSON.parse(resultStr) as Record<string, Object>
            } catch (err) {
                lastError = err as Error
                console.warn(`[API] ${method} ${fullUrl} failed (attempt ${retryCount + 1}/${MAX_RETRY + 1}): ${lastError.message}`)
            } finally {
                httpRequest.destroy()
            }

            if (retryCount < MAX_RETRY) {
                const delay: number = 500 * (retryCount + 1)
                await new Promise<void>((resolve: () => void) => {
                    setTimeout(() => {
                        resolve()
                    }, delay)
                })
            }
            retryCount++
        }

        throw new Error(`${method} ${fullUrl} failed: ${lastError.message}`)
    }

    /**
     * 将 Uint8Array 按 UTF-8 编码转换为字符串
     * 由于 ArkTS 中 TextDecoder 可能不可用，这里手动实现 UTF-8 解码。
     * 支持 1~4 字节 UTF-8 序列（覆盖 ASCII / CJK / emoji），
     * 4 字节序列会转换为 UTF-16 代理对。
     */
    private utf8ArrayToString(arr: Uint8Array): string {
        let result: string = ''
        let i: number = 0
        while (i < arr.length) {
            const byte1: number = arr[i++]
            if (byte1 < 0x80) {
                // 1-byte sequence (ASCII)
                result += String.fromCharCode(byte1)
            } else if (byte1 < 0xC0) {
                // 非法前导字节，跳过
                result += '?'
            } else if (byte1 < 0xE0) {
                // 2-byte sequence
                const byte2: number = arr[i++]
                const code: number = ((byte1 & 0x1F) << 6) | (byte2 & 0x3F)
                result += String.fromCharCode(code)
            } else if (byte1 < 0xF0) {
                // 3-byte sequence（大部分中文字符）
                const byte2: number = arr[i++]
                const byte3: number = arr[i++]
                const code: number = ((byte1 & 0x0F) << 12) | ((byte2 & 0x3F) << 6) | (byte3 & 0x3F)
                result += String.fromCharCode(code)
            } else {
                // 4-byte sequence（emoji 等辅助平面字符）
                const byte2: number = arr[i++]
                const byte3: number = arr[i++]
                const byte4: number = arr[i++]
                const code: number = ((byte1 & 0x07) << 18) | ((byte2 & 0x3F) << 12) | ((byte3 & 0x3F) << 6) | (byte4 & 0x3F)
                // 转换为 UTF-16 代理对
                const surrogateOffset: number = code - 0x10000
                const high: number = 0xD800 + (surrogateOffset >> 10)
                const low: number = 0xDC00 + (surrogateOffset & 0x3FF)
                result += String.fromCharCode(high) + String.fromCharCode(low)
            }
        }
        return result
    }

    /**
     * 构造一个空的歌词结果对象
     */
    private emptyLyricResult(): Record<string, Object> {
        const empty: Record<string, Object> = {}
        empty['lyrics'] = ''
        return empty
    }

    // ==================== 登录相关 API（走远程代理服务器）====================

    /** 获取二维码 key */
    async getQrKey(): Promise<Record<string, Object>> {
        return this.request('GET', `${this.LOGIN_BASE_URL}/login/qr/key`)
    }

    /** 生成二维码图片（base64） */
    async getQrCreate(key: string, qrimg: boolean = true): Promise<Record<string, Object>> {
        const params: Record<string, string> = {
            'key': key,
            'qrimg': String(qrimg)
        }
        return this.request('GET', `${this.LOGIN_BASE_URL}/login/qr/create`, params)
    }

    /** 轮询二维码扫码状态 */
    async checkQrCode(key: string): Promise<Record<string, Object>> {
        const params: Record<string, string> = { 'key': key }
        return this.request('GET', `${this.LOGIN_BASE_URL}/login/qr/check`, params)
    }

    /** 发送手机验证码 */
    async sendCaptcha(mobile: string): Promise<Record<string, Object>> {
        const body: Record<string, string> = { 'mobile': mobile }
        return this.request('POST', `${this.LOGIN_BASE_URL}/send/captcha`, undefined, body)
    }

    /** 手机验证码登录 */
    async loginByPhone(mobile: string, captcha: string): Promise<Record<string, Object>> {
        const body: Record<string, string> = { 'mobile': mobile, 'captcha': captcha }
        return this.request('POST', `${this.LOGIN_BASE_URL}/login/cellphone`, undefined, body)
    }

    /** 获取用户详情（需要 Authorization 头） */
    async getUserDetail(): Promise<Record<string, Object>> {
        return this.request('GET', `${this.LOGIN_BASE_URL}/user/detail`)
    }

    /** 获取 VIP 详情（需要 Authorization 头） */
    async getVipDetail(): Promise<Record<string, Object>> {
        return this.request('GET', `${this.LOGIN_BASE_URL}/user/vip/detail`)
    }

    /** 注册设备 */
    async registerDevice(): Promise<Record<string, Object>> {
        return this.request('GET', `${this.LOGIN_BASE_URL}/register/dev`)
    }

    // ==================== 搜索相关 API（直连酷狗官方）====================

    /**
     * 搜索歌曲
     * GET https://songsearch.kugou.com/song_search_v2?keyword=XXX&page=1&pagesize=30&platform=WebFilter
     * 返回：{ status:1, data:{ lists:[{ FileHash, SongName, SingerName, AlbumName, AlbumID,
     *   Duration, Image300, FileID, Extra, Privilege, LrclistId }] } }
     */
    async searchSongs(keyword: string, page: number = 1, pageSize: number = 30): Promise<Record<string, Object>> {
        const params: Record<string, string> = {
            'keyword': keyword,
            'page': String(page),
            'pagesize': String(pageSize),
            'platform': 'WebFilter'
        }
        return this.request('GET', this.KUGOU_SEARCH_URL, params)
    }

    /**
     * 获取热搜词
     * 直连酷狗没有公开稳定的热搜接口，这里返回内置默认热搜词。
     * 返回格式：{ data: [{ word: '周杰伦', score: 100 }, ...] }
     */
    async getHotSearch(): Promise<Record<string, Object>> {
        const hotWords: Record<string, Object>[] = []
        const pairs: string[] = [
            '周杰伦', '林俊杰', '陈奕迅', '邓紫棋', '薛之谦',
            '毛不易', '华晨宇', '李荣浩', '隔壁老樊', '告五人'
        ]
        for (let i: number = 0; i < pairs.length; i++) {
            const entry: Record<string, Object> = {}
            entry['word'] = pairs[i]
            entry['score'] = 100 - i * 3
            hotWords.push(entry)
        }
        const result: Record<string, Object> = {}
        result['data'] = hotWords as Object
        return result
    }

    /**
     * 搜索建议
     * 复用搜索接口，pagesize=5，仅返回前 5 条。
     * 返回格式同 searchSongs：{ data: { lists: [...] } }
     */
    async getSearchSuggest(keyword: string): Promise<Record<string, Object>> {
        const params: Record<string, string> = {
            'keyword': keyword,
            'page': '1',
            'pagesize': '5',
            'platform': 'WebFilter'
        }
        return this.request('GET', this.KUGOU_SEARCH_URL, params)
    }

    // ==================== 排行榜 API（直连酷狗官方）====================

    /**
     * 获取排行榜列表
     * GET https://m.kugou.com/rank/list&json=true
     * 返回：{ rank:{ total:55, list:[{ rankid, rankname, intro, imgurl, picurl, update_frequency }] } }
     * 调用方通过 result['rank']['list'] 获取列表
     */
    async getRankList(): Promise<Record<string, Object>> {
        return this.request('GET', this.KUGOU_RANK_LIST_URL)
    }

    /**
     * 获取排行榜歌曲
     * GET https://m.kugou.com/rank/info&rankid=XXX&page=1&json=true
     * 返回：{ songs:{ list:[{ hash, filename, duration, album_id, ... }], ... }, info:{ rankname, ... } }
     * 调用方通过 result['songs']['list'] 获取歌曲列表
     */
    async getRankSongs(rankId: string, page: number = 1): Promise<Record<string, Object>> {
        // 注意：酷狗移动端 API 使用 '&' 而非 '?' 分隔首个参数，因此这里直接拼接
        const url: string = `${this.KUGOU_RANK_INFO_URL}&rankid=${encodeURIComponent(rankId)}&page=${encodeURIComponent(String(page))}&json=true`
        return this.request('GET', url)
    }

    // ==================== 歌曲播放 API（直连酷狗官方）====================

    /**
     * 获取歌曲播放地址
     * GET https://m.kugou.com/app/i/getSongInfo.php?cmd=playInfo&hash=XXX&album_audio_id=XXX&album_id=0
     * 返回：{ url:'https://sharefs.kugou.com/...mp3', status:1, songName, hash }
     * 注意：如果 status 为 0 或 url 为空，说明需要 VIP 或参数错误。
     */
    async getSongUrl(hash: string, albumId: string = '', albumAudioId: string = ''): Promise<Record<string, Object>> {
        const params: Record<string, string> = {
            'cmd': 'playInfo',
            'hash': hash,
            'album_audio_id': albumAudioId ? albumAudioId : '0',
            'album_id': albumId ? albumId : '0'
        }
        return this.request('GET', this.KUGOU_SONG_URL, params)
    }

    // ==================== 歌词 API（直连酷狗官方，两步）====================

    /**
     * 获取歌词
     * 步骤1：搜索歌词
     *   GET https://lyrics.kugou.com/search?ver=1&man=yes&client=pc&keyword=歌手-歌曲名&hash=XXX&duration=毫秒
     *   返回：{ status:200, candidates:[{ id, accesskey, singer, song, duration }] }
     * 步骤2：下载歌词
     *   GET https://lyrics.kugou.com/download?ver=1&client=pc&id=XXX&accesskey=XXX&fmt=lrc&charset=utf8
     *   返回：{ status:200, content:'base64编码的LRC歌词' }
     *
     * @param songName 歌曲名
     * @param artist   歌手名
     * @param hash     歌曲 hash
     * @param duration 歌曲时长（毫秒）
     * @returns { lyrics: '解码后的LRC内容' }，无匹配时 lyrics 为空字符串
     */
    async getLyric(songName: string, artist: string, hash: string, duration: number): Promise<Record<string, Object>> {
        // 步骤1: 搜索歌词
        const keyword: string = artist && songName ? `${artist}-${songName}` : (songName ? songName : artist)
        const searchParams: Record<string, string> = {
            'ver': '1',
            'man': 'yes',
            'client': 'pc',
            'keyword': keyword,
            'hash': hash,
            'duration': String(duration)
        }
        const searchResult: Record<string, Object> = await this.request('GET', this.KUGOU_LRC_SEARCH_URL, searchParams)

        const candidatesObj: Object | undefined = searchResult['candidates']
        if (!candidatesObj || !Array.isArray(candidatesObj)) {
            return this.emptyLyricResult()
        }
        const candidates: Object[] = candidatesObj as Object[]
        if (candidates.length === 0) {
            return this.emptyLyricResult()
        }

        const first: Record<string, Object> = candidates[0] as Record<string, Object>
        const id: string = String(first['id'] || '')
        const accesskey: string = (first['accesskey'] as string) || ''
        if (!id || !accesskey) {
            return this.emptyLyricResult()
        }

        // 步骤2: 下载歌词
        const downloadParams: Record<string, string> = {
            'ver': '1',
            'client': 'pc',
            'id': id,
            'accesskey': accesskey,
            'fmt': 'lrc',
            'charset': 'utf8'
        }
        const downloadResult: Record<string, Object> = await this.request('GET', this.KUGOU_LRC_DOWNLOAD_URL, downloadParams)

        const content: string = (downloadResult['content'] as string) || ''
        if (!content) {
            return this.emptyLyricResult()
        }

        // base64 解码 → Uint8Array → UTF-8 字符串
        const base64: util.Base64Helper = new util.Base64Helper()
        const decoded: Uint8Array = base64.decodeSync(content)
        const lrc: string = this.utf8ArrayToString(decoded)

        const result: Record<string, Object> = {}
        result['lyrics'] = lrc
        return result
    }

    // ==================== 推荐 API ====================

    /**
     * 每日推荐
     * 直接使用排行榜的第一个榜单作为推荐：
     * 调用 getRankList 获取第一个 rankid，再调用 getRankSongs 返回该榜单歌曲。
     */
    async getDailyRecommend(): Promise<Record<string, Object>> {
        const rankListResult: Record<string, Object> = await this.getRankList()
        const rankObj: Object | undefined = rankListResult['rank']
        if (!rankObj) {
            return rankListResult
        }
        const rank: Record<string, Object> = rankObj as Record<string, Object>
        const listObj: Object | undefined = rank['list']
        if (!listObj || !Array.isArray(listObj)) {
            return rankListResult
        }
        const list: Object[] = listObj as Object[]
        if (list.length === 0) {
            return rankListResult
        }
        const first: Record<string, Object> = list[0] as Record<string, Object>
        const rankId: string = String(first['rankid'] || '')
        if (!rankId) {
            return rankListResult
        }
        return this.getRankSongs(rankId, 1)
    }
}

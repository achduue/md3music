import http from '@ohos.net.http';
import { Base64Helper } from '@ohos.util';
import { API_BASE_URL, AppStorageKeys } from '../common/Constants';

export class KugouApi {
  private static instance: KugouApi = new KugouApi();
  private base64Helper: Base64Helper = new Base64Helper();

  private constructor() {
  }

  public static getInstance(): KugouApi {
    return KugouApi.instance;
  }

  private buildAuthHeaders(): Record<string, string> {
    const token: string = AppStorage.get<string>(AppStorageKeys.TOKEN) || '';
    const userId: string = AppStorage.get<string>(AppStorageKeys.USER_ID) || '';
    const vipToken: string = AppStorage.get<string>(AppStorageKeys.VIP_TOKEN) || '';
    return {
      'token': token,
      'userid': userId,
      'vip_token': vipToken,
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Safari/537.36',
      'Content-Type': 'application/json;charset=utf-8'
    };
  }

  private async request(url: string, method: http.RequestMethod,
    headers?: Record<string, string>, body?: string): Promise<Record<string, Object>> {
    const maxRetries: number = 2;
    let lastError: Error | null = null;

    for (let i = 0; i <= maxRetries; i++) {
      try {
        const result: Record<string, Object> = await new Promise<Record<string, Object>>(
          (resolve: (value: Record<string, Object>) => void,
            reject: (reason: Error) => void): void => {
            const httpRequest: http.HttpRequest = http.createHttp();
            httpRequest.request(url, {
              method: method,
              header: headers || {},
              extraData: body,
              connectTimeout: 15000,
              readTimeout: 15000,
              expectDataType: http.HttpDataType.STRING
            }).then((response: http.HttpResponse): void => {
              try {
                let resultObj: Record<string, Object>;
                if (typeof response.result === 'string') {
                  resultObj = JSON.parse(response.result) as Record<string, Object>;
                } else {
                  resultObj = response.result as Record<string, Object>;
                }
                resolve(resultObj);
              } catch (e) {
                reject(new Error('Failed to parse response: ' + String(e)));
              }
            }).catch((err: Error): void => {
              reject(err);
            }).finally((): void => {
              httpRequest.destroy();
            });
          });
        return result;
      } catch (e) {
        lastError = e instanceof Error ? e : new Error(String(e));
      }
    }
    throw lastError || new Error('Request failed after retries');
  }

  private async get(url: string, headers?: Record<string, string>): Promise<Record<string, Object>> {
    return this.request(url, http.RequestMethod.GET, headers, undefined);
  }

  private async post(url: string, body: Record<string, Object>,
    headers?: Record<string, string>): Promise<Record<string, Object>> {
    const reqHeaders: Record<string, string> = headers || {
      'Content-Type': 'application/json;charset=utf-8',
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36'
    };
    return this.request(url, http.RequestMethod.POST, reqHeaders, JSON.stringify(body));
  }

  private uint8ArrayToString(arr: Uint8Array): string {
    let result: string = '';
    for (let i = 0; i < arr.length; i++) {
      result += String.fromCharCode(arr[i]);
    }
    return result;
  }

  // ==================== 登录API ====================

  public async getQrKey(): Promise<Record<string, Object>> {
    return this.get(API_BASE_URL + '/login/qr/key');
  }

  public async getQrCreate(key: string, qrimg: boolean): Promise<Record<string, Object>> {
    return this.get(API_BASE_URL + '/login/qr/create?key=' + key + '&qrimg=' + String(qrimg));
  }

  public async checkQrCode(key: string): Promise<Record<string, Object>> {
    return this.get(API_BASE_URL + '/login/qr/check?key=' + key);
  }

  public async sendCaptcha(mobile: string): Promise<Record<string, Object>> {
    return this.post(API_BASE_URL + '/send/captcha', { 'mobile': mobile });
  }

  public async loginByPhone(mobile: string, captcha: string): Promise<Record<string, Object>> {
    return this.post(API_BASE_URL + '/login/cellphone', {
      'mobile': mobile,
      'captcha': captcha
    });
  }

  public async getUserDetail(): Promise<Record<string, Object>> {
    const headers: Record<string, string> = this.buildAuthHeaders();
    return this.get(API_BASE_URL + '/user/detail', headers);
  }

  public async getVipDetail(): Promise<Record<string, Object>> {
    const headers: Record<string, string> = this.buildAuthHeaders();
    return this.get(API_BASE_URL + '/user/vip/detail', headers);
  }

  public async registerDevice(): Promise<Record<string, Object>> {
    return this.get(API_BASE_URL + '/register/dev');
  }

  // ==================== 搜索API ====================

  public async searchSongs(keyword: string, page: number, pageSize: number): Promise<Record<string, Object>> {
    const url: string = 'https://songsearch.kugou.com/song_search_v2?keyword=' +
      encodeURIComponent(keyword) +
      '&page=' + String(page) +
      '&pagesize=' + String(pageSize) +
      '&platform=WebFilter';
    return this.get(url);
  }

  public getHotSearch(): Record<string, Object> {
    return {
      'data': [
        { 'word': '周杰伦', 'score': 100 },
        { 'word': '薛之谦', 'score': 98 },
        { 'word': '林俊杰', 'score': 95 },
        { 'word': '邓紫棋', 'score': 92 },
        { 'word': '陈奕迅', 'score': 90 },
        { 'word': '王菲', 'score': 88 },
        { 'word': '蔡徐坤', 'score': 85 },
        { 'word': '李荣浩', 'score': 82 },
        { 'word': '毛不易', 'score': 80 },
        { 'word': '张杰', 'score': 78 }
      ]
    };
  }

  // ==================== 排行榜API ====================

  public async getRankList(): Promise<Record<string, Object>> {
    return this.get('https://m.kugou.com/rank/list&json=true');
  }

  public async getRankSongs(rankId: string, page: number): Promise<Record<string, Object>> {
    return this.get('https://m.kugou.com/rank/info&rankid=' + rankId + '&page=' + String(page) + '&json=true');
  }

  // ==================== 歌曲播放API ====================

  public async getSongUrl(hash: string, albumId: string, albumAudioId: string): Promise<Record<string, Object>> {
    const url: string = 'https://m.kugou.com/app/i/getSongInfo.php&cmd=playInfo&hash=' + hash;
    return this.get(url);
  }

  // ==================== 歌词API ====================

  public async getLyric(songName: string, artist: string, hash: string,
    durationMs: number): Promise<Record<string, Object>> {
    try {
      const keyword: string = encodeURIComponent(artist + ' - ' + songName);
      const searchUrl: string = 'https://lyrics.kugou.com/search?ver=1&man=yes&client=pc&keyword=' +
        keyword + '&hash=' + hash + '&duration=' + String(durationMs);
      const searchResult: Record<string, Object> = await this.get(searchUrl);

      const candidates: Object[] = (searchResult['candidates'] as Object[]) || [];
      if (candidates.length === 0) {
        return { 'lyrics': '' };
      }

      const firstCandidate: Record<string, Object> = candidates[0] as Record<string, Object>;
      const id: string = String(firstCandidate['id'] || '');
      const accesskey: string = String(firstCandidate['accesskey'] || '');

      if (!id || !accesskey) {
        return { 'lyrics': '' };
      }

      const downloadUrl: string = 'https://lyrics.kugou.com/download?ver=1&client=pc&id=' +
        id + '&accesskey=' + accesskey + '&fmt=lrc&charset=utf8';
      const downloadResult: Record<string, Object> = await this.get(downloadUrl);

      const content: string = (downloadResult['content'] as string) || '';
      if (!content) {
        return { 'lyrics': '' };
      }

      const decodedBytes: Uint8Array = this.base64Helper.decodeSync(content);
      const lyrics: string = this.uint8ArrayToString(decodedBytes);
      return { 'lyrics': lyrics };
    } catch (e) {
      console.error('KugouApi getLyric error: ' + String(e));
      return { 'lyrics': '' };
    }
  }
}
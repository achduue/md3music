/**
 * ============================================================
 * 声明：本文件由 AI（TRAE 助手）辅助生成，尚未经过技术验证。
 * 代码未在真实 HarmonyOS 设备上编译运行，可能存在编译错误、
 * API 调用不正确等问题，请自行审查测试后使用。
 * 原始项目: https://github.com/zzyoxml/md3Music (Flutter/Android)
 * ============================================================
 */

/**
 * 歌曲数据模型 - 对应原Flutter版本 Song model
 * 修复: 统一字段命名，增强解析逻辑
 */
export class Song {
  id: string = ''          // 歌曲hash，唯一标识
  title: string = ''       // 歌曲名
  artist: string = ''      // 艺术家
  album: string = ''       // 专辑名
  duration: number = 0     // 时长（秒）
  url: string = ''         // 播放URL（解析后填充）
  artworkUri: string = ''  // 封面图URL
  isOnline: boolean = true // 是否为在线歌曲
  albumId: string = ''     // 专辑ID
  artistId: string = ''    // 艺术家ID
  albumAudioId: string = '' // 专辑音频ID
  hash: string = ''        // 酷狗hash（原始标识）
  fileId: number = 0       // 歌单中的文件ID
  privilege: number = 0    // 播放权限
  extra: string = ''       // 额外信息(320k/128k标识)
  lyricId: number = 0      // 歌词ID
  accesskey: string = ''   // 歌词访问key

  /**
   * 从酷狗搜索结果解析
   * 修复: 完善字段映射，处理 HTML 实体编码
   */
  static fromKugouSearch(item: Record<string, Object>): Song {
    const song = new Song()
    song.hash = (item['FileHash'] as string) || ''
    song.id = song.hash
    // 清理 HTML 实体编码 (酷狗返回的标题可能包含 &amp; 等)
    song.title = Song.decodeHtml((item['SongName'] as string) || '')
    song.artist = Song.decodeHtml((item['SingerName'] as string) || '')
    song.album = Song.decodeHtml((item['AlbumName'] as string) || '')
    song.albumId = String(item['AlbumID'] || '')
    song.duration = Number(item['Duration'] || 0)
    // 封面图处理：优先使用 300x300，回退到更小尺寸
    song.artworkUri = (item['Image300'] as string) ||
      (item['AlbumImg300'] as string) ||
      (item['Image'] as string) || ''
    song.fileId = Number(item['FileID'] || 0)
    song.extra = (item['Extra'] as string) || ''
    song.privilege = Number(item['Privilege'] || 0)
    song.lyricId = Number(item['LrclistId'] || 0)
    return song
  }

  /**
   * 从排行榜结果解析
   * 排行榜API返回的字段名可能不同
   */
  static fromKugouRank(item: Record<string, Object>): Song {
    const song = Song.fromKugouSearch(item)
    // 排行榜中可能有不同的字段名
    if (!song.hash) {
      song.hash = (item['hash'] as string) || (item['Hash'] as string) || ''
      song.id = song.hash
    }
    if (!song.title) song.title = Song.decodeHtml((item['songname'] as string) || (item['audio_name'] as string) || '')
    if (!song.artist) song.artist = Song.decodeHtml((item['singername'] as string) || (item['singer_name'] as string) || '')
    if (!song.album) song.album = Song.decodeHtml((item['albumname'] as string) || (item['album_name'] as string) || '')
    if (!song.duration) song.duration = Number(item['duration'] || item['timelength'] || 0)
    if (!song.albumId) song.albumId = String(item['albumid'] || item['album_id'] || '')
    return song
  }

  /**
   * 解析 HTML 实体编码
   */
  private static decodeHtml(text: string): string {
    if (!text) return ''
    return text
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/&apos;/g, "'")
  }

  /**
   * 从音频URL响应中提取播放地址
   * 修复: 增强多种响应格式的兼容性
   */
  static extractPlayUrl(result: Record<string, Object>): string {
    const data = result['data']
    if (!data) return ''

    // 格式1: { data: { url: "https://..." } }
    const dataObj = data as Record<string, Object>
    if (dataObj['url']) return (dataObj['url'] as string) || ''
    if (dataObj['play_url']) return (dataObj['play_url'] as string) || ''

    // 格式2: { data: { info: [{ url: "https://..." }] } }
    const info = dataObj['info']
    if (info) {
      if (Array.isArray(info)) {
        for (const item of info as Object[]) {
          const itemObj = item as Record<string, Object>
          const url = (itemObj['url'] as string) || (itemObj['play_url'] as string) || ''
          if (url) return url
        }
      } else {
        const infoObj = info as Record<string, Object>
        if (infoObj['url']) return (infoObj['url'] as string) || ''
      }
    }

    // 格式3: { data: [{ url: "https://..." }] }
    if (Array.isArray(data)) {
      for (const item of data as Object[]) {
        const itemObj = item as Record<string, Object>
        const url = (itemObj['url'] as string) || ''
        if (url) return url
      }
    }

    // 格式4: { data: { url_info: [{ url: "https://..." }] } }
    const urlInfo = dataObj['url_info']
    if (urlInfo && Array.isArray(urlInfo)) {
      for (const item of urlInfo as Object[]) {
        const itemObj = item as Record<string, Object>
        const url = (itemObj['url'] as string) || ''
        if (url) return url
      }
    }

    return ''
  }
}
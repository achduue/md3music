/**
 * 歌曲数据模型
 * 负责从酷狗搜索 / 排行榜响应中解析歌曲，并提取播放地址
 */

/**
 * 歌曲实体
 */
export class Song {
    id: string = ''
    title: string = ''
    artist: string = ''
    album: string = ''
    duration: number = 0
    url: string = ''
    artworkUri: string = ''
    isOnline: boolean = true
    albumId: string = ''
    artistId: string = ''
    quality: string = ''
    albumAudioId: string = ''
    hash: string = ''
    fileId: number = 0
    privilege: number = 0
    extra: string = ''
    lyricId: number = 0
    accesskey: string = ''

    /**
     * 从酷狗搜索结果解析
     * 字段名（搜索接口 /song_search_v2 的 lists 元素）：
     * FileHash, SongName, SingerName, AlbumName, AlbumID,
     * Duration, Image300, FileID, Extra, Privilege, LrclistId
     */
    static fromKugouSearch(item: Record<string, Object>): Song {
        const song: Song = new Song()
        song.hash = (item['FileHash'] as string) || ''
        song.id = song.hash
        song.title = Song.decodeHtml((item['SongName'] as string) || '')
        song.artist = Song.decodeHtml((item['SingerName'] as string) || '')
        song.album = Song.decodeHtml((item['AlbumName'] as string) || '')
        song.albumId = String(item['AlbumID'] || '')
        song.duration = Number(item['Duration'] || 0)
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
     * 从排行榜结果解析（兼容大小写字段名）
     * 排行榜接口字段命名不统一，此处对 hash / 标题 / 歌手 / 专辑 / 时长 / 专辑ID
     * 做大小写兼容回退。
     */
    static fromKugouRank(item: Record<string, Object>): Song {
        const song: Song = Song.fromKugouSearch(item)
        if (!song.hash) {
            song.hash = (item['hash'] as string) || (item['Hash'] as string) || ''
            song.id = song.hash
        }
        if (!song.title) {
            song.title = Song.decodeHtml(
                (item['songname'] as string) ||
                (item['audio_name'] as string) ||
                (item['SongName'] as string) || ''
            )
        }
        if (!song.artist) {
            song.artist = Song.decodeHtml(
                (item['singername'] as string) ||
                (item['singer_name'] as string) ||
                (item['SingerName'] as string) || ''
            )
        }
        if (!song.album) {
            song.album = Song.decodeHtml(
                (item['albumname'] as string) ||
                (item['album_name'] as string) ||
                (item['AlbumName'] as string) || ''
            )
        }
        if (!song.duration) {
            song.duration = Number(item['duration'] || item['timelength'] || 0)
        }
        if (!song.albumId) {
            song.albumId = String(item['albumid'] || item['album_id'] || '')
        }
        return song
    }

    /**
     * 从音频URL响应中提取播放地址
     * 依次检查：data.url、data.play_url、data.info[].url、data.info.play_url、
     * data 为数组时的 *.url、data.url_info[].url
     */
    static extractPlayUrl(result: Record<string, Object>): string {
        const data: Object | undefined = result['data']
        if (!data) {
            return ''
        }

        // data 作为对象
        const dataObj: Record<string, Object> = data as Record<string, Object>
        if (dataObj['url']) {
            return (dataObj['url'] as string) || ''
        }
        if (dataObj['play_url']) {
            return (dataObj['play_url'] as string) || ''
        }

        // data.info 可能是数组或对象
        const info: Object | undefined = dataObj['info']
        if (info) {
            if (Array.isArray(info)) {
                const infoArr: Object[] = info as Object[]
                for (const item of infoArr) {
                    const itemObj: Record<string, Object> = item as Record<string, Object>
                    const url: string = (itemObj['url'] as string) ||
                        (itemObj['play_url'] as string) || ''
                    if (url) {
                        return url
                    }
                }
            } else {
                const infoObj: Record<string, Object> = info as Record<string, Object>
                if (infoObj['url']) {
                    return (infoObj['url'] as string) || ''
                }
                if (infoObj['play_url']) {
                    return (infoObj['play_url'] as string) || ''
                }
            }
        }

        // data 本身是数组
        if (Array.isArray(data)) {
            const dataArr: Object[] = data as Object[]
            for (const item of dataArr) {
                const itemObj: Record<string, Object> = item as Record<string, Object>
                const url: string = (itemObj['url'] as string) ||
                    (itemObj['play_url'] as string) || ''
                if (url) {
                    return url
                }
            }
        }

        // data.url_info 数组
        const urlInfo: Object | undefined = dataObj['url_info']
        if (urlInfo && Array.isArray(urlInfo)) {
            const urlArr: Object[] = urlInfo as Object[]
            for (const item of urlArr) {
                const itemObj: Record<string, Object> = item as Record<string, Object>
                const url: string = (itemObj['url'] as string) || ''
                if (url) {
                    return url
                }
            }
        }

        return ''
    }

    /**
     * 解析 HTML 实体编码（使用简单字符串替换，避免引入额外依赖）
     */
    private static decodeHtml(text: string): string {
        if (!text) {
            return ''
        }
        let result: string = text
        result = Song.replaceAllStr(result, '&amp;', '&')
        result = Song.replaceAllStr(result, '&lt;', '<')
        result = Song.replaceAllStr(result, '&gt;', '>')
        result = Song.replaceAllStr(result, '&quot;', '"')
        result = Song.replaceAllStr(result, '&#39;', "'")
        result = Song.replaceAllStr(result, '&apos;', "'")
        return result
    }

    /**
     * 简单字符串替换（替换所有匹配项，不使用正则表达式）
     */
    private static replaceAllStr(text: string, search: string, replacement: string): string {
        if (!search) {
            return text
        }
        let result: string = text
        while (result.indexOf(search) >= 0) {
            result = result.replace(search, replacement)
        }
        return result
    }
}

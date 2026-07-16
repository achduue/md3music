/**
 * 歌曲数据模型
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
     */
    static fromKugouSearch(item: Record<string, Object>): Song {
        const song = new Song()
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
     * 从排行榜结果解析
     */
    static fromKugouRank(item: Record<string, Object>): Song {
        const song = Song.fromKugouSearch(item)
        if (!song.hash) {
            song.hash = (item['hash'] as string) || (item['Hash'] as string) || ''
            song.id = song.hash
        }
        if (!song.title) {
            song.title = Song.decodeHtml((item['songname'] as string) || (item['audio_name'] as string) || '')
        }
        if (!song.artist) {
            song.artist = Song.decodeHtml((item['singername'] as string) || (item['singer_name'] as string) || '')
        }
        if (!song.album) {
            song.album = Song.decodeHtml((item['albumname'] as string) || (item['album_name'] as string) || '')
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
     * 解析 HTML 实体编码（使用简单字符串替换）
     */
    private static decodeHtml(text: string): string {
        if (!text) return ''
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
        let result: string = text
        while (result.indexOf(search) >= 0) {
            result = result.replace(search, replacement)
        }
        return result
    }

    /**
     * 从音频URL响应中提取播放地址
     */
    static extractPlayUrl(result: Record<string, Object>): string {
        const data = result['data']
        if (!data) return ''

        const dataObj = data as Record<string, Object>
        if (dataObj['url']) return (dataObj['url'] as string) || ''
        if (dataObj['play_url']) return (dataObj['play_url'] as string) || ''

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

        if (Array.isArray(data)) {
            for (const item of data as Object[]) {
                const itemObj = item as Record<string, Object>
                const url = (itemObj['url'] as string) || ''
                if (url) return url
            }
        }

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

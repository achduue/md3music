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
  quality: string = '128'
  hash: string = ''
  albumAudioId: string = ''
  fileId: string = ''
  // 歌词关联
  lyricId: string = ''
  accesskey: string = ''

  static fromSearch(item: Record<string, Object>): Song {
    const s = new Song()
    s.hash = (item['FileHash'] as string) || ''
    s.title = Song.decodeHtml((item['SongName'] as string) || '')
    s.artist = Song.decodeHtml((item['SingerName'] as string) || '')
    s.album = Song.decodeHtml((item['AlbumName'] as string) || '')
    s.albumId = String((item['AlbumID'] as number) || 0)
    s.duration = (item['Duration'] as number) || 0
    s.artworkUri = (item['Image300'] as string) || (item['Img300'] as string) || ''
    s.fileId = String((item['FileID'] as number) || 0)
    s.albumAudioId = s.fileId
    s.id = s.hash
    return s
  }

  static fromRank(item: Record<string, Object>): Song {
    const s = new Song()
    s.hash = ((item['hash'] as string) || '').toUpperCase()
    const filename: string = (item['filename'] as string) || ''
    if (filename) {
      const sep: number = filename.indexOf(' - ')
      if (sep > 0) {
        s.artist = filename.substring(0, sep).trim()
        s.title = filename.substring(sep + 3).trim()
      } else {
        s.title = filename.trim()
      }
    }
    s.duration = (item['duration'] as number) || 0
    s.albumId = String((item['album_id'] as number) || 0)
    s.albumAudioId = String((item['album_audio_id'] as number) || s.albumId)
    s.id = s.hash
    return s
  }

  static extractUrl(result: Record<string, Object>): string {
    const url: string = (result['url'] as string) || ''
    if (url) return url
    const data: Record<string, Object> = (result['data'] as Record<string, Object>) || {}
    const dataUrl: string = (data['url'] as string) || (data['play_url'] as string) || ''
    if (dataUrl) return dataUrl
    return ''
  }

  static decodeHtml(text: string): string {
    if (!text) return ''
    let result = text
    result = Song.replaceAll(result, '&amp;', '&')
    result = Song.replaceAll(result, '&lt;', '<')
    result = Song.replaceAll(result, '&gt;', '>')
    result = Song.replaceAll(result, '&quot;', '"')
    result = Song.replaceAll(result, '&#39;', "'")
    result = Song.replaceAll(result, '&apos;', "'")
    return result
  }

  private static replaceAll(str: string, from: string, to: string): string {
    let result = str
    let idx = result.indexOf(from)
    while (idx >= 0) {
      result = result.substring(0, idx) + to + result.substring(idx + from.length)
      idx = result.indexOf(from, idx + to.length)
    }
    return result
  }
}
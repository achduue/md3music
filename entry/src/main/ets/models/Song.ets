/**
 * 歌曲数据模型 - 对应原Flutter版本 Song model
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

  static fromKugouSearch(item: Record<string, Object>): Song {
    const song = new Song();
    song.hash = (item['FileHash'] as string) || '';
    song.id = song.hash;
    song.title = (item['SongName'] as string) || '';
    song.artist = (item['SingerName'] as string) || '';
    song.album = (item['AlbumName'] as string) || '';
    song.albumId = String(item['AlbumID'] || '');
    song.duration = Number(item['Duration'] || 0);
    song.artworkUri = (item['Image300'] as string) || (item['AlbumImg300'] as string) || '';
    song.fileId = Number(item['FileID'] || 0);
    song.extra = (item['Extra'] as string) || '';
    song.privilege = Number(item['Privilege'] || 0);
    song.lrcId = Number(item['LrclistId'] || 0);
    return song;
  }

  static fromKugouPrivilege(item: Record<string, Object>): Partial<Song> {
    return {
      albumAudioId: String(item['album_audio_id'] || ''),
    };
  }

  static fromKugouAudio(item: Record<string, Object>): string {
    // 返回播放URL
    const urlInfo = item['url'] as string;
    return urlInfo || '';
  }
}
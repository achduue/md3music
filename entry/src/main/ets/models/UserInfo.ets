/**
 * 用户信息模型
 */
import { Song } from './Song'

export class UserInfo {
    userid: string = ''
    token: string = ''
    vipToken: string = ''
    vipType: number = 0
    userName: string = ''
    avatar: string = ''
    nickName: string = ''
    isVip: boolean = false
    vipExpireTime: number = 0
    isLoggedIn: boolean = false

    clear(): void {
        this.userid = ''
        this.token = ''
        this.vipToken = ''
        this.vipType = 0
        this.userName = ''
        this.avatar = ''
        this.nickName = ''
        this.isVip = false
        this.vipExpireTime = 0
        this.isLoggedIn = false
    }
}

/**
 * 歌单模型
 */
export class Playlist {
    id: string = ''
    name: string = ''
    description: string = ''
    artworkUri: string = ''
    songCount: number = 0
    creator: string = ''
    songs: Song[] = []
    playCount: number = 0
}

/**
 * 排行榜模型
 */
export class RankList {
    id: string = ''
    name: string = ''
    coverUrl: string = ''
    songList: Song[] = []
    updateTime: string = ''
    rankType: number = 0
}

/**
 * 歌词行
 */
export class LyricLine {
    time: number = 0
    text: string = ''
}

/**
 * 歌词数据
 */
export class LyricData {
    lines: LyricLine[] = []
    rawLrc: string = ''
}

/**
 * 热搜词
 */
export class HotWord {
    keyword: string = ''
    hotLevel: number = 0
}

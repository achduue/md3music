/**
 * 用户信息相关模型
 * 包含歌词、排行榜列表项、热搜词等数据结构
 */

/**
 * 歌词行
 */
export class LyricLine {
    time: number = 0
    text: string = ''

    constructor(time: number = 0, text: string = '') {
        this.time = time
        this.text = text
    }
}

/**
 * 歌词数据
 */
export class LyricData {
    rawLrc: string = ''
    lines: LyricLine[] = []
}

/**
 * 排行榜列表项
 * 从 /rank/list 响应解析，兼容常见的字段命名
 */
export class RankListItem {
    id: string = ''
    name: string = ''
    coverImg: string = ''
    intro: string = ''
    updateFrequency: string = ''
    sortId: number = 0

    /**
     * 从 Record<string, Object> 解析排行榜条目
     * 兼容字段：rankid/specialid、rankname/specialname、imgurl/picurl、
     * intro、update_frequency/updatefrequency、sortid
     */
    static fromRecord(item: Record<string, Object>): RankListItem {
        const rank: RankListItem = new RankListItem()
        rank.id = String(item['rankid'] || item['specialid'] || item['id'] || '')
        rank.name = (item['rankname'] as string) ||
            (item['specialname'] as string) ||
            (item['name'] as string) || ''
        rank.coverImg = (item['imgurl'] as string) ||
            (item['picurl'] as string) ||
            (item['coverImg'] as string) ||
            (item['img780'] as string) || ''
        rank.intro = (item['intro'] as string) || (item['description'] as string) || ''
        rank.updateFrequency = (item['update_frequency'] as string) ||
            (item['updatefrequency'] as string) ||
            (item['updateFrequency'] as string) || ''
        rank.sortId = Number(item['sortid'] || item['sortId'] || 0)
        return rank
    }
}

/**
 * 热搜词条目
 * 从 /search/hot 响应解析
 */
export class HotSearchItem {
    word: string = ''
    score: number = 0

    /**
     * 从 Record<string, Object> 解析热搜词
     * 兼容字段：word/keyword/searchword、score/hot/hotlevel
     */
    static fromRecord(item: Record<string, Object>): HotSearchItem {
        const hot: HotSearchItem = new HotSearchItem()
        hot.word = (item['word'] as string) ||
            (item['keyword'] as string) ||
            (item['searchword'] as string) || ''
        hot.score = Number(item['score'] || item['hot'] || item['hotlevel'] || 0)
        return hot
    }
}

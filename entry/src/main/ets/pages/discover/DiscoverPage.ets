/**
 * 排行榜详情页 - 显示排行榜内歌曲列表
 *
 * 流程:
 * 1. 从 AppStorage 获取 rank_id 和 rank_name
 * 2. 调用 KugouApi.getInstance().getRankSongs(rankId, page) 加载歌曲
 * 3. 解析响应：result['songs']['list'] as Record<string, Object>[]，每项用 Song.fromKugouRank() 解析
 * 4. 过滤无效歌曲（标题为空或时长为 0）
 * 5. 点击歌曲 → PlayerManager.playOnlinePlaylist()
 * 6. 支持分页加载更多（onReachEnd）
 */
import router from '@ohos.router'
import { KugouApi } from '../../api/KugouApi'
import { Song } from '../../models/Song'
import { PlayerManager } from '../../utils/PlayerManager'
import { AppStorageKeys, MD3Colors } from '../../common/Constants'
import { ImageUtils } from '../../utils/LocalStorage'

const PAGE_SIZE: number = 30

@Entry
@Component
struct DiscoverPage {
    @State rankName: string = ''
    @State rankId: string = ''
    @State songs: Song[] = []
    @State isLoading: boolean = true
    @State loadError: boolean = false

    @State page: number = 1
    @State hasMore: boolean = true
    @State isLoadingMore: boolean = false

    private player: PlayerManager = PlayerManager.getInstance()

    aboutToAppear(): void {
        this.rankName = AppStorage.get<string>(AppStorageKeys.RANK_NAME) || '排行榜'
        this.rankId = AppStorage.get<string>(AppStorageKeys.RANK_ID) || '6666'
        this.loadRankSongs()
    }

    /**
     * 加载排行榜歌曲（第一页）
     * API: GET /rank/audio?rankid=xxx&page=1
     */
    private async loadRankSongs(): Promise<void> {
        this.isLoading = true
        this.loadError = false
        this.page = 1
        this.hasMore = true
        try {
            const api: KugouApi = KugouApi.getInstance()
            const result: Record<string, Object> = await api.getRankSongs(this.rankId, this.page)
            this.songs = this.parseRankSongs(result)
            // 若返回数量小于页大小，说明没有更多了
            this.hasMore = this.songs.length >= PAGE_SIZE
        } catch (err) {
            console.error('加载排行榜失败:', err)
            this.loadError = true
        } finally {
            this.isLoading = false
        }
    }

    /**
     * 加载更多（分页）
     */
    private async loadMore(): Promise<void> {
        if (this.isLoadingMore || !this.hasMore) {
            return
        }
        this.isLoadingMore = true
        const nextPage: number = this.page + 1
        try {
            const api: KugouApi = KugouApi.getInstance()
            const result: Record<string, Object> = await api.getRankSongs(this.rankId, nextPage)
            const newSongs: Song[] = this.parseRankSongs(result)
            if (newSongs.length > 0) {
                this.songs = [...this.songs, ...newSongs]
                this.page = nextPage
                this.hasMore = newSongs.length >= PAGE_SIZE
            } else {
                this.hasMore = false
            }
        } catch (err) {
            console.error('加载更多失败:', err)
        } finally {
            this.isLoadingMore = false
        }
    }

    /**
     * 解析排行榜歌曲列表
     * 新API响应结构：result['songs']['list'] 为 Record<string, Object>[]，每项用 Song.fromKugouRank() 解析
     * 旧格式兼容：result['data']['info'] 为数组
     * 过滤无效歌曲（标题为空 / 为 "-" / 时长为 0）
     */
    private parseRankSongs(result: Record<string, Object>): Song[] {
        let arr: Record<string, Object>[] = []

        // 新API格式：result['songs']['list']
        const songs: Object | undefined = result['songs']
        if (songs) {
            const songsObj: Record<string, Object> = songs as Record<string, Object>
            const songsList: Object | undefined = songsObj['list']
            if (songsList && Array.isArray(songsList)) {
                arr = songsList as Record<string, Object>[]
            }
        }

        // 旧格式兼容：result['data']['info']
        if (arr.length === 0) {
            const data: Object | undefined = result['data']
            if (data) {
                const dataObj: Record<string, Object> = data as Record<string, Object>
                const info: Object | undefined = dataObj['info']
                if (info && Array.isArray(info)) {
                    arr = info as Record<string, Object>[]
                }
            }
        }

        return arr.map((item: Record<string, Object>) => Song.fromKugouRank(item))
            .filter((s: Song) => s.title !== '' && s.title !== '-' && s.duration > 0)
    }

    /**
     * 播放指定歌曲
     */
    private playSong(index: number): void {
        if (this.songs.length === 0) {
            return
        }
        this.player.playOnlinePlaylist(this.songs, index)
    }

    /**
     * 播放全部（从第一首开始）
     */
    private playAll(): void {
        if (this.songs.length === 0) {
            return
        }
        this.player.playOnlinePlaylist(this.songs, 0)
    }

    build() {
        Column() {
            // 顶部导航栏
            Row() {
                Button() {
                    Text('◀')
                        .fontSize(20)
                        .fontColor(MD3Colors.OnSurface)
                }
                .type(ButtonType.Circle)
                .backgroundColor('#00000000')
                .width(44)
                .height(44)
                .onClick(() => {
                    router.back()
                })

                Text(this.rankName)
                    .fontSize(20)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(MD3Colors.OnSurface)
                    .layoutWeight(1)
                    .textAlign(TextAlign.Center)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                Row().width(44).height(44)
            }
            .width('100%')
            .height(56)
            .padding({ left: 4, right: 4 })

            // 播放全部按钮
            if (this.songs.length > 0) {
                Row() {
                    Button() {
                        Row() {
                            Text('▶')
                                .fontSize(14)
                                .fontColor(MD3Colors.Primary)
                            Text(`播放全部 (${this.songs.length})`)
                                .fontSize(14)
                                .fontWeight(FontWeight.Medium)
                                .fontColor(MD3Colors.Primary)
                                .margin({ left: 6 })
                        }
                    }
                    .type(ButtonType.Capsule)
                    .backgroundColor(MD3Colors.PrimaryContainer)
                    .height(40)
                    .padding({ left: 20, right: 20 })
                    .onClick(() => {
                        this.playAll()
                    })
                }
                .width('100%')
                .padding({ left: 16, top: 4, bottom: 4 })
            }

            // 内容区域：加载中 / 加载失败 / 空 / 歌曲列表
            if (this.isLoading) {
                Column({ space: 12 }) {
                    LoadingProgress()
                        .width(40)
                        .height(40)
                        .color(MD3Colors.Primary)
                    Text('加载中...')
                        .fontSize(14)
                        .fontColor(MD3Colors.OnSurfaceVariant)
                }
                .width('100%')
                .layoutWeight(1)
                .justifyContent(FlexAlign.Center)
            } else if (this.loadError) {
                Column({ space: 12 }) {
                    Text('加载失败')
                        .fontSize(16)
                        .fontColor(MD3Colors.OnSurfaceVariant)
                    Button('重试')
                        .type(ButtonType.Capsule)
                        .height(40)
                        .fontSize(14)
                        .backgroundColor(MD3Colors.PrimaryContainer)
                        .fontColor(MD3Colors.Primary)
                        .onClick(() => {
                            this.loadRankSongs()
                        })
                }
                .width('100%')
                .layoutWeight(1)
                .justifyContent(FlexAlign.Center)
            } else if (this.songs.length === 0) {
                Column({ space: 12 }) {
                    Text('暂无歌曲')
                        .fontSize(16)
                        .fontColor(MD3Colors.OnSurfaceVariant)
                    Button('刷新')
                        .type(ButtonType.Capsule)
                        .height(40)
                        .fontSize(14)
                        .backgroundColor(MD3Colors.PrimaryContainer)
                        .fontColor(MD3Colors.Primary)
                        .onClick(() => {
                            this.loadRankSongs()
                        })
                }
                .width('100%')
                .layoutWeight(1)
                .justifyContent(FlexAlign.Center)
            } else {
                List({ space: 0 }) {
                    ForEach(this.songs, (song: Song, index: number) => {
                        ListItem() {
                            Row() {
                                // 排名序号（前 3 名高亮）
                                Text(String(index + 1))
                                    .fontSize(index < 3 ? 18 : 15)
                                    .fontWeight(index < 3 ? FontWeight.Bold : FontWeight.Normal)
                                    .fontColor(index < 3 ? MD3Colors.Primary : MD3Colors.OnSurfaceVariant)
                                    .width(32)
                                    .textAlign(TextAlign.Center)

                                // 封面
                                Image(song.artworkUri
                                    ? ImageUtils.getCoverUrl(song.artworkUri)
                                    : ImageUtils.DEFAULT_COVER)
                                    .width(44)
                                    .height(44)
                                    .borderRadius(8)
                                    .margin({ right: 12 })
                                    .interpolation(ImageInterpolation.Medium)

                                // 标题 / 歌手
                                Column({ space: 3 }) {
                                    Text(song.title)
                                        .fontSize(15)
                                        .fontWeight(FontWeight.Medium)
                                        .fontColor(MD3Colors.OnSurface)
                                        .maxLines(1)
                                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                                        .constraintSize({ maxWidth: '70%' })
                                    Text(song.artist)
                                        .fontSize(12)
                                        .fontColor(MD3Colors.OnSurfaceVariant)
                                        .maxLines(1)
                                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                                        .constraintSize({ maxWidth: '70%' })
                                }
                                .alignItems(HorizontalAlign.Start)
                                .layoutWeight(1)

                                // 时长
                                Text(PlayerManager.formatDuration(song.duration))
                                    .fontSize(12)
                                    .fontColor(MD3Colors.OnSurfaceVariant)
                                    .margin({ right: 12 })
                            }
                            .width('100%')
                            .height(68)
                            .padding({ left: 12, right: 12 })
                            .borderRadius(12)
                            .onClick(() => {
                                this.playSong(index)
                            })
                        }
                    }, (song: Song, index: number) => `${song.id || song.hash}_${index}`)

                    // 加载更多指示器
                    if (this.isLoadingMore) {
                        ListItem() {
                            Row({ space: 8 }) {
                                LoadingProgress()
                                    .width(24)
                                    .height(24)
                                    .color(MD3Colors.Primary)
                                Text('加载更多...')
                                    .fontSize(13)
                                    .fontColor(MD3Colors.OnSurfaceVariant)
                            }
                            .width('100%')
                            .height(56)
                            .justifyContent(FlexAlign.Center)
                        }
                    } else if (!this.hasMore) {
                        ListItem() {
                            Text('没有更多了')
                                .fontSize(13)
                                .fontColor(MD3Colors.OnSurfaceVariant)
                                .width('100%')
                                .height(48)
                                .textAlign(TextAlign.Center)
                        }
                    }
                }
                .layoutWeight(1)
                .scrollBar(BarState.Off)
                .padding({ top: 4, bottom: 16 })
                .onReachEnd(() => {
                    this.loadMore()
                })
            }
        }
        .width('100%')
        .height('100%')
        .backgroundColor(MD3Colors.Background)
    }
}

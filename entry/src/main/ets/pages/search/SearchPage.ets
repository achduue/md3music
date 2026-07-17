/**
 * 搜索结果页
 *
 * 搜索流程:
 * 1. 从 AppStorage 获取 search_keyword
 * 2. 调用 KugouApi.getInstance().searchSongs(keyword, page, 30) 搜索
 * 3. 解析响应：result['data']['lists'] as Record<string, Object>[]，每项用 Song.fromKugouSearch() 解析
 * 4. 过滤无效歌曲（标题为空 / 为 "-" / 时长为 0）
 * 5. 点击歌曲 → PlayerManager.playOnlinePlaylist()
 * 6. 支持分页加载更多（onReachEnd）
 * 7. 搜索框 onChange 更新 keyword，onSubmit 触发搜索
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
struct SearchPage {
    @State keyword: string = ''
    @State songs: Song[] = []
    @State isLoading: boolean = false
    @State hasSearched: boolean = false
    @State loadError: boolean = false

    @State page: number = 1
    @State hasMore: boolean = true
    @State isLoadingMore: boolean = false

    private player: PlayerManager = PlayerManager.getInstance()

    aboutToAppear(): void {
        this.keyword = AppStorage.get<string>(AppStorageKeys.SEARCH_KEYWORD) || ''
        if (this.keyword !== '') {
            this.doSearch()
        }
    }

    /**
     * 执行搜索（第一页）
     * API: GET /search?keyword=xxx&page=1&pagesize=30
     */
    private async doSearch(): Promise<void> {
        const trimmed: string = this.keyword.trim()
        if (trimmed === '') {
            return
        }

        this.isLoading = true
        this.hasSearched = true
        this.loadError = false
        this.page = 1
        this.hasMore = true

        try {
            const api: KugouApi = KugouApi.getInstance()
            const result: Record<string, Object> = await api.searchSongs(trimmed, this.page, PAGE_SIZE)
            this.songs = this.parseSearchSongs(result)
            this.hasMore = this.songs.length >= PAGE_SIZE
        } catch (err) {
            console.error('搜索失败:', err)
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
            const result: Record<string, Object> = await api.searchSongs(this.keyword, nextPage, PAGE_SIZE)
            const newSongs: Song[] = this.parseSearchSongs(result)
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
     * 解析搜索结果
     * 响应结构：result['data']['lists'] 为 Record<string, Object>[]，每项用 Song.fromKugouSearch() 解析
     * 过滤无效歌曲（标题为空 / 为 "-" / 时长为 0）
     */
    private parseSearchSongs(result: Record<string, Object>): Song[] {
        const data: Object | undefined = result['data']
        if (!data) {
            return []
        }
        const dataObj: Record<string, Object> = data as Record<string, Object>
        const lists: Object | undefined = dataObj['lists']
        if (!lists || !Array.isArray(lists)) {
            return []
        }
        const arr: Record<string, Object>[] = lists as Record<string, Object>[]
        return arr.map((item: Record<string, Object>) => Song.fromKugouSearch(item))
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
            // 搜索栏 + 返回按钮
            Row({ space: 8 }) {
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

                Search({ value: this.keyword, placeholder: '搜索歌曲、歌手、专辑' })
                    .width('100%')
                    .height(40)
                    .fontColor(MD3Colors.OnSurface)
                    .placeholderColor(MD3Colors.OnSurfaceVariant)
                    .backgroundColor(MD3Colors.SurfaceContainer)
                    .borderRadius(20)
                    .onChange((value: string) => {
                        this.keyword = value
                    })
                    .onSubmit((value: string) => {
                        this.keyword = value
                        this.doSearch()
                    })
            }
            .width('100%')
            .padding({ left: 4, right: 12, top: 8 })

            // 内容区域
            if (this.isLoading && this.songs.length === 0) {
                // 首次加载中
                Column({ space: 12 }) {
                    LoadingProgress()
                        .width(40)
                        .height(40)
                        .color(MD3Colors.Primary)
                    Text('搜索中...')
                        .fontSize(14)
                        .fontColor(MD3Colors.OnSurfaceVariant)
                }
                .width('100%')
                .layoutWeight(1)
                .justifyContent(FlexAlign.Center)
            } else if (this.loadError && this.songs.length === 0) {
                // 加载失败
                Column({ space: 12 }) {
                    Text('搜索失败')
                        .fontSize(16)
                        .fontColor(MD3Colors.OnSurfaceVariant)
                    Button('重试')
                        .type(ButtonType.Capsule)
                        .height(40)
                        .fontSize(14)
                        .backgroundColor(MD3Colors.PrimaryContainer)
                        .fontColor(MD3Colors.Primary)
                        .onClick(() => {
                            this.doSearch()
                        })
                }
                .width('100%')
                .layoutWeight(1)
                .justifyContent(FlexAlign.Center)
            } else if (this.songs.length === 0 && this.hasSearched) {
                // 无结果
                Column({ space: 8 }) {
                    Text('暂无搜索结果')
                        .fontSize(16)
                        .fontColor(MD3Colors.OnSurfaceVariant)
                    Text(`未找到与 "${this.keyword}" 相关的歌曲`)
                        .fontSize(13)
                        .fontColor(MD3Colors.OnSurfaceVariant)
                }
                .width('100%')
                .layoutWeight(1)
                .justifyContent(FlexAlign.Center)
            } else if (this.songs.length === 0) {
                // 空状态（未搜索）
                Column({ space: 8 }) {
                    Text('搜索音乐')
                        .fontSize(16)
                        .fontColor(MD3Colors.OnSurfaceVariant)
                    Text('输入歌曲名、歌手或专辑名开始搜索')
                        .fontSize(13)
                        .fontColor(MD3Colors.OnSurfaceVariant)
                }
                .width('100%')
                .layoutWeight(1)
                .justifyContent(FlexAlign.Center)
            } else {
                // 播放全部按钮
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

                // 搜索结果列表
                List({ space: 0 }) {
                    ForEach(this.songs, (song: Song, index: number) => {
                        ListItem() {
                            Row() {
                                // 序号
                                Text(String(index + 1))
                                    .fontSize(14)
                                    .fontColor(MD3Colors.OnSurfaceVariant)
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

                                // 标题 / 歌手 - 专辑
                                Column({ space: 3 }) {
                                    Text(song.title)
                                        .fontSize(15)
                                        .fontWeight(FontWeight.Medium)
                                        .fontColor(MD3Colors.OnSurface)
                                        .maxLines(1)
                                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                                        .constraintSize({ maxWidth: '70%' })
                                    Text(`${song.artist}${song.album ? ' - ' + song.album : ''}`)
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
                                    .margin({ right: 8 })

                                // 更多按钮
                                Button() {
                                    Text('⋯')
                                        .fontSize(20)
                                        .fontColor(MD3Colors.OnSurfaceVariant)
                                }
                                .type(ButtonType.Circle)
                                .backgroundColor('#00000000')
                                .width(36)
                                .height(36)
                            }
                            .width('100%')
                            .height(68)
                            .padding({ left: 8, right: 8 })
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

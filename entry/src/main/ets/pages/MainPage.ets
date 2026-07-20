/**
 * 主页面 - 底部 Tab 导航 + 迷你播放器
 *
 * 三个 Tab：
 * - 发现：顶部标题栏 + 排行榜区域（从 API 加载真实排行榜列表）+ 每日推荐
 * - 搜索：搜索框 + 热搜词（从 API 加载）+ 快捷搜索标签
 * - 我的：用户信息卡片 + 设置菜单（音质、播放模式、关于、退出登录）
 *
 * 底部区域（迷你播放器 + Tab 栏）通过 .overlay() 叠加在 Tabs 之上。
 * 迷你播放器通过 @StorageLink 监听 IS_PLAYING / CURRENT_SONG 状态。
 */
import router from '@ohos.router'
import { AppStorageKeys, MD3Colors, AudioQuality, PlayMode } from '../common/Constants'
import { PlayerManager } from '../utils/PlayerManager'
import { Song } from '../models/Song'
import { RankListItem, HotSearchItem } from '../models/UserInfo'
import { KugouApi } from '../api/KugouApi'
import { ImageUtils } from '../utils/LocalStorage'

const QUICK_SEARCH_TAGS: string[] = [
    '周杰伦', '薛之谦', '林俊杰', '邓紫棋', '陈奕迅', '毛不易', '李荣浩', '许嵩'
]

@Entry
@Component
struct MainPage {
    @State currentTab: number = 0
    @StorageLink(AppStorageKeys.IS_LOGGED_IN) isLoggedIn: boolean = false
    @StorageLink(AppStorageKeys.IS_PLAYING) isPlaying: boolean = false
    @StorageLink(AppStorageKeys.USER_NICKNAME) userNickname: string = ''
    @StorageLink(AppStorageKeys.USER_AVATAR) userAvatar: string = ''
    @StorageLink(AppStorageKeys.CURRENT_SONG) @Watch('onSongJsonChanged') currentSongJson: string = ''
    @StorageLink(AppStorageKeys.AUDIO_QUALITY) audioQuality: string = '128'
    @StorageLink(AppStorageKeys.PLAY_MODE) playMode: number = 0

    private player: PlayerManager = PlayerManager.getInstance()

    @State currentSong: Song = new Song()
    @State showMiniPlayer: boolean = false

    // 排行榜数据
    @State rankList: RankListItem[] = []
    @State isRankLoading: boolean = true
    @State rankLoadError: boolean = false

    // 热搜数据
    @State hotSearchList: HotSearchItem[] = []
    @State isHotSearchLoading: boolean = true

    aboutToAppear(): void {
        // 恢复当前歌曲状态
        if (this.currentSongJson) {
            this.currentSong = this.parseSongJson(this.currentSongJson)
            this.showMiniPlayer = this.currentSong.title !== ''
        }

        // 加载排行榜列表
        this.loadRankList()
        // 加载热搜词
        this.loadHotSearch()
    }

    /**
     * 监听 CURRENT_SONG 变化，更新迷你播放器
     */
    onSongJsonChanged(): void {
        if (this.currentSongJson) {
            this.currentSong = this.parseSongJson(this.currentSongJson)
            this.showMiniPlayer = this.currentSong.title !== ''
        } else {
            this.currentSong = new Song()
            this.showMiniPlayer = false
        }
    }

    /**
     * 将 JSON 字符串解析为 Song 对象（严格模式：逐字段赋值）
     */
    private parseSongJson(json: string): Song {
        if (!json) {
            return new Song()
        }
        try {
            const parsed: Object = JSON.parse(json)
            const obj: Record<string, Object> = parsed as Record<string, Object>
            const song: Song = new Song()
            song.id = (obj['id'] as string) || ''
            song.title = (obj['title'] as string) || ''
            song.artist = (obj['artist'] as string) || ''
            song.album = (obj['album'] as string) || ''
            song.duration = Number(obj['duration'] || 0)
            song.url = (obj['url'] as string) || ''
            song.artworkUri = (obj['artworkUri'] as string) || ''
            song.hash = (obj['hash'] as string) || ''
            song.albumId = (obj['albumId'] as string) || ''
            song.isOnline = true
            return song
        } catch (e) {
            console.warn('解析当前歌曲 JSON 失败')
            return new Song()
        }
    }

    /**
     * 加载排行榜列表
     * API: GET /rank/list
     */
    private async loadRankList(): Promise<void> {
        this.isRankLoading = true
        this.rankLoadError = false
        try {
            const api: KugouApi = KugouApi.getInstance()
            const result: Record<string, Object> = await api.getRankList()
            this.rankList = this.parseRankList(result)
        } catch (err) {
            console.error('加载排行榜失败:', err)
            this.rankLoadError = true
        } finally {
            this.isRankLoading = false
        }
    }

    /**
     * 解析排行榜列表响应
     * 新API响应结构：result['rank']['list'] 为 Record<string, Object>[]
     * 旧格式兼容：result['data'] 为数组，或对象包含 list/rank/ranks 字段
     */
    private parseRankList(result: Record<string, Object>): RankListItem[] {
        let arr: Record<string, Object>[] = []

        // 新API格式：result['rank']['list']
        const rank: Object | undefined = result['rank']
        if (rank) {
            const rankObj: Record<string, Object> = rank as Record<string, Object>
            const rankList: Object | undefined = rankObj['list']
            if (rankList && Array.isArray(rankList)) {
                arr = rankList as Record<string, Object>[]
            }
        }

        // 旧格式兼容：result['data']
        if (arr.length === 0) {
            const data: Object | undefined = result['data']
            if (data) {
                if (Array.isArray(data)) {
                    arr = data as Record<string, Object>[]
                } else {
                    const dataObj: Record<string, Object> = data as Record<string, Object>
                    const list: Object | undefined = dataObj['list'] || dataObj['rank'] || dataObj['ranks']
                    if (list && Array.isArray(list)) {
                        arr = list as Record<string, Object>[]
                    }
                }
            }
        }

        return arr.map((item: Record<string, Object>) => RankListItem.fromRecord(item))
            .filter((r: RankListItem) => r.id !== '' && r.name !== '')
    }

    /**
     * 加载热搜词
     * API: GET /search/hot
     */
    private async loadHotSearch(): Promise<void> {
        this.isHotSearchLoading = true
        try {
            const api: KugouApi = KugouApi.getInstance()
            const result: Record<string, Object> = await api.getHotSearch()
            this.hotSearchList = this.parseHotSearch(result)
        } catch (err) {
            console.error('加载热搜失败:', err)
        } finally {
            this.isHotSearchLoading = false
        }
    }

    /**
     * 解析热搜响应
     * 响应结构：result['data'] 为 Record<string, Object>[]，每项用 HotSearchItem.fromRecord() 解析
     */
    private parseHotSearch(result: Record<string, Object>): HotSearchItem[] {
        const data: Object | undefined = result['data']
        if (!data) {
            return []
        }
        let arr: Record<string, Object>[] = []
        if (Array.isArray(data)) {
            arr = data as Record<string, Object>[]
        } else {
            const dataObj: Record<string, Object> = data as Record<string, Object>
            const list: Object | undefined = dataObj['list'] || dataObj['hot'] || dataObj['items']
            if (list && Array.isArray(list)) {
                arr = list as Record<string, Object>[]
            }
        }
        return arr.map((item: Record<string, Object>) => HotSearchItem.fromRecord(item))
            .filter((h: HotSearchItem) => h.word !== '')
    }

    /**
     * 跳转到排行榜详情页
     */
    private goToRank(rank: RankListItem): void {
        AppStorage.setOrCreate(AppStorageKeys.RANK_ID, rank.id)
        AppStorage.setOrCreate(AppStorageKeys.RANK_NAME, rank.name)
        router.pushUrl({ url: 'pages/discover/DiscoverPage' })
    }

    /**
     * 跳转到搜索结果页
     */
    private goToSearch(keyword: string): void {
        const trimmed: string = keyword.trim()
        if (trimmed === '') {
            return
        }
        AppStorage.setOrCreate(AppStorageKeys.SEARCH_KEYWORD, trimmed)
        router.pushUrl({ url: 'pages/search/SearchPage' })
    }

    /**
     * 获取音质显示文本
     */
    private getQualityText(): string {
        if (this.audioQuality === AudioQuality.FLAC) {
            return '无损 FLAC'
        } else if (this.audioQuality === AudioQuality.HIGH) {
            return '高质 320kbps'
        } else {
            return '标准 128kbps'
        }
    }

    /**
     * 获取播放模式显示文本
     */
    private getPlayModeText(): string {
        if (this.playMode === PlayMode.SINGLE) {
            return '单曲循环'
        } else if (this.playMode === PlayMode.SHUFFLE) {
            return '随机播放'
        } else {
            return '列表循环'
        }
    }

    /**
     * 退出登录：清空用户相关存储
     */
    private logout(): void {
        AppStorage.setOrCreate(AppStorageKeys.IS_LOGGED_IN, false)
        AppStorage.setOrCreate(AppStorageKeys.TOKEN, '')
        AppStorage.setOrCreate(AppStorageKeys.USER_ID, '')
        AppStorage.setOrCreate(AppStorageKeys.VIP_TOKEN, '')
        AppStorage.setOrCreate(AppStorageKeys.USER_NICKNAME, '')
        AppStorage.setOrCreate(AppStorageKeys.USER_AVATAR, '')
    }

    build() {
        Tabs({ index: this.currentTab }) {
            TabContent() {
                this.DiscoverTabContent()
            }
            .tabBar(this.TabPlaceholder('发现', 0))

            TabContent() {
                this.SearchTabContent()
            }
            .tabBar(this.TabPlaceholder('搜索', 1))

            TabContent() {
                this.SettingsTabContent()
            }
            .tabBar(this.TabPlaceholder('我的', 2))
        }
        .barHeight(0)
        .scrollable(true)
        .barMode(BarMode.Fixed)
        .barWidth('100%')
        .animationDuration(300)
        .onChange((index: number) => {
            this.currentTab = index
        })
        .overlay(this.BottomSection())
    }

    // ==================== 底部区域（迷你播放器 + Tab 栏） ====================

    @Builder
    TabPlaceholder(title: string, index: number) {
        Column() {
            Text(title)
                .fontSize(12)
                .fontColor(this.currentTab === index ? MD3Colors.Primary : MD3Colors.OnSurfaceVariant)
        }
        .width('100%')
        .height(0)
    }

    @Builder
    BottomSection() {
        Column() {
            // 迷你播放器（有歌曲播放时显示）
            if (this.showMiniPlayer) {
                this.MiniPlayer()
            }
            // 底部 Tab 栏
            this.BottomTabBar()
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .position({ x: 0, y: '100%' })
        .translate({ y: '-100%' })
    }

    @Builder
    MiniPlayer() {
        Row() {
            // 封面
            Image(this.currentSong.artworkUri
                ? ImageUtils.getCoverUrl(this.currentSong.artworkUri)
                : ImageUtils.DEFAULT_COVER)
                .width(44)
                .height(44)
                .borderRadius(8)
                .shadow({ radius: 4, color: '#15000000', offsetX: 0, offsetY: 2 })
                .interpolation(ImageInterpolation.Medium)

            // 歌曲名 / 歌手
            Column({ space: 2 }) {
                Text(this.currentSong.title || '未在播放')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(MD3Colors.OnSurface)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .constraintSize({ maxWidth: '55%' })
                Text(this.currentSong.artist || '')
                    .fontSize(12)
                    .fontColor(MD3Colors.OnSurfaceVariant)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .constraintSize({ maxWidth: '55%' })
            }
            .alignItems(HorizontalAlign.Start)
            .margin({ left: 12 })
            .layoutWeight(1)

            // 播放 / 暂停按钮
            Button() {
                Text(this.isPlaying ? '⏸' : '▶')
                    .fontSize(18)
                    .fontColor(MD3Colors.OnSurface)
            }
            .type(ButtonType.Circle)
            .backgroundColor('#00000000')
            .width(40)
            .height(40)
            .margin({ right: 4 })
            .onClick(() => {
                this.player.togglePlay()
            })

            // 下一曲按钮
            Button() {
                Text('▶▶')
                    .fontSize(14)
                    .fontColor(MD3Colors.OnSurface)
            }
            .type(ButtonType.Circle)
            .backgroundColor('#00000000')
            .width(40)
            .height(40)
            .onClick(() => {
                this.player.next()
            })
        }
        .width('100%')
        .height(64)
        .padding({ left: 16, right: 12 })
        .backgroundColor(MD3Colors.PrimaryContainer)
        .borderRadius({ topLeft: 16, topRight: 16 })
        .shadow({ radius: 8, color: '#20000000', offsetX: 0, offsetY: -2 })
        .onClick(() => {
            router.pushUrl({ url: 'pages/player/PlayerPage' })
        })
    }

    @Builder
    BottomTabBar() {
        Row() {
            this.BottomTab('发现', 0)
            this.BottomTab('搜索', 1)
            this.BottomTab('我的', 2)
        }
        .width('100%')
        .height(56)
        .backgroundColor(MD3Colors.Surface)
        .padding({ top: 4, bottom: 4 })
        .shadow({ radius: 8, color: '#0F000000', offsetX: 0, offsetY: -1 })
    }

    @Builder
    BottomTab(title: string, index: number) {
        Column() {
            Text(title)
                .fontSize(13)
                .fontWeight(this.currentTab === index ? FontWeight.Medium : FontWeight.Normal)
                .fontColor(this.currentTab === index ? MD3Colors.Primary : MD3Colors.OnSurfaceVariant)
        }
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
        .height('100%')
        .onClick(() => {
            this.currentTab = index
        })
    }

    // ==================== 发现页内容 ====================

    @Builder
    DiscoverTabContent() {
        Column() {
            // 顶部标题栏
            Row() {
                Text('发现')
                    .fontSize(24)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(MD3Colors.OnSurface)
                    .layoutWeight(1)

                if (this.isLoggedIn && this.userAvatar) {
                    Image(ImageUtils.getCoverUrl(this.userAvatar))
                        .width(32)
                        .height(32)
                        .borderRadius(16)
                        .onClick(() => {
                            router.pushUrl({ url: 'pages/settings/SettingsPage' })
                        })
                } else {
                    Button('登录')
                        .type(ButtonType.Capsule)
                        .height(32)
                        .fontSize(13)
                        .backgroundColor(MD3Colors.SecondaryContainer)
                        .fontColor(MD3Colors.Secondary)
                        .onClick(() => {
                            router.pushUrl({ url: 'pages/login/LoginPage' })
                        })
                }
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 8 })

            // 内容滚动区
            Scroll() {
                Column({ space: 24 }) {
                    // 排行榜区域标题
                    Text('排行榜')
                        .fontSize(20)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(MD3Colors.OnSurface)
                        .width('100%')
                        .padding({ left: 16 })

                    // 排行榜卡片
                    if (this.isRankLoading) {
                        Row({ space: 8 }) {
                            LoadingProgress()
                                .width(28)
                                .height(28)
                                .color(MD3Colors.Primary)
                            Text('加载排行榜...')
                                .fontSize(14)
                                .fontColor(MD3Colors.OnSurfaceVariant)
                        }
                        .width('100%')
                        .justifyContent(FlexAlign.Center)
                        .padding({ top: 32, bottom: 32 })
                    } else if (this.rankLoadError) {
                        Column({ space: 12 }) {
                            Text('排行榜加载失败')
                                .fontSize(14)
                                .fontColor(MD3Colors.OnSurfaceVariant)
                            Button('重试')
                                .type(ButtonType.Capsule)
                                .height(36)
                                .fontSize(13)
                                .backgroundColor(MD3Colors.PrimaryContainer)
                                .fontColor(MD3Colors.Primary)
                                .onClick(() => {
                                    this.loadRankList()
                                })
                        }
                        .width('100%')
                        .alignItems(HorizontalAlign.Center)
                        .padding({ top: 32, bottom: 32 })
                    } else if (this.rankList.length === 0) {
                        Text('暂无排行榜数据')
                            .fontSize(14)
                            .fontColor(MD3Colors.OnSurfaceVariant)
                            .width('100%')
                            .textAlign(TextAlign.Center)
                            .padding({ top: 32, bottom: 32 })
                    } else {
                        // 排行榜卡片横向滚动
                        Scroll() {
                            Row({ space: 12 }) {
                                ForEach(this.rankList, (rank: RankListItem, index: number) => {
                                    this.RankCard(rank)
                                }, (rank: RankListItem) => rank.id)
                            }
                            .padding({ left: 16, right: 16 })
                        }
                        .scrollable(ScrollDirection.Horizontal)
                        .scrollBar(BarState.Off)
                    }

                    // 每日推荐区域标题
                    Text('每日推荐')
                        .fontSize(20)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(MD3Colors.OnSurface)
                        .width('100%')
                        .padding({ left: 16 })

                    // 每日推荐卡片
                    Row() {
                        Column({ space: 8 }) {
                            Text('登录后查看个性化推荐')
                                .fontSize(14)
                                .fontColor(MD3Colors.OnSurfaceVariant)
                            if (!this.isLoggedIn) {
                                Button('去登录')
                                    .type(ButtonType.Capsule)
                                    .height(36)
                                    .fontSize(13)
                                    .backgroundColor(MD3Colors.Primary)
                                    .fontColor(MD3Colors.OnPrimary)
                                    .onClick(() => {
                                        router.pushUrl({ url: 'pages/login/LoginPage' })
                                    })
                            }
                        }
                        .width('100%')
                        .alignItems(HorizontalAlign.Center)
                        .padding({ top: 16, bottom: 16 })
                    }
                    .width('100%')
                    .margin({ left: 16, right: 16 })
                    .borderRadius(16)
                    .backgroundColor(MD3Colors.SurfaceContainerLow)
                    .padding({ left: 16, right: 16 })
                }
                .padding({ bottom: this.showMiniPlayer ? 140 : 76 })
            }
            .layoutWeight(1)
            .scrollBar(BarState.Off)
        }
        .width('100%')
        .height('100%')
        .backgroundColor(MD3Colors.Background)
    }

    @Builder
    RankCard(rank: RankListItem) {
        Column() {
            // 排行榜封面
            Image(ImageUtils.getCoverUrl(rank.coverImg))
                .width(108)
                .height(108)
                .borderRadius(16)
                .interpolation(ImageInterpolation.Medium)
                .shadow({ radius: 12, color: '#25000000', offsetX: 0, offsetY: 4 })

            Text(rank.name)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(MD3Colors.OnSurface)
                .margin({ top: 6 })
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .constraintSize({ maxWidth: 108 })

            if (rank.updateFrequency) {
                Text(rank.updateFrequency)
                    .fontSize(11)
                    .fontColor(MD3Colors.OnSurfaceVariant)
                    .maxLines(1)
                    .margin({ top: 2 })
            }
        }
        .alignItems(HorizontalAlign.Center)
        .width(108)
        .onClick(() => {
            this.goToRank(rank)
        })
    }

    // ==================== 搜索页内容 ====================

    @Builder
    SearchTabContent() {
        Column() {
            // 搜索栏
            Row({ space: 12 }) {
                Search({ placeholder: '搜索歌曲、歌手、专辑' })
                    .width('100%')
                    .height(40)
                    .fontColor(MD3Colors.OnSurface)
                    .placeholderColor(MD3Colors.OnSurfaceVariant)
                    .backgroundColor(MD3Colors.SurfaceContainer)
                    .borderRadius(20)
                    .onSubmit((value: string) => {
                        this.goToSearch(value)
                    })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12 })

            // 内容滚动区
            Scroll() {
                Column({ space: 20 }) {
                    // 热搜区域
                    Column({ space: 12 }) {
                        Text('热搜榜')
                            .fontSize(18)
                            .fontWeight(FontWeight.Bold)
                            .fontColor(MD3Colors.OnSurface)

                        if (this.isHotSearchLoading) {
                            Row({ space: 8 }) {
                                LoadingProgress()
                                    .width(24)
                                    .height(24)
                                    .color(MD3Colors.Primary)
                                Text('加载热搜...')
                                    .fontSize(13)
                                    .fontColor(MD3Colors.OnSurfaceVariant)
                            }
                            .padding({ top: 16 })
                        } else if (this.hotSearchList.length > 0) {
                            ForEach(this.hotSearchList, (item: HotSearchItem, index: number) => {
                                Row() {
                                    Text(String(index + 1))
                                        .fontSize(14)
                                        .fontWeight(index < 3 ? FontWeight.Bold : FontWeight.Normal)
                                        .fontColor(index < 3 ? MD3Colors.Primary : MD3Colors.OnSurfaceVariant)
                                        .width(24)
                                        .textAlign(TextAlign.Center)
                                    Text(item.word)
                                        .fontSize(14)
                                        .fontColor(MD3Colors.OnSurface)
                                        .layoutWeight(1)
                                        .maxLines(1)
                                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                                        .margin({ left: 8 })
                                }
                                .width('100%')
                                .height(40)
                                .padding({ left: 8, right: 8 })
                                .borderRadius(8)
                                .onClick(() => {
                                    this.goToSearch(item.word)
                                })
                            }, (item: HotSearchItem, index: number) => `${item.word}_${index}`)
                        } else {
                            Text('暂无热搜数据')
                                .fontSize(13)
                                .fontColor(MD3Colors.OnSurfaceVariant)
                                .padding({ top: 16 })
                        }
                    }
                    .width('100%')
                    .padding({ left: 16, right: 16 })
                    .alignItems(HorizontalAlign.Start)

                    // 快捷搜索标签
                    Column({ space: 12 }) {
                        Text('快捷搜索')
                            .fontSize(18)
                            .fontWeight(FontWeight.Bold)
                            .fontColor(MD3Colors.OnSurface)

                        Flex({ wrap: FlexWrap.Wrap }) {
                            ForEach(QUICK_SEARCH_TAGS, (tag: string, index: number) => {
                                Text(tag)
                                    .fontSize(14)
                                    .fontColor(MD3Colors.OnSurfaceVariant)
                                    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                                    .borderRadius(20)
                                    .backgroundColor(MD3Colors.SurfaceVariant)
                                    .margin({ right: 8, bottom: 8 })
                                    .onClick(() => {
                                        this.goToSearch(tag)
                                    })
                            }, (tag: string, index: number) => `${tag}_${index}`)
                        }
                        .width('100%')
                    }
                    .width('100%')
                    .padding({ left: 16, right: 16 })
                    .alignItems(HorizontalAlign.Start)
                }
                .padding({ bottom: this.showMiniPlayer ? 140 : 76 })
            }
            .layoutWeight(1)
            .scrollBar(BarState.Off)
        }
        .width('100%')
        .height('100%')
        .backgroundColor(MD3Colors.Background)
    }

    // ==================== 我的页内容 ====================

    @Builder
    SettingsTabContent() {
        Column() {
            // 标题
            Text('我的')
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor(MD3Colors.OnSurface)
                .width('100%')
                .padding({ left: 16, right: 16, top: 16, bottom: 8 })

            Scroll() {
                Column({ space: 16 }) {
                    // 用户信息卡片
                    Row() {
                        if (this.isLoggedIn) {
                            Image(this.userAvatar
                                ? ImageUtils.getCoverUrl(this.userAvatar)
                                : ImageUtils.DEFAULT_COVER)
                                .width(56)
                                .height(56)
                                .borderRadius(28)
                                .shadow({ radius: 8, color: '#20000000', offsetX: 0, offsetY: 2 })
                            Column({ space: 4 }) {
                                Text(this.userNickname || '酷狗用户')
                                    .fontSize(18)
                                    .fontWeight(FontWeight.Bold)
                                    .fontColor(MD3Colors.OnSurface)
                                Text('已登录')
                                    .fontSize(13)
                                    .fontColor(MD3Colors.Primary)
                            }
                            .alignItems(HorizontalAlign.Start)
                            .margin({ left: 16 })
                            .layoutWeight(1)
                        } else {
                            Image(ImageUtils.DEFAULT_COVER)
                                .width(56)
                                .height(56)
                                .borderRadius(28)
                            Column({ space: 4 }) {
                                Text('未登录')
                                    .fontSize(18)
                                    .fontWeight(FontWeight.Bold)
                                    .fontColor(MD3Colors.OnSurface)
                                Text('点击登录账号')
                                    .fontSize(13)
                                    .fontColor(MD3Colors.OnSurfaceVariant)
                            }
                            .alignItems(HorizontalAlign.Start)
                            .margin({ left: 16 })
                            .layoutWeight(1)
                        }

                        Text('›')
                            .fontSize(24)
                            .fontColor(MD3Colors.Outline)
                    }
                    .width('100%')
                    .padding(16)
                    .borderRadius(20)
                    .backgroundColor(MD3Colors.SurfaceContainerLow)
                    .shadow({ radius: 4, color: '#10000000', offsetX: 0, offsetY: 2 })
                    .onClick(() => {
                        if (!this.isLoggedIn) {
                            router.pushUrl({ url: 'pages/login/LoginPage' })
                        } else {
                            router.pushUrl({ url: 'pages/settings/SettingsPage' })
                        }
                    })

                    // 设置选项
                    Column({ space: 0 }) {
                        this.SettingItem('音质设置', this.getQualityText(), false, () => {
                            router.pushUrl({ url: 'pages/settings/SettingsPage' })
                        })
                        Divider().color(MD3Colors.OutlineVariant).margin({ left: 52 })
                        this.SettingItem('播放模式', this.getPlayModeText(), false, () => {
                            router.pushUrl({ url: 'pages/settings/SettingsPage' })
                        })
                        Divider().color(MD3Colors.OutlineVariant).margin({ left: 52 })
                        this.SettingItem('关于', 'MD3Music v1.0.0', false, () => {
                            router.pushUrl({ url: 'pages/settings/SettingsPage' })
                        })

                        if (this.isLoggedIn) {
                            Divider().color(MD3Colors.OutlineVariant).margin({ left: 52 })
                            this.SettingItem('退出登录', '', true, () => {
                                this.logout()
                            })
                        }
                    }
                    .width('100%')
                    .borderRadius(16)
                    .backgroundColor(MD3Colors.Surface)
                    .shadow({ radius: 2, color: '#08000000', offsetX: 0, offsetY: 1 })
                    .clip(true)
                }
                .padding({ left: 16, right: 16, bottom: this.showMiniPlayer ? 140 : 76 })
            }
            .layoutWeight(1)
            .scrollBar(BarState.Off)
        }
        .width('100%')
        .height('100%')
        .backgroundColor(MD3Colors.Background)
    }

    @Builder
    SettingItem(title: string, subtitle: string, isDanger: boolean, onClick: () => void) {
        Row() {
            Text(title)
                .fontSize(16)
                .fontColor(isDanger ? MD3Colors.Error : MD3Colors.OnSurface)
                .layoutWeight(1)

            if (subtitle) {
                Text(subtitle)
                    .fontSize(14)
                    .fontColor(MD3Colors.OnSurfaceVariant)
                    .margin({ right: 8 })
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .constraintSize({ maxWidth: '40%' })
            }

            Text('›')
                .fontSize(20)
                .fontColor(MD3Colors.Outline)
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16 })
        .onClick(onClick)
    }
}

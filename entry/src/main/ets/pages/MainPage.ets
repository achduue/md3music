/**
 * ============================================================
 * 声明：本文件由 AI（TRAE 助手）辅助生成，尚未经过技术验证。
 * 代码未在真实 HarmonyOS 设备上编译运行，可能存在编译错误、
 * API 调用不正确等问题，请自行审查测试后使用。
 * 原始项目: https://github.com/zzyoxml/md3Music (Flutter/Android)
 * ============================================================
 */

/**
 * 主页面 - 底部Tab导航
 * 对应原Flutter: app.dart (MainApp with BottomNavigationBar)
 * Tab: 发现 | 搜索 | 设置
 */
import router from '@ohos.router'
import { AppStorageKeys, MD3Colors } from '../common/Constants'
import { PlayerManager } from '../utils/PlayerManager'
import { Song } from '../models/Song'
import { ImageUtils } from '../utils/LocalStorage'

@Entry
@Component
struct MainPage {
  @State currentTab: number = 0
  @StorageLink(AppStorageKeys.IS_LOGGED_IN) isLoggedIn: boolean = false
  @StorageLink(AppStorageKeys.IS_PLAYING) isPlaying: boolean = false
  @StorageLink(AppStorageKeys.USER_NICKNAME) userNickname: string = ''
  @StorageLink(AppStorageKeys.USER_AVATAR) userAvatar: string = ''
  @StorageLink(AppStorageKeys.CURRENT_SONG) currentSongJson: string = ''

  private player: PlayerManager = PlayerManager.getInstance()
  @State currentSong: Song = new Song()
  @State showMiniPlayer: boolean = false

  aboutToAppear(): void {
    // 恢复当前歌曲状态
    if (this.currentSongJson) {
      try {
        this.currentSong = JSON.parse(this.currentSongJson) as Song
        this.showMiniPlayer = true
      } catch (e) {}
    }

    // 监听歌曲变化
    this.player.onSongChanged = (song: Song) => {
      this.currentSong = song
      this.showMiniPlayer = true
    }

    this.player.onPlayingChanged = (playing: boolean) => {
      AppStorage.setOrCreate(AppStorageKeys.IS_PLAYING, playing)
      this.isPlaying = playing
    }
  }

  build() {
    Tabs({
      barPosition: this.showMiniPlayer ? BarPosition.Start : BarPosition.End,
      index: this.currentTab
    }) {
      // 发现页
      TabContent() {
        // 发现页内容直接内嵌
        this.DiscoverTabContent()
      }
      .tabBar(this.TabBarItem('发现', 0))

      // 搜索页
      TabContent() {
        this.SearchTabContent()
      }
      .tabBar(this.TabBarItem('搜索', 1))

      // 设置页
      TabContent() {
        this.SettingsTabContent()
      }
      .tabBar(this.TabBarItem('我的', 2))
    }
    .vertical(false)
    .scrollable(true)
    .barMode(BarMode.Fixed)
    .barWidth('100%')
    .barHeight(this.showMiniPlayer ? 0 : 56)
    .animationDuration(300)
    .onChange((index: number) => {
      this.currentTab = index
    })

    // 底部区域：迷你播放器 + Tab栏
    .overlay(this.BottomSection())
  }

  @Builder
  TabBarItem(title: string, index: number) {
    Column() {
      Text(title)
        .fontSize(12)
        .fontColor(this.currentTab === index ? MD3Colors.Primary : MD3Colors.OnSurfaceVariant)
        .margin({ top: 4 })
    }
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(56)
  }

  @Builder
  BottomSection() {
    Column() {
      // 迷你播放器
      if (this.showMiniPlayer) {
        Row() {
          Image(this.currentSong.artworkUri ? ImageUtils.getCoverUrl(this.currentSong.artworkUri) : ImageUtils.DEFAULT_COVER)
            .width(44).height(44)
            .borderRadius(8)
            .shadow({ radius: 4, color: '#15000000', offsetX: 0, offsetY: 2 })

          Column({ space: 2 }) {
            Text(this.currentSong.title || '未在播放')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(MD3Colors.OnSurface)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ maxWidth: '55%' })
            Text(this.currentSong.artist)
              .fontSize(12)
              .fontColor(MD3Colors.OnSurfaceVariant)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ maxWidth: '55%' })
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12 })
          .layoutWeight(1)

          Button() {
            Image($r('sys.media.ohos_ic_public_play'))
              .width(32).height(32)
              .fillColor(MD3Colors.OnSurface)
          }
          .type(ButtonType.Circle)
          .backgroundColor(Color.Transparent)
          .margin({ right: 4 })
          .onClick(() => this.player.togglePlay())

          Button() {
            Image($r('sys.media.ohos_ic_public_skip_next'))
              .width(32).height(32)
              .fillColor(MD3Colors.OnSurface)
          }
          .type(ButtonType.Circle)
          .backgroundColor(Color.Transparent)
          .onClick(() => this.player.next())
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

      // 底部Tab栏
      Row() {
        this.BottomTab('发现', 0)
        this.BottomTab('搜索', 1)
        this.BottomTab('我的', 2)
      }
      .width('100%')
      .height(56)
      .backgroundColor(MD3Colors.Surface)
      .padding({ top: 4 })
      .shadow({ radius: 8, color: '#0F000000', offsetX: 0, offsetY: -1 })
    }
    .alignItems(HorizontalAlign.Center)
    .position({ x: 0, y: '100%' })
    .translate({ y: '-100%' })
    .width('100%')
  }

  @Builder
  BottomTab(title: string, index: number) {
    Column() {
      Text(title)
        .fontSize(12)
        .fontColor(this.currentTab === index ? MD3Colors.Primary : MD3Colors.OnSurfaceVariant)
        .margin({ top: 2 })
    }
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .layoutWeight(1)
    .height('100%')
    .onClick(() => { this.currentTab = index })
  }

  // ==================== 发现页内容 ====================
  @Builder
  DiscoverTabContent() {
    Column() {
      // 顶部标题
      Row() {
        Text('发现')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(MD3Colors.OnSurface)
          .layoutWeight(1)

        // 用户头像/登录
        if (this.isLoggedIn && this.userAvatar) {
          Image(ImageUtils.getCoverUrl(this.userAvatar))
            .width(32).height(32)
            .borderRadius(16)
            .onClick(() => router.pushUrl({ url: 'pages/settings/SettingsPage' }))
        } else {
          Button('登录')
            .type(ButtonType.Capsule)
            .height(32)
            .fontSize(13)
            .backgroundColor(MD3Colors.SecondaryContainer)
            .fontColor(MD3Colors.Secondary)
            .onClick(() => router.pushUrl({ url: 'pages/login/LoginPage' }))
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 8 })

      Scroll() {
        Column({ space: 24 }) {
          // 排行榜区域
          Text('排行榜')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(MD3Colors.OnSurface)
            .width('100%')
            .padding({ left: 16 })

          Row({ space: 12 }) {
            this.RankCard('热歌榜', '6666', '#FF6750A4')
            this.RankCard('新歌榜', '6666', '#FF625B71')
            this.RankCard('飙升榜', '6666', '#FFB3261E')
          }
          .padding({ left: 16, right: 16 })
          .width('100%')

          // 每日推荐
          Text('每日推荐')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(MD3Colors.OnSurface)
            .width('100%')
            .padding({ left: 16 })

          Text('登录后查看个性化推荐')
            .fontSize(14)
            .fontColor(MD3Colors.OnSurfaceVariant)
            .width('100%')
            .padding({ left: 16 })
            .onClick(() => {
              if (!this.isLoggedIn) router.pushUrl({ url: 'pages/login/LoginPage' })
            })
        }
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MD3Colors.Background)
  }

  @Builder
  RankCard(name: string, rankId: string, color: string) {
    Column() {
      Column() {
        Image(ImageUtils.DEFAULT_COVER)
          .width(80).height(80)
          .borderRadius(12)
      }
      .width(108)
      .height(108)
      .borderRadius(16)
      .backgroundColor(color)
      .justifyContent(FlexAlign.Center)
      .shadow({ radius: 12, color: '#25000000', offsetX: 0, offsetY: 4 })

      Text(name)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(MD3Colors.OnSurface)
        .margin({ top: 6 })
        .maxLines(1)
    }
    .alignItems(HorizontalAlign.Center)
    .layoutWeight(1)
    .onClick(() => {
      AppStorage.setOrCreate('rank_id', rankId)
      AppStorage.setOrCreate('rank_name', name)
      router.pushUrl({ url: 'pages/discover/DiscoverPage' })
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
          .onChange((value: string) => {
            if (value.length > 0) {
              AppStorage.setOrCreate('search_keyword', value)
              router.pushUrl({ url: 'pages/search/SearchPage' })
            }
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12 })

      // 热搜
      Column({ space: 12 }) {
        Text('热搜')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(MD3Colors.OnSurface)

        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
          ForEach(['周杰伦', '薛之谦', '林俊杰', '邓紫棋', '陈奕迅', '毛不易', '李荣浩', '许嵩'],
            (item: string) => {
              Text(item)
                .fontSize(14)
                .fontColor(MD3Colors.OnSurfaceVariant)
                .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                .borderRadius(20)
                .backgroundColor(MD3Colors.SurfaceVariant)
                .margin({ right: 8, bottom: 8 })
                .onClick(() => {
                  AppStorage.setOrCreate('search_keyword', item)
                  router.pushUrl({ url: 'pages/search/SearchPage' })
                })
            })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MD3Colors.Background)
  }

  // ==================== 设置/我的页内容 ====================
  @Builder
  SettingsTabContent() {
    Column() {
      // 用户信息卡片
      Row() {
        if (this.isLoggedIn) {
          Image(this.userAvatar ? ImageUtils.getCoverUrl(this.userAvatar) : ImageUtils.DEFAULT_COVER)
            .width(56).height(56)
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
            .width(56).height(56)
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
          .onClick(() => router.pushUrl({ url: 'pages/login/LoginPage' }))
        }
      }
      .width('100%')
      .padding(16)
      .margin({ top: 16, left: 16, right: 16 })
      .borderRadius(20)
      .backgroundColor(MD3Colors.SurfaceContainerLow)
      .shadow({ radius: 4, color: '#10000000', offsetX: 0, offsetY: 2 })

      // 设置选项
      Column({ space: 0 }) {
        this.SettingItem('音质设置', '标准 128kbps', () => {})
        Divider().color(MD3Colors.OutlineVariant).margin({ left: 52 })
        this.SettingItem('播放模式', '列表循环', () => {})
        Divider().color(MD3Colors.OutlineVariant).margin({ left: 52 })
        this.SettingItem('关于', 'MD3Music 鸿蒙版 v1.0.0', () => {})

        if (this.isLoggedIn) {
          Divider().color(MD3Colors.OutlineVariant).margin({ left: 52 })
          this.SettingItem('退出登录', '', () => {
            AppStorage.setOrCreate(AppStorageKeys.IS_LOGGED_IN, false)
            AppStorage.setOrCreate(AppStorageKeys.TOKEN, '')
            AppStorage.setOrCreate(AppStorageKeys.USER_ID, '')
            AppStorage.setOrCreate(AppStorageKeys.VIP_TOKEN, '')
            AppStorage.setOrCreate(AppStorageKeys.USER_NICKNAME, '')
            AppStorage.setOrCreate(AppStorageKeys.USER_AVATAR, '')
          })
        }
      }
      .width('100%')
      .margin({ top: 16, left: 16, right: 16 })
      .borderRadius(16)
      .backgroundColor(MD3Colors.Surface)
      .shadow({ radius: 2, color: '#08000000', offsetX: 0, offsetY: 1 })
      .clip(true)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MD3Colors.Background)
  }

  @Builder
  SettingItem(title: string, subtitle: string, onClick: () => void) {
    Row() {
      Text(title)
        .fontSize(16)
        .fontColor(MD3Colors.OnSurface)
        .layoutWeight(1)

      if (subtitle) {
        Text(subtitle)
          .fontSize(14)
          .fontColor(MD3Colors.OnSurfaceVariant)
          .margin({ right: 8 })
      }

      if (title === '退出登录') {
        Text(title)
          .fontSize(16)
          .fontColor(MD3Colors.Error)
      } else {
        Image($r('sys.media.ohos_ic_public_arrow_right'))
          .width(20).height(20)
          .fillColor(MD3Colors.Outline)
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .onClick(onClick)
  }
}
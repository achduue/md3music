/**
 * ============================================================
 * 声明：本文件由 AI（TRAE 助手）辅助生成，尚未经过技术验证。
 * 代码未在真实 HarmonyOS 设备上编译运行，可能存在编译错误、
 * API 调用不正确等问题，请自行审查测试后使用。
 * 原始项目: https://github.com/zzyoxml/md3Music (Flutter/Android)
 * ============================================================
 */

/**
 * 搜索结果页面
 * 对应原Flutter: SearchPage (modules/search/search_page.dart)
 *
 * 搜索流程:
 * 1. GET /search?keyword=xxx → 云端 → songsearch.kugou.com/song_search_v2
 * 2. 解析返回的 lists 数组 → Song.fromKugouSearch()
 * 3. 点击歌曲 → PlayerManager.playOnlinePlaylist()
 */
import router from '@ohos.router'
import { KugouApi } from '../../api/KugouApi'
import { Song } from '../../models/Song'
import { PlayerManager } from '../../utils/PlayerManager'
import { MD3Colors, AppStorageKeys } from '../../common/Constants'
import { ImageUtils } from '../../utils/LocalStorage'

@Entry
@Component
struct SearchPage {
  @State keyword: string = ''
  @State songs: Song[] = []
  @State isLoading: boolean = false
  @State hasSearched: boolean = false
  @State page: number = 1

  private player: PlayerManager = PlayerManager.getInstance()

  aboutToAppear(): void {
    this.keyword = AppStorage.get<string>('search_keyword') || ''
    if (this.keyword) {
      this.doSearch()
    }
  }

  /**
   * 执行搜索
   * 对应原Flutter: KugouProvider.searchSongs(keyword, page)
   * API: GET /search?keyword=xxx&page=1&pagesize=30
   */
  async doSearch(): Promise<void> {
    if (!this.keyword.trim()) return

    this.isLoading = true
    this.hasSearched = true
    this.page = 1

    try {
      const api = KugouApi.getInstance()
      const result = await api.searchSongs(this.keyword, this.page, 30)

      // 解析搜索结果
      // 响应结构: { status: 1, data: { lists: [...], total: 500 } }
      const data = result['data'] as Record<string, Object> | undefined
      if (data) {
        const lists = data['lists'] as Record<string, Object>[] | undefined
        if (lists && lists.length > 0) {
          this.songs = lists.map(item => Song.fromKugouSearch(item))
          // 过滤无效歌曲（对应原Flutter：过滤标题为空/"-"、时长为0的无效歌曲）
          this.songs = this.songs.filter(s =>
            s.title && s.title !== '' && s.title !== '-' && s.duration > 0
          )
        } else {
          this.songs = []
        }
      }
    } catch (err) {
      console.error('搜索失败:', err)
    } finally {
      this.isLoading = false
    }
  }

  /**
   * 加载更多
   */
  async loadMore(): Promise<void> {
    if (this.isLoading) return
    this.page++
    this.isLoading = true

    try {
      const api = KugouApi.getInstance()
      const result = await api.searchSongs(this.keyword, this.page, 30)
      const data = result['data'] as Record<string, Object> | undefined
      if (data) {
        const lists = data['lists'] as Record<string, Object>[] | undefined
        if (lists) {
          const newSongs = lists.map(item => Song.fromKugouSearch(item))
            .filter(s => s.title && s.title !== '' && s.title !== '-' && s.duration > 0)
          this.songs = [...this.songs, ...newSongs]
        }
      }
    } catch (err) {
      this.page--
    } finally {
      this.isLoading = false
    }
  }

  /**
   * 播放歌曲
   * 对应原Flutter: KugouProvider.playSong(context, song, list, index)
   * → PlayerProvider.playOnlinePlaylist(songs, startIndex)
   */
  playSong(index: number): void {
    if (this.songs.length === 0) return
    this.player.playOnlinePlaylist(this.songs, index)
  }

  build() {
    Column() {
      // 搜索栏
      Row({ space: 12 }) {
        Button() {
          Image($r('sys.media.ohos_ic_public_arrow_left'))
            .width(24).height(24).fillColor(MD3Colors.OnSurface)
        }
        .type(ButtonType.Circle)
        .backgroundColor(Color.Transparent)
        .onClick(() => router.back())

        Search({ value: this.keyword, placeholder: '搜索歌曲、歌手、专辑' })
          .width('100%')
          .height(40)
          .fontColor(MD3Colors.OnSurface)
          .placeholderColor(MD3Colors.OnSurfaceVariant)
          .backgroundColor(MD3Colors.SurfaceContainer)
          .borderRadius(20)
          .onChange((value: string) => { this.keyword = value })
          .onSubmit(() => this.doSearch())
      }
      .width('100%')
      .padding({ left: 4, right: 16, top: 8 })

      // 搜索结果列表
      if (this.isLoading && this.songs.length === 0) {
        // 加载中
        Column() {
          LoadingProgress()
            .width(40).height(40)
            .color(MD3Colors.Primary)
          Text('搜索中...')
            .fontSize(14)
            .fontColor(MD3Colors.OnSurfaceVariant)
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.songs.length === 0 && this.hasSearched) {
        // 无结果
        Column() {
          Text('暂无搜索结果')
            .fontSize(16)
            .fontColor(MD3Colors.OnSurfaceVariant)
          Button('重试')
            .type(ButtonType.Capsule)
            .backgroundColor(MD3Colors.PrimaryContainer)
            .fontColor(MD3Colors.Primary)
            .margin({ top: 16 })
            .onClick(() => this.doSearch())
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.songs.length > 0) {
        // 播放全部按钮
        Row() {
          Button() {
            Image($r('sys.media.ohos_ic_public_play'))
              .width(18).height(18).fillColor(MD3Colors.Primary)
            Text(` 播放全部 (${this.songs.length})`)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(MD3Colors.Primary)
          }
          .type(ButtonType.Capsule)
          .backgroundColor(MD3Colors.PrimaryContainer)
          .margin({ left: 16, top: 8 })
          .onClick(() => this.playSong(0))
        }
        .width('100%')

        // 歌曲列表
        List({ space: 0 }) {
          ForEach(this.songs, (song: Song, index: number) => {
            ListItem() {
              Row() {
                // 序号/封面
                Text(String(index + 1))
                  .fontSize(14)
                  .fontColor(MD3Colors.OnSurfaceVariant)
                  .width(28)
                  .textAlign(TextAlign.Center)

                Image(song.artworkUri ? ImageUtils.getCoverUrl(song.artworkUri) : ImageUtils.DEFAULT_COVER)
                  .width(44).height(44)
                  .borderRadius(8)
                  .margin({ right: 12 })
                  .interpolation(ImageInterpolation.Medium)

                // 歌曲信息
                Column({ space: 3 }) {
                  Text(song.title)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(MD3Colors.OnSurface)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .constraintSize({ maxWidth: '70%' })
                  Text(`${song.artist} - ${song.album}`)
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

                // 更多
                Button() {
                  Image($r('sys.media.ohos_ic_public_more'))
                    .width(20).height(20).fillColor(MD3Colors.OnSurfaceVariant)
                }
                .type(ButtonType.Circle)
                .backgroundColor(Color.Transparent)
              }
              .width('100%')
              .height(68)
              .padding({ left: 8, right: 8 })
              .borderRadius(12)
              .onClick(() => this.playSong(index))
            }
          }, (song: Song) => song.id || song.hash)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .padding({ top: 4 })
        .onReachEnd(() => {
          if (!this.isLoading) this.loadMore()
        })

        // 加载更多指示
        if (this.isLoading) {
          Row() {
            LoadingProgress()
              .width(24).height(24)
              .color(MD3Colors.Primary)
            Text('加载更多...')
              .fontSize(13)
              .fontColor(MD3Colors.OnSurfaceVariant)
              .margin({ left: 8 })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 8, bottom: 16 })
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MD3Colors.Background)
  }
}
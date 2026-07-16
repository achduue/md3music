/**
 * ============================================================
 * 声明：本文件由 AI（TRAE 助手）辅助生成，尚未经过技术验证。
 * 代码未在真实 HarmonyOS 设备上编译运行，可能存在编译错误、
 * API 调用不正确等问题，请自行审查测试后使用。
 * 原始项目: https://github.com/zzyoxml/md3Music (Flutter/Android)
 * ============================================================
 */

/**
 * 发现页 - 排行榜/歌单详情
 * 对应原Flutter: DiscoverPage / RankSongsPage
 *
 * 流程:
 * 1. 从AppStorage获取 rank_id
 * 2. GET /rank/audio?rankid=xxx → 获取排行榜歌曲
 * 3. 解析并展示歌曲列表
 * 4. 点击播放 → PlayerManager.playOnlinePlaylist()
 */
import router from '@ohos.router'
import { KugouApi } from '../../api/KugouApi'
import { Song } from '../../models/Song'
import { PlayerManager } from '../../utils/PlayerManager'
import { MD3Colors, AppStorageKeys } from '../../common/Constants'
import { ImageUtils } from '../../utils/LocalStorage'

@Entry
@Component
struct DiscoverPage {
  @State rankName: string = ''
  @State rankId: string = ''
  @State songs: Song[] = []
  @State isLoading: boolean = true

  private player: PlayerManager = PlayerManager.getInstance()

  aboutToAppear(): void {
    this.rankName = AppStorage.get<string>('rank_name') || '排行榜'
    this.rankId = AppStorage.get<string>('rank_id') || '6666'
    this.loadRankSongs()
  }

  /**
   * 加载排行榜歌曲
   * 对应原Flutter: KugouProvider.loadRankSongs(rankId, page)
   * API: GET /rank/audio?rankid=xxx&page=1
   */
  async loadRankSongs(): Promise<void> {
    this.isLoading = true
    try {
      const api = KugouApi.getInstance()
      const result = await api.getRankSongs(this.rankId, 1)

      // 解析排行榜歌曲列表
      const data = result['data'] as Record<string, Object> | undefined
      if (data) {
        const info = data['info'] as Record<string, Object>[] | undefined
        if (info) {
          this.songs = info.map(item => Song.fromKugouSearch(item))
            .filter(s => s.title && s.title !== '' && s.title !== '-' && s.duration > 0)
        }

        // 尝试其他数据结构
        if (this.songs.length === 0) {
          const songs = data['songs'] as Record<string, Object>[] | undefined
          if (songs) {
            this.songs = songs.map(item => Song.fromKugouSearch(item))
              .filter(s => s.title && s.title !== '' && s.title !== '-' && s.duration > 0)
          }
        }
      }
    } catch (err) {
      console.error('加载排行榜失败:', err)
    } finally {
      this.isLoading = false
    }
  }

  playSong(index: number): void {
    if (this.songs.length === 0) return
    this.player.playOnlinePlaylist(this.songs, index)
  }

  build() {
    Column() {
      // 顶部
      Row() {
        Button() {
          Image($r('sys.media.ohos_ic_public_arrow_left'))
            .width(24).height(24).fillColor(MD3Colors.OnSurface)
        }
        .type(ButtonType.Circle)
        .backgroundColor(Color.Transparent)
        .onClick(() => router.back())

        Text(this.rankName)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(MD3Colors.OnSurface)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Row().width(48).height(48)
      }
      .width('100%')
      .height(56)
      .padding({ left: 4, right: 16 })

      // 播放全部
      if (this.songs.length > 0) {
        Row() {
          Button() {
            Row() {
              Text(`▶ 播放全部 (${this.songs.length})`)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(MD3Colors.Primary)
            }
          }
          .type(ButtonType.Capsule)
          .backgroundColor(MD3Colors.PrimaryContainer)
          .margin({ left: 16, top: 8 })
          .onClick(() => this.playSong(0))
        }
        .width('100%')
      }

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40).height(40)
            .color(MD3Colors.Primary)
          Text('加载中...')
            .fontSize(14)
            .fontColor(MD3Colors.OnSurfaceVariant)
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.songs.length > 0) {
        List({ space: 0 }) {
          ForEach(this.songs, (song: Song, index: number) => {
            ListItem() {
              Row() {
                // 排名序号
                Text(String(index + 1))
                  .fontSize(16)
                  .fontWeight(index < 3 ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(index < 3 ? MD3Colors.Primary : MD3Colors.OnSurfaceVariant)
                  .width(32)
                  .textAlign(TextAlign.Center)

                Image(song.artworkUri ? ImageUtils.getCoverUrl(song.artworkUri) : ImageUtils.DEFAULT_COVER)
                  .width(44).height(44)
                  .borderRadius(8)
                  .margin({ right: 12 })

                Column({ space: 3 }) {
                  Text(song.title)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(MD3Colors.OnSurface)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .constraintSize({ maxWidth: '65%' })
                  Text(song.artist)
                    .fontSize(12)
                    .fontColor(MD3Colors.OnSurfaceVariant)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .constraintSize({ maxWidth: '65%' })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Text(PlayerManager.formatDuration(song.duration))
                  .fontSize(12)
                  .fontColor(MD3Colors.OnSurfaceVariant)
                  .margin({ right: 12 })
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
      } else {
        Column() {
          Text('加载失败')
            .fontSize(16)
            .fontColor(MD3Colors.OnSurfaceVariant)
          Button('重试')
            .type(ButtonType.Capsule)
            .backgroundColor(MD3Colors.PrimaryContainer)
            .fontColor(MD3Colors.Primary)
            .margin({ top: 16 })
            .onClick(() => this.loadRankSongs())
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MD3Colors.Background)
  }
}
/**
 * 全屏播放器页面
 *
 * 功能: 封面展示、进度条拖动、播放控制、歌词同步滚动
 * 播放流程: PlayerManager.playOnlineSong() → API获取URL → AVPlayer播放
 */
import router from '@ohos.router'
import { PlayerManager } from '../../utils/PlayerManager'
import { Song } from '../../models/Song'
import { MD3Colors, PlayMode } from '../../common/Constants'
import { ImageUtils } from '../../utils/LocalStorage'

@Entry
@Component
struct PlayerPage {
  private player: PlayerManager = PlayerManager.getInstance()
  @State currentSong: Song = new Song()
  @State isPlaying: boolean = false
  @State currentPosition: number = 0
  @State duration: number = 0
  @State playMode: PlayMode = PlayMode.LOOP
  @State isDragging: boolean = false
  @State dragPosition: number = 0

  // 歌词
  @State lyricLines: string[] = []
  @State currentLyricIndex: number = 0
  private lyricScroller: Scroller = new Scroller()
  @State showLyric: boolean = false

  private positionTimer: number = -1

  aboutToAppear(): void {
    this.currentSong = this.player.currentSong
    this.isPlaying = this.player.isPlaying
    this.duration = this.player.duration
    this.playMode = this.player.playMode
    this.currentPosition = this.player.currentPosition
    this.lyricLines = this.player.lyricData.lines.map(l => l.text)
    this.currentLyricIndex = this.player.currentLyricIndex

    // 监听回调
    this.player.onSongChanged = (song: Song) => { this.currentSong = song }
    this.player.onPlayingChanged = (playing: boolean) => { this.isPlaying = playing }
    this.player.onDurationChanged = (dur: number) => { this.duration = dur }
    this.player.onPositionChanged = (pos: number) => {
      if (!this.isDragging) {
        this.currentPosition = pos
      }
    }
    this.player.onLyricChanged = (index: number) => {
      this.currentLyricIndex = index
      // 自动滚动到当前歌词行
      if (index > 2) {
        this.lyricScroller.scrollToIndex(index - 2, true)
      }
    }

    // 定时更新位置（用于进度条平滑更新）
    this.positionTimer = setInterval(() => {
      if (this.isPlaying && !this.isDragging) {
        this.currentPosition = this.player.currentPosition
      }
    }, 200)
  }

  aboutToDisappear(): void {
    if (this.positionTimer !== -1) clearInterval(this.positionTimer)
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        Button() {
          Text('◀')
            .fontSize(20)
            .fontColor('#FFFFFFFF')
        }
        .type(ButtonType.Circle)
        .backgroundColor(Color.Transparent)
        .onClick(() => router.back())

        Column() {
          Text(this.currentSong.title || '未在播放')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFFFF')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.currentSong.artist)
            .fontSize(12)
            .fontColor('#B0FFFFFF')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .margin({ right: 48 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 4, right: 16 })

      // 内容区域
      if (!this.showLyric) {
        // 封面
        Column() {
          Image(this.currentSong.artworkUri ? ImageUtils.getCoverUrl(this.currentSong.artworkUri) : ImageUtils.DEFAULT_COVER)
            .width(280)
            .height(280)
            .borderRadius(24)
            .shadow({ radius: 32, color: '#40000000', offsetX: 0, offsetY: 8 })
            .animation({ duration: 300 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .onClick(() => { this.showLyric = true })
      } else {
        // 歌词
        if (this.lyricLines.length > 0) {
          List({ scroller: this.lyricScroller }) {
            ForEach(this.lyricLines, (text: string, index: number) => {
              ListItem() {
                Text(text)
                  .fontSize(index === this.currentLyricIndex ? 18 : 15)
                  .fontWeight(index === this.currentLyricIndex ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(index === this.currentLyricIndex ? '#FFFFFFFF' : '#80FFFFFF')
                  .width('80%')
                  .textAlign(TextAlign.Center)
                  .padding({ top: 12, bottom: 12 })
              }
            })
          }
          .layoutWeight(1)
          .alignListItem(ListItemAlign.Center)
          .scrollBar(BarState.Off)
          .padding({ top: 60, bottom: 60 })
          .onClick(() => { this.showLyric = false })
        } else {
          Column() {
            Text('暂无歌词')
              .fontSize(15)
              .fontColor('#80FFFFFF')
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.showLyric = false })
        }
      }

      // 底部控制区
      Column({ space: 16 }) {
        // 进度条
        Column({ space: 4 }) {
          Slider({
            value: this.isDragging ? this.dragPosition : this.currentPosition,
            min: 0,
            max: this.duration || 1,
            step: 1,
            style: SliderStyle.OutSet
          })
            .blockColor('#FFFFFFFF')
            .trackColor('#40FFFFFF')
            .selectedColor('#FFFFFFFF')
            .width('100%')
            .showSteps(false)
            .showTips(false)
            .onChange((value: number, mode: SliderChangeMode) => {
              if (mode === SliderChangeMode.Begin) {
                this.isDragging = true
              } else if (mode === SliderChangeMode.Moving) {
                this.dragPosition = value
              } else if (mode === SliderChangeMode.End) {
                this.isDragging = false
                this.player.seek(value)
              }
            })

          Row() {
            Text(PlayerManager.formatDuration(this.isDragging ? this.dragPosition : this.currentPosition))
              .fontSize(11)
              .fontColor('#B0FFFFFF')
            Text(PlayerManager.formatDuration(this.duration))
              .fontSize(11)
              .fontColor('#B0FFFFFF')
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
        }
        .padding({ left: 24, right: 24 })

        // 播放控制按钮
        Row() {
          // 播放模式
          Button() {
            Text(this.getPlayModeIcon())
              .fontSize(22)
              .fontColor('#FFFFFFFF')
          }
          .type(ButtonType.Circle)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.playMode = this.player.togglePlayMode()
          })

          // 上一曲
          Button() {
            Text('◀◀')
              .fontSize(18).fontColor('#FFFFFFFF')
          }
          .type(ButtonType.Circle)
          .backgroundColor(Color.Transparent)
          .onClick(() => this.player.previous())

          // 播放/暂停
          Button() {
            Text(this.isPlaying ? '⏸' : '▶')
              .fontSize(32)
              .fontColor('#FF6750A4')
          }
          .type(ButtonType.Circle)
          .width(64).height(64)
          .backgroundColor('#FFFFFFFF')
          .shadow({ radius: 12, color: '#40000000', offsetX: 0, offsetY: 4 })
          .onClick(() => this.player.togglePlay())

          // 下一曲
          Button() {
            Text('▶▶')
              .fontSize(18).fontColor('#FFFFFFFF')
          }
          .type(ButtonType.Circle)
          .backgroundColor(Color.Transparent)
          .onClick(() => this.player.next())

          // 占位
          Row().width(48).height(48)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceEvenly)
        .alignItems(VerticalAlign.Center)
        .padding({ bottom: 24 })
      }
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 180,
      colors: [[MD3Colors.PlayerBackground, 0.0], [MD3Colors.PlayerSurface, 0.5], [MD3Colors.PlayerBackground, 1.0]]
    })
  }

  private getPlayModeIcon(): string {
    switch (this.playMode) {
      case PlayMode.SINGLE:
        return '🔂'  // 单曲循环
      case PlayMode.SHUFFLE:
        return '🔀'  // 随机
      default:
        return '🔁'  // 列表循环
    }
  }
}

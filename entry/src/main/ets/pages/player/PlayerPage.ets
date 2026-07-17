/**
 * 全屏播放器页面
 *
 * 功能：封面展示、进度条拖动、播放控制、歌词同步滚动
 * 播放流程：PlayerManager.playOnlineSong() -> API 获取 URL -> AVPlayer 播放
 *
 * ArkTS 约束：
 * - 颜色统一使用 '#AARRGGBB' 8 位格式，透明背景使用 '#00000000'
 * - 定时器使用 number 类型持有
 * - 回调与 map 的箭头函数参数显式标注类型
 */
import router from '@ohos.router'
import { PlayerManager } from '../../utils/PlayerManager'
import { Song } from '../../models/Song'
import { LyricLine } from '../../models/UserInfo'
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

    // 定时器句柄（setInterval 返回 number）
    private positionTimer: number = -1

    aboutToAppear(): void {
        // 从 PlayerManager 恢复当前状态
        this.currentSong = this.player.currentSong
        this.isPlaying = this.player.isPlaying
        this.duration = this.player.duration
        this.playMode = this.player.playMode
        this.currentPosition = this.player.currentPosition
        this.lyricLines = this.player.lyricData.lines.map((l: LyricLine) => l.text)
        this.currentLyricIndex = this.player.currentLyricIndex

        // 注册状态变更回调
        this.player.onSongChanged = (song: Song) => {
            this.currentSong = song
        }
        this.player.onPlayingChanged = (playing: boolean) => {
            this.isPlaying = playing
        }
        this.player.onDurationChanged = (dur: number) => {
            this.duration = dur
        }
        this.player.onPositionChanged = (pos: number) => {
            if (!this.isDragging) {
                this.currentPosition = pos
            }
        }
        this.player.onLyricChanged = (index: number) => {
            this.currentLyricIndex = index
            // 自动滚动到当前歌词行（保持当前行位于靠上位置）
            if (index > 2) {
                this.lyricScroller.scrollToIndex(index - 2, true)
            }
        }

        // 每 200ms 更新进度条位置，并同步异步加载的歌词
        this.positionTimer = setInterval(() => {
            if (this.isPlaying && !this.isDragging) {
                this.currentPosition = this.player.currentPosition
            }
            // 歌词为异步获取，按行数变化时刷新
            const lines: LyricLine[] = this.player.lyricData.lines
            if (lines.length !== this.lyricLines.length) {
                this.lyricLines = lines.map((l: LyricLine) => l.text)
            }
        }, 200)
    }

    aboutToDisappear(): void {
        if (this.positionTimer !== -1) {
            clearInterval(this.positionTimer)
            this.positionTimer = -1
        }
    }

    build() {
        Column() {
            // 顶部导航栏：返回按钮 + 歌曲名/歌手名
            Row() {
                Button() {
                    Text('◀')
                        .fontSize(20)
                        .fontColor('#FFFFFFFF')
                }
                .type(ButtonType.Circle)
                .backgroundColor('#00000000')
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

            // 主内容区：封面视图 <-> 歌词视图，点击切换
            if (!this.showLyric) {
                // 封面视图：大封面 280x280，圆角 24，阴影
                Column() {
                    Image(this.currentSong.artworkUri
                        ? ImageUtils.getCoverUrl(this.currentSong.artworkUri)
                        : ImageUtils.DEFAULT_COVER)
                        .width(280)
                        .height(280)
                        .borderRadius(24)
                        .shadow({ radius: 32, color: '#40000000', offsetX: 0, offsetY: 8 })
                        .animation({ duration: 300 })
                        .interpolation(ImageInterpolation.Medium)
                }
                .layoutWeight(1)
                .justifyContent(FlexAlign.Center)
                .width('100%')
                .onClick(() => {
                    this.showLyric = true
                })
            } else {
                // 歌词视图：List 列表，当前行高亮加粗，自动滚动
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
                        }, (text: string, index: number) => `${index}_${text}`)
                    }
                    .layoutWeight(1)
                    .alignListItem(ListItemAlign.Center)
                    .scrollBar(BarState.Off)
                    .padding({ top: 60, bottom: 60 })
                    .onClick(() => {
                        this.showLyric = false
                    })
                } else {
                    Column() {
                        Text('暂无歌词')
                            .fontSize(15)
                            .fontColor('#80FFFFFF')
                    }
                    .layoutWeight(1)
                    .justifyContent(FlexAlign.Center)
                    .onClick(() => {
                        this.showLyric = false
                    })
                }
            }

            // 底部控制区
            Column({ space: 16 }) {
                // 进度条 + 时间显示
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

                // 播放控制按钮行：播放模式 + 上一曲 + 播放/暂停 + 下一曲 + 占位
                Row() {
                    // 播放模式
                    Button() {
                        Text(this.getPlayModeIcon())
                            .fontSize(22)
                            .fontColor('#FFFFFFFF')
                    }
                    .type(ButtonType.Circle)
                    .backgroundColor('#00000000')
                    .onClick(() => {
                        this.playMode = this.player.togglePlayMode()
                    })

                    // 上一曲
                    Button() {
                        Text('◀◀')
                            .fontSize(18)
                            .fontColor('#FFFFFFFF')
                    }
                    .type(ButtonType.Circle)
                    .backgroundColor('#00000000')
                    .onClick(() => this.player.previous())

                    // 播放/暂停（大圆形按钮）
                    Button() {
                        Text(this.isPlaying ? '⏸' : '▶')
                            .fontSize(32)
                            .fontColor('#FF6750A4')
                    }
                    .type(ButtonType.Circle)
                    .width(64)
                    .height(64)
                    .backgroundColor('#FFFFFFFF')
                    .shadow({ radius: 12, color: '#40000000', offsetX: 0, offsetY: 4 })
                    .onClick(() => this.player.togglePlay())

                    // 下一曲
                    Button() {
                        Text('▶▶')
                            .fontSize(18)
                            .fontColor('#FFFFFFFF')
                    }
                    .type(ButtonType.Circle)
                    .backgroundColor('#00000000')
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

    /**
     * 获取播放模式图标
     * 🔁 列表循环 / 🔂 单曲循环 / 🔀 随机
     */
    private getPlayModeIcon(): string {
        switch (this.playMode) {
            case PlayMode.SINGLE:
                return '🔂'
            case PlayMode.SHUFFLE:
                return '🔀'
            default:
                return '🔁'
        }
    }
}

import router from '@ohos.router';
import { AppStorageKeys, MD3Colors, PlayMode } from '../common/Constants';
import { Song } from '../models/Song';
import { PlayerManager } from '../utils/PlayerManager';

class ImageUtils {
  static readonly DEFAULT_COVER: string = 'https://img2.baidu.com/it/u=2641407080,437092947&fm=253&fmt=auto&app=138&f=JPEG?w=500&h=500';

  static getCoverUrl(url: string): string {
    if (!url || url === '') {
      return ImageUtils.DEFAULT_COVER;
    }
    if (url.startsWith('//')) {
      return 'https:' + url;
    }
    if (url.indexOf('{size}') >= 0) {
      return url.replace('{size}', '480');
    }
    return url;
  }
}

@Entry
@Component
struct PlayerPage {
  @State private currentSong: Song | null = null;
  @State private isPlaying: boolean = false;
  @State private currentPosition: number = 0;
  @State private duration: number = 0;
  @State private playMode: PlayMode = PlayMode.LOOP;
  @State private progressValue: number = 0;
  private playerManager: PlayerManager = PlayerManager.getInstance();
  private timerId: number = -1;

  aboutToAppear(): void {
    // 从 PlayerManager 获取当前状态
    this.currentSong = this.playerManager.currentSong;
    this.isPlaying = this.playerManager.isPlaying;
    this.currentPosition = this.playerManager.currentPosition;
    this.duration = this.playerManager.duration;
    this.playMode = this.playerManager.playMode;

    // 注册回调
    this.playerManager.onSongChanged = (song: Song | null): void => {
      this.currentSong = song;
    };
    this.playerManager.onPlayingChanged = (playing: boolean): void => {
      this.isPlaying = playing;
    };
    this.playerManager.onPositionChanged = (pos: number, dur: number): void => {
      this.currentPosition = pos;
      this.duration = dur;
      if (dur > 0) {
        this.progressValue = pos / dur;
      } else {
        this.progressValue = 0;
      }
    };

    // 启动定时器更新进度
    this.timerId = setInterval((): void => {
      if (this.playerManager.isPlaying) {
        this.currentPosition = this.playerManager.currentPosition;
        this.duration = this.playerManager.duration;
        if (this.duration > 0) {
          this.progressValue = this.currentPosition / this.duration;
        }
      }
    }, 200);
  }

  aboutToDisappear(): void {
    // 清除回调
    if (this.playerManager.onSongChanged === this.onSongChangedWrapper) {
      this.playerManager.onSongChanged = null;
    }
    if (this.playerManager.onPlayingChanged === this.onPlayingChangedWrapper) {
      this.playerManager.onPlayingChanged = null;
    }
    if (this.playerManager.onPositionChanged === this.onPositionChangedWrapper) {
      this.playerManager.onPositionChanged = null;
    }

    // 清除定时器
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  // 包装函数用于回调比较
  private onSongChangedWrapper = (song: Song | null): void => {
    this.currentSong = song;
  };
  private onPlayingChangedWrapper = (playing: boolean): void => {
    this.isPlaying = playing;
  };
  private onPositionChangedWrapper = (pos: number, dur: number): void => {
    this.currentPosition = pos;
    this.duration = dur;
    if (dur > 0) {
      this.progressValue = pos / dur;
    } else {
      this.progressValue = 0;
    }
  };

  private onSliderChange(value: number): void {
    this.progressValue = value;
    if (this.duration > 0) {
      const targetPos: number = Math.floor(value * this.duration);
      this.playerManager.seek(targetPos);
    }
  }

  private getCover(): string {
    if (!this.currentSong) return ImageUtils.DEFAULT_COVER;
    return ImageUtils.getCoverUrl(this.currentSong.artworkUri);
  }

  private getPlayModeIcon(): string {
    switch (this.playMode) {
      case PlayMode.LOOP:
        return '循环';
      case PlayMode.SINGLE:
        return '单曲';
      case PlayMode.SHUFFLE:
        return '随机';
      default:
        return '循环';
    }
  }

  private getPlayModeColor(): string {
    return MD3Colors.ON_PRIMARY;
  }

  private togglePlayMode(): void {
    this.playerManager.togglePlayMode();
    this.playMode = this.playerManager.playMode;
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Button() {
          Text('< 返回')
            .fontSize(16)
            .fontColor('#FFFFFFFF')
        }
        .backgroundColor('#00000000')
        .onClick((event: ClickEvent): void => {
          router.back();
        })
        .width(60)

        Column() {
          Text(this.currentSong ? this.currentSong.title : '未播放')
            .fontSize(16)
            .fontColor('#FFFFFFFF')
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .textAlign(TextAlign.Center)
          Text(this.currentSong ? this.currentSong.artist : '')
            .fontSize(13)
            .fontColor('#99FFFFFF')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        // 占位保持对称
        Text('')
          .width(60)
      }
      .width('100%')
      .height(56)
      .padding({ left: 4, right: 16 })
      .margin({ top: 24 })

      // 主内容区 - 大封面图
      Column() {
        Image(this.getCover())
          .width(280)
          .height(280)
          .borderRadius(24)
          .objectFit(ImageFit.Cover)
          .shadow({ radius: 20, color: '#40000000', offsetX: 0, offsetY: 8 })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      // 进度条区域
      Column() {
        Slider({
          value: this.progressValue,
          min: 0,
          max: 1,
          step: 0.001
        })
          .width('85%')
          .trackThickness(3)
          .blockSize(12)
          .blockColor('#FFFFFFFF')
          .trackColor('#33FFFFFF')
          .selectedColor(MD3Colors.PRIMARY)
          .onChange((value: number): void => {
            this.onSliderChange(value);
          })

        Row() {
          Text(PlayerManager.formatDuration(this.currentPosition))
            .fontSize(12)
            .fontColor('#99FFFFFF')
          Text(PlayerManager.formatDuration(this.duration))
            .fontSize(12)
            .fontColor('#99FFFFFF')
        }
        .width('85%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ top: 4 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .margin({ bottom: 16 })

      // 控制按钮行
      Row() {
        // 播放模式按钮
        Button() {
          Text(this.getPlayModeIcon())
            .fontSize(13)
            .fontColor('#FFFFFFFF')
            .fontWeight(FontWeight.Medium)
        }
        .width(52)
        .height(52)
        .backgroundColor('#33FFFFFF')
        .borderRadius(26)
        .onClick((event: ClickEvent): void => {
          this.togglePlayMode();
        })

        // 上一曲
        Button() {
          Text('|<')
            .fontSize(20)
            .fontColor('#FFFFFFFF')
            .fontWeight(FontWeight.Bold)
        }
        .width(52)
        .height(52)
        .backgroundColor('#33FFFFFF')
        .borderRadius(26)
        .margin({ left: 24 })
        .onClick((event: ClickEvent): void => {
          this.playerManager.previous();
        })
        .enabled(this.playerManager.playList.length > 0)

        // 播放/暂停按钮(大圆形)
        Button() {
          Text(this.isPlaying ? '||' : '>')
            .fontSize(28)
            .fontColor('#FFFFFFFF')
            .fontWeight(FontWeight.Bold)
        }
        .width(72)
        .height(72)
        .backgroundColor(MD3Colors.PRIMARY)
        .borderRadius(36)
        .margin({ left: 24, right: 24 })
        .onClick((event: ClickEvent): void => {
          this.playerManager.togglePlay();
        })
        .enabled(this.currentSong !== null)

        // 下一曲
        Button() {
          Text('>|')
            .fontSize(20)
            .fontColor('#FFFFFFFF')
            .fontWeight(FontWeight.Bold)
        }
        .width(52)
        .height(52)
        .backgroundColor('#33FFFFFF')
        .borderRadius(26)
        .onClick((event: ClickEvent): void => {
          this.playerManager.next();
        })
        .enabled(this.playerManager.playList.length > 0)

        // 占位
        Button() {
          Text('')
            .fontSize(13)
        }
        .width(52)
        .height(52)
        .backgroundColor('#00000000')
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 48 })
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [
        ['#FF1A1A2E', 0.0],
        ['#FF16213E', 0.5],
        ['#FF0F3460', 1.0]
      ]
    })
  }
}
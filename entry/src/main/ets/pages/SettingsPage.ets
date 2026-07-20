import router from '@ohos.router';
import { AppStorageKeys, MD3Colors, AudioQuality, PlayMode } from '../common/Constants';
import { PlayerManager } from '../utils/PlayerManager';

interface AudioQualityOption {
  label: string;
  value: AudioQuality;
}

interface PlayModeOption {
  label: string;
  value: PlayMode;
}

@Entry
@Component
struct SettingsPage {
  @StorageLink(AppStorageKeys.AUDIO_QUALITY) private audioQuality: string = AudioQuality.HIGH;
  @StorageLink(AppStorageKeys.PLAY_MODE) private playMode: number = PlayMode.LOOP;
  @StorageLink(AppStorageKeys.IS_LOGGED_IN) private isLoggedIn: boolean = false;

  private audioOptions: AudioQualityOption[] = [
    { label: '标准音质 (128kbps)', value: AudioQuality.STANDARD },
    { label: '高质音质 (320kbps)', value: AudioQuality.HIGH },
    { label: '无损音质 (FLAC)', value: AudioQuality.FLAC }
  ];

  private playModeOptions: PlayModeOption[] = [
    { label: '列表循环', value: PlayMode.LOOP },
    { label: '单曲循环', value: PlayMode.SINGLE },
    { label: '随机播放', value: PlayMode.SHUFFLE }
  ];

  private onAudioQualityChange(value: AudioQuality): void {
    this.audioQuality = value;
    AppStorage.setOrCreate(AppStorageKeys.AUDIO_QUALITY, value);
  }

  private onPlayModeChange(value: PlayMode): void {
    this.playMode = value;
    AppStorage.setOrCreate(AppStorageKeys.PLAY_MODE, value);
    PlayerManager.getInstance().setPlayMode(value);
  }

  private logout(): void {
    AppStorage.setOrCreate(AppStorageKeys.TOKEN, '');
    AppStorage.setOrCreate(AppStorageKeys.USER_ID, '');
    AppStorage.setOrCreate(AppStorageKeys.VIP_TOKEN, '');
    AppStorage.setOrCreate(AppStorageKeys.IS_LOGGED_IN, false);
    AppStorage.setOrCreate(AppStorageKeys.USER_NICKNAME, '');
    AppStorage.setOrCreate(AppStorageKeys.USER_AVATAR, '');
    router.back();
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Button() {
          Text('< 返回')
            .fontSize(16)
            .fontColor(MD3Colors.ON_SURFACE)
        }
        .backgroundColor('#00000000')
        .onClick((event: ClickEvent): void => {
          router.back();
        })

        Text('设置')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(MD3Colors.ON_SURFACE)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .margin({ right: 60 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })
      .backgroundColor(MD3Colors.SURFACE)

      Scroll() {
        Column() {
          // 音质设置
          Text('音质设置')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(MD3Colors.ON_SURFACE)
            .width('100%')
            .padding({ left: 16, top: 16, bottom: 8 })

          Column() {
            ForEach(this.audioOptions, (option: AudioQualityOption): void => {
              Row() {
                Radio({ value: option.value, group: 'audioQuality' })
                  .checked(this.audioQuality === option.value)
                  .onChange((checked: boolean): void => {
                    if (checked) {
                      this.onAudioQualityChange(option.value);
                    }
                  })
                  .width(20)
                  .height(20)
                  .margin({ right: 12 })

                Text(option.label)
                  .fontSize(15)
                  .fontColor(MD3Colors.ON_SURFACE)
              }
              .width('100%')
              .height(48)
              .padding({ left: 16, right: 16 })
              .onClick((event: ClickEvent): void => {
                this.onAudioQualityChange(option.value);
              })
            })
          }
          .width('100%')
          .backgroundColor(MD3Colors.SURFACE_CONTAINER)
          .borderRadius(12)
          .padding({ top: 4, bottom: 4 })

          // 分隔线
          Text('')
            .width('100%')
            .height(1)
            .backgroundColor(MD3Colors.OUTLINE)
            .margin({ top: 24, bottom: 8 })

          // 播放模式设置
          Text('播放模式')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(MD3Colors.ON_SURFACE)
            .width('100%')
            .padding({ left: 16, top: 8, bottom: 8 })

          Column() {
            ForEach(this.playModeOptions, (option: PlayModeOption): void => {
              Row() {
                Radio({ value: String(option.value), group: 'playMode' })
                  .checked(this.playMode === option.value)
                  .onChange((checked: boolean): void => {
                    if (checked) {
                      this.onPlayModeChange(option.value);
                    }
                  })
                  .width(20)
                  .height(20)
                  .margin({ right: 12 })

                Text(option.label)
                  .fontSize(15)
                  .fontColor(MD3Colors.ON_SURFACE)
              }
              .width('100%')
              .height(48)
              .padding({ left: 16, right: 16 })
              .onClick((event: ClickEvent): void => {
                this.onPlayModeChange(option.value);
              })
            })
          }
          .width('100%')
          .backgroundColor(MD3Colors.SURFACE_CONTAINER)
          .borderRadius(12)
          .padding({ top: 4, bottom: 4 })

          // 分隔线
          Text('')
            .width('100%')
            .height(1)
            .backgroundColor(MD3Colors.OUTLINE)
            .margin({ top: 24, bottom: 8 })

          // 关于
          Text('关于')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(MD3Colors.ON_SURFACE)
            .width('100%')
            .padding({ left: 16, top: 8, bottom: 8 })

          Row() {
            Text('应用版本')
              .fontSize(15)
              .fontColor(MD3Colors.ON_SURFACE)
            Text('v1.0.0')
              .fontSize(15)
              .fontColor(MD3Colors.ON_SURFACE_VARIANT)
          }
          .width('100%')
          .height(48)
          .padding({ left: 16, right: 16 })
          .backgroundColor(MD3Colors.SURFACE_CONTAINER)
          .borderRadius(12)
          .justifyContent(FlexAlign.SpaceBetween)

          // 退出登录
          if (this.isLoggedIn) {
            Text('')
              .width('100%')
              .height(1)
              .backgroundColor(MD3Colors.OUTLINE)
              .margin({ top: 24, bottom: 8 })

            Button() {
              Text('退出登录')
                .fontSize(16)
                .fontColor(MD3Colors.ERROR)
                .fontWeight(FontWeight.Medium)
            }
            .width('90%')
            .height(48)
            .backgroundColor(MD3Colors.SURFACE_CONTAINER)
            .borderRadius(24)
            .margin({ top: 16 })
            .onClick((event: ClickEvent): void => {
              this.logout();
            })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 32 })
      }
      .layoutWeight(1)
      .backgroundColor(MD3Colors.BACKGROUND)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MD3Colors.BACKGROUND)
  }
}
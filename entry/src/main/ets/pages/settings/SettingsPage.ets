/**
 * ============================================================
 * 声明：本文件由 AI（TRAE 助手）辅助生成，尚未经过技术验证。
 * 代码未在真实 HarmonyOS 设备上编译运行，可能存在编译错误、
 * API 调用不正确等问题，请自行审查测试后使用。
 * 原始项目: https://github.com/zzyoxml/md3Music (Flutter/Android)
 * ============================================================
 */

/**
 * 设置页面
 * 对应原Flutter: SettingsPage (modules/settings/)
 */
import router from '@ohos.router'
import { AppStorageKeys, MD3Colors, AudioQuality, PlayMode } from '../../common/Constants'

@Entry
@Component
struct SettingsPage {
  @StorageLink(AppStorageKeys.IS_LOGGED_IN) isLoggedIn: boolean = false
  @StorageLink(AppStorageKeys.USER_NICKNAME) userNickname: string = ''
  @StorageLink(AppStorageKeys.USER_AVATAR) userAvatar: string = ''
  @StorageLink(AppStorageKeys.AUDIO_QUALITY) audioQuality: string = '128'
  @StorageLink(AppStorageKeys.PLAY_MODE) playMode: number = 0

  build() {
    Column() {
      // 顶部导航
      Row() {
        Button() {
          Image($r('sys.media.ohos_ic_public_arrow_left'))
            .width(24).height(24).fillColor(MD3Colors.OnSurface)
        }
        .type(ButtonType.Circle)
        .backgroundColor(Color.Transparent)
        .onClick(() => router.back())

        Text('设置')
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

      Scroll() {
        Column({ space: 16 }) {
          // 音质设置
          Column() {
            Text('音质设置')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(MD3Colors.Primary)
              .width('100%')
              .padding({ left: 16, bottom: 8 })

            this.QualityOption('标准', '128kbps', AudioQuality.STANDARD)
            this.QualityOption('高质', '320kbps', AudioQuality.HIGH)
            this.QualityOption('无损', 'FLAC', AudioQuality.FLAC)
          }
          .width('100%')
          .margin({ left: 16, right: 16 })
          .borderRadius(16)
          .backgroundColor(MD3Colors.Surface)
          .clip(true)

          // 播放模式
          Column() {
            Text('播放模式')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(MD3Colors.Primary)
              .width('100%')
              .padding({ left: 16, bottom: 8 })

            this.PlayModeOption('列表循环', PlayMode.LOOP)
            this.PlayModeOption('单曲循环', PlayMode.SINGLE)
            this.PlayModeOption('随机播放', PlayMode.SHUFFLE)
          }
          .width('100%')
          .margin({ left: 16, right: 16 })
          .borderRadius(16)
          .backgroundColor(MD3Colors.Surface)
          .clip(true)

          // 关于
          Column() {
            Text('关于')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(MD3Colors.Primary)
              .width('100%')
              .padding({ left: 16, bottom: 8 })

            Row() {
              Text('应用版本')
                .fontSize(16)
                .fontColor(MD3Colors.OnSurface)
                .layoutWeight(1)
              Text('v1.0.0')
                .fontSize(14)
                .fontColor(MD3Colors.OnSurfaceVariant)
            }
            .width('100%')
            .height(52)
            .padding({ left: 16, right: 16 })

            Divider().color(MD3Colors.OutlineVariant).margin({ left: 16 })

            Row() {
              Text('项目来源')
                .fontSize(16)
                .fontColor(MD3Colors.OnSurface)
                .layoutWeight(1)
              Text('zzyoxml/md3Music')
                .fontSize(14)
                .fontColor(MD3Colors.OnSurfaceVariant)
            }
            .width('100%')
            .height(52)
            .padding({ left: 16, right: 16 })
          }
          .width('100%')
          .margin({ left: 16, right: 16 })
          .borderRadius(16)
          .backgroundColor(MD3Colors.Surface)
          .clip(true)

          // 退出登录
          if (this.isLoggedIn) {
            Button('退出登录')
              .type(ButtonType.Capsule)
              .width('90%')
              .height(48)
              .fontSize(16)
              .backgroundColor(MD3Colors.Error)
              .fontColor('#FFFFFFFF')
              .margin({ top: 16 })
              .onClick(() => {
                AppStorage.setOrCreate(AppStorageKeys.IS_LOGGED_IN, false)
                AppStorage.setOrCreate(AppStorageKeys.TOKEN, '')
                AppStorage.setOrCreate(AppStorageKeys.USER_ID, '')
                AppStorage.setOrCreate(AppStorageKeys.VIP_TOKEN, '')
                AppStorage.setOrCreate(AppStorageKeys.USER_NICKNAME, '')
                AppStorage.setOrCreate(AppStorageKeys.USER_AVATAR, '')
                router.back()
              })
          }
        }
        .padding({ top: 16, bottom: 32 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MD3Colors.Background)
  }

  @Builder
  QualityOption(label: string, desc: string, quality: AudioQuality) {
    Row() {
      Column({ space: 2 }) {
        Text(label)
          .fontSize(16)
          .fontColor(MD3Colors.OnSurface)
        Text(desc)
          .fontSize(12)
          .fontColor(MD3Colors.OnSurfaceVariant)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Radio({ value: quality, group: 'quality' })
        .checked(this.audioQuality === quality)
        .onChange((isChecked: boolean) => {
          if (isChecked) {
            AppStorage.setOrCreate(AppStorageKeys.AUDIO_QUALITY, quality)
          }
        })
    }
    .width('100%')
    .height(60)
    .padding({ left: 16, right: 16 })
  }

  @Builder
  PlayModeOption(label: string, mode: PlayMode) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor(MD3Colors.OnSurface)
        .layoutWeight(1)

      Radio({ value: String(mode), group: 'playmode' })
        .checked(this.playMode === mode)
        .onChange((isChecked: boolean) => {
          if (isChecked) {
            AppStorage.setOrCreate(AppStorageKeys.PLAY_MODE, mode)
          }
        })
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
  }
}
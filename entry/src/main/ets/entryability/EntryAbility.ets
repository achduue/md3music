import UIAbility from '@ohos.app.ability.UIAbility'
import window from '@ohos.window'
import { AppStorageKeys } from '../common/Constants'

export default class EntryAbility extends UIAbility {
  async onCreate(want, launchParam): Promise<void> {
    console.info('[MD3Music] EntryAbility onCreate')

    // 初始化默认AppStorage值
    AppStorage.setOrCreate(AppStorageKeys.IS_LOGGED_IN, false)
    AppStorage.setOrCreate(AppStorageKeys.IS_PLAYING, false)
    AppStorage.setOrCreate(AppStorageKeys.PLAY_MODE, 0)
    AppStorage.setOrCreate(AppStorageKeys.AUDIO_QUALITY, '128')

    // 设置窗口全屏
    try {
      const mainWindow = await window.getLastWindow(this.context)
      await mainWindow.setWindowLayoutFullScreen(false)
    } catch (err) {
      console.error('设置窗口失败:', err)
    }
  }

  onWindowStageCreate(windowStage): void {
    console.info('[MD3Music] EntryAbility onWindowStageCreate')
    windowStage.loadContent('pages/MainPage', (err) => {
      if (err.code) {
        console.error(`加载内容失败: ${JSON.stringify(err)}`)
        return
      }
      console.info('[MD3Music] 加载内容成功')
    })
  }

  onForeground(): void {
    console.info('[MD3Music] EntryAbility onForeground')
  }

  onBackground(): void {
    console.info('[MD3Music] EntryAbility onBackground')
  }

  onDestroy(): void {
    console.info('[MD3Music] EntryAbility onDestroy')
  }
}
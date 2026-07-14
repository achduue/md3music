/**
 * 应用入口 Ability v2.0
 * 修复: 后台/前台生命周期管理，正确释放播放器资源
 */
import UIAbility from '@ohos.app.ability.UIAbility'
import window from '@ohos.window'
import { AppStorageKeys } from '../common/Constants'
import { PlayerManager } from '../utils/PlayerManager'

export default class EntryAbility extends UIAbility {
  async onCreate(want, launchParam): Promise<void> {
    console.info('[MD3Music] EntryAbility onCreate')

    // 初始化默认AppStorage值
    AppStorage.setOrCreate(AppStorageKeys.IS_LOGGED_IN, false)
    AppStorage.setOrCreate(AppStorageKeys.IS_PLAYING, false)
    AppStorage.setOrCreate(AppStorageKeys.PLAY_MODE, 0)
    AppStorage.setOrCreate(AppStorageKeys.AUDIO_QUALITY, '128')

    // 设置窗口
    try {
      const mainWindow = await window.getLastWindow(this.context)
      await mainWindow.setWindowLayoutFullScreen(false)
      // 设置状态栏颜色为深色背景
      await mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#1B1B2E',
        navigationBarColor: '#F8FDFA',
        isStatusBarLightIcon: true,
        isNavigationBarLightIcon: false,
      })
    } catch (err) {
      console.error('[MD3Music] set window failed:', err)
    }
  }

  onWindowStageCreate(windowStage): void {
    console.info('[MD3Music] EntryAbility onWindowStageCreate')
    windowStage.loadContent('pages/MainPage', (err) => {
      if (err.code) {
        console.error(`[MD3Music] loadContent failed: ${JSON.stringify(err)}`)
        return
      }
      console.info('[MD3Music] loadContent success')
    })
  }

  onForeground(): void {
    console.info('[MD3Music] EntryAbility onForeground')
    // 应用回到前台，可以恢复播放器状态
  }

  onBackground(): void {
    console.info('[MD3Music] EntryAbility onBackground')
    // 应用进入后台，如果有长时任务在运行则保持播放
    // 如果没有播放，则释放长时任务
    const player = PlayerManager.getInstance()
    if (!player.isPlaying) {
      player.stopContinuousTask()
    }
  }

  onDestroy(): void {
    console.info('[MD3Music] EntryAbility onDestroy')
    // 应用销毁时释放播放器资源
    const player = PlayerManager.getInstance()
    player.release()
  }
}
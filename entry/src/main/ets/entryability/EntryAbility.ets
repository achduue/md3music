/**
 * 应用入口 Ability
 */
import UIAbility from '@ohos.app.ability.UIAbility'
import Want from '@ohos.app.ability.Want'
import AbilityConstant from '@ohos.app.ability.AbilityConstant'
import window from '@ohos.window'
import { BusinessError } from '@ohos.base'
import { AppStorageKeys } from '../common/Constants'
import { PlayerManager } from '../utils/PlayerManager'

export default class EntryAbility extends UIAbility {
    async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
        console.info('[MD3Music] EntryAbility onCreate')

        AppStorage.setOrCreate(AppStorageKeys.IS_LOGGED_IN, false)
        AppStorage.setOrCreate(AppStorageKeys.IS_PLAYING, false)
        AppStorage.setOrCreate(AppStorageKeys.PLAY_MODE, 0)
        AppStorage.setOrCreate(AppStorageKeys.AUDIO_QUALITY, '128')

        try {
            const mainWindow = await window.getLastWindow(this.context)
            await mainWindow.setWindowLayoutFullScreen(false)
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

    onWindowStageCreate(windowStage: window.WindowStage): void {
        console.info('[MD3Music] EntryAbility onWindowStageCreate')
        windowStage.loadContent('pages/MainPage', (err: BusinessError) => {
            if (err.code) {
                console.error(`[MD3Music] loadContent failed: ${JSON.stringify(err)}`)
                return
            }
            console.info('[MD3Music] loadContent success')
        })
    }

    onForeground(): void {
        console.info('[MD3Music] EntryAbility onForeground')
    }

    onBackground(): void {
        console.info('[MD3Music] EntryAbility onBackground')
        const player = PlayerManager.getInstance()
        if (!player.isPlaying) {
            player.stopContinuousTask()
        }
    }

    onDestroy(): void {
        console.info('[MD3Music] EntryAbility onDestroy')
        const player = PlayerManager.getInstance()
        player.release()
    }
}

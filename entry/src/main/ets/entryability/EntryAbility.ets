/**
 * 应用入口 Ability
 *
 * 职责：
 * - onCreate: 加载本地持久化存储（preferences），恢复登录状态到 AppStorage
 * - onWindowStageCreate: 加载 'pages/MainPage' 入口页面，并设置全屏
 * - onForeground / onBackground: 空实现（后台播放长时任务由 PlayerManager 自行管理）
 *
 * ArkTS 约束：
 * - 不使用 any/unknown，preferences 读取结果显式 as 转换
 * - 颜色统一使用 '#AARRGGBB'
 */
import UIAbility from '@ohos.app.ability.UIAbility'
import Want from '@ohos.app.ability.Want'
import AbilityConstant from '@ohos.app.ability.AbilityConstant'
import window from '@ohos.window'
import preferences from '@ohos.data.preferences'
import { BusinessError } from '@ohos.base'
import { AppStorageKeys } from '../common/Constants'
import { PlayerManager } from '../utils/PlayerManager'

// 持久化存储名（与 utils/LocalStorage 模块保持一致）
const PREF_NAME: string = 'md3music_prefs'

export default class EntryAbility extends UIAbility {
    onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
        console.info('[MD3Music] EntryAbility onCreate')

        // 设置 AppStorage 默认值
        AppStorage.setOrCreate(AppStorageKeys.IS_LOGGED_IN, false)
        AppStorage.setOrCreate(AppStorageKeys.IS_PLAYING, false)
        AppStorage.setOrCreate(AppStorageKeys.PLAY_MODE, 0)
        AppStorage.setOrCreate(AppStorageKeys.AUDIO_QUALITY, '128')

        // 加载 localStorage（preferences），恢复登录状态到 AppStorage
        // UIAbility 生命周期方法不使用 async/await，改用 .then() 处理异步
        this.restoreLoginState().catch((err: Error) => {
            console.error('[MD3Music] restore login state failed:', err.message)
        })
    }

    /**
     * 从持久化存储恢复登录状态与偏好设置
     * 读取 token / userid / vipToken / 昵称 / 头像 / 播放模式 / 音质，
     * 写入 AppStorage 供全局读取。
     */
    private async restoreLoginState(): Promise<void> {
        try {
            const pref: preferences.Preferences = await preferences.getPreferences(this.context, PREF_NAME)
            const token: string = await pref.get(AppStorageKeys.TOKEN, '') as string
            const userid: string = await pref.get(AppStorageKeys.USER_ID, '') as string
            const vipToken: string = await pref.get(AppStorageKeys.VIP_TOKEN, '') as string
            const nickname: string = await pref.get(AppStorageKeys.USER_NICKNAME, '') as string
            const avatar: string = await pref.get(AppStorageKeys.USER_AVATAR, '') as string
            const playMode: number = await pref.get(AppStorageKeys.PLAY_MODE, 0) as number
            const audioQuality: string = await pref.get(AppStorageKeys.AUDIO_QUALITY, '128') as string

            // 恢复播放模式与音质
            AppStorage.setOrCreate(AppStorageKeys.PLAY_MODE, playMode)
            AppStorage.setOrCreate(AppStorageKeys.AUDIO_QUALITY, audioQuality)

            // 恢复登录状态
            if (token && userid) {
                AppStorage.setOrCreate(AppStorageKeys.TOKEN, token)
                AppStorage.setOrCreate(AppStorageKeys.USER_ID, userid)
                AppStorage.setOrCreate(AppStorageKeys.VIP_TOKEN, vipToken)
                AppStorage.setOrCreate(AppStorageKeys.USER_NICKNAME, nickname)
                AppStorage.setOrCreate(AppStorageKeys.USER_AVATAR, avatar)
                AppStorage.setOrCreate(AppStorageKeys.IS_LOGGED_IN, true)
                console.info('[MD3Music] login state restored')
            }
        } catch (err) {
            console.error('[MD3Music] restore login state failed:', (err as Error).message)
        }
    }

    onWindowStageCreate(windowStage: window.WindowStage): void {
        console.info('[MD3Music] EntryAbility onWindowStageCreate')

        // 初始化播放器：先传入 context（后台长时任务依赖 UIAbility context），
        // 再调用 initPlayer() 创建 AVPlayer 并注册监听
        const player: PlayerManager = PlayerManager.getInstance()
        player.setContext(this.context)
        player.initPlayer().then(() => {
            console.info('[MD3Music] player initPlayer success')
        }).catch((err: BusinessError) => {
            console.error('[MD3Music] player initPlayer failed:', err.message)
        })

        // 加载入口页面
        windowStage.loadContent('pages/MainPage', (err: BusinessError) => {
            if (err.code) {
                console.error(`[MD3Music] loadContent failed: ${JSON.stringify(err)}`)
                return
            }
            console.info('[MD3Music] loadContent success')
        })

        // 设置全屏
        windowStage.getMainWindow().then((mainWindow: window.Window) => {
            mainWindow.setWindowLayoutFullScreen(true)
                .then(() => {
                    console.info('[MD3Music] setWindowLayoutFullScreen success')
                })
                .catch((err: BusinessError) => {
                    console.error('[MD3Music] setWindowLayoutFullScreen failed:', err.message)
                })
        }).catch((err: BusinessError) => {
            console.error('[MD3Music] getMainWindow failed:', err.message)
        })
    }

    onForeground(): void {
        // 空实现
    }

    onBackground(): void {
        // 空实现（后台播放长时任务由 PlayerManager 自行管理）
    }

    onDestroy(): void {
        console.info('[MD3Music] EntryAbility onDestroy')
        const player: PlayerManager = PlayerManager.getInstance()
        player.release()
    }
}

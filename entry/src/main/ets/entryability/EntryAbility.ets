import UIAbility from '@ohos.app.ability.UIAbility';
import Window from '@ohos.window';
import preferences from '@ohos.data.preferences';
import { AppStorageKeys } from '../common/Constants';
import { PlayerManager } from '../utils/PlayerManager';

export default class EntryAbility extends UIAbility {
  private playerManager: PlayerManager = PlayerManager.getInstance();

  onCreate(want: Record<string, Object>, launchParam: Record<string, Object>): void {
    AppStorage.setOrCreate(AppStorageKeys.IS_LOGGED_IN, false);
    AppStorage.setOrCreate(AppStorageKeys.IS_PLAYING, false);
    AppStorage.setOrCreate(AppStorageKeys.PLAY_MODE, 0);
    this.restoreLoginState();
  }

  private async restoreLoginState(): Promise<void> {
    try {
      const prefs: preferences.Preferences = await preferences.getPreferences(this.context, 'md3music_prefs');
      const token: string = (await prefs.get('token', '')) as string;
      const userId: string = (await prefs.get('userid', '')) as string;
      const vipToken: string = (await prefs.get('vip_token', '')) as string;
      const nickname: string = (await prefs.get('nickname', '')) as string;
      const avatar: string = (await prefs.get('avatar', '')) as string;
      const playMode: number = (await prefs.get('play_mode', 0)) as number;

      AppStorage.setOrCreate(AppStorageKeys.TOKEN, token);
      AppStorage.setOrCreate(AppStorageKeys.USER_ID, userId);
      AppStorage.setOrCreate(AppStorageKeys.VIP_TOKEN, vipToken);
      AppStorage.setOrCreate(AppStorageKeys.USER_NICKNAME, nickname);
      AppStorage.setOrCreate(AppStorageKeys.USER_AVATAR, avatar);
      AppStorage.setOrCreate(AppStorageKeys.PLAY_MODE, playMode);
      AppStorage.setOrCreate(AppStorageKeys.IS_LOGGED_IN, token.length > 0);
    } catch (e) {
      console.error('EntryAbility restoreLoginState failed: ' + String(e));
    }
  }

  onWindowStageCreate(windowStage: Window.WindowStage): void {
    this.playerManager.setContext(this.context);
    this.playerManager.initPlayer();

    windowStage.loadContent('pages/MainPage', (err: Error): void => {
      if (err) {
        console.error('EntryAbility loadContent failed: ' + JSON.stringify(err));
        return;
      }
    });

    try {
      const mainWindow: Window.Window = windowStage.getMainWindowSync();
      mainWindow.setFullScreen(true);
    } catch (e) {
      console.error('EntryAbility setFullScreen failed: ' + String(e));
    }
  }

  onForeground(): void {
  }

  onBackground(): void {
  }

  onDestroy(): void {
    this.playerManager.release();
  }
}
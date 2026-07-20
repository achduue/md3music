import router from '@ohos.router';
import { AppStorageKeys, MD3Colors } from '../common/Constants';
import { KugouApi } from '../api/KugouApi';

@Entry
@Component
struct LoginPage {
  @State private currentTab: number = 0;
  // 二维码登录
  @State private qrCodeBase64: string = '';
  @State private qrStatus: string = '等待扫码';
  @State private qrKey: string = '';
  @State private qrLoading: boolean = false;
  // 手机号登录
  @State private phoneNumber: string = '';
  @State private captchaCode: string = '';
  @State private countdown: number = 0;
  @State private isSending: boolean = false;
  @State private isLogging: boolean = false;
  @State private loginError: string = '';

  private api: KugouApi = KugouApi.getInstance();
  private qrTimerId: number = -1;
  private qrExpireTimerId: number = -1;

  aboutToAppear(): void {
    this.generateQrCode();
  }

  aboutToDisappear(): void {
    this.clearTimers();
  }

  private clearTimers(): void {
    if (this.qrTimerId >= 0) {
      clearInterval(this.qrTimerId);
      this.qrTimerId = -1;
    }
    if (this.qrExpireTimerId >= 0) {
      clearInterval(this.qrExpireTimerId);
      this.qrExpireTimerId = -1;
    }
  }

  private async generateQrCode(): Promise<void> {
    this.qrLoading = true;
    this.qrStatus = '生成二维码...';
    this.clearTimers();
    try {
      const keyResult: Record<string, Object> = await this.api.getQrKey();
      const data: Record<string, Object> = (keyResult['data'] as Record<string, Object>) || {};
      const key: string = (data['unikey'] as string) || '';
      if (!key) {
        this.qrStatus = '获取二维码失败';
        this.qrLoading = false;
        return;
      }
      this.qrKey = key;

      const qrResult: Record<string, Object> = await this.api.getQrCreate(key, true);
      const qrData: Record<string, Object> = (qrResult['data'] as Record<string, Object>) || {};
      const qrImg: string = (qrData['qrimg'] as string) || '';
      if (qrImg) {
        this.qrCodeBase64 = qrImg;
      } else {
        this.qrCodeBase64 = '';
      }
      this.qrStatus = '请使用酷狗APP扫码';
      this.qrLoading = false;

      // 开始轮询
      this.qrTimerId = setInterval((): void => {
        this.checkQrCodeStatus();
      }, 2000);

      // 5分钟过期
      this.qrExpireTimerId = setInterval((): void => {
        this.qrStatus = '二维码已过期，重新生成...';
        this.clearTimers();
        this.generateQrCode();
      }, 300000);

    } catch (e) {
      this.qrStatus = '生成二维码失败: ' + String(e);
      this.qrLoading = false;
    }
  }

  private async checkQrCodeStatus(): Promise<void> {
    if (!this.qrKey) return;
    try {
      const result: Record<string, Object> = await this.api.checkQrCode(this.qrKey);
      const code: number = (result['code'] as number) || -1;
      const cookieObj: Record<string, Object> = (result['cookie'] as Record<string, Object>) || {};
      const message: string = (result['message'] as string) || '';

      if (code === 800) {
        this.qrStatus = '二维码已过期';
        this.clearTimers();
        // 自动重新生成
        setTimeout((): void => {
          this.generateQrCode();
        }, 1500);
      } else if (code === 803) {
        // 登录成功
        this.qrStatus = '登录成功';
        this.clearTimers();
        const token: string = (cookieObj['token'] as string) || (cookieObj['musickg'] as string) || '';
        const userId: string = String((cookieObj['userid'] as number) || (cookieObj['user_id'] as number) || 0);
        const vipToken: string = (cookieObj['vip_token'] as string) || '';
        if (token) {
          AppStorage.setOrCreate(AppStorageKeys.TOKEN, token);
          AppStorage.setOrCreate(AppStorageKeys.USER_ID, userId);
          AppStorage.setOrCreate(AppStorageKeys.VIP_TOKEN, vipToken);
          AppStorage.setOrCreate(AppStorageKeys.IS_LOGGED_IN, true);
          // 获取用户信息
          this.fetchUserInfo();
        }
        router.back();
      } else if (code === 802) {
        this.qrStatus = '已扫码，确认登录中...';
      } else {
        this.qrStatus = '等待扫码';
      }
    } catch (e) {
      console.error('checkQrCode error: ' + String(e));
    }
  }

  private async fetchUserInfo(): Promise<void> {
    try {
      const result: Record<string, Object> = await this.api.getUserDetail();
      const profile: Record<string, Object> = (result['profile'] as Record<string, Object>) || {};
      const nickname: string = (profile['nickname'] as string) || '';
      const avatar: string = (profile['avatarUrl'] as string) || '';
      if (nickname) {
        AppStorage.setOrCreate(AppStorageKeys.USER_NICKNAME, nickname);
      }
      if (avatar) {
        AppStorage.setOrCreate(AppStorageKeys.USER_AVATAR, avatar);
      }
    } catch (e) {
      console.error('fetchUserInfo error: ' + String(e));
    }
  }

  private async sendCaptcha(): Promise<void> {
    if (!this.phoneNumber || this.phoneNumber.length < 11) {
      this.loginError = '请输入正确的手机号';
      return;
    }
    this.isSending = true;
    this.loginError = '';
    try {
      const result: Record<string, Object> = await this.api.sendCaptcha(this.phoneNumber);
      const code: number = (result['code'] as number) || 0;
      if (code === 200) {
        this.startCountdown();
      } else {
        this.loginError = (result['message'] as string) || '发送验证码失败';
      }
    } catch (e) {
      this.loginError = '发送验证码失败: ' + String(e);
    } finally {
      this.isSending = false;
    }
  }

  private startCountdown(): void {
    this.countdown = 60;
    const countdownTimer: number = setInterval((): void => {
      this.countdown--;
      if (this.countdown <= 0) {
        clearInterval(countdownTimer);
        this.countdown = 0;
      }
    }, 1000);
  }

  private async loginByPhone(): Promise<void> {
    if (!this.phoneNumber || !this.captchaCode) {
      this.loginError = '请填写手机号和验证码';
      return;
    }
    this.isLogging = true;
    this.loginError = '';
    try {
      const result: Record<string, Object> = await this.api.loginByPhone(this.phoneNumber, this.captchaCode);
      const code: number = (result['code'] as number) || 0;
      if (code === 200) {
        const profile: Record<string, Object> = (result['profile'] as Record<string, Object>) || {};
        const token: string = (result['token'] as string) || '';
        const userId: string = String((profile['userId'] as number) || 0);
        const nickname: string = (profile['nickname'] as string) || '';
        const avatar: string = (profile['avatarUrl'] as string) || '';

        if (token) {
          AppStorage.setOrCreate(AppStorageKeys.TOKEN, token);
          AppStorage.setOrCreate(AppStorageKeys.USER_ID, userId);
          AppStorage.setOrCreate(AppStorageKeys.IS_LOGGED_IN, true);
          AppStorage.setOrCreate(AppStorageKeys.USER_NICKNAME, nickname);
          AppStorage.setOrCreate(AppStorageKeys.USER_AVATAR, avatar);
        }
        router.back();
      } else {
        this.loginError = (result['message'] as string) || '登录失败';
      }
    } catch (e) {
      this.loginError = '登录失败: ' + String(e);
    } finally {
      this.isLogging = false;
    }
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
          this.clearTimers();
          router.back();
        })

        Text('登录')
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

      // Tab切换
      Tabs({ index: this.currentTab }) {
        TabContent() {
          Column() {
            if (this.qrLoading) {
              LoadingState('生成二维码中...')
            } else if (this.qrCodeBase64) {
              Image(this.qrCodeBase64)
                .width(200)
                .height(200)
                .objectFit(ImageFit.Contain)
                .margin({ top: 32 })

              Text(this.qrStatus)
                .fontSize(14)
                .fontColor(MD3Colors.ON_SURFACE_VARIANT)
                .margin({ top: 16 })
                .textAlign(TextAlign.Center)
            } else {
              ErrorState('二维码加载失败')
            }
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }

        TabContent() {
          Column() {
            // 手机号输入
            TextInput({ placeholder: '请输入手机号', text: this.phoneNumber })
              .width('85%')
              .height(48)
              .backgroundColor(MD3Colors.SURFACE_CONTAINER_HIGH)
              .borderRadius(12)
              .fontSize(16)
              .placeholderFont({ size: 14 })
              .placeholderColor(MD3Colors.ON_SURFACE_VARIANT)
              .onChange((value: string): void => {
                this.phoneNumber = value;
              })
              .margin({ top: 32 })
              .type(InputType.PhoneNumber)
              .maxLength(11)

            // 验证码 + 发送按钮
            Row() {
              TextInput({ placeholder: '请输入验证码', text: this.captchaCode })
                .layoutWeight(1)
                .height(48)
                .backgroundColor(MD3Colors.SURFACE_CONTAINER_HIGH)
                .borderRadius(12)
                .fontSize(16)
                .placeholderFont({ size: 14 })
                .placeholderColor(MD3Colors.ON_SURFACE_VARIANT)
                .onChange((value: string): void => {
                  this.captchaCode = value;
                })
                .type(InputType.Number)
                .maxLength(6)

              Button() {
                Text(this.countdown > 0 ? String(this.countdown) + 's' : '发送验证码')
                  .fontSize(14)
                  .fontColor(this.countdown > 0 ? MD3Colors.ON_SURFACE_VARIANT : MD3Colors.ON_PRIMARY)
                  .fontWeight(FontWeight.Medium)
              }
              .height(48)
              .backgroundColor(this.countdown > 0 ? MD3Colors.SURFACE_CONTAINER_HIGH : MD3Colors.PRIMARY)
              .borderRadius(12)
              .padding({ left: 16, right: 16 })
              .margin({ left: 8 })
              .onClick((event: ClickEvent): void => {
                if (this.countdown <= 0 && !this.isSending) {
                  this.sendCaptcha();
                }
              })
            }
            .width('85%')
            .margin({ top: 16 })

            // 错误信息
            if (this.loginError !== '') {
              Text(this.loginError)
                .fontSize(13)
                .fontColor(MD3Colors.ERROR)
                .width('85%')
                .margin({ top: 8 })
            }

            // 登录按钮
            Button() {
              Text(this.isLogging ? '登录中...' : '登录')
                .fontSize(16)
                .fontColor(MD3Colors.ON_PRIMARY)
                .fontWeight(FontWeight.Medium)
            }
            .width('85%')
            .height(48)
            .backgroundColor(MD3Colors.PRIMARY)
            .borderRadius(24)
            .margin({ top: 24 })
            .onClick((event: ClickEvent): void => {
              this.loginByPhone();
            })
            .enabled(!this.isLogging)
          }
          .width('100%')
          .height('100%')
          .alignItems(HorizontalAlign.Center)
        }
      }
      .barHeight(0)
      .layoutWeight(1)

      // 自定义Tab栏
      Row() {
        Button() {
          Text('二维码登录')
            .fontSize(15)
            .fontColor(this.currentTab === 0 ? MD3Colors.PRIMARY : MD3Colors.ON_SURFACE_VARIANT)
            .fontWeight(this.currentTab === 0 ? FontWeight.Medium : FontWeight.Normal)
        }
        .backgroundColor('#00000000')
        .layoutWeight(1)
        .height(44)
        .onClick((event: ClickEvent): void => {
          this.currentTab = 0;
          if (this.currentTab === 0) {
            this.generateQrCode();
          }
        })

        Button() {
          Text('手机号登录')
            .fontSize(15)
            .fontColor(this.currentTab === 1 ? MD3Colors.PRIMARY : MD3Colors.ON_SURFACE_VARIANT)
            .fontWeight(this.currentTab === 1 ? FontWeight.Medium : FontWeight.Normal)
        }
        .backgroundColor('#00000000')
        .layoutWeight(1)
        .height(44)
        .onClick((event: ClickEvent): void => {
          this.currentTab = 1;
        })
      }
      .width('100%')
      .height(48)
      .backgroundColor(MD3Colors.SURFACE)
      .padding({ bottom: 4 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MD3Colors.BACKGROUND)
  }
}
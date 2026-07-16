/**
 * ============================================================
 * 声明：本文件由 AI（TRAE 助手）辅助生成，尚未经过技术验证。
 * 代码未在真实 HarmonyOS 设备上编译运行，可能存在编译错误、
 * API 调用不正确等问题，请自行审查测试后使用。
 * 原始项目: https://github.com/zzyoxml/md3Music (Flutter/Android)
 * ============================================================
 */

/**
 * 登录页面 - 支持二维码登录和手机验证码登录
 * 对应原Flutter: LoginPage (modules/user/login_page.dart)
 *
 * 二维码登录流程(对应原版):
 * 1. GET /login/qr/key → 获取key
 * 2. GET /login/qr/create?key=xxx → 获取base64二维码图片
 * 3. Timer轮询 GET /login/qr/check?key=xxx → status=4成功
 *
 * 手机登录流程:
 * 1. POST /captcha/sent → 发送验证码
 * 2. POST /login/cellphone → 验证码登录
 */
import router from '@ohos.router'
import { KugouApi } from '../../api/KugouApi'
import { AppStorageKeys, MD3Colors } from '../../common/Constants'

@Entry
@Component
struct LoginPage {
  @State currentTab: number = 0  // 0=二维码, 1=手机号
  @State qrBase64: string = ''
  @State qrStatus: string = '等待扫码'
  @State qrKey: string = ''
  @State isQrLoading: boolean = false
  @State isQrExpired: boolean = false
  @State phone: string = ''
  @State verifyCode: string = ''
  @State isSendingCode: boolean = false
  @State countdown: number = 0
  @State isLogging: boolean = false
  @State errorMsg: string = ''

  private qrTimer: number = -1
  private countdownTimer: number = -1
  private checkTimer: number = -1

  aboutToAppear(): void {
    this.generateQrCode()
  }

  aboutToDisappear(): void {
    this.clearAllTimers()
  }

  private clearAllTimers(): void {
    if (this.qrTimer !== -1) clearInterval(this.qrTimer)
    if (this.countdownTimer !== -1) clearInterval(this.countdownTimer)
    if (this.checkTimer !== -1) clearInterval(this.checkTimer)
  }

  // ==================== 二维码登录 ====================

  /**
   * 生成二维码
   * 对应原Flutter: LoginPage.generateQrCode()
   * 步骤1: GET /login/qr/key → 获取key
   * 步骤2: GET /login/qr/create?key=xxx&qrimg=1 → base64图片
   */
  async generateQrCode(): Promise<void> {
    this.isQrLoading = true
    this.isQrExpired = false
    this.qrStatus = '生成二维码中...'
    this.clearAllTimers()

    try {
      const api = KugouApi.getInstance()

      // Step 1: 获取二维码key
      const keyResult = await api.getQrKey()
      const keyData = keyResult['data'] as Record<string, Object> | undefined
      if (!keyData || !keyData['key']) {
        this.errorMsg = '获取二维码失败，请重试'
        this.isQrLoading = false
        return
      }
      this.qrKey = keyData['key'] as string

      // Step 2: 获取二维码图片（base64）
      const createResult = await api.getQrCreate(this.qrKey, true)
      const createData = createResult['data'] as Record<string, Object> | undefined
      if (createData) {
        this.qrBase64 = (createData['base64'] as string) || ''
      }

      this.qrStatus = '请使用酷狗音乐APP扫码'
      this.isQrLoading = false

      // Step 3: 开始轮询扫码状态（每2秒）
      // 对应原Flutter: Timer.periodic(2秒)
      this.checkTimer = setInterval(() => this.checkQrStatus(), 2000)

      // 二维码5分钟后过期
      this.qrTimer = setTimeout(() => {
        this.isQrExpired = true
        this.qrStatus = '二维码已过期，点击刷新'
        clearInterval(this.checkTimer)
      }, 300000) // 5分钟

    } catch (err) {
      this.errorMsg = `生成二维码失败: ${err}`
      this.isQrLoading = false
    }
  }

  /**
   * 检查二维码扫码状态
   * 对应原Flutter: LoginPage.checkQrCode()
   * GET /login/qr/check?key=xxx
   * status: 0=等待, 1=已扫码, 2/800=过期, 4=确认成功
   */
  async checkQrStatus(): Promise<void> {
    if (!this.qrKey || this.isQrExpired) return

    try {
      const api = KugouApi.getInstance()
      const result = await api.checkQrCode(this.qrKey)
      const data = result['data'] as Record<string, Object> | undefined
      if (!data) return

      const status = Number(data['status'] || 0)

      switch (status) {
        case 0:
          this.qrStatus = '等待扫码'
          break
        case 1:
          this.qrStatus = '已扫码，请在手机上确认'
          break
        case 4:
          // 登录成功
          this.qrStatus = '登录成功！'
          clearInterval(this.checkTimer)
          clearTimeout(this.qrTimer)
          const token = (data['token'] || '') as string
          const userid = String(data['userid'] || '')
          const vipToken = (data['vip_token'] || '') as string
          const vipType = Number(data['vip_type'] || 0)
          this.saveLoginInfo(token, userid, vipToken, vipType)
          break
        case 2:
        case 800:
          this.isQrExpired = true
          this.qrStatus = '二维码已过期，点击刷新'
          clearInterval(this.checkTimer)
          break
      }
    } catch (err) {
      console.error('检查二维码状态失败:', err)
    }
  }

  // ==================== 手机号登录 ====================

  /**
   * 发送验证码
   * 对应原Flutter: KugouProvider.sendLoginCaptcha(phone)
   * POST /captcha/sent { mobile }
   */
  async sendVerifyCode(): Promise<void> {
    if (!this.phone || this.phone.length !== 11) {
      this.errorMsg = '请输入正确的手机号'
      return
    }

    this.isSendingCode = true
    this.errorMsg = ''

    try {
      const api = KugouApi.getInstance()
      const result = await api.sendCaptcha(this.phone)
      if (result['status'] === 1) {
        // 开始倒计时60秒
        this.countdown = 60
        this.countdownTimer = setInterval(() => {
          this.countdown--
          if (this.countdown <= 0) {
            clearInterval(this.countdownTimer)
          }
        }, 1000)
      } else {
        this.errorMsg = (result['msg'] || '发送验证码失败') as string
      }
    } catch (err) {
      this.errorMsg = `发送验证码失败: ${err}`
    } finally {
      this.isSendingCode = false
    }
  }

  /**
   * 手机验证码登录
   * 对应原Flutter: KugouProvider.loginByPhone(phone, code)
   * POST /login/cellphone { mobile, code }
   * 内部由云端处理AES/RSA加密
   */
  async phoneLogin(): Promise<void> {
    if (!this.phone || this.phone.length !== 11) {
      this.errorMsg = '请输入正确的手机号'
      return
    }
    if (!this.verifyCode || this.verifyCode.length < 4) {
      this.errorMsg = '请输入验证码'
      return
    }

    this.isLogging = true
    this.errorMsg = ''

    try {
      const api = KugouApi.getInstance()
      const result = await api.loginByPhone(this.phone, this.verifyCode)

      if (result['status'] === 1) {
        const data = result['data'] as Record<string, Object> | undefined
        if (data) {
          const token = (data['token'] || '') as string
          const userid = String(data['userid'] || '')
          const vipToken = (data['vip_token'] || '') as string
          const vipType = Number(data['vip_type'] || 0)
          this.saveLoginInfo(token, userid, vipToken, vipType)
        }
      } else {
        this.errorMsg = (result['msg'] || '登录失败') as string
      }
    } catch (err) {
      this.errorMsg = `登录失败: ${err}`
    } finally {
      this.isLogging = false
    }
  }

  /**
   * 保存登录信息
   * 对应原Flutter: KugouApiClient.setLoginCookies()
   * 保存到 AppStorage (对应SharedPreferences)
   */
  private saveLoginInfo(token: string, userid: string, vipToken: string, vipType: number): void {
    AppStorage.setOrCreate(AppStorageKeys.TOKEN, token)
    AppStorage.setOrCreate(AppStorageKeys.USER_ID, userid)
    AppStorage.setOrCreate(AppStorageKeys.VIP_TOKEN, vipToken)
    AppStorage.setOrCreate(AppStorageKeys.VIP_TYPE, vipType)
    AppStorage.setOrCreate(AppStorageKeys.IS_LOGGED_IN, true)

    // 拉取用户信息
    this.fetchUserInfo(userid, token)

    // 返回上一页
    setTimeout(() => router.back(), 500)
  }

  /**
   * 获取用户信息
   * 对应原Flutter: KugouProvider.refreshUserInfo()
   * POST /user/detail
   */
  private async fetchUserInfo(userid: string, token: string): Promise<void> {
    try {
      const api = KugouApi.getInstance()
      const result = await api.getUserDetail()
      const data = result['data'] as Record<string, Object> | undefined
      if (data) {
        const userName = (data['user_name'] || data['nick_name'] || '') as string
        const avatar = (data['avatar'] || '') as string
        AppStorage.setOrCreate(AppStorageKeys.USER_NICKNAME, userName)
        AppStorage.setOrCreate(AppStorageKeys.USER_AVATAR, avatar)
      }
    } catch (err) {
      console.error('获取用户信息失败:', err)
    }
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Button() {
          Image($r('sys.media.ohos_ic_public_arrow_left'))
            .width(24).height(24).fillColor(MD3Colors.OnSurface)
        }
        .type(ButtonType.Circle)
        .backgroundColor(Color.Transparent)
        .onClick(() => router.back())

        Text('登录')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(MD3Colors.OnSurface)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        // 右侧占位
        Row().width(48).height(48)
      }
      .width('100%')
      .height(56)
      .padding({ left: 4, right: 16 })

      // Tab切换
      Row() {
        Text('二维码登录')
          .fontSize(14)
          .fontWeight(this.currentTab === 0 ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.currentTab === 0 ? MD3Colors.Primary : MD3Colors.OnSurfaceVariant)
          .padding({ bottom: 8 })
          .borderWidth({ bottom: this.currentTab === 0 ? 2 : 0 })
          .borderColor(MD3Colors.Primary)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .onClick(() => { this.currentTab = 0 })

        Text('手机号登录')
          .fontSize(14)
          .fontWeight(this.currentTab === 1 ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.currentTab === 1 ? MD3Colors.Primary : MD3Colors.OnSurfaceVariant)
          .padding({ bottom: 8 })
          .borderWidth({ bottom: this.currentTab === 1 ? 2 : 0 })
          .borderColor(MD3Colors.Primary)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .onClick(() => { this.currentTab = 1 })
      }
      .width('90%')
      .padding({ top: 8, bottom: 16 })
      .justifyContent(FlexAlign.SpaceEvenly)

      // 内容区
      if (this.currentTab === 0) {
        // 二维码登录
        Column() {
          if (this.isQrLoading) {
            LoadingProgress()
              .width(48).height(48)
              .color(MD3Colors.Primary)
          } else if (this.qrBase64) {
            Image(`data:image/png;base64,${this.qrBase64}`)
              .width(200).height(200)
              .borderRadius(12)
              .shadow({ radius: 16, color: '#20000000', offsetX: 0, offsetY: 4 })
          }

          Text(this.qrStatus)
            .fontSize(14)
            .fontColor(MD3Colors.OnSurfaceVariant)
            .margin({ top: 16 })

          if (this.isQrExpired) {
            Button('刷新二维码')
              .type(ButtonType.Capsule)
              .backgroundColor(MD3Colors.Primary)
              .fontColor(MD3Colors.OnPrimary)
              .margin({ top: 16 })
              .onClick(() => this.generateQrCode())
          }
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)

      } else {
        // 手机号登录
        Column({ space: 20 }) {
          // 手机号输入
          Column({ space: 4 }) {
            TextInput({ placeholder: '请输入手机号', text: this.phone })
              .type(InputType.PhoneNumber)
              .maxLength(11)
              .fontSize(16)
              .onChange((value: string) => { this.phone = value })
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .borderRadius(12)
              .backgroundColor(MD3Colors.SurfaceContainer)
          }

          // 验证码输入
          Row({ space: 12 }) {
            TextInput({ placeholder: '请输入验证码', text: this.verifyCode })
              .type(InputType.Number)
              .maxLength(6)
              .layoutWeight(1)
              .fontSize(16)
              .onChange((value: string) => { this.verifyCode = value })
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .borderRadius(12)
              .backgroundColor(MD3Colors.SurfaceContainer)

            Button(this.countdown > 0 ? `${this.countdown}s` : '发送验证码')
              .type(ButtonType.Capsule)
              .fontSize(14)
              .backgroundColor(this.countdown > 0 ? MD3Colors.OutlineVariant : MD3Colors.Primary)
              .fontColor(this.countdown > 0 ? MD3Colors.OnSurfaceVariant : MD3Colors.OnPrimary)
              .enabled(this.countdown <= 0 && !this.isSendingCode)
              .height(48)
              .constraintSize({ minWidth: 110 })
              .onClick(() => this.sendVerifyCode())
          }

          // 登录按钮
          Button('登录')
            .type(ButtonType.Capsule)
            .width('100%')
            .height(48)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(MD3Colors.Primary)
            .fontColor(MD3Colors.OnPrimary)
            .enabled(!this.isLogging)
            .opacity(this.isLogging ? 0.6 : 1)
            .margin({ top: 12 })
            .onClick(() => this.phoneLogin())

          if (this.isLogging) {
            Row() {
              LoadingProgress().width(20).height(20).color(MD3Colors.Primary)
              Text('登录中...').fontSize(14).fontColor(MD3Colors.OnSurfaceVariant).margin({ left: 8 })
            }
            .margin({ top: 8 })
          }
        }
        .width('90%')
        .margin({ top: 40 })
      }

      // 错误提示
      if (this.errorMsg) {
        Text(this.errorMsg)
          .fontSize(13)
          .fontColor(MD3Colors.Error)
          .width('90%')
          .textAlign(TextAlign.Center)
          .margin({ bottom: 24 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MD3Colors.Background)
  }
}
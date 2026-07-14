# MD3Music 鸿蒙版

基于 [zzyoxml/md3Music](https://github.com/zzyoxml/md3Music) 移植的 HarmonyOS 版本。

Material Design 3 风格音乐播放器，数据来源为酷狗音乐 API。

## 功能

- 二维码登录 / 手机验证码登录
- 歌曲搜索（含分页加载）
- 在线播放（进度控制、上一曲/下一曲、三种循环模式）
- 歌词同步滚动
- 排行榜浏览
- Material Design 3 主题

## 环境要求

- DevEco Studio 5.0+ (NEXT)
- HarmonyOS SDK API 12 (5.0.0)
- 测试设备：HarmonyOS 5.0+

## 构建步骤

1. 用 DevEco Studio 打开项目根目录
2. 等待 SDK 同步和依赖安装完成
3. 配置签名：File → Project Structure → Signing Configs
4. Build → Build Hap(s)/APP(s) → Build Hap(s)
5. 输出：`entry/build/default/outputs/default/entry-default-signed.hap`

## 安装

```bash
hdc install entry-default-signed.hap
```

或通过 DevEco Studio 直接运行到设备。

## 架构说明

鸿蒙版采用直连云端 API 架构（无需嵌入 Node.js）：

- 所有 API 请求直连云端服务器 `115.29.236.96:5621`
- 登录加密（AES/RSA/MD5签名）由云端处理
- 音频播放使用 `@ohos.multimedia.media.AVPlayer`
- 状态管理使用 `AppStorage` + 单例模式

## 致谢

- [zzyoxml/md3Music](https://github.com/zzyoxml/md3Music) - 原始 Flutter/Android 项目
- [EchoMusic](https://github.com/hoowhoami/EchoMusic) - UI 设计和架构参考
- [KuGouMusicApi](https://github.com/MakcRe/KuGouMusicApi) - API 代理服务

## 许可证

MIT License
/**
 * 本地存储工具类
 * 使用 @ohos.data.preferences 实现持久化
 * 对应原Flutter的 SharedPreferences
 */
import preferences from '@ohos.data.preferences'

const PREF_NAME = 'md3music_prefs'

export class LocalStorage {
  private static instance: LocalStorage
  private pref: preferences.Preferences | null = null

  private constructor() {}

  static async getInstance(): Promise<LocalStorage> {
    if (!LocalStorage.instance) {
      LocalStorage.instance = new LocalStorage()
      await LocalStorage.instance.init()
    }
    return LocalStorage.instance
  }

  private async init(): Promise<void> {
    try {
      this.pref = await preferences.getPreferences(getContext(this), PREF_NAME)
    } catch (err) {
      console.error('初始化 preferences 失败:', err)
    }
  }

  async getString(key: string, defaultValue: string = ''): Promise<string> {
    if (!this.pref) return defaultValue
    try {
      return await this.pref.get(key, defaultValue) as string
    } catch {
      return defaultValue
    }
  }

  async setString(key: string, value: string): Promise<void> {
    if (!this.pref) return
    try {
      await this.pref.put(key, value)
      await this.pref.flush()
    } catch (err) {
      console.error(`存储 ${key} 失败:`, err)
    }
  }

  async getNumber(key: string, defaultValue: number = 0): Promise<number> {
    if (!this.pref) return defaultValue
    try {
      return await this.pref.get(key, defaultValue) as number
    } catch {
      return defaultValue
    }
  }

  async setNumber(key: string, value: number): Promise<void> {
    if (!this.pref) return
    try {
      await this.pref.put(key, value)
      await this.pref.flush()
    } catch (err) {
      console.error(`存储 ${key} 失败:`, err)
    }
  }

  async getBoolean(key: string, defaultValue: boolean = false): Promise<boolean> {
    if (!this.pref) return defaultValue
    try {
      return await this.pref.get(key, defaultValue) as boolean
    } catch {
      return defaultValue
    }
  }

  async setBoolean(key: string, value: boolean): Promise<void> {
    if (!this.pref) return
    try {
      await this.pref.put(key, value)
      await this.pref.flush()
    } catch (err) {
      console.error(`存储 ${key} 失败:`, err)
    }
  }

  async remove(key: string): Promise<void> {
    if (!this.pref) return
    try {
      await this.pref.delete(key)
      await this.pref.flush()
    } catch (err) {
      console.error(`删除 ${key} 失败:`, err)
    }
  }

  async clear(): Promise<void> {
    if (!this.pref) return
    try {
      await this.pref.clear()
      await this.pref.flush()
    } catch (err) {
      console.error('清除存储失败:', err)
    }
  }
}

/**
 * 图片工具类
 * 处理酷狗图片URL（为空时使用默认占位图）
 */
export class ImageUtils {
  static readonly DEFAULT_COVER = 'https://img2.baidu.com/it/u=2641407080,437092947&fm=253&fmt=auto&app=138&f=JPEG?w=500&h=500'

  static getCoverUrl(url: string): string {
    if (!url || url === '' || url === 'null' || url === 'undefined') {
      return ImageUtils.DEFAULT_COVER
    }
    // 酷狗图片URL通常不带https头
    if (url.startsWith('//')) {
      return `https:${url}`
    }
    return url
  }
}
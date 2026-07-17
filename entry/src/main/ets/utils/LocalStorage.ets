/**
 * 本地存储与图片工具
 * LocalStorage 基于 @ohos.data.preferences 实现持久化；
 * ImageUtils 处理酷狗图片 URL（补全协议、占位图）。
 */
import preferences from '@ohos.data.preferences'

const PREF_NAME: string = 'md3music_prefs'

/**
 * 持久化存储工具类（单例）
 * 封装 @ohos.data.preferences 的常用读写操作。
 */
export class LocalStorage {
    private static instance: LocalStorage
    private pref: preferences.Preferences | null = null

    private constructor() {
    }

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
        const pref: preferences.Preferences | null = this.pref
        if (!pref) {
            return defaultValue
        }
        try {
            return await pref.get(key, defaultValue) as string
        } catch (err) {
            console.error(`读取 ${key} 失败:`, err)
            return defaultValue
        }
    }

    async setString(key: string, value: string): Promise<void> {
        const pref: preferences.Preferences | null = this.pref
        if (!pref) {
            return
        }
        try {
            await pref.put(key, value)
            await pref.flush()
        } catch (err) {
            console.error(`存储 ${key} 失败:`, err)
        }
    }

    async getNumber(key: string, defaultValue: number = 0): Promise<number> {
        const pref: preferences.Preferences | null = this.pref
        if (!pref) {
            return defaultValue
        }
        try {
            return await pref.get(key, defaultValue) as number
        } catch (err) {
            console.error(`读取 ${key} 失败:`, err)
            return defaultValue
        }
    }

    async setNumber(key: string, value: number): Promise<void> {
        const pref: preferences.Preferences | null = this.pref
        if (!pref) {
            return
        }
        try {
            await pref.put(key, value)
            await pref.flush()
        } catch (err) {
            console.error(`存储 ${key} 失败:`, err)
        }
    }

    async getBoolean(key: string, defaultValue: boolean = false): Promise<boolean> {
        const pref: preferences.Preferences | null = this.pref
        if (!pref) {
            return defaultValue
        }
        try {
            return await pref.get(key, defaultValue) as boolean
        } catch (err) {
            console.error(`读取 ${key} 失败:`, err)
            return defaultValue
        }
    }

    async setBoolean(key: string, value: boolean): Promise<void> {
        const pref: preferences.Preferences | null = this.pref
        if (!pref) {
            return
        }
        try {
            await pref.put(key, value)
            await pref.flush()
        } catch (err) {
            console.error(`存储 ${key} 失败:`, err)
        }
    }

    async remove(key: string): Promise<void> {
        const pref: preferences.Preferences | null = this.pref
        if (!pref) {
            return
        }
        try {
            await pref.delete(key)
            await pref.flush()
        } catch (err) {
            console.error(`删除 ${key} 失败:`, err)
        }
    }

    async clear(): Promise<void> {
        const pref: preferences.Preferences | null = this.pref
        if (!pref) {
            return
        }
        try {
            await pref.clear()
            await pref.flush()
        } catch (err) {
            console.error('清除存储失败:', err)
        }
    }
}

/**
 * 图片工具类
 * 处理酷狗图片 URL：空值/无效值使用默认占位图，// 开头补全 https 协议。
 */
export class ImageUtils {
    /** 稳定的默认封面图（百度图床占位图） */
    static readonly DEFAULT_COVER: string =
        'https://img2.baidu.com/it/u=2641407080,437092947&fm=253&fmt=auto&app=138&f=JPEG?w=500&h=500'

    static getCoverUrl(url: string): string {
        if (!url || url === '' || url === 'null' || url === 'undefined') {
            return ImageUtils.DEFAULT_COVER
        }
        if (url.startsWith('//')) {
            return `https:${url}`
        }
        return url
    }
}

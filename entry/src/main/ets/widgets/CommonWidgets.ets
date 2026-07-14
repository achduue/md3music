/**
 * ============================================================
 * 声明：本文件由 AI（TRAE 助手）辅助生成，尚未经过技术验证。
 * 代码未在真实 HarmonyOS 设备上编译运行，可能存在编译错误、
 * API 调用不正确等问题，请自行审查测试后使用。
 * 原始项目: https://github.com/zzyoxml/md3Music (Flutter/Android)
 * ============================================================
 */

/**
 * 公共 UI 组件
 * 提供统一的加载、错误提示、空状态等组件
 */

@Builder
export function LoadingState(text: string = '加载中...') {
  Column() {
    LoadingProgress()
      .width(40)
      .height(40)
      .color('#FF6750A4')
    Text(text)
      .fontSize(14)
      .fontColor('#FF49454F')
      .margin({ top: 12 })
  }
  .width('100%')
  .layoutWeight(1)
  .justifyContent(FlexAlign.Center)
}

@Builder
export function ErrorState(message: string, onRetry: () => void) {
  Column() {
    Text(message)
      .fontSize(16)
      .fontColor('#FF49454F')
      .textAlign(TextAlign.Center)
    Button('重试')
      .type(ButtonType.Capsule)
      .backgroundColor('#FFEADDFF')
      .fontColor('#FF6750A4')
      .margin({ top: 16 })
      .onClick(() => onRetry())
  }
  .width('100%')
  .layoutWeight(1)
  .justifyContent(FlexAlign.Center)
}

@Builder
export function EmptyState(text: string = '暂无数据') {
  Column() {
    Text(text)
      .fontSize(16)
      .fontColor('#FF49454F')
  }
  .width('100%')
  .layoutWeight(1)
  .justifyContent(FlexAlign.Center)
}

/**
 * 歌曲列表项 Builder
 * 统一歌曲列表项样式
 */
@Builder
export function SongListItem(song: Song, index: number, showRank: boolean = false, onPlay: (index: number) => void) {
  Row() {
    // 序号或排名
    Text(showRank ? String(index + 1) : String(index + 1))
      .fontSize(showRank && index < 3 ? 16 : 14)
      .fontWeight(showRank && index < 3 ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(showRank && index < 3 ? '#FF6750A4' : '#FF49454F')
      .width(28)
      .textAlign(TextAlign.Center)

    // 封面
    Image(song.artworkUri ? ImageUtils.getCoverUrl(song.artworkUri) : ImageUtils.DEFAULT_COVER)
      .width(44)
      .height(44)
      .borderRadius(8)
      .margin({ right: 12 })
      .interpolation(ImageInterpolation.Medium)

    // 歌曲信息
    Column({ space: 3 }) {
      Text(song.title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FF1C1B1F')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: '65%' })
      Text(song.artist)
        .fontSize(12)
        .fontColor('#FF49454F')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: '65%' })
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)

    // 时长
    Text(PlayerManager.formatDuration(song.duration))
      .fontSize(12)
      .fontColor('#FF49454F')
      .margin({ right: 12 })
  }
  .width('100%')
  .height(68)
  .padding({ left: 8, right: 8 })
  .borderRadius(12)
  .onClick(() => onPlay(index))
}

import { Song } from '../models/Song'
import { PlayerManager } from '../utils/PlayerManager'
import { ImageUtils } from '../utils/LocalStorage'
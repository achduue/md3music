/**
 * 公共 UI 组件
 * 提供统一的加载、错误提示、空状态等 @Builder 组件，以及统一歌曲列表项。
 */

import { Song } from '../models/Song'
import { PlayerManager } from '../utils/PlayerManager'
import { ImageUtils } from '../utils/LocalStorage'
import { MD3Colors } from '../common/Constants'

/**
 * 加载中状态：居中 LoadingProgress + 文字
 */
@Builder
export function LoadingState(text: string = '加载中...') {
    Column() {
        LoadingProgress()
            .width(40)
            .height(40)
            .color(MD3Colors.Primary)
        Text(text)
            .fontSize(14)
            .fontColor(MD3Colors.OnSurfaceVariant)
            .margin({ top: 12 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
}

/**
 * 错误状态：错误提示 + 重试按钮
 */
@Builder
export function ErrorState(message: string, onRetry: () => void) {
    Column() {
        Text(message)
            .fontSize(16)
            .fontColor(MD3Colors.OnSurfaceVariant)
            .textAlign(TextAlign.Center)
        Button('重试')
            .type(ButtonType.Capsule)
            .backgroundColor(MD3Colors.PrimaryContainer)
            .fontColor(MD3Colors.Primary)
            .margin({ top: 16 })
            .onClick(() => onRetry())
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
}

/**
 * 空状态提示
 */
@Builder
export function EmptyState(text: string = '暂无数据') {
    Column() {
        Text(text)
            .fontSize(16)
            .fontColor(MD3Colors.OnSurfaceVariant)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
}

/**
 * 统一歌曲列表项
 * showRank 为 true 时，前三名序号高亮（用于排行榜场景）
 */
@Builder
export function SongListItem(song: Song, index: number, showRank: boolean = false, onPlay: (index: number) => void) {
    Row() {
        // 序号 / 排名
        Text(String(index + 1))
            .fontSize(showRank && index < 3 ? 16 : 14)
            .fontWeight(showRank && index < 3 ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(showRank && index < 3 ? MD3Colors.Primary : MD3Colors.OnSurfaceVariant)
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
                .fontColor(MD3Colors.OnSurface)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .constraintSize({ maxWidth: '65%' })
            Text(song.artist)
                .fontSize(12)
                .fontColor(MD3Colors.OnSurfaceVariant)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .constraintSize({ maxWidth: '65%' })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // 时长
        Text(PlayerManager.formatDuration(song.duration))
            .fontSize(12)
            .fontColor(MD3Colors.OnSurfaceVariant)
            .margin({ right: 12 })
    }
    .width('100%')
    .height(68)
    .padding({ left: 8, right: 8 })
    .borderRadius(12)
    .onClick(() => onPlay(index))
}

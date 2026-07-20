import router from '@ohos.router';
import { AppStorageKeys, MD3Colors } from '../common/Constants';
import { Song } from '../models/Song';
import { KugouApi } from '../api/KugouApi';
import { PlayerManager } from '../utils/PlayerManager';

class ImageUtils {
  static readonly DEFAULT_COVER: string = 'https://img2.baidu.com/it/u=2641407080,437092947&fm=253&fmt=auto&app=138&f=JPEG?w=500&h=500';

  static getCoverUrl(url: string): string {
    if (!url || url === '') {
      return ImageUtils.DEFAULT_COVER;
    }
    if (url.startsWith('//')) {
      return 'https:' + url;
    }
    if (url.indexOf('{size}') >= 0) {
      return url.replace('{size}', '480');
    }
    return url;
  }
}

@Entry
@Component
struct SearchPage {
  @State private keyword: string = '';
  @State private songs: Song[] = [];
  @State private isLoading: boolean = false;
  @State private errorMsg: string = '';
  @State private hasSearched: boolean = false;
  private playerManager: PlayerManager = PlayerManager.getInstance();

  aboutToAppear(): void {
    const keyword: string = AppStorage.get<string>(AppStorageKeys.SEARCH_KEYWORD) || '';
    this.keyword = keyword;
    if (keyword) {
      this.doSearch(keyword);
    }
  }

  private async doSearch(keyword: string): Promise<void> {
    if (!keyword.trim()) return;
    this.isLoading = true;
    this.errorMsg = '';
    this.hasSearched = true;
    try {
      const result: Record<string, Object> = await KugouApi.getInstance().searchSongs(keyword, 1, 30);
      const dataObj: Record<string, Object> = (result['data'] as Record<string, Object>) || {};
      const lists: Object[] = (dataObj['lists'] as Object[]) || [];
      const songList: Song[] = [];
      for (let i = 0; i < lists.length; i++) {
        const item: Record<string, Object> = lists[i] as Record<string, Object>;
        const song: Song = Song.fromSearch(item);
        if (song.hash !== '') {
          songList.push(song);
        }
      }
      this.songs = songList;
    } catch (e) {
      this.errorMsg = '搜索失败: ' + String(e);
    } finally {
      this.isLoading = false;
    }
  }

  private playAll(): void {
    if (this.songs.length > 0) {
      this.playerManager.playList(this.songs, 0);
    }
  }

  private playSong(index: number): void {
    if (index >= 0 && index < this.songs.length) {
      this.playerManager.playList(this.songs, index);
    }
  }

  private getCoverForSong(song: Song): string {
    return ImageUtils.getCoverUrl(song.artworkUri);
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
          router.back();
        })

        Search({ placeholder: '搜索歌曲、歌手...', value: this.keyword })
          .layoutWeight(1)
          .height(40)
          .backgroundColor(MD3Colors.SURFACE_CONTAINER_HIGH)
          .borderRadius(20)
          .fontColor(MD3Colors.ON_SURFACE)
          .placeholderFont({ size: 14 })
          .placeholderColor(MD3Colors.ON_SURFACE_VARIANT)
          .onChange((value: string): void => {
            this.keyword = value;
          })
          .onSubmit((value: string): void => {
            this.doSearch(value);
          })
          .margin({ left: 4, right: 12 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 4, right: 8 })
      .backgroundColor(MD3Colors.SURFACE)

      if (this.isLoading) {
        LoadingState('搜索中...')
      } else if (this.errorMsg !== '') {
        ErrorState(this.errorMsg)
      } else if (this.hasSearched && this.songs.length === 0) {
        EmptyState('未找到相关歌曲')
      } else if (this.hasSearched && this.songs.length > 0) {
        // 播放全部按钮
        Button() {
          Row() {
            Text('播放全部')
              .fontSize(15)
              .fontColor(MD3Colors.ON_PRIMARY)
              .fontWeight(FontWeight.Medium)
            Text('(' + String(this.songs.length) + '首)')
              .fontSize(13)
              .fontColor(MD3Colors.ON_PRIMARY)
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
        }
        .width('90%')
        .height(44)
        .backgroundColor(MD3Colors.PRIMARY)
        .borderRadius(22)
        .margin({ top: 8, bottom: 8 })
        .onClick((event: ClickEvent): void => {
          this.playAll();
        })

        // 歌曲列表
        List() {
          ForEach(this.songs, (song: Song, index: number): void => {
            ListItem() {
              Row() {
                // 序号
                Text(String(index + 1))
                  .fontSize(14)
                  .fontColor(MD3Colors.ON_SURFACE_VARIANT)
                  .width(28)
                  .textAlign(TextAlign.Center)

                // 封面
                Image(this.getCoverForSong(song))
                  .width(44)
                  .height(44)
                  .borderRadius(8)
                  .objectFit(ImageFit.Cover)
                  .margin({ left: 4, right: 10 })

                // 歌曲信息
                Column() {
                  Text(song.title)
                    .fontSize(14)
                    .fontColor(MD3Colors.ON_SURFACE)
                    .fontWeight(FontWeight.Medium)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')
                  Text(song.artist)
                    .fontSize(12)
                    .fontColor(MD3Colors.ON_SURFACE_VARIANT)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')
                    .margin({ top: 2 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                // 时长
                Text(PlayerManager.formatDuration(song.duration))
                  .fontSize(12)
                  .fontColor(MD3Colors.ON_SURFACE_VARIANT)
                  .margin({ right: 12 })
              }
              .width('100%')
              .height(64)
              .padding({ left: 12, right: 8 })
              .backgroundColor(MD3Colors.SURFACE)
            }
            .onClick((event: ClickEvent): void => {
              this.playSong(index);
            })
          }, (song: Song, index: number): string => song.hash + '_' + String(index))
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor(MD3Colors.SURFACE)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MD3Colors.BACKGROUND)
  }
}
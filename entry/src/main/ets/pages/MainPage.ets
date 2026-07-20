import router from '@ohos.router';
import { AppStorageKeys, MD3Colors, RankInfo } from '../common/Constants';
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

interface TabItem {
  title: string;
  icon: string;
  index: number;
}

@Component
struct MiniPlayer {
  @StorageLink(AppStorageKeys.CURRENT_SONG) private currentSong: string = '';
  @StorageLink(AppStorageKeys.IS_PLAYING) private isPlaying: boolean = false;
  private playerManager: PlayerManager = PlayerManager.getInstance();

  private getSongName(): string {
    if (!this.currentSong) return '';
    try {
      const parsed: Record<string, Object> = JSON.parse(this.currentSong) as Record<string, Object>;
      return (parsed['title'] as string) || '';
    } catch (e) {
      return '';
    }
  }

  private getArtist(): string {
    if (!this.currentSong) return '';
    try {
      const parsed: Record<string, Object> = JSON.parse(this.currentSong) as Record<string, Object>;
      return (parsed['artist'] as string) || '';
    } catch (e) {
      return '';
    }
  }

  private getCover(): string {
    if (!this.currentSong) return '';
    try {
      const parsed: Record<string, Object> = JSON.parse(this.currentSong) as Record<string, Object>;
      const artwork: string = (parsed['artworkUri'] as string) || '';
      return ImageUtils.getCoverUrl(artwork);
    } catch (e) {
      return ImageUtils.DEFAULT_COVER;
    }
  }

  build() {
    Column() {
      if (this.currentSong !== '') {
        Row() {
          Image(this.getCover())
            .width(40)
            .height(40)
            .borderRadius(8)
            .margin({ left: 12, right: 8 })
            .objectFit(ImageFit.Cover)

          Column() {
            Text(this.getSongName())
              .fontSize(14)
              .fontColor('#FFFFFFFF')
              .fontWeight(FontWeight.Medium)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
            Text(this.getArtist())
              .fontSize(12)
              .fontColor('#99FFFFFF')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 4, right: 8 })

          Row() {
            Image(this.isPlaying ? '/common/images/ic_pause.png' : '/common/images/ic_play.png')
              .width(28)
              .height(28)
              .fillColor('#FFFFFFFF')
              .onClick((event: ClickEvent): void => {
                this.playerManager.togglePlay();
              })
              .margin({ right: 16 })

            Image('/common/images/ic_next.png')
              .width(28)
              .height(28)
              .fillColor('#FFFFFFFF')
              .onClick((event: ClickEvent): void => {
                this.playerManager.next();
              })
              .margin({ right: 12 })
          }
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .height(56)
        .backgroundColor('#FF1A1A2E')
        .borderRadius(12)
        .margin({ left: 8, right: 8, bottom: 4 })
        .onClick((event: ClickEvent): void => {
          router.pushUrl({ url: 'pages/PlayerPage' });
        })
      }
    }
    .width('100%')
  }
}

@Component
struct DiscoverTab {
  @State private rankList: RankInfo[] = [];
  @State private isLoading: boolean = true;
  @State private errorMsg: string = '';

  aboutToAppear(): void {
    this.loadRankList();
  }

  private async loadRankList(): Promise<void> {
    this.isLoading = true;
    this.errorMsg = '';
    try {
      const result: Record<string, Object> = await KugouApi.getInstance().getRankList();
      const rankObj: Record<string, Object> = (result['rank'] as Record<string, Object>) || {};
      const list: Object[] = (rankObj['list'] as Object[]) || [];
      const ranks: RankInfo[] = [];
      for (let i = 0; i < list.length; i++) {
        const item: Record<string, Object> = list[i] as Record<string, Object>;
        const info: RankInfo = new RankInfo();
        info.id = String((item['rankid'] as number) || (item['id'] as number) || 0);
        info.name = (item['rankname'] as string) || (item['name'] as string) || '';
        info.coverImg = (item['imgurl'] as string) || (item['cover_img'] as string) || '';
        info.intro = (item['intro'] as string) || '';
        info.updateFrequency = (item['update_frequency'] as string) || (item['intro'] as string) || '';
        ranks.push(info);
      }
      this.rankList = ranks;
    } catch (e) {
      this.errorMsg = '加载排行榜失败: ' + String(e);
    } finally {
      this.isLoading = false;
    }
  }

  private navigateToRank(rank: RankInfo): void {
    AppStorage.setOrCreate(AppStorageKeys.RANK_ID, rank.id);
    AppStorage.setOrCreate(AppStorageKeys.RANK_NAME, rank.name);
    router.pushUrl({ url: 'pages/DiscoverPage' });
  }

  build() {
    Column() {
      Text('发现')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(MD3Colors.ON_SURFACE)
        .width('100%')
        .padding({ left: 16, top: 16, bottom: 8 })

      if (this.isLoading) {
        LoadingState('加载排行榜中...')
      } else if (this.errorMsg !== '') {
        ErrorState(this.errorMsg)
      } else {
        Text('排行榜')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(MD3Colors.ON_SURFACE)
          .width('100%')
          .padding({ left: 16, top: 8, bottom: 8 })

        Scroll() {
          Row() {
            ForEach(this.rankList, (item: RankInfo, index: number): void => {
              Column() {
                Image(ImageUtils.getCoverUrl(item.coverImg))
                  .width(120)
                  .height(120)
                  .borderRadius(12)
                  .objectFit(ImageFit.Cover)

                Text(item.name)
                  .fontSize(13)
                  .fontColor(MD3Colors.ON_SURFACE)
                  .fontWeight(FontWeight.Medium)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width(120)
                  .textAlign(TextAlign.Center)
                  .margin({ top: 4 })

                Text(item.updateFrequency)
                  .fontSize(11)
                  .fontColor(MD3Colors.ON_SURFACE_VARIANT)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width(120)
                  .textAlign(TextAlign.Center)
              }
              .margin({ right: 12 })
              .onClick((event: ClickEvent): void => {
                this.navigateToRank(item);
              })
            }, (item: RankInfo, index: number): string => item.id)
          }
          .padding({ left: 16, right: 16 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .height(200)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MD3Colors.BACKGROUND)
  }
}

@Component
struct SearchTab {
  @State private keyword: string = '';
  @State private hotWords: string[] = [];
  @State private isLoading: boolean = true;

  aboutToAppear(): void {
    this.loadHotSearch();
  }

  private loadHotSearch(): void {
    this.isLoading = true;
    try {
      const result: Record<string, Object> = KugouApi.getInstance().getHotSearch();
      const data: Object[] = (result['data'] as Object[]) || [];
      const words: string[] = [];
      for (let i = 0; i < data.length; i++) {
        const item: Record<string, Object> = data[i] as Record<string, Object>;
        const word: string = (item['word'] as string) || '';
        if (word) {
          words.push(word);
        }
      }
      this.hotWords = words;
    } catch (e) {
      console.error('loadHotSearch error: ' + String(e));
    } finally {
      this.isLoading = false;
    }
  }

  private doSearch(keyword: string): void {
    if (!keyword.trim()) return;
    AppStorage.setOrCreate(AppStorageKeys.SEARCH_KEYWORD, keyword.trim());
    router.pushUrl({ url: 'pages/SearchPage' });
  }

  build() {
    Column() {
      Text('搜索')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(MD3Colors.ON_SURFACE)
        .width('100%')
        .padding({ left: 16, top: 16, bottom: 8 })

      Search({ placeholder: '搜索歌曲、歌手...', value: this.keyword })
        .width('90%')
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
        .margin({ top: 8, bottom: 16 })

      if (!this.isLoading && this.hotWords.length > 0) {
        Text('热门搜索')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(MD3Colors.ON_SURFACE)
          .width('100%')
          .padding({ left: 16, bottom: 8 })

        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.hotWords, (word: string): void => {
            Button() {
              Text(word)
                .fontSize(13)
                .fontColor(MD3Colors.PRIMARY)
            }
            .height(32)
            .borderRadius(16)
            .backgroundColor(MD3Colors.PRIMARY_CONTAINER)
            .padding({ left: 14, right: 14 })
            .margin({ right: 8, bottom: 8 })
            .onClick((event: ClickEvent): void => {
              this.doSearch(word);
            })
          })
        }
        .padding({ left: 16, right: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MD3Colors.BACKGROUND)
  }
}

@Component
struct ProfileTab {
  @StorageLink(AppStorageKeys.IS_LOGGED_IN) private isLoggedIn: boolean = false;
  @StorageLink(AppStorageKeys.USER_NICKNAME) private nickname: string = '';
  @StorageLink(AppStorageKeys.USER_AVATAR) private avatar: string = '';

  build() {
    Column() {
      Text('我的')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(MD3Colors.ON_SURFACE)
        .width('100%')
        .padding({ left: 16, top: 16, bottom: 8 })

      if (this.isLoggedIn) {
        Row() {
          Image(this.avatar || ImageUtils.DEFAULT_COVER)
            .width(64)
            .height(64)
            .borderRadius(32)
            .objectFit(ImageFit.Cover)
            .margin({ right: 16 })

          Column() {
            Text(this.nickname || '用户')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor(MD3Colors.ON_SURFACE)
            Text('已登录')
              .fontSize(13)
              .fontColor(MD3Colors.ON_SURFACE_VARIANT)
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('90%')
        .padding(16)
        .backgroundColor(MD3Colors.SURFACE_CONTAINER)
        .borderRadius(16)
        .margin({ top: 16 })
      } else {
        Button() {
          Text('点击登录')
            .fontSize(16)
            .fontColor(MD3Colors.ON_PRIMARY)
            .fontWeight(FontWeight.Medium)
        }
        .width(200)
        .height(48)
        .backgroundColor(MD3Colors.PRIMARY)
        .borderRadius(24)
        .margin({ top: 32 })
        .onClick((event: ClickEvent): void => {
          router.pushUrl({ url: 'pages/LoginPage' });
        })
      }

      // 设置按钮
      Button() {
        Row() {
          Text('设置')
            .fontSize(16)
            .fontColor(MD3Colors.ON_SURFACE)
          Text('>')
            .fontSize(16)
            .fontColor(MD3Colors.ON_SURFACE_VARIANT)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .padding({ left: 16, right: 16 })
      }
      .width('90%')
      .height(56)
      .backgroundColor(MD3Colors.SURFACE_CONTAINER)
      .borderRadius(12)
      .margin({ top: 24 })
      .onClick((event: ClickEvent): void => {
        router.pushUrl({ url: 'pages/SettingsPage' });
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MD3Colors.BACKGROUND)
    .alignItems(HorizontalAlign.Center)
  }
}

@Entry
@Component
struct MainPage {
  @State private currentTabIndex: number = 0;
  private tabs: TabItem[] = [
    { title: '发现', icon: '/common/images/ic_discover.png', index: 0 },
    { title: '搜索', icon: '/common/images/ic_search.png', index: 1 },
    { title: '我的', icon: '/common/images/ic_profile.png', index: 2 }
  ];

  build() {
    Column() {
      Tabs({ index: this.currentTabIndex }) {
        TabContent() {
          DiscoverTab()
        }
        TabContent() {
          SearchTab()
        }
        TabContent() {
          ProfileTab()
        }
      }
      .barHeight(0)
      .layoutWeight(1)
      .onChange((index: number): void => {
        this.currentTabIndex = index;
      })
      .backgroundColor(MD3Colors.BACKGROUND)

      // 迷你播放器
      MiniPlayer()

      // 自定义底部Tab栏
      Row() {
        ForEach(this.tabs, (tab: TabItem): void => {
          Column() {
            Image(tab.icon)
              .width(24)
              .height(24)
              .fillColor(this.currentTabIndex === tab.index ? MD3Colors.PRIMARY : MD3Colors.ON_SURFACE_VARIANT)
            Text(tab.title)
              .fontSize(12)
              .fontColor(this.currentTabIndex === tab.index ? MD3Colors.PRIMARY : MD3Colors.ON_SURFACE_VARIANT)
              .margin({ top: 2 })
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .onClick((event: ClickEvent): void => {
            this.currentTabIndex = tab.index;
          })
        })
      }
      .width('100%')
      .height(56)
      .backgroundColor(MD3Colors.SURFACE)
      .padding({ bottom: 4 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MD3Colors.BACKGROUND)
  }
}
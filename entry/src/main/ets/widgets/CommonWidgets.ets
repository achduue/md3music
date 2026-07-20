@Builder function LoadingState(message: string) {
  Row() {
    LoadingProgress()
    Text(message)
      .fontSize(14)
      .fontColor('#FF49454F')
      .margin({ left: 8 })
  }
  .width('100%')
  .height(200)
  .justifyContent(FlexAlign.Center)
  .alignItems(VerticalAlign.Center)
  .direction(Direction.Column)
}

@Builder function ErrorState(message: string) {
  Column() {
    Text(message)
      .fontSize(14)
      .fontColor('#FFB3261E')
      .textAlign(TextAlign.Center)
      .margin(16)
  }
  .width('100%')
  .height(200)
  .justifyContent(FlexAlign.Center)
}

@Builder function EmptyState(message: string) {
  Column() {
    Text(message)
      .fontSize(14)
      .fontColor('#FF49454F')
      .margin(16)
  }
  .width('100%')
  .height(200)
  .justifyContent(FlexAlign.Center)
}
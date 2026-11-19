@Entry
@Component
struct Index {
  build() {
    Column() {
      Text('课间 · 鸿蒙测试')
        .fontSize(20)
        .fontColor('#235D50');
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center);
  }
}

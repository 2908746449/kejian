@Component
export struct ScheduleFormContent {
  @LocalStorageProp('heading') heading: string = '接下来';
  @LocalStorageProp('course1Name') course1Name: string = '暂无课程';
  @LocalStorageProp('course1Detail') course1Detail: string = '打开课间查看完整课表';
  @LocalStorageProp('course2Name') course2Name: string = '暂无课程';
  @LocalStorageProp('course2Detail') course2Detail: string = '打开课间查看完整课表';
  @Prop wide: boolean = false;

  build() {
    Column({ space: this.wide ? 14 : 10 }) {
      Row() {
        Text('课间')
          .fontSize(this.wide ? 16 : 13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#235D50');
        Blank();
        Text(this.heading)
          .fontSize(11)
          .fontColor('#74817D');
      }
      .width('100%');
      if (this.wide) {
        Row({ space: 12 }) {
          this.lesson(this.course1Name, this.course1Detail);
          this.lesson(this.course2Name, this.course2Detail);
        }
        .width('100%')
        .layoutWeight(1);
      } else {
        this.lesson(this.course1Name, this.course1Detail);
        this.lesson(this.course2Name, this.course2Detail);
      }
    }
    .padding(this.wide ? 16 : 12)
    .width('100%')
    .height('100%')
    .backgroundColor('#F8FAF8')
    .borderRadius(20)
    .onClick(() => {
      postCardAction(this, { action: 'router', abilityName: 'EntryAbility' });
    });
  }

  @Builder
  private lesson(name: string, detail: string) {
    Column({ space: 5 }) {
      Text(name)
        .fontSize(this.wide ? 15 : 13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#26322F')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%');
      Text(detail)
        .fontSize(this.wide ? 12 : 10)
        .fontColor('#74817D')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%');
    }
    .padding({ left: 10, right: 10, top: 8, bottom: 8 })
    .width('100%')
    .layoutWeight(1)
    .backgroundColor('#FFFFFF')
    .borderRadius(12);
  }
}

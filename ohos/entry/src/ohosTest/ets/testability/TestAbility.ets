import UIAbility from '@ohos.app.ability.UIAbility';
import AbilityDelegatorRegistry from '@ohos.app.ability.abilityDelegatorRegistry';
import hilog from '@ohos.hilog';
import { Hypium } from '@ohos/hypium';
import testsuite from '../test/List.test';
import window from '@ohos.window';

export default class TestAbility extends UIAbility {
  onCreate(): void {
    const delegator = AbilityDelegatorRegistry.getAbilityDelegator();
    const testArguments = AbilityDelegatorRegistry.getArguments();
    Hypium.hypiumTest(delegator, testArguments, testsuite);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('testability/pages/Index').catch((error: Error) => {
      hilog.error(0x0000, 'KejianTest', 'Unable to open test page: %{public}s', error.message);
    });
  }
}

"""Verify widget embedding and deployment settings; requires macOS plutil."""
import json
from pathlib import Path
import plistlib
import subprocess

root = Path(__file__).resolve().parents[1] / 'ios'
project = json.loads(subprocess.check_output([
    'plutil', '-convert', 'json', '-o', '-', str(root / 'Runner.xcodeproj/project.pbxproj')
]))
objects = project['objects']
targets = {o['name']: o for o in objects.values() if o.get('isa') == 'PBXNativeTarget'}
runner, widget = targets['Runner'], targets['ScheduleWidget']
assert widget['productType'] == 'com.apple.product-type.app-extension'
for target, entitlement in [(runner, 'Runner/Runner.entitlements'), (widget, 'ScheduleWidget/ScheduleWidget.entitlements')]:
    for config in objects[target['buildConfigurationList']]['buildConfigurations']:
        settings = objects[config]['buildSettings']
        assert settings['IPHONEOS_DEPLOYMENT_TARGET'] == '15.0'
        assert settings['CODE_SIGN_ENTITLEMENTS'] == entitlement
    sources = [objects[f]['fileRef'] for b in target['buildPhases']
               if objects[b]['isa'] == 'PBXSourcesBuildPhase' for f in objects[b]['files']]
    assert any(objects[f]['path'] == 'WidgetSnapshot.swift' for f in sources)
assert any(objects[d]['target'] in [k for k, v in objects.items() if v is widget] for d in runner['dependencies'])
phases = [objects[b] for b in runner['buildPhases']]
assert next(i for i,b in enumerate(phases) if b.get('dstSubfolderSpec') == '13') < next(i for i,b in enumerate(phases) if b.get('name') == 'Run Script'), 'Embed extensions before Flutter Run Script'
embed = [objects[b] for b in runner['buildPhases'] if objects[b].get('dstSubfolderSpec') == '13']
assert any(objects[f]['fileRef'] == widget['productReference'] for b in embed for f in b['files'])
for path in ['Runner/Runner.entitlements', 'ScheduleWidget/ScheduleWidget.entitlements']:
    with (root / path).open('rb') as file:
        assert plistlib.load(file)['com.apple.security.application-groups'] == ['$(KEJIAN_APP_GROUP)']
with (root / 'ScheduleWidget/Info.plist').open('rb') as file:
    assert plistlib.load(file)['NSExtension']['NSExtensionPointIdentifier'] == 'com.apple.widgetkit-extension'
print('iOS 15 targets, shared source membership, App Group entitlements, and embedded extension checked.')

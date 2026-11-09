"""Package an arm64 iPhoneOS Release app for an existing TrollStore install.

Requires macOS and ldid. No Apple provisioning profile or private entitlements
are used. TrollStore performs the installation signing on the user's device.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import plistlib
import re
import shutil
import struct
import subprocess
import tempfile
import zipfile
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
APP_ID = "dev.kejian.kejian"
WIDGET_ID = APP_ID + ".ScheduleWidget"
GROUP = "group.dev.kejian.kejian"
TEAM = "TROLLTROLL"  # Local identity, matching TrollStore's fallback team.
MACHO64 = b"\xcf\xfa\xed\xfe"


def read_plist(path: Path) -> dict:
    with path.open("rb") as file:
        return plistlib.load(file)


def macho_details(path: Path) -> dict | None:
    with path.open("rb") as file:
        if file.read(4) != MACHO64:
            return None
        header = file.read(28)
        cpu, _, _, command_count, _, _, _ = struct.unpack("<7I", header)
        if cpu != 0x0100000C:
            raise ValueError(f"Expected arm64: {path}")
        platform = minimum = None
        for _ in range(command_count):
            command, size = struct.unpack("<2I", file.read(8))
            payload = file.read(size - 8)
            if command == 0x32:  # LC_BUILD_VERSION
                platform, minimum = struct.unpack("<2I", payload[:8])
            elif command == 0x25:  # LC_VERSION_MIN_IPHONEOS
                platform, minimum = 2, struct.unpack("<I", payload[:4])[0]
        if platform != 2 or minimum is None:
            raise ValueError(f"Expected iPhoneOS device binary (platform 2): {path}")
        if minimum > (15 << 16):
            raise ValueError(f"Binary requires a system newer than iOS 15.0: {path}")
        version = f"{minimum >> 16}.{(minimum >> 8) & 255}.{minimum & 255}"
        return {"architecture": "arm64", "platform": "iPhoneOS", "minimumOS": version}


def validate_bundle(app: Path, version: str, build: str) -> None:
    widget = app / "PlugIns/ScheduleWidget.appex"
    for bundle, identifier in ((app, APP_ID), (widget, WIDGET_ID)):
        info = read_plist(bundle / "Info.plist")
        expected = {
            "CFBundleIdentifier": identifier,
            "CFBundleShortVersionString": version,
            "CFBundleVersion": build,
            "MinimumOSVersion": "15.0",
            "KejianAppGroup": GROUP,
        }
        for key, value in expected.items():
            if info.get(key) != value:
                raise ValueError(f"{bundle.name}: {key} expected {value!r}, got {info.get(key)!r}")
        if info.get("CFBundleSupportedPlatforms") != ["iPhoneOS"]:
            raise ValueError(f"Not an iPhoneOS app: {bundle}")
    if read_plist(widget / "Info.plist")["NSExtension"]["NSExtensionPointIdentifier"] != "com.apple.widgetkit-extension":
        raise ValueError("Expected embedded WidgetKit extension")
    if not (app / "Frameworks/App.framework/App").is_file():
        raise ValueError("Missing Flutter AOT application framework")
    assets = app / "Frameworks/App.framework/flutter_assets"
    if (assets / "kernel_blob.bin").exists():
        raise ValueError("Debug/JIT build is not suitable for this Release IPA")
    if (app / "embedded.mobileprovision").exists():
        raise ValueError("Expected a build without an Apple provisioning profile")


def sign_bundle(app: Path, temp: Path) -> list[dict]:
    binaries = []
    for path in sorted(app.rglob("*")):
        if not path.is_file() or path.is_symlink():
            continue
        details = macho_details(path)
        if details is None:
            continue
        subprocess.run(["ldid", "-S", str(path)], check=True)
        binaries.append({"path": str(path.relative_to(app)), **details})
    for executable, identifier in (
        (app / "Runner", APP_ID),
        (app / "PlugIns/ScheduleWidget.appex/ScheduleWidget", WIDGET_ID),
    ):
        values = {
            "application-identifier": f"{TEAM}.{identifier}",
            "com.apple.developer.team-identifier": TEAM,
            "com.apple.security.application-groups": [GROUP],
        }
        entitlements = temp / f"{executable.name}.plist"
        entitlements.write_bytes(plistlib.dumps(values))
        subprocess.run(["ldid", f"-S{entitlements}", str(executable)], check=True)
        signed = plistlib.loads(subprocess.check_output(["ldid", "-e", str(executable)]))
        if signed != values:
            raise ValueError(f"Signed entitlements did not match for {identifier}")
        subprocess.run(["codesign", "--verify", str(executable)], check=True)
    if not any(item["path"] == "Runner" for item in binaries):
        raise ValueError("App executable is missing or not Mach-O")
    if not any(item["path"] == "PlugIns/ScheduleWidget.appex/ScheduleWidget" for item in binaries):
        raise ValueError("Widget executable is missing or not Mach-O")
    return binaries


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    app = args.app.resolve()
    match = re.search(r"^version: ([^+\s]+)\+(\d+)\s*$", (PROJECT / "pubspec.yaml").read_text(), re.MULTILINE)
    if match is None:
        raise ValueError("pubspec.yaml must contain version: NAME+BUILD")
    version, build = match.groups()
    validate_bundle(app, version, build)
    args.output.mkdir(parents=True, exist_ok=True)
    ipa = args.output.resolve() / f"kejian-ios-trollstore-v{version}.ipa"
    with tempfile.TemporaryDirectory(prefix="kejian-ipa-") as directory:
        temp = Path(directory)
        staged = temp / "Payload/Runner.app"
        shutil.copytree(app, staged, symlinks=True)
        binaries = sign_bundle(staged, temp)
        subprocess.run(["ditto", "-c", "-k", "--keepParent", "--norsrc", str(staged.parent), str(ipa)], check=True)
    with zipfile.ZipFile(ipa) as archive:
        if archive.testzip() is not None:
            raise ValueError("Corrupt IPA archive")
        for required in ("Payload/Runner.app/Runner", "Payload/Runner.app/PlugIns/ScheduleWidget.appex/ScheduleWidget"):
            if required not in archive.namelist():
                raise ValueError(f"Missing IPA member: {required}")
    report = {
        "file": ipa.name,
        "sha256": hashlib.sha256(ipa.read_bytes()).hexdigest(),
        "version": version,
        "build": build,
        "minimumOS": "15.0",
        "appGroup": GROUP,
        "binaries": binaries,
        "installation": "Open in an existing TrollStore installation",
        "deviceVerified": False,
    }
    ipa.with_suffix(".json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

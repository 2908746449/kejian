#!/usr/bin/env python3
"""Prepare an isolated OHOS dependency graph without changing mobile lockfiles."""

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PDFRX_URL = "https://gitcode.com/oh-flutter/pdfrx.git"
PDFRX_REV = "99b3c7e37639a21c61b131950c94472fd4410945"
PDFIUM_SHA256 = "2e37967741a1353d19935cbda1b0c6ba802042713b2b422940ff90f725708edd"
PACKAGES = ("pdfrx", "pdfrx_engine", "pdfium_dart", "pdfium_flutter")


def prepare(checks_only: bool = False) -> Path:
    build_dir = ROOT / "build"
    build_dir.mkdir(exist_ok=True)
    destination = Path(tempfile.mkdtemp(prefix="harmonyos-", dir=build_dir))
    for name in ("pubspec.yaml", "pubspec.lock", "analysis_options.yaml"):
        shutil.copy2(ROOT / name, destination / name)
    options = destination / "analysis_options.yaml"
    options.write_text(options.read_text().replace(
        "  exclude:\n", "  exclude:\n    - third_party/**\n"))
    for name in ("lib", "assets", "test", "integration_test", "tool"):
        shutil.copytree(ROOT / name, destination / name,
                        ignore=shutil.ignore_patterns("__pycache__"))
    if not checks_only:
        shutil.copytree(ROOT / "ohos", destination / "ohos", ignore=shutil.ignore_patterns(
            "oh_modules", "node_modules", "build", ".hvigor", ".idea", ".preview",
            "local.properties", "flutter_assets", "GeneratedPluginRegistrant.ets",
            ".sign", "signing", "*.p12", "*.p7b", "*.cer", "*.pem", "*.keystore", "*.jks"))

    source = destination / "third_party" / "pdfrx"
    source.mkdir(parents=True)
    subprocess.run(["git", "init", "-q", str(source)], check=True)
    subprocess.run(["git", "-C", str(source), "fetch", "--depth=1", PDFRX_URL, PDFRX_REV],
                   check=True, stdout=subprocess.DEVNULL)
    subprocess.run(["git", "-C", str(source), "checkout", "--detach", "-q", "FETCH_HEAD"],
                   check=True)
    library = source / "packages/pdfium_flutter/ohos/libs/arm64-v8a/libpdfium.so"
    if hashlib.sha256(library.read_bytes()).hexdigest() != PDFIUM_SHA256:
        raise RuntimeError("Pinned OHOS PDFium library failed SHA-256 verification")

    for package in PACKAGES:
        manifest = source / "packages" / package / "pubspec.yaml"
        manifest.write_text(manifest.read_text().replace("resolution: workspace\n", ""))
    # code_assets 1.x does not recognize OHOS. The library is packaged in the
    # plugin HAR instead; retaining the Darwin-only metadata is unnecessary.
    (source / "packages/pdfium_flutter/hook/link.dart").write_text(
        "import 'package:hooks/hooks.dart';\n"
        "void main(List<String> args) async {\n"
        "  await link(args, (input, output) async {\n"
        "    output.assets.addEncodedAssets(input.assets.encodedAssets);\n"
        "  });\n"
        "}\n")
    overrides = {"dependency_overrides": {
        package: {"path": f"third_party/pdfrx/packages/{package}"} for package in PACKAGES
    }}
    (destination / "pubspec_overrides.yaml").write_text(json.dumps(overrides, indent=2) + "\n")
    (destination / "HARMONYOS_SOURCE.json").write_text(json.dumps({
        "source": str(ROOT),
        "source_revision": subprocess.check_output(
            ["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip(),
        "source_has_local_changes": bool(subprocess.check_output(
            ["git", "-C", str(ROOT), "status", "--porcelain"], text=True).strip()),
        "pdfrx_repository": PDFRX_URL,
        "pdfrx_revision": PDFRX_REV, "pdfium_sha256": PDFIUM_SHA256,
        "checks_only": checks_only,
    }, indent=2) + "\n")
    return destination


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checks-only", action="store_true",
                        help="Omit the OHOS host to allow Dart checks without a Harmony SDK")
    args = parser.parse_args()
    print(prepare(checks_only=args.checks_only))

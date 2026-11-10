#!/usr/bin/env python3
"""Check the actual arm64 release APK before uploading it."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import zipfile


def run(*command: str) -> str:
    result = subprocess.run(command, text=True, capture_output=True, check=False)
    if result.returncode:
        raise RuntimeError(f"{' '.join(command)} failed:\n{result.stdout}{result.stderr}")
    return result.stdout


def check(apk: Path, build_tools: Path) -> dict:
    project = Path(__file__).resolve().parents[1]
    version = re.search(r"^version: (\S+)\+(\d+)$", (project / "pubspec.yaml").read_text(), re.MULTILINE)
    if not version:
        raise ValueError("pubspec.yaml must specify version: NAME+BUILD")
    badging = run(str(build_tools / "aapt2"), "dump", "badging", str(apk))
    package = re.search(r"package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'", badging)
    if not package or package.groups() != ("dev.kejian.kejian", version[2], version[1]):
        raise ValueError("APK package/version does not match the project")
    if "native-code: 'arm64-v8a'\n" not in badging:
        raise ValueError("APK must advertise only arm64-v8a")
    with zipfile.ZipFile(apk) as archive:
        entries = archive.namelist()
        if archive.testzip() or len(entries) != len(set(entries)):
            raise ValueError("APK has corrupt or duplicate ZIP entries")
        if archive.getinfo("resources.arsc").compress_type != zipfile.ZIP_STORED:
            raise ValueError("resources.arsc must be uncompressed")
        for name in ("META-INF/MANIFEST.MF", "META-INF/CERT.SF", "META-INF/CERT.RSA"):
            archive.getinfo(name)
        libraries = [name for name in entries if name.startswith("lib/") and name.endswith(".so")]
        for name in libraries:
            data = archive.read(name)
            if not name.startswith("lib/arm64-v8a/") or data[:6] != b"\x7fELF\x02\x01" or struct.unpack_from("<H", data, 18)[0] != 183:
                raise ValueError(f"Unexpected native architecture: {name}")
            if archive.getinfo(name).compress_type != zipfile.ZIP_DEFLATED:
                raise ValueError(f"Expected extractable compressed library: {name}")
        for required in ("libapp.so", "libflutter.so", "libpdfium.so", "libmlkit_google_ocr_pipeline.so"):
            if f"lib/arm64-v8a/{required}" not in libraries:
                raise ValueError(f"Missing native library: {required}")
    run(str(build_tools / "zipalign"), "-c", "-P", "16", "4", str(apk))
    schemes = {}
    for sdk, scheme in ((23, "v1"), (24, "v2"), (28, "v3")):
        output = run(str(build_tools / "apksigner"), "verify", "--verbose", "--min-sdk-version", str(sdk), "--max-sdk-version", str(sdk), str(apk))
        if not re.search(rf"Verified using {scheme} scheme[^\n]*: true", output):
            raise ValueError(f"{scheme} signature did not verify")
        schemes[scheme] = True
    signer = run(str(build_tools / "apksigner"), "verify", "--print-certs", "--min-sdk-version", "24", "--max-sdk-version", "34", str(apk))
    certificate = re.search(r"certificate SHA-256 digest: ([0-9a-f]+)", signer)
    if not certificate:
        raise ValueError("APK signer certificate was not reported")
    return {
        "file": apk.name, "size": apk.stat().st_size,
        "sha256": hashlib.sha256(apk.read_bytes()).hexdigest(),
        "package": package[1], "version": package[3], "build": package[2],
        "abi": "arm64-v8a", "nativeLibraries": libraries,
        "signatureSchemes": schemes, "certificateSha256": certificate[1],
        "sourceCommit": run("git", "-C", str(project), "rev-parse", "HEAD").strip(),
        "deviceVerified": False,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    parser.add_argument("--build-tools", type=Path, required=True)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    report = check(args.apk.resolve(), args.build_tools.resolve())
    output = json.dumps(report, indent=2, ensure_ascii=False) + "\n"
    if args.report:
        args.report.write_text(output)
    print(output, end="")

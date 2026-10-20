#!/usr/bin/env python3
"""把桌面安装包写成 Sparkle / WinSparkle 的 appcast.xml。

私钥来自环境变量，不写入仓库：
- SPARKLE_ED25519_KEY：macOS Ed25519 PEM
- WINSPARKLE_DSA_PRIVATE_KEY：Windows DSA PEM
没配密钥时仍生成订阅，但对应安装包不带签名，Sparkle 会拒绝安装。
"""

from __future__ import annotations

import argparse
import base64
import email.utils
import os
import subprocess
import sys
import tempfile
import xml.sax.saxutils
from pathlib import Path


def parse_pubspec_version(text: str) -> tuple[str, str]:
    for line in text.splitlines():
        if line.startswith("version:"):
            raw = line.split(":", 1)[1].strip()
            name, _, build = raw.partition("+")
            return name, build or "0"
    raise ValueError("pubspec.yaml 缺少 version")


def installer_os(filename: str) -> str | None:
    if filename.endswith(".dmg"):
        return "macos"
    if filename.endswith(".exe"):
        return "windows"
    return None


def escape(value: str) -> str:
    return xml.sax.saxutils.escape(value, {'"': "&quot;"})


def sign_file(path: Path, kind: str, pem_text: str) -> str:
    suffix = ".pem"
    with tempfile.NamedTemporaryFile("w", suffix=suffix, delete=False) as handle:
        handle.write(pem_text)
        if not pem_text.endswith("\n"):
            handle.write("\n")
        key_path = handle.name
    try:
        if kind == "ed25519":
            signature = subprocess.check_output(
                [
                    "openssl",
                    "pkeyutl",
                    "-sign",
                    "-inkey",
                    key_path,
                    "-rawin",
                    "-in",
                    str(path),
                ],
            )
        elif kind == "dsa":
            signature = subprocess.check_output(
                [
                    "openssl",
                    "dgst",
                    "-sha1",
                    "-sign",
                    key_path,
                    "-binary",
                    str(path),
                ],
            )
        else:
            raise ValueError(kind)
    finally:
        os.remove(key_path)
    return base64.b64encode(signature).decode("ascii")


def build_appcast(
    *,
    version_name: str,
    version_build: str,
    tag: str,
    repository: str,
    installers: list[tuple[Path, str, str | None]],
) -> str:
    enclosures: list[str] = []
    # 国内网络到 github.com 的下载链路不稳定（实测 5 次断点重试仅 2.2MB/30MB，
    # Sparkle 报 "An error occurred while downloading the update"）——
    # gh-proxy.com 实测全量 30MB 60s 拉满。安装包下载统一走代理前缀。
    download_proxy = "https://gh-proxy.com/"
    for path, operating_system, signature in installers:
        url = (
            f"{download_proxy}https://github.com/{repository}/releases/download/"
            f"{tag}/{path.name}"
        )
        attributes = [
            f'url="{escape(url)}"',
            f'sparkle:os="{operating_system}"',
            f'sparkle:version="{escape(version_build)}"',
            f'sparkle:shortVersionString="{escape(version_name)}"',
            f'length="{path.stat().st_size}"',
            'type="application/octet-stream"',
        ]
        if signature and operating_system == "macos":
            attributes.append(f'sparkle:edSignature="{escape(signature)}"')
        if signature and operating_system == "windows":
            attributes.append(f'sparkle:dsaSignature="{escape(signature)}"')
        enclosures.append(f"      <enclosure {' '.join(attributes)} />")
    if not enclosures:
        raise ValueError("没有可写入 appcast 的 dmg 或 exe")
    published = email.utils.formatdate(usegmt=True)
    body = "\n".join(enclosures)
    return f"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>zh-cloud todo</title>
    <item>
      <title>{escape(version_name)}</title>
      <pubDate>{published}</pubDate>
{body}
    </item>
  </channel>
</rss>
"""


def collect_installers(dist: Path) -> list[tuple[Path, str]]:
    found: list[tuple[Path, str]] = []
    for path in sorted(dist.iterdir()):
        if not path.is_file():
            continue
        operating_system = installer_os(path.name)
        if operating_system is not None:
            found.append((path, operating_system))
    return found


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dist", required=True)
    parser.add_argument("--pubspec", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument(
        "--repository",
        default=os.environ.get("GITHUB_REPOSITORY", "izhaong/zh-cloud-todo-flutter"),
    )
    args = parser.parse_args(argv)
    version_name, version_build = parse_pubspec_version(
        Path(args.pubspec).read_text(encoding="utf-8")
    )
    ed_key = os.environ.get("SPARKLE_ED25519_KEY", "").strip()
    dsa_key = os.environ.get("WINSPARKLE_DSA_PRIVATE_KEY", "").strip()
    signed: list[tuple[Path, str, str | None]] = []
    for path, operating_system in collect_installers(Path(args.dist)):
        signature: str | None = None
        if operating_system == "macos":
            if ed_key:
                signature = sign_file(path, "ed25519", ed_key)
            else:
                print(
                    "appcast: 未配置 SPARKLE_ED25519_KEY，macOS 包没有签名",
                    file=sys.stderr,
                )
        elif operating_system == "windows":
            if dsa_key:
                signature = sign_file(path, "dsa", dsa_key)
            else:
                print(
                    "appcast: 未配置 WINSPARKLE_DSA_PRIVATE_KEY，Windows 包没有签名",
                    file=sys.stderr,
                )
        signed.append((path, operating_system, signature))
    xml = build_appcast(
        version_name=version_name,
        version_build=version_build,
        tag=args.tag,
        repository=args.repository,
        installers=signed,
    )
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(xml, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

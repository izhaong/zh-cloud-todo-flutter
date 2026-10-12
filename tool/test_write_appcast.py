#!/usr/bin/env python3
"""write_appcast.py 的文件选择与签名属性。"""

import subprocess
import tempfile
import unittest
from pathlib import Path

import write_appcast


class WriteAppcastTest(unittest.TestCase):
    def test_only_dmg_and_exe_enter_the_feed(self) -> None:
        self.assertEqual(write_appcast.installer_os("todo-flutter-1.0.5-aarch64.dmg"), "macos")
        self.assertEqual(write_appcast.installer_os("todo-flutter-1.0.5-x86_64.exe"), "windows")
        self.assertIsNone(write_appcast.installer_os("todo-flutter-1.0.5-x86_64.deb"))
        self.assertIsNone(write_appcast.installer_os("todo-flutter-1.0.5-android.apk"))

    def test_pubspec_version_splits_build_number(self) -> None:
        self.assertEqual(
            write_appcast.parse_pubspec_version("name: demo\nversion: 1.0.5+6\n"),
            ("1.0.5", "6"),
        )

    def test_appcast_points_at_github_release_assets(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            dmg = root / "todo-flutter-1.0.5-aarch64.dmg"
            exe = root / "todo-flutter-1.0.5-x86_64.exe"
            deb = root / "todo-flutter-1.0.5-x86_64.deb"
            dmg.write_bytes(b"dmg")
            exe.write_bytes(b"exe-bytes")
            deb.write_bytes(b"deb")
            xml = write_appcast.build_appcast(
                version_name="1.0.5",
                version_build="6",
                tag="v1.0.5",
                repository="izhaong/zh-cloud-todo-flutter",
                installers=[
                    (dmg, "macos", "ed-sig"),
                    (exe, "windows", "dsa-sig"),
                ],
            )
        self.assertIn(
            "https://github.com/izhaong/zh-cloud-todo-flutter/releases/download/v1.0.5/todo-flutter-1.0.5-aarch64.dmg",
            xml,
        )
        self.assertIn('sparkle:edSignature="ed-sig"', xml)
        self.assertIn('sparkle:dsaSignature="dsa-sig"', xml)
        self.assertIn('sparkle:shortVersionString="1.0.5"', xml)
        self.assertIn('length="3"', xml)
        self.assertNotIn(".deb", xml)

    def test_ed25519_signature_is_base64(self) -> None:
        openssl = "openssl"
        try:
            probe = subprocess.run(
                [openssl, "genpkey", "-algorithm", "ED25519"],
                check=False,
                capture_output=True,
            )
        except FileNotFoundError:
            self.skipTest("openssl 不存在")
        if probe.returncode != 0:
            self.skipTest("当前 openssl 不能生成 Ed25519")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            key = root / "key.pem"
            key.write_bytes(probe.stdout)
            payload = root / "payload.bin"
            payload.write_bytes(b"hello")
            signature = write_appcast.sign_file(payload, "ed25519", key.read_text())
        self.assertTrue(signature)
        self.assertNotIn("PRIVATE", signature)


if __name__ == "__main__":
    unittest.main()

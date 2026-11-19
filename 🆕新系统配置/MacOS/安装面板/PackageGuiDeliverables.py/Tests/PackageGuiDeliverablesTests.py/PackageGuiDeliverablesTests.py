#!/usr/bin/env python3
"""仅用临时夹具验证GUI归档，不构建或运行真实App/EXE。Created by Jobs."""

import hashlib
import importlib.util
import json
import logging
import os
import plistlib
import struct
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path, PurePosixPath
from unittest import mock


SOURCE = Path(__file__).resolve().parents[2] / "PackageGuiDeliverables.py"
MODULE_SPEC = importlib.util.spec_from_file_location("jobs_gui_packager", SOURCE)
PACKAGER = importlib.util.module_from_spec(MODULE_SPEC)
sys.modules[MODULE_SPEC.name] = PACKAGER
MODULE_SPEC.loader.exec_module(PACKAGER)


class PackagingTests(unittest.TestCase):
    # 每个测试只在独立临时目录创建源码/产物形状夹具。
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="Jobs GUI 归档测试 空格-")
        self.root = Path(self.directory.name).resolve()

    # 清理本测试拥有的临时目录，不接触业务源码与输出。
    def tearDown(self):
        self.directory.cleanup()

    # 简化夹具写入，确保编码与实际源目录命名一致。
    def write(self, relative, content=b"fixture"):
        target = self.root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
        return target

    # 创建仅用于PE解析测试的MZ/PE头，绝不作为真实成品发布。
    def pe_fixture(self, relative):
        content = bytearray(128)
        content[:2] = b"MZ"
        struct.pack_into("<I", content, 0x3C, 64)
        content[64:68] = b"PE\0\0"
        struct.pack_into("<H", content, 68, 0x014C)
        return self.write(relative, content)

    # 创建最小Mac收据/Payload形状；签名调用仅在测试内替身。
    def app_fixture(self, app, source, profile):
        source = self.write(source, b"fixture Swift source")
        self.write(f"{app}/Contents/MacOS/JobsEnvironmentManager", b"fixture executable")
        resource = self.root / app / "Contents/Resources"
        resource.mkdir(parents=True, exist_ok=True)
        receipt = {"profile": profile, "builtAtUTC": "2026-11-17T00:00:00Z", "sourceSHA256": PACKAGER.file_sha256(source)}
        (resource / "BuildReceipt.plist").write_bytes(plistlib.dumps(receipt))
        (resource / "data.txt").write_bytes(b"fixture runtime resource")
        payload = "".join(PACKAGER.file_sha256(p) + "  ./" + p.name + "\n" for p in sorted(resource.iterdir()))
        (resource / "Payload.sha256").write_text(payload)

    # 固定日期与权限使相同文件在修改mtime后仍生成相同ZIP。
    def test_deterministic_zip_and_readback(self):
        source = self.write("sources/中文 file.txt", b"current user edits\n")
        tree = PACKAGER.InputTree(source.parent, PurePosixPath("package"))
        entries = PACKAGER.collect_entries([tree])
        one = PACKAGER.write_verified_zip(self.root / "one.zip", entries)
        os.utime(source, (1_700_000_000, 1_700_000_000))
        two = PACKAGER.write_verified_zip(self.root / "two.zip", PACKAGER.collect_entries([tree]))
        self.assertEqual(one["sha256"], two["sha256"])
        with zipfile.ZipFile(self.root / "one.zip") as archive:
            self.assertEqual(archive.read("package/中文 file.txt"), b"current user edits\n")

    # 产品去除开发Tests/Launcher，保留运行必需C#辅助源码。
    def test_product_exclusions(self):
        for name in ("Tests/test.txt", "Launcher/program.cs", "Resources/PanelWorker.cs", "__pycache__/a.pyc", ".git/config", "README.md"):
            self.write("runtime/" + name)
        product = PACKAGER.collect_entries([PACKAGER.InputTree(self.root / "runtime", PurePosixPath("Runtime"), True)])
        self.assertEqual([entry.archive for entry in product], ["Runtime/README.md", "Runtime/Resources/PanelWorker.cs"])
        source = PACKAGER.collect_entries([PACKAGER.InputTree(self.root / "runtime", PurePosixPath("Runtime"))])
        self.assertIn("Runtime/Launcher/program.cs", [entry.archive for entry in source])

    # 当前文件内容变化不能通过旧摘要发布。
    def test_mutated_source_rejected(self):
        source = self.write("source.txt", b"before")
        entries = PACKAGER.collect_entries([PACKAGER.InputTree(source, PurePosixPath("source.txt"))])
        source.write_bytes(b"changed")
        with self.assertRaises(PACKAGER.PackagingError):
            PACKAGER.write_verified_zip(self.root / "mutated.zip", entries)

    # 绝对和穿越路径不能进入压缩包。
    def test_archive_path_validation(self):
        for name in ("../escape", "/absolute", "dir/../../escape", "dir\\escape", "bad\nname"):
            with self.subTest(name=name), self.assertRaises(PACKAGER.PackagingError):
                PACKAGER.assert_archive_name(name)

    # 不跟随逃出输入树的链接，也不打包账户数据。
    def test_symlink_and_secret_rejection(self):
        self.write("outside.txt")
        self.write("source/inside.txt")
        (self.root / "source/link").symlink_to("../outside.txt")
        with self.assertRaises(PACKAGER.PackagingError):
            PACKAGER.collect_entries([PACKAGER.InputTree(self.root / "source", PurePosixPath("Source"))])
        (self.root / "source/link").unlink()
        self.write("source/credentials.json", b"never print or archive")
        with self.assertRaises(PACKAGER.PackagingError):
            PACKAGER.collect_entries([PACKAGER.InputTree(self.root / "source", PurePosixPath("Source"))])

    # 保留输入树内相对链接而不是把它展开成另一份文件。
    def test_safe_symlink_preserved(self):
        self.write("source/file.txt")
        (self.root / "source/link").symlink_to("file.txt")
        entries = PACKAGER.collect_entries([PACKAGER.InputTree(self.root / "source", PurePosixPath("Source"))])
        link = [entry for entry in entries if entry.kind == "symlink"][0]
        self.assertEqual(link.link_target, "file.txt")
        PACKAGER.write_verified_zip(self.root / "links.zip", entries)

    # 假扩展名不是PE，合法头只代表格式，不宣称原生运行通过。
    def test_pe_validation(self):
        executable = self.pe_fixture("fixture.exe")
        result = PACKAGER.verify_windows_exe(executable)
        self.assertFalse(result["nativeWindowsExecutionVerifiedByPackager"])
        executable.write_bytes(b"not executable")
        with self.assertRaises(PACKAGER.PackagingError):
            PACKAGER.verify_windows_exe(executable)

    # Mac收据必须绑定当前Swift，Payload必须覆盖全部资源。
    @mock.patch.object(PACKAGER.subprocess, "run", return_value=mock.Mock(returncode=0))
    def test_mac_receipt_and_full_payload(self, _run):
        self.app_fixture("System.app", "EnvironmentManager.swift", "system")
        spec = PACKAGER.DeliverySpec("Mac", "Mac", "MacOS", "native-app", "source", [], "System.app", [], [], [], [], app=self.root / "System.app", swift_source=self.root / "EnvironmentManager.swift", profile="system")
        result = PACKAGER.verify_mac_app(spec)
        self.assertEqual(result["resourceCount"], 2)
        self.write("System.app/Contents/Resources/unlisted.txt")
        with self.assertRaises(PACKAGER.PackagingError):
            PACKAGER.verify_mac_app(spec)
        (self.root / "System.app/Contents/Resources/unlisted.txt").unlink()
        spec.swift_source.write_bytes(b"different current source")
        with self.assertRaises(PACKAGER.PackagingError):
            PACKAGER.verify_mac_app(spec)

    # 包自身Payload仍正确但当前后端源码已变，也必须拒绝新源码配旧产品。
    @mock.patch.object(PACKAGER.subprocess, "run", return_value=mock.Mock(returncode=0))
    def test_mac_current_source_changes_reject_stale_bundle(self, _run):
        for profile in ("system", "env"):
            with self.subTest(profile=profile):
                source_root = self.root / profile
                self.app_fixture(f"{profile}/Manager.app", f"{profile}/安装面板/Sources/EnvironmentManager.swift", profile)
                current_source = self.write(f"{profile}/scripts/active.sh", b"current backend before update\n")
                bundled_source = self.write(f"{profile}/Manager.app/Contents/Resources/package/scripts/active.sh", current_source.read_bytes())
                resource = source_root / "Manager.app/Contents/Resources"
                payload_files = sorted(path for path in resource.rglob("*") if path.is_file() and path.name != "Payload.sha256")
                (resource / "Payload.sha256").write_text("".join(PACKAGER.file_sha256(path) + "  ./" + path.relative_to(resource).as_posix() + "\n" for path in payload_files))
                spec = PACKAGER.DeliverySpec(profile, profile, "MacOS", "native-app", "source", [], "Manager.app", [], [], [], [], app=source_root / "Manager.app", swift_source=source_root / "安装面板/Sources/EnvironmentManager.swift", profile=profile)
                self.assertEqual(PACKAGER.verify_mac_app(spec)["currentPackageSourceFilesMatched"], 1)
                # 显式源根与生产的Swift父级推算得到相同核验结果。
                self.assertEqual(PACKAGER.verify_mac_app(spec, source_root)["currentPackageSourceFilesMatched"], 1)
                original_bundle_hash = PACKAGER.file_sha256(bundled_source)
                current_source.write_bytes(b"current backend changed after app build\n")
                self.assertEqual(PACKAGER.file_sha256(bundled_source), original_bundle_hash)
                with self.assertRaisesRegex(PACKAGER.PackagingError, "落后于当前源树"):
                    PACKAGER.verify_mac_app(spec)
                current_source.unlink()
                with self.assertRaisesRegex(PACKAGER.PackagingError, "当前源树缺失"):
                    PACKAGER.verify_mac_app(spec)

    # 包内原目录精确映射新源树，摘要变更或新源缺失仍须拒绝。
    @mock.patch.object(PACKAGER.subprocess, "run", return_value=mock.Mock(returncode=0))
    def test_system_bundle_root_maps_to_current_multi_platform_tree(self, _run):
        swift_relative = f"{PACKAGER.SYSTEM_PANEL}/Sources/EnvironmentManager.swift"
        self.app_fixture("Manager.app", swift_relative, "system")
        relative = "MacOS/【MacOS】🆕新系统配置.command/backend.command"
        current = self.write(f"{PACKAGER.MULTI}/{relative}", b"current backend\n")
        resource = self.root / "Manager.app/Contents/Resources"
        self.write(f"Manager.app/Contents/Resources/package/{PACKAGER.BUNDLED_SYSTEM_ROOT}/{relative}", current.read_bytes())
        payload_files = sorted(path for path in resource.rglob("*") if path.is_file() and path.name != "Payload.sha256")
        (resource / "Payload.sha256").write_text("".join(PACKAGER.file_sha256(path) + "  ./" + path.relative_to(resource).as_posix() + "\n" for path in payload_files))
        spec = PACKAGER.DeliverySpec("System", "System", "MacOS", "native-app", "source", [], "Manager.app", [], [], [], [], app=self.root / "Manager.app", swift_source=self.root / swift_relative, profile="system")
        self.assertEqual(PACKAGER.verify_mac_app(spec)["currentPackageSourceFilesMatched"], 1)
        current.write_bytes(b"changed backend\n")
        with self.assertRaisesRegex(PACKAGER.PackagingError, "落后于当前源树"):
            PACKAGER.verify_mac_app(spec)
        current.unlink()
        self.write(f"{PACKAGER.BUNDLED_SYSTEM_ROOT}/{relative}", b"current backend\n")
        with self.assertRaisesRegex(PACKAGER.PackagingError, "当前源树缺失"):
            PACKAGER.verify_mac_app(spec)

    # 九套规范必须保持范围稳定，产品不能静默遗漏EXE或Mac收据。
    def test_fixed_nine_specs_and_missing_inputs(self):
        specs = PACKAGER.delivery_specs(self.root)
        self.assertEqual(len(specs), 9)
        plans, errors = PACKAGER.inspect_specs(specs)
        self.assertEqual(len(plans), 9)
        self.assertTrue(errors)
        self.assertFalse((self.root / "交付产物").exists())

    # 输入树内输出在写入前拒绝，不会递归打入自身stage。
    def test_output_inside_input_rejected(self):
        with self.assertRaises(PACKAGER.PackagingError):
            PACKAGER.main(["--project-root", str(self.root), "--output", f"{PACKAGER.SYSTEM_PANEL}/Output", "--yes"])
        self.assertFalse((self.root / PACKAGER.SYSTEM_PANEL / "Output").exists())

    # 输出祖先为链接时拒绝，不覆盖它指向的目录。
    def test_output_symlink_rejected(self):
        (self.root / "elsewhere").mkdir()
        (self.root / "link").symlink_to(self.root / "elsewhere", target_is_directory=True)
        with self.assertRaises(PACKAGER.PackagingError):
            PACKAGER.prepare_output(self.root / "link/Output")

    # 九套归档只使用格式夹具，验证发布结构、相对层级、摘要和旧版本保全。
    @mock.patch.object(PACKAGER.subprocess, "run", return_value=mock.Mock(returncode=0))
    def test_nine_package_fixture_publish(self, _run):
        multi = PACKAGER.MULTI
        env = PACKAGER.ENVIRONMENT
        self.app_fixture(f"{multi}/MacOS/{PACKAGER.SYSTEM_APP}", f"{PACKAGER.SYSTEM_PANEL}/Sources/EnvironmentManager.swift", "system")
        self.app_fixture(f"{env}/{PACKAGER.ENVIRONMENT_APP}", f"{env}/安装面板/Sources/EnvironmentManager.swift", "env")
        self.write("icon.png")
        self.write(f"{env}/icon.png")
        for item in ("安装面板/Resources/PanelTranslations.json", "安装面板/【MacOS】构建安装面板.command/【MacOS】构建安装面板.command"):
            self.write(f"{multi}/MacOS/{item}")
            self.write(f"{env}/{item}")
        self.write(f"{PACKAGER.SYSTEM_PANEL}/【MacOS@Xcode】准备面板资源.command/【MacOS@Xcode】准备面板资源.command")
        self.write(f"{multi}/MacOS/【MacOS】🆕新系统配置.command/【MacOS】🆕新系统配置.command")
        self.write(f"{multi}/MacOS/{PACKAGER.SYSTEM_PROJECT}/project.pbxproj")
        for item in ("scripts/tool.sh", "zsh/custom.zsh", "Sys/module.sh", "【MacOS】环境管理后端.command/【MacOS】环境管理后端.command", "sync_env.txt"):
            self.write(f"{env}/{item}")
        windows = f"{multi}/WindowsOS/{PACKAGER.WINDOWS_GUI}"
        self.write(f"{windows}/{PACKAGER.WINDOWS_GUI}")
        self.write(f"{windows}/Resources/PanelWorker.cs")
        self.write(f"{windows}/Resources/PanelTranslations.json")
        self.write(f"{windows}/Launcher/JobsSystemSetupManager.csproj")
        self.write(f"{windows}/Launcher/Program.cs")
        for item in ("app.manifest", "NuGet.Config", "packages.lock.json"):
            self.write(f"{windows}/Launcher/{item}")
        self.write(f"{windows}/Launcher/bin/compiler-output.dll")
        self.pe_fixture(f"{windows}/{PACKAGER.WINDOWS_EXE}")
        self.write(f"{windows}/{PACKAGER.WINDOWS_EXE}.config")
        base = self.root / windows
        receipt = {"schemaVersion": 1, "product": "JobsSystemSetupManager", "actualBuildUtc": "2026-11-17T00:00:00Z", "sourceFiles": [{"path": f"Launcher/{item}", "sha256": PACKAGER.file_sha256(base / "Launcher" / item)} for item in ("JobsSystemSetupManager.csproj", "Program.cs", "app.manifest", "NuGet.Config", "packages.lock.json")], "outputs": [{"path": item, "sha256": PACKAGER.file_sha256(base / item), "sizeBytes": (base / item).stat().st_size} for item in (PACKAGER.WINDOWS_EXE, PACKAGER.WINDOWS_EXE + ".config")]}
        self.write(f"{windows}/LauncherBuildReceipt.json", json.dumps(receipt).encode())
        shared = f"{multi}/安装面板"
        for item in ("UnixManager.tcl/UnixManager.tcl", "UnixManager.tcl/ManagerCore.tcl", "UnixManager.tcl/RunBackend.sh/RunBackend.sh", "Resources/UnixTranslations.dict"):
            self.write(f"{shared}/{item}")
        for platform in PACKAGER.UNIX_PLATFORMS:
            for action in ("🧰新系统配置管理", "🆕新系统配置"):
                filename = f"【{platform}】{action}.sh"
                self.write(f"{multi}/{platform}/{filename}/{filename}")
        specs = PACKAGER.delivery_specs(self.root)
        plans, errors = PACKAGER.inspect_specs(specs)
        self.assertEqual(errors, [])
        output = self.root / multi / "交付产物/GUI源码与成品"
        old = output / "existing-version/keep.txt"
        old.parent.mkdir(parents=True)
        old.write_text("existing deliverable")
        published = PACKAGER.package_all(self.root, output, specs, plans)
        self.assertEqual(old.read_text(), "existing deliverable")
        self.assertEqual(len(list(published.glob("*/source.zip"))), 9)
        self.assertEqual(len(list(published.glob("*/product.zip"))), 9)
        for spec in specs:
            directory = published / spec.key
            manifest = json.loads((directory / "manifest.json").read_text())
            self.assertEqual(manifest["id"], spec.key)
            for archive in ("source", "product"):
                item = manifest["archives"][archive]
                self.assertEqual(PACKAGER.file_sha256(directory / item["file"]), item["sha256"])
        with zipfile.ZipFile(published / "MacOS-System/source.zip") as archive:
            self.assertIn(f"JobsConfigOS/{multi}/MacOS/{PACKAGER.SYSTEM_PROJECT}/project.pbxproj", archive.namelist())
            self.assertIn(f"JobsConfigOS/{PACKAGER.SYSTEM_PANEL}/Sources/EnvironmentManager.swift", archive.namelist())
        with zipfile.ZipFile(published / "WindowsOS/source.zip") as archive:
            self.assertFalse(any("Launcher/bin/" in item for item in archive.namelist()))


if __name__ == "__main__":
    logging.disable(logging.CRITICAL)
    unittest.main(verbosity=2)

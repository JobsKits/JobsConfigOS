#!/usr/bin/env python3
"""Jobs GUI 源码与成品打包器（Python 3.9+，仅标准库）。

默认 --plan 只读列出九套明确输入及缺失项；--yes 才生成版本化交付目录。
只归档当前源码与真实产物，不编译、不安装、不卸载、不覆盖旧交付物。
Created by Jobs on 2026年11月17日，星期二.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import logging
import os
import plistlib
import re
import stat
import struct
import subprocess
import sys
import tempfile
import zipfile
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path, PurePosixPath
from typing import Dict, Iterable, List, Optional, Sequence, Tuple


MULTI = "🆕新系统配置"
SYSTEM_PANEL = f"{MULTI}/MacOS/安装面板"
BUNDLED_SYSTEM_ROOT = "【MacOS】🆕新系统配置"
ENVIRONMENT = "🌍JobsMacEnvVarConfigs"
SYSTEM_APP = "【MacOS】🧰新系统配置管理.app"
ENVIRONMENT_APP = "【MacOS】🌍环境配置管理.app"
SYSTEM_PROJECT = "【MacOS】🧰新系统配置管理.xcodeproj"
ENVIRONMENT_PROJECT = "【MacOS】🌍环境配置管理.xcodeproj"
WINDOWS_GUI = "【WindowsOS】🧰新系统配置管理.ps1"
WINDOWS_EXE = "JobsSystemSetupManager.exe"
UNIX_PLATFORMS = ("Ubuntu", "Debian", "RockyLinux", "Alpine", "AlibabaCloudLinux", "FreeBSD")
ZIP_TIME = (1980, 1, 1, 0, 0, 0)
SHANGHAI = timezone(timedelta(hours=8), "Asia/Shanghai")
SKIP_NAMES = {
    ".git", ".DS_Store", "node_modules", "Pods", ".dart_tool", "build", "Build",
    "DerivedData", "__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache",
    ".venv", "venv", ".cache", "Caches", "Cache", "work", "Work", "dist", "Dist",
    "Logs", "logs", "Backups", "backups", ".runtime", ".tools", ".jobs-markdown-toc",
    "xcuserdata", "UserInterfaceState.xcuserstate", ".swiftpm", ".build", "交付产物",
}
SECRET_NAMES = {".env", "auth.json", "credentials.json", "credentials", "cookies", "cookies.json", "login data", "id_rsa", "id_ed25519", "id_ecdsa"}
SECRET_SUFFIXES = {".pem", ".key", ".p12", ".pfx", ".mobileprovision"}
NAV = '<a href="#前言">🔼</a> <a href="#🔚">🔽</a>'
FOOTER = '<a id="🔚" href="#前言">我是有底线的➤点我回到首页</a>\n'
LOGGER = logging.getLogger("jobs.gui-delivery")


class PackagingError(RuntimeError):
    """可向用户明确报告的输入、验证或发布错误。"""


@dataclass(frozen=True)
class InputTree:
    """磁盘输入与归档路径的固定映射，不依赖调用工作目录。"""

    source: Path
    archive: PurePosixPath
    product: bool = False
    complete_app: bool = False


@dataclass(frozen=True)
class FileEntry:
    """记录单个文件/符号链接的内容身份和归档权限。"""

    source: Path
    archive: str
    kind: str
    mode: int
    size: int
    sha256: str
    link_target: str = ""

    # 公开清单仅记录归档相对路径，不泄露开发机根目录。
    def manifest_record(self) -> dict:
        """生成可公开交付的相对路径清单，不暴露开发机路径。"""
        result = {"path": self.archive, "type": self.kind, "mode": oct(self.mode), "size": self.size, "sha256": self.sha256}
        if self.link_target:
            result["target"] = self.link_target
        return result


@dataclass
class DeliverySpec:
    """九套已确认 GUI 的具体源码、成品与运行合同。"""

    key: str
    title: str
    platform: str
    kind: str
    source_entry: str
    build_entries: List[str]
    launch_entry: str
    dependencies: List[str]
    source_trees: List[InputTree]
    product_trees: List[InputTree]
    required: List[Path]
    app: Optional[Path] = None
    swift_source: Optional[Path] = None
    profile: Optional[str] = None
    exe: Optional[Path] = None
    verified: List[str] = field(default_factory=list)
    pending: List[str] = field(default_factory=list)


# 展示固定自述，实际打包只接受明确 --yes 参数。
def show_intro() -> None:
    print("Jobs GUI 源码与成品交付打包器")
    print("范围：新系统与环境配置两套 Mac GUI，以及 WindowsOS 和六套 Unix GUI。")
    print("默认 --plan 只读；--yes 才写独立新版本目录，不覆盖旧包。")
    print("只读取指定源码/真实产物，不构建或安装系统工具；失败保留日志和临时现场。")


# 定位自身所在的 JobsConfigOS，保留显式测试/迁移根路径。
def parse_arguments(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    actions = parser.add_mutually_exclusive_group()
    actions.add_argument("--plan", action="store_true", help="只读盘点九套输入；默认动作")
    actions.add_argument("--yes", action="store_true", help="确认按计划归档并发布新版本")
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[4], help="JobsConfigOS 根目录；默认按脚本自身定位")
    parser.add_argument("--output", type=Path, help="输出根；相对路径按项目根定位，默认 🆕新系统配置/交付产物/GUI源码与成品")
    return parser.parse_args(argv)


# 用流式摘要核验内容，不将整个 App 文件载入内存。
def file_sha256(path: Path) -> str:
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


# 返回明确映射，源码保持可重建所需的完整相对层级。
def delivery_specs(root: Path) -> List[DeliverySpec]:
    multi = root / MULTI
    environment = root / ENVIRONMENT
    system_app = multi / "MacOS" / SYSTEM_APP
    env_app = environment / ENVIRONMENT_APP
    system_swift = root / SYSTEM_PANEL / "Sources/EnvironmentManager.swift"
    env_swift = environment / "安装面板/Sources/EnvironmentManager.swift"
    environment_payload = ["scripts", "zsh", "Sys", "【MacOS】环境管理后端.command", "sync_env.txt"]
    common_verified = ["打包器复核归档逐文件SHA-256与ZIP完整性；此项不是目标系统GUI运行结论"]
    system_source_paths = [SYSTEM_PANEL, "icon.png", f"{MULTI}/MacOS/【MacOS】🆕新系统配置.command", f"{MULTI}/MacOS/{SYSTEM_PROJECT}"]
    system_source_paths += [f"{ENVIRONMENT}/{name}" for name in environment_payload]
    env_source_paths = ["安装面板", "icon.png"] + environment_payload
    # 环境工程若由本任务新增，按它真实存在的位置纳入；无工程仍保留swiftc构建器。
    if (environment / ENVIRONMENT_PROJECT).is_dir():
        env_source_paths.append(ENVIRONMENT_PROJECT)
    system_build = f"JobsConfigOS/{SYSTEM_PANEL}/【MacOS】构建安装面板.command/【MacOS】构建安装面板.command"
    env_build = f"JobsMacEnvVarConfigs/安装面板/【MacOS】构建安装面板.command/【MacOS】构建安装面板.command"
    specs = [
        DeliverySpec(
            key="MacOS-System", title="MacOS 新系统配置管理", platform="MacOS", kind="native-app",
            source_entry=f"JobsConfigOS/{SYSTEM_PANEL}/Sources/EnvironmentManager.swift",
            build_entries=[f"JobsConfigOS/{MULTI}/MacOS/{SYSTEM_PROJECT}", system_build],
            launch_entry=SYSTEM_APP,
            dependencies=["macOS 13+；App自带GUI二进制、后端和运行资源", "执行所选安装任务所需工具/权限仍由后端检查；重建源码需要Xcode/Swift命令行工具"],
            source_trees=[InputTree(root / name, PurePosixPath("JobsConfigOS") / name) for name in system_source_paths],
            product_trees=[InputTree(system_app, PurePosixPath(SYSTEM_APP), True, True)],
            required=[root / name for name in system_source_paths] + [system_swift, root / SYSTEM_PANEL / "Resources/PanelTranslations.json", root / SYSTEM_PANEL / "【MacOS】构建安装面板.command/【MacOS】构建安装面板.command", root / SYSTEM_PANEL / "【MacOS@Xcode】准备面板资源.command/【MacOS@Xcode】准备面板资源.command", multi / "MacOS" / SYSTEM_PROJECT / "project.pbxproj"], app=system_app, swift_source=system_swift, profile="system",
            verified=common_verified + ["Mac构建收据Swift源码SHA、完整Payload及package资源与当前源树逐项SHA校验"],
            pending=["另一台Mac/AirDrop、全部安装卸载与真实权限完整验收未由打包器执行"],
        ),
        DeliverySpec(
            key="MacOS-Environment", title="MacOS 环境配置管理", platform="MacOS", kind="native-app",
            source_entry="JobsMacEnvVarConfigs/安装面板/Sources/EnvironmentManager.swift",
            build_entries=([f"JobsMacEnvVarConfigs/{ENVIRONMENT_PROJECT}"] if (environment / ENVIRONMENT_PROJECT).is_dir() else []) + [env_build],
            launch_entry=ENVIRONMENT_APP,
            dependencies=["macOS 13+；App自带GUI二进制、后端和终端配置运行资源", "实际环境安装/卸载遵循用户授权与受管收据；重建需要Xcode/Swift命令行工具"],
            source_trees=[InputTree(environment / name, PurePosixPath("JobsMacEnvVarConfigs") / name) for name in env_source_paths],
            product_trees=[InputTree(env_app, PurePosixPath(ENVIRONMENT_APP), True, True)],
            required=[environment / name for name in env_source_paths] + [env_swift, environment / "安装面板/Resources/PanelTranslations.json", environment / "安装面板/【MacOS】构建安装面板.command/【MacOS】构建安装面板.command"], app=env_app, swift_source=env_swift, profile="env",
            verified=common_verified + ["Mac构建收据Swift源码SHA、完整Payload及package资源与当前源树逐项SHA校验"],
            pending=["另一台Mac/AirDrop、所有组件真实部署/恢复及权限验收未由打包器执行"],
        ),
    ]
    windows = multi / "WindowsOS"
    exe = windows / WINDOWS_GUI / WINDOWS_EXE
    specs.append(DeliverySpec(
        key="WindowsOS", title="WindowsOS 新系统配置管理", platform="WindowsOS", kind="windows-pe-launcher-and-powershell-runtime",
        source_entry=f"WindowsOS/{WINDOWS_GUI}/{WINDOWS_GUI}",
        build_entries=[f"WindowsOS/{WINDOWS_GUI}/Launcher/JobsSystemSetupManager.csproj"],
        launch_entry=f"WindowsOS/{WINDOWS_GUI}/{WINDOWS_EXE}",
        dependencies=["Windows 10 1809 64位及以上目标；.NET Framework 4.7.2或兼容后续4.x、Windows PowerShell 5.1和WinForms；目标机验收仍待核", "EXE为AnyCPU托管GUI启动器，不是Native AOT或自包含运行时；必须保留本包PowerShell GUI、同平台CLI和运行资源，安装任务需要WinGet及实际授权"],
        source_trees=[InputTree(windows, PurePosixPath("WindowsOS"))],
        product_trees=[InputTree(windows, PurePosixPath("WindowsOS"), True)],
        required=[windows / WINDOWS_GUI / WINDOWS_GUI, windows / WINDOWS_GUI / "Resources/PanelWorker.cs", windows / WINDOWS_GUI / "Resources/PanelTranslations.json", windows / WINDOWS_GUI / "Launcher/JobsSystemSetupManager.csproj", windows / WINDOWS_GUI / "Launcher/Program.cs", exe, exe.with_suffix(".exe.config"), windows / WINDOWS_GUI / "LauncherBuildReceipt.json"],
        exe=exe, verified=common_verified + ["真实EXE存在及PE头/架构字段核验；不将其作为WindowsGUI运行结论"],
        pending=["目标Windows上的EXE双击、WinForms/UAC/托盘、真实WinGet包事务未由打包器验收"],
    ))
    shared = multi / "安装面板"
    for platform in UNIX_PLATFORMS:
        platform_root = multi / platform
        launcher = f"【{platform}】🧰新系统配置管理.sh"
        backend = f"【{platform}】🆕新系统配置.sh"
        trees = [InputTree(platform_root, PurePosixPath("GuiRuntime") / platform), InputTree(shared, PurePosixPath("GuiRuntime/安装面板"))]
        specs.append(DeliverySpec(
            key=platform, title=f"{platform} 新系统配置管理", platform=platform, kind="interpreted-tcl-tk-gui-runtime",
            source_entry="GuiRuntime/安装面板/UnixManager.tcl/UnixManager.tcl",
            build_entries=[], launch_entry=f"GuiRuntime/{platform}/{launcher}/{launcher}",
            dependencies=[f"匹配的{platform} x64/ARM64桌面；具体最低OS版本尚未实机锁定", "Tcl/Tk 8.6+、DISPLAY；Wayland需XWayland；写任务需root或可用PolicyKit图形授权", "这是解释型GUI成品运行包，保留完整同平台CLI/共享资源；不是ELF、AppImage或内嵌Tk的独立二进制"],
            source_trees=trees, product_trees=[InputTree(t.source, t.archive, True) for t in trees],
            required=[platform_root / launcher / launcher, platform_root / backend / backend, shared / "UnixManager.tcl/UnixManager.tcl", shared / "UnixManager.tcl/ManagerCore.tcl", shared / "UnixManager.tcl/RunBackend.sh/RunBackend.sh", shared / "Resources/UnixTranslations.dict"],
            verified=common_verified + ["共享模型与本机Tk隔离验证的历史记录见随包说明；不外推目标发行版已运行"],
            pending=[f"{platform}原生桌面、字体/辅助技术、PolicyKit和真实系统包事务未验", "运行依赖Tcl/Tk和图形桌面，不自动安装GUI运行时"],
        ))
    return specs


# 保守过滤用户数据/缓存；产品App必须完整，不能静默删签名资源。
def excluded(path: Path, product: bool, complete_app: bool) -> bool:
    if complete_app:
        return False
    if path.name in SKIP_NAMES or path.name.startswith(("ManualBy", ".JobsPanelBuild.", ".GuiDeliverables-stage-")):
        return True
    if path.suffix.lower() in {".pyc", ".pyo", ".log", ".tmp", ".swp"}:
        return True
    if path.name.endswith(".app"):
        return True
    if path.name in {"bin", "obj"} and "Launcher" in path.parts:
        return True
    if product and path.name in {"Tests", "tests", "Launcher"}:
        return True
    return False


# 密钥/会话资料一律拒绝纳入；只报告相对文件名，不打印正文。
def assert_no_sensitive_name(path: Path) -> None:
    if path.name.lower() in SECRET_NAMES or path.suffix.lower() in SECRET_SUFFIXES:
        raise PackagingError(f"拒绝归档疑似密钥或账户数据文件：{path.name}")


# 路径不能逃出归档根或携带可执行解压路径片段。
def assert_archive_name(name: str) -> None:
    pure = PurePosixPath(name)
    if pure.is_absolute() or ".." in pure.parts or not name or "\\" in name or "\x00" in name or "\n" in name or "\r" in name:
        raise PackagingError(f"归档路径不安全：{name!r}")


# 固定输入树逐项快照，符号链接只保留安全的相对链接且不跟随。
def collect_entries(trees: Iterable[InputTree]) -> List[FileEntry]:
    result: Dict[str, FileEntry] = {}

    def visit(source: Path, archive: PurePosixPath, tree: InputTree) -> None:
        if excluded(source, tree.product, tree.complete_app):
            return
        if not source.exists() and not source.is_symlink():
            raise PackagingError(f"缺少明确打包输入：{source}")
        assert_no_sensitive_name(source)
        assert_archive_name(archive.as_posix())
        info = source.lstat()
        if stat.S_ISLNK(info.st_mode):
            target = os.readlink(source)
            if os.path.isabs(target):
                raise PackagingError(f"拒绝开发机绝对链接：{source.name}")
            # 解压后的链接必须留在本输入树，不能借链接取得仓库外数据。
            resolved = (source.parent / target).resolve()
            tree_root = tree.source.resolve() if tree.source.is_dir() else tree.source.parent.resolve()
            if resolved != tree_root and tree_root not in resolved.parents:
                raise PackagingError(f"链接逃出允许的输入树：{source.name}")
            content = target.encode("utf-8")
            entry = FileEntry(source, archive.as_posix(), "symlink", stat.S_IMODE(info.st_mode), len(content), hashlib.sha256(content).hexdigest(), target)
        elif stat.S_ISDIR(info.st_mode):
            for child in sorted(source.iterdir(), key=lambda item: item.name):
                visit(child, archive / child.name, tree)
            return
        elif stat.S_ISREG(info.st_mode):
            entry = FileEntry(source, archive.as_posix(), "file", stat.S_IMODE(info.st_mode), info.st_size, file_sha256(source))
        else:
            raise PackagingError(f"拒绝非普通文件或链接：{source.name}")
        if entry.archive in result and result[entry.archive] != entry:
            raise PackagingError(f"归档路径重复冲突：{entry.archive}")
        result[entry.archive] = entry

    for tree in trees:
        visit(tree.source, tree.archive, tree)
    return sorted(result.values(), key=lambda item: item.archive)


# Mac必须有可核对收据，且Payload覆盖全部资源而非只检查清单已有项。
def verify_mac_app(spec: DeliverySpec, source_root: Optional[Path] = None) -> dict:
    assert spec.app is not None and spec.swift_source is not None
    if not spec.app.is_dir() or spec.app.is_symlink():
        raise PackagingError(f"{spec.key}必须为真实App目录，不能是链接")
    resource = spec.app / "Contents/Resources"
    receipt_path = resource / "BuildReceipt.plist"
    payload_path = resource / "Payload.sha256"
    if not receipt_path.is_file() or not payload_path.is_file():
        raise PackagingError(f"{spec.key}缺少真实BuildReceipt.plist/Payload.sha256，需先重建App")
    with receipt_path.open("rb") as stream:
        receipt = plistlib.load(stream)
    if not isinstance(receipt, dict):
        raise PackagingError(f"{spec.key}构建收据不是字典")
    source_digest = file_sha256(spec.swift_source)
    if receipt.get("profile") != spec.profile or receipt.get("sourceSHA256") != source_digest or not receipt.get("builtAtUTC"):
        raise PackagingError(f"{spec.key}构建收据与当前Swift源码/profile不匹配")
    panel_root = spec.swift_source.parent.parent
    inferred_root = (panel_root.parents[2] if spec.profile == "system" and
                     panel_root.parent.name == "MacOS" and panel_root.parent.parent.name == MULTI
                     else panel_root.parent)
    current_root = source_root if source_root is not None else inferred_root
    matched_source_files = 0
    expected: Dict[str, str] = {}
    for line in payload_path.read_text(encoding="utf-8").splitlines():
        match = re.fullmatch(r"([0-9a-f]{64}) [ *](.+)", line)
        if match is None:
            raise PackagingError(f"{spec.key}资源清单格式无效")
        name = match.group(2)
        if name.startswith("./"):
            name = name[2:]
        assert_archive_name(name)
        if name in expected or name == "Payload.sha256":
            raise PackagingError(f"{spec.key}资源清单重复或自引用")
        expected[name] = match.group(1)
        target = resource / name
        if not target.is_file() or target.is_symlink() or file_sha256(target) != match.group(1):
            raise PackagingError(f"{spec.key}资源不匹配：{name}")
        if PurePosixPath(name).parts[0] == "package":
            source_relative = PurePosixPath(name).relative_to("package")
            # App 内沿用既有目录合同，仓库入口使用当前多平台目录名。
            if spec.profile == "system" and source_relative.parts[0] == BUNDLED_SYSTEM_ROOT:
                source_relative = PurePosixPath(MULTI).joinpath(*source_relative.parts[1:])
            current_source = current_root.joinpath(*source_relative.parts)
            if not current_source.is_file() or current_source.is_symlink():
                raise PackagingError(f"{spec.key}包内源码在当前源树缺失或不是普通文件：{source_relative}")
            if file_sha256(current_source) != match.group(1):
                raise PackagingError(f"{spec.key}包内资源落后于当前源树，请刷新App后再归档：{source_relative}")
            matched_source_files += 1
    actual = {p.relative_to(resource).as_posix() for p in resource.rglob("*") if p.is_file() and p.relative_to(resource).as_posix() != "Payload.sha256"}
    if actual != set(expected):
        raise PackagingError(f"{spec.key}Payload覆盖范围不完整：缺项{len(actual-set(expected))}，多项{len(set(expected)-actual)}")
    result = {"receipt": receipt, "swiftSourceSHA256": source_digest, "resourceCount": len(expected), "currentPackageSourceFilesMatched": matched_source_files}
    if sys.platform == "darwin":
        verification = subprocess.run(["/usr/bin/codesign", "--verify", "--deep", "--strict", str(spec.app)], capture_output=True, text=True, check=False)
        if verification.returncode:
            raise PackagingError(f"{spec.key}App签名验证失败：{verification.stderr.strip()}")
        result["signatureVerifiedOnMacOS"] = True
    else:
        result["signatureVerifiedOnMacOS"] = False
    return result


# 只接受真实MZ/PE程序，并记录机器架构；不以扩展名伪装EXE。
def verify_windows_exe(path: Path) -> dict:
    with path.open("rb") as stream:
        header = stream.read(64)
        if len(header) < 64 or header[:2] != b"MZ":
            raise PackagingError("Windows GUI产物不是有效MZ程序")
        offset = struct.unpack_from("<I", header, 0x3C)[0]
        if offset < 64 or offset > path.stat().st_size - 24:
            raise PackagingError("Windows GUI产物PE偏移无效")
        stream.seek(offset)
        pe_header = stream.read(24)
        if pe_header[:4] != b"PE\0\0":
            raise PackagingError("Windows GUI产物缺少PE签名")
        machine = struct.unpack_from("<H", pe_header, 4)[0]
    machines = {0x014C: "i386/AnyCPU candidate", 0x8664: "x64", 0xAA64: "ARM64"}
    if machine not in machines:
        raise PackagingError(f"Windows GUI不支持的机器类型：0x{machine:04x}")
    return {"file": path.name, "sha256": file_sha256(path), "peMachine": f"0x{machine:04x}", "machineDescription": machines[machine], "nativeWindowsExecutionVerifiedByPackager": False}


# 将真实Launcher构建收据绑定当前工程、EXE及config，不将托管构建称为Windows实机运行。
def verify_windows_launcher(path: Path) -> dict:
    result = verify_windows_exe(path)
    base = path.parent
    receipt_path = base / "LauncherBuildReceipt.json"
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    if not isinstance(receipt, dict) or receipt.get("schemaVersion") != 1 or receipt.get("product") != "JobsSystemSetupManager" or not receipt.get("actualBuildUtc"):
        raise PackagingError("Windows Launcher构建收据格式不匹配")
    expected_source = {"Launcher/JobsSystemSetupManager.csproj", "Launcher/Program.cs", "Launcher/app.manifest", "Launcher/NuGet.Config", "Launcher/packages.lock.json"}
    expected_outputs = {WINDOWS_EXE, WINDOWS_EXE + ".config"}
    for key, expected in (("sourceFiles", expected_source), ("outputs", expected_outputs)):
        rows = receipt.get(key)
        if not isinstance(rows, list) or any(not isinstance(row, dict) for row in rows):
            raise PackagingError(f"Windows收据{key}无效")
        names = [row.get("path") for row in rows]
        if len(names) != len(expected) or set(names) != expected:
            raise PackagingError(f"Windows收据{key}范围不匹配")
        for row in rows:
            target = base / row["path"]
            if not target.is_file() or target.is_symlink() or file_sha256(target) != row.get("sha256"):
                raise PackagingError(f"Windows构建收据与当前文件不符：{row['path']}")
            if key == "outputs" and target.stat().st_size != row.get("sizeBytes"):
                raise PackagingError(f"Windows构建产物大小不匹配：{row['path']}")
    result["buildReceiptFileSHA256"] = file_sha256(receipt_path)
    result["buildReceipt"] = receipt
    result["sourceAndOutputHashesMatchReceipt"] = True
    return result


# 盘点九套输入；计划会显示缺失产物，不为缺失项下载或编造文件。
def inspect_specs(specs: Sequence[DeliverySpec]) -> Tuple[List[dict], List[str]]:
    plans: List[dict] = []
    errors: List[str] = []
    for spec in specs:
        plan = {"id": spec.key, "title": spec.title, "sourceEntry": spec.source_entry, "buildEntries": spec.build_entries, "launchEntry": spec.launch_entry, "sourceInputs": [str(tree.source) for tree in spec.source_trees], "productInputs": [str(tree.source) for tree in spec.product_trees]}
        missing = [str(path) for path in spec.required if not path.exists()]
        if missing:
            plan["errors"] = ["缺少输入：" + name for name in missing]
        else:
            try:
                source = collect_entries(spec.source_trees)
                product = collect_entries(spec.product_trees)
                plan.update(sourceFiles=len(source), productFiles=len(product), sourceBytes=sum(entry.size for entry in source), productBytes=sum(entry.size for entry in product))
                if spec.app:
                    plan["artifactValidation"] = verify_mac_app(spec)
                elif spec.exe:
                    plan["artifactValidation"] = verify_windows_launcher(spec.exe)
                else:
                    plan["artifactValidation"] = {"kind": spec.kind, "requiresTclTk": True, "standaloneElf": False}
            except (OSError, ValueError, plistlib.InvalidFileException, PackagingError) as error:
                plan["errors"] = [str(error)]
        if plan.get("errors"):
            errors.extend(f"{spec.key}: {value}" for value in plan["errors"])
        plans.append(plan)
    return plans, errors


# 固定ZIP时间与UNIX权限，逐项读回SHA，任何输入变化立即停止。
def write_verified_zip(destination: Path, entries: Sequence[FileEntry]) -> dict:
    with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9, allowZip64=True) as archive:
        for entry in entries:
            info = zipfile.ZipInfo(entry.archive, ZIP_TIME)
            info.create_system = 3
            type_bits = stat.S_IFLNK if entry.kind == "symlink" else stat.S_IFREG
            info.external_attr = (type_bits | entry.mode) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            data = entry.link_target.encode("utf-8") if entry.kind == "symlink" else entry.source.read_bytes()
            if len(data) != entry.size or hashlib.sha256(data).hexdigest() != entry.sha256:
                raise PackagingError(f"打包期间输入被修改，停止发布：{entry.archive}")
            archive.writestr(info, data, compresslevel=9)
    with zipfile.ZipFile(destination, "r") as archive:
        if archive.testzip() is not None:
            raise PackagingError(f"ZIP CRC验证失败：{destination.name}")
        if archive.namelist() != [entry.archive for entry in entries]:
            raise PackagingError(f"ZIP条目清单不一致：{destination.name}")
        for entry in entries:
            data = archive.read(entry.archive)
            if hashlib.sha256(data).hexdigest() != entry.sha256:
                raise PackagingError(f"ZIP读回SHA不一致：{entry.archive}")
    return {"file": destination.name, "sha256": file_sha256(destination), "bytes": destination.stat().st_size, "entries": [entry.manifest_record() for entry in entries]}


# 生成每套明确的源码入口、最终启动文件和原生/解释型边界。
def package_readme(spec: DeliverySpec) -> str:
    dependencies = "\n".join("- " + item for item in spec.dependencies)
    verified = "\n".join("- " + item for item in spec.verified)
    pending = "\n".join("- " + item for item in spec.pending)
    builders = "\n".join("- `" + item + "`" for item in spec.build_entries) or "- 无二进制构建步骤；源码本身由系统Tcl/Tk解释执行。"
    return f'''# {spec.title}｜源码与成品运行包

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 🔥 <span id="前言">前言</span>

平台：{spec.platform}。交付类型：`{spec.kind}`。`source.zip` 包含当前源码及必要构建/运行资源，`product.zip` 包含最终运行内容；两者分开交付。每个ZIP旁有独立SHA256，`manifest.json`保存逐文件来源快照摘要，解压后不得拆散原有相对结构。

## 一、<span id="entries">源码、构建与启动</span> {NAV}

- 源码入口（解压source.zip后）：`{spec.source_entry}`。
- 成品启动文件（解压product.zip后）：`{spec.launch_entry}`。

构建入口：

{builders}

Mac产品直接打开App；Windows打开真实EXE并保留相邻运行资源；Unix在目标桌面使用`sh`调用上述启动文件。生产包不要求打包器的Python环境。

## 二、<span id="runtime">运行依赖与范围</span> {NAV}

{dependencies}

本包不附带用户配置、账户凭据、密钥、运行日志或系统缓存。源码包的默认配置/模板仍保留原文件内容；本轮没有运行其中的安装/卸载动作。Unix包为解释型GUI运行包，不冒充ELF/AppImage；Windows EXE是启动器，不代表PowerShell GUI已经编译到二进制里。

## 三、<span id="verification">已验与未验</span> {NAV}

本次打包实际核验：

{verified}

目标平台待验边界：

{pending}

包的生成时间是归档时间，不冒充App/EXE编译时间；原生构建回执单独保存在运行内容或manifest。SHA256能核对完整性，不代表开发者签名或目标机器运行验收。

{FOOTER}'''


# 生成版本总览，链接九套交付，不使用开发机绝对路径。
def index_readme(specs: Sequence[DeliverySpec], created: str) -> str:
    rows = "\n".join(f"| {spec.title} | [{spec.key}](./{spec.key}/README.md) | `{spec.kind}` |" for spec in specs)
    return f'''# GUI 源码与成品交付

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 🔥 <span id="前言">前言</span>

本轮归档时间（上海）：{created}。范围为新系统与环境配置两套Mac GUI、WindowsOS及六Unix平台GUI，共9套；每套提供独立源码包、成品运行包、SHA256及逐文件manifest。归档不执行编译、安装或卸载，也不替代目标系统验收。

## 一、<span id="packages">九套交付</span> {NAV}

| 工具/平台 | 说明与包 | 产物类型 |
| --- | --- | --- |
{rows}

每套目录包含`source.zip`、`product.zip`、各自`.sha256`、`manifest.json`及本地说明。Mac为现有原生App，Windows为真实EXE启动器及PowerShell运行资源，六Unix为依赖Tcl/Tk桌面的解释型运行包。各包明确自己的运行依赖及已验/待验；不把生成ZIP称为全部平台实机通过。

{FOOTER}'''


# 只在输出祖先无链接时创建新目录，禁止覆盖或向链接目标发布。
def prepare_output(output: Path) -> None:
    for part in (output, *output.parents):
        if part.is_symlink():
            raise PackagingError(f"输出路径不能包含符号链接：{part}")
        if part.exists() and not part.is_dir():
            raise PackagingError(f"输出祖先不是目录：{part}")
    output.mkdir(parents=True, exist_ok=True)


# 暂存全部九套并复核输入未变，再原子发布唯一版本目录。
def package_all(root: Path, output: Path, specs: Sequence[DeliverySpec], plans: Sequence[dict]) -> Path:
    prepare_output(output)
    created = datetime.now(SHANGHAI)
    version = created.strftime("%Y.%m.%d %H-%M-%S")
    target = output / version
    if target.exists():
        target = output / (version + "-" + os.urandom(4).hex())
    stage = Path(tempfile.mkdtemp(prefix=".GuiDeliverables-stage-", dir=output))
    handler = logging.FileHandler(stage / "packaging.log", encoding="utf-8")
    handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
    LOGGER.addHandler(handler)
    LOGGER.info("已授权打包九套GUI，暂存目录：%s", stage.name)
    manifest_index = []
    final_snapshots = []
    try:
        for spec, plan in zip(specs, plans):
            LOGGER.info("开始：%s", spec.key)
            destination = stage / spec.key
            destination.mkdir()
            source_before = collect_entries(spec.source_trees)
            product_before = collect_entries(spec.product_trees)
            # 此处再次校验，不能使用计划后已变化的App/EXE。
            validation = verify_mac_app(spec) if spec.app else verify_windows_launcher(spec.exe) if spec.exe else plan["artifactValidation"]
            source_archive = write_verified_zip(destination / "source.zip", source_before)
            product_archive = write_verified_zip(destination / "product.zip", product_before)
            if source_before != collect_entries(spec.source_trees) or product_before != collect_entries(spec.product_trees):
                raise PackagingError(f"归档期间{spec.key}输入树发生变化，停止发布全部九套")
            for item in (source_archive, product_archive):
                (destination / (item["file"] + ".sha256")).write_text(f'{item["sha256"]}  {item["file"]}\n', encoding="utf-8")
            manifest = {"schemaVersion": 1, "id": spec.key, "title": spec.title, "platform": spec.platform, "kind": spec.kind, "packagedAtShanghai": created.isoformat(), "sourceEntry": spec.source_entry, "buildEntries": spec.build_entries, "launchEntry": spec.launch_entry, "dependencies": spec.dependencies, "verified": spec.verified, "pending": spec.pending, "artifactValidation": validation, "archivePolicy": {"fixedZipTimestamp": "1980-01-01T00:00:00", "sourceContentUnchanged": True, "preserveRelativeLayout": True, "secretsAndCachesExcluded": True}, "archives": {"source": source_archive, "product": product_archive}}
            manifest_path = destination / "manifest.json"
            manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            manifest_digest = file_sha256(manifest_path)
            (destination / "manifest.json.sha256").write_text(f"{manifest_digest}  manifest.json\n", encoding="utf-8")
            (destination / "README.md").write_text(package_readme(spec), encoding="utf-8")
            final_snapshots.append((spec, source_before, product_before))
            manifest_index.append({"id": spec.key, "manifestSHA256": manifest_digest, "sourceSHA256": source_archive["sha256"], "productSHA256": product_archive["sha256"]})
            LOGGER.info("已验证：%s，源码%d项/成品%d项", spec.key, len(source_before), len(product_before))
        (stage / "README.md").write_text(index_readme(specs, created.strftime("%Y-%m-%d %H:%M:%S")), encoding="utf-8")
        (stage / "manifest.json").write_text(json.dumps({"schemaVersion": 1, "packagedAtShanghai": created.isoformat(), "packages": manifest_index}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        top_digest = file_sha256(stage / "manifest.json")
        (stage / "manifest.json.sha256").write_text(f"{top_digest}  manifest.json\n", encoding="utf-8")
        for spec, source_before, product_before in final_snapshots:
            if source_before != collect_entries(spec.source_trees) or product_before != collect_entries(spec.product_trees):
                raise PackagingError(f"最终发布前{spec.key}输入发生变化；请在源码稳定后重试")
        LOGGER.info("全部九套验证完成，发布：%s", target.name)
        handler.close()
        LOGGER.removeHandler(handler)
        if target.exists():
            raise PackagingError(f"发布目标已存在，保留原件：{target.name}")
        stage.rename(target)
        return target
    except Exception:
        LOGGER.exception("打包失败，全部暂存保留供核对：%s", stage)
        raise
    finally:
        handler.close()
        if handler in LOGGER.handlers:
            LOGGER.removeHandler(handler)


# 高层入口先说明范围，再只读核验，明确授权后才归档。
def main(argv: Optional[Sequence[str]] = None) -> int:
    show_intro()
    arguments = parse_arguments(argv)
    root = arguments.project_root.expanduser().resolve()
    if not root.is_dir():
        raise PackagingError("项目根目录不存在")
    output = arguments.output or Path(MULTI) / "交付产物/GUI源码与成品"
    if not output.is_absolute():
        output = root / output
    specs = delivery_specs(root)
    # 先规范相对片段，再拒绝任何输入树内的输出，避免把暂存再次打进源码包。
    output = Path(os.path.abspath(output))
    for spec in specs:
        for tree in spec.source_trees + spec.product_trees:
            source = tree.source.resolve()
            if output == source or source in output.parents:
                raise PackagingError("输出不能位于打包输入目录内")
    plans, errors = inspect_specs(specs)
    print(json.dumps({"mode": "package" if arguments.yes else "plan", "output": str(output), "packages": plans, "errors": errors}, ensure_ascii=False, indent=2))
    if errors:
        print("输入核验未通过；没有生成或发布交付包。", file=sys.stderr)
        return 2
    if not arguments.yes:
        print("只读计划通过；实际归档需显式 --yes。")
        return 0
    LOGGER.setLevel(logging.INFO)
    stream = logging.StreamHandler()
    stream.setFormatter(logging.Formatter("%(levelname)s %(message)s"))
    LOGGER.addHandler(stream)
    target = package_all(root, output, specs, plans)
    print("已生成并核验9套源码与成品：" + str(target))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (PackagingError, OSError, ValueError, plistlib.InvalidFileException, zipfile.BadZipFile) as error:
        print("错误：" + str(error), file=sys.stderr)
        raise SystemExit(1)
    except KeyboardInterrupt:
        print("已取消；未发布的暂存现场保留。", file=sys.stderr)
        raise SystemExit(130)

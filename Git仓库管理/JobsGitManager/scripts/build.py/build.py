#!/usr/bin/env python3
# 构建自述：仅为当前系统打包；输出替换本工具dist，Git状态不变。
"""Native packaging with frozen startup checks and a relative launch manifest."""
from __future__ import annotations
import argparse
from datetime import datetime
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tempfile
import venv

PROJECT = Path(__file__).resolve().parents[2]
DELIVERY = PROJECT.parent
REPOSITORY = DELIVERY.parent
DIST_ROOT = DELIVERY / "dist"
PLATFORM_KEY = "MacOS" if sys.platform == "darwin" else "WindowsOS"
DIST = DIST_ROOT / PLATFORM_KEY
APP_NAME = "JobsGitManager"
DEPENDENCIES = ["PySide6-Essentials==6.12.0", "pyinstaller==6.22.3"]


def confirm(yes):
    """Explain effects before modifying dependencies or old artifacts."""
    print("Jobs Git 仓库管理｜本机打包", flush=True)
    print(f"目标：{platform.system()} {platform.machine()}；源码：{PROJECT}", flush=True)
    print(f"影响：替换本工具旧产物 {DIST}；缺少依赖时准备独立构建环境。", flush=True)
    print("不下载子仓、不暂存、不提交、不推送；成功后打开产物目录并启动App。", flush=True)
    if yes:
        return
    if not sys.stdin.isatty():
        raise RuntimeError("需要交互确认；自动化明确传入 --yes。")
    styled = sys.stdout.isatty() and "NO_COLOR" not in os.environ
    prompt = ("\033[1;36m是否开始构建\033[0m？[\033[1;32m回车继续\033[0m / \033[1;31m其它输入取消\033[0m]：" if styled else "是否开始构建？[回车继续 / 其它输入取消]：")
    try:
        if input(prompt) != "":
            raise SystemExit(0)
    except EOFError:
        raise SystemExit(130)


def run(args, **kwargs):
    """Execute exact argument vectors and propagate tool failures."""
    print(" +", " ".join(map(str, args)), flush=True)
    return subprocess.run(list(map(str, args)), check=True, **kwargs)


def prepare_environment(args):
    """Reuse pinned healthy tools or prepare an isolated project build venv."""
    if not (3, 11) <= sys.version_info[:2] < (3, 15):
        raise RuntimeError("构建需要 Python 3.11–3.14。")
    healthy = True
    for name, version in (("PySide6-Essentials", "6.12.0"), ("pyinstaller", "6.22.3")):
        try:
            healthy = healthy and importlib.metadata.version(name) == version
        except importlib.metadata.PackageNotFoundError:
            healthy = False
    if healthy:
        return False
    environment = PROJECT / ".build-venv"
    if environment.is_symlink():
        raise RuntimeError("拒绝符号链接构建环境。")
    python = environment / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
    if not python.exists():
        venv.EnvBuilder(with_pip=True).create(environment)
    run([python, "-m", "pip", "install", *DEPENDENCIES])
    command = [python, Path(__file__).resolve(), "--yes"]
    if args.no_open:
        command.append("--no-open")
    run(command)
    return True


def clean_output():
    """Clean only this app's fixed output and invalidate its old manifests."""
    if DIST.parent != DIST_ROOT or DIST_ROOT.is_symlink() or DIST.is_symlink():
        raise RuntimeError("不安全的输出目录。")
    for filename in (("latest-macos.json",) if sys.platform == "darwin" else ("latest-windows.json",)):
        manifest = DELIVERY / filename
        if manifest.is_symlink():
            raise RuntimeError("拒绝覆盖链接清单。")
        if manifest.exists():
            manifest.unlink()
    if DIST.exists():
        if not DIST.is_dir():
            raise RuntimeError("输出根不是目录。")
        shutil.rmtree(DIST)
    DIST.mkdir(parents=True)


def copy_notices(output):
    """Include dependency license files while leaving installed vendors intact."""
    notices = output / "LICENSES"
    notices.mkdir()
    for name in ("PySide6-Essentials", "shiboken6", "pyinstaller"):
        distribution = importlib.metadata.distribution(name)
        for item in distribution.files or []:
            if "license" in str(item).lower() and ".dist-info/" in str(item):
                source = distribution.locate_file(item)
                if source.is_file():
                    target = notices / name / str(item).split(".dist-info/", 1)[1]
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(source, target)
    (notices / "README.txt").write_text(
        "Python: https://docs.python.org/3/license.html\n"
        "PySide6 / Qt: LGPLv3 or commercial; https://doc.qt.io/qtforpython-6/licenses.html\n"
        "PyInstaller: GPL with bootloader exception; https://pyinstaller.org/en/stable/license.html\n"
        "Qt libraries remain separately replaceable in this onedir bundle.\n"
        "Git is installed separately, not redistributed here.\n", encoding="utf-8")


def build(output, work):
    """Bundle the shared GUI with this host's Python and Qt runtime."""
    entry = PROJECT / "src/jobs_git_manager/entry.py"
    command = [sys.executable, "-m", "PyInstaller", "--noconfirm", "--clean", "--windowed", "--onedir",
               "--name", APP_NAME, "--paths", PROJECT / "src",
               "--add-data", str(PROJECT / "src/jobs_git_manager/assets") + os.pathsep + "jobs_git_manager/assets",
               "--distpath", output,
               "--workpath", work / "work", "--specpath", work,
               "--exclude-module", "PySide6.QtWebEngineCore", "--exclude-module", "PySide6.QtQml",
               "--exclude-module", "PySide6.QtQuick", "--exclude-module", "PySide6.QtPdf"]
    if sys.platform == "darwin":
        command += ["--osx-bundle-identifier", "com.jobs.git-manager"]
    run(command + [entry])
    app = output / (f"{APP_NAME}.app" if sys.platform == "darwin" else APP_NAME)
    executable = app / (f"Contents/MacOS/{APP_NAME}" if sys.platform == "darwin" else f"{APP_NAME}.exe")
    if not executable.is_file():
        raise RuntimeError("没有生成预期可执行程序。")
    if sys.platform == "darwin" and (output / APP_NAME).is_dir():
        shutil.rmtree(output / APP_NAME)
    return app, executable


def smoke(executable, work):
    """Verify frozen startup with no development source imports or implicit cwd."""
    evidence = work / "smoke"
    environment = os.environ.copy()
    environment.pop("PYTHONPATH", None)
    environment["QT_QPA_PLATFORM"] = "offscreen"
    run([executable, "--repo", REPOSITORY, "--smoke-test", evidence], env=environment, cwd=work, timeout=180)
    record = json.loads((evidence / "startup.json").read_text(encoding="utf-8"))
    if record.get("frozen") is not True or record.get("state") == "failed":
        raise RuntimeError(f"打包成品启动验证失败：{record}")
    return record


def publish(output, app, record):
    """Package native distributions and publish only a verified relative target."""
    copy_notices(output)
    license_target = app / ("Contents/Resources/LICENSES" if sys.platform == "darwin" else "LICENSES")
    shutil.copytree(output / "LICENSES", license_target)
    if sys.platform == "darwin":
        run(["/usr/bin/codesign", "--force", "--deep", "--sign", "-", app])
        archive = output / f"{APP_NAME}-macOS-{platform.machine()}.zip"
        run(["/usr/bin/ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", app, archive])
        staging = output / ".dmg-content"
        staging.mkdir()
        try:
            run(["/usr/bin/ditto", app, staging / app.name])
            shutil.copytree(output / "LICENSES", staging / "LICENSES")
            os.symlink("/Applications", staging / "Applications")
            run(["/usr/bin/hdiutil", "create", "-volname", APP_NAME, "-srcfolder", staging,
                 "-format", "UDZO", output / f"{APP_NAME}.dmg"])
        finally:
            shutil.rmtree(staging)
        relative = app.relative_to(DELIVERY).as_posix()
        manifest = "latest-macos.json"
    else:
        archive = Path(shutil.make_archive(str(output / f"{APP_NAME}-Windows-{platform.machine()}"), "zip", output, app.name))
        relative = (app / f"{APP_NAME}.exe").relative_to(DELIVERY).as_posix()
        manifest = "latest-windows.json"
    (output / "build-info.json").write_text(json.dumps({
        "platform": platform.platform(), "architecture": platform.machine(), "python": platform.python_version(),
        "dependencies": {name: importlib.metadata.version(name) for name in ("PySide6-Essentials", "pyinstaller")},
        "smoke": record,
        "source_sha256": {path.relative_to(PROJECT).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
                          for path in (PROJECT / "src").rglob("*.py")},
    }, ensure_ascii=False, indent=2), encoding="utf-8")
    (DELIVERY / manifest).write_text(json.dumps({"executable": relative}, ensure_ascii=False, indent=2), encoding="utf-8")
    return archive


def open_result(output, app):
    """Open the output location and start the actual completed native app."""
    if sys.platform == "darwin":
        run(["/usr/bin/open", output])
        run(["/usr/bin/open", "-n", app, "--args", "--repo", REPOSITORY])
    else:
        os.startfile(str(output))
        subprocess.Popen([str(app / f"{APP_NAME}.exe"), "--repo", str(REPOSITORY)])


def main(argv=None):
    """Confirm, prepare, rebuild, verify and publish one timestamped native build."""
    parser = argparse.ArgumentParser(description="Build JobsGitManager on the target OS")
    parser.add_argument("--yes", action="store_true", help="Confirm the documented build effects")
    parser.add_argument("--no-open", action="store_true", help="Skip Finder/Explorer and app launch for automated QA")
    args = parser.parse_args(argv)
    confirm(args.yes)
    if sys.platform not in ("darwin", "win32"):
        raise RuntimeError("仅支持在 MacOS / WindowsOS 本机打包。")
    if prepare_environment(args):
        return 0
    clean_output()
    output = DIST / datetime.now().strftime("%Y.%m.%d %H-%M-%S")
    output.mkdir()
    with tempfile.TemporaryDirectory(prefix="jobs-git-manager-build-") as temporary:
        work = Path(temporary)
        app, executable = build(output, work)
        record = smoke(executable, work)
        archive = publish(output, app, record)
    print(f"完成：{app}\n分发包：{archive}")
    if not args.no_open:
        open_result(output, app)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (Exception, KeyboardInterrupt) as error:
        print(f"构建未完成：{error}", file=sys.stderr)
        raise SystemExit(1)

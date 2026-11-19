#!/usr/bin/env python3
# 脚本自述：
# - 脚本名称：lifecycle_tests.py
# - 核心用途：以临时 HOME 和假包管理器验证安装、卸载及保护门禁。
# - 影响范围：仅写本轮临时目录；不访问 registry，不安装或卸载本机环境。
# - 运行提示：必须 --yes；失败保留临时现场并输出路径。
"""隔离验证新系统配置后端；Python 仅为测试依赖。"""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
import pty
from pathlib import Path
import select
import shutil
import subprocess
import struct
import tempfile
import termios
import time


NPM_STUB = r"""#!/bin/zsh
if [[ "$1" == --version ]]; then [[ ! -f "$TEST_ROOT/npm-missing" ]] || exit 127; print 11.0.0; exit 0; fi
if [[ "$1" == view ]]; then print '">=20"'; exit 0; fi
print -r -- "$*" >> "$TEST_ROOT/npm.calls"
if [[ -f "$TEST_ROOT/npm-pause" ]]; then
    : > "$TEST_ROOT/npm-ready"
    while [[ -f "$TEST_ROOT/npm-pause" ]]; do sleep 0.1; done
fi
if [[ -f "$TEST_ROOT/network-left" ]]; then
    count="$(cat "$TEST_ROOT/network-left")"
    if (( count > 0 )); then print $((count-1)) > "$TEST_ROOT/network-left"; print -u2 'npm ERR ETIMEDOUT'; exit 1; fi
fi
[[ "${TEST_PERMISSION:-0}" != 1 ]] || { print -u2 EACCES; exit 13; }
prefix=""
package=""
while (( $# )); do
    case "$1" in
        --prefix) shift; prefix="$1" ;;
        rea-agents@latest) package=rea-agents; executable=rea ;;
        quicktype@latest) package=quicktype; executable=quicktype ;;
        @colbymchenry/codegraph@latest) package=@colbymchenry/codegraph; executable=codegraph ;;
    esac
    shift
done
[[ "$prefix" == "$HOME/.local/share/jobs-system-setup/"* && -n "$package" ]] || exit 99
mkdir -p "$prefix/lib/node_modules/$package" "$prefix/bin" || exit 1
printf '{"name":"%s","version":"1.2.3"}\n' "$package" > "$prefix/lib/node_modules/$package/package.json"
printf '#!/bin/zsh\nprint 1.2.3\nexit %s\n' "${TEST_BAD_BINARY:-0}" > "$prefix/bin/$executable"
if [[ "${TEST_CLI_USES_NODE:-0}" == 1 ]]; then
    printf '#!/bin/zsh\nexec node -e '\''process.exit(0)'\''\n' > "$prefix/bin/$executable"
fi
chmod u+x "$prefix/bin/$executable"
[[ "${TEST_NPM_FAIL:-0}" != 1 ]] || exit 7
"""

NODE_STUB = r"""#!/bin/zsh
[[ "$1" == -e ]] || exit 97
if [[ "$2" == 'process.exit(0)' ]]; then
    if [[ -f "$TEST_ROOT/node-broken" ]]; then print -u2 "Library not loaded: $TEST_ROOT/brew/opt/simdutf/lib/libsimdutf.37.dylib"; exit 134; fi
    exit 0
fi
if [[ "$2" == *JOBS_ENGINE_CHECK* ]]; then
    [[ ! -f "$TEST_ROOT/engine-old" || -n "$5" ]] || exit 42
    exit 0
fi
[[ "$2" != *JOBS_INSTALLED_ENGINE* ]] || { print '">=20"'; exit 0; }
[[ "$2" != *JOBS_CLI_MANIFEST* ]] || { [[ -z "${TEST_GLOBAL_MANIFEST:-}" ]] || print -r -- "$TEST_GLOBAL_MANIFEST"; exit 0; }
[[ "$2" == *'package.json'* ]] && exit 96
[[ -f "$3" ]] || exit 95
grep -q '"version":"1.2.3"' "$3" || exit 94
print 1.2.3
"""

BREW_STUB = r"""#!/bin/zsh
prefix="$TEST_ROOT/brew"
case "$1" in
    --version) print 'Homebrew fixture'; exit 0 ;;
    --prefix)
        if [[ -n "$2" && -d "$prefix/Cellar/$2" ]]; then print -r -- "$prefix/Cellar/$2/1.0.0"; else print -r -- "$prefix"; fi
        exit 0 ;;
    config|doctor) exit 0 ;;
    info)
        if [[ "$4" == node* ]]; then
            if [[ "${TEST_NODE_ALIAS_ONLY:-0}" == 1 ]]; then
                print '{"formulae":[{"name":"node","keg_only":false,"versions":{"stable":"26.13.1"}}]}'
            else
                print '{"formulae":[{"name":"node@26","keg_only":true,"versions":{"stable":"26.13.1"}}]}'
            fi
        elif [[ "$4" == ruby@3.4 ]]; then
            print '{"formulae":[{"name":"ruby@3.4","keg_only":true,"versions":{"stable":"3.4.9"}}]}'
        else
            if [[ "${TEST_RUBY_ALIAS_ONLY:-0}" == 1 ]]; then
                print '{"formulae":[{"name":"ruby","keg_only":false,"aliases":["ruby@4.0"],"versioned_formulae":["ruby@4.0"],"versions":{"stable":"4.0.9"}}]}'
            else
                print '{"formulae":[{"name":"ruby","keg_only":false,"aliases":["ruby@4.0"],"versioned_formulae":["ruby@3.4"],"versions":{"stable":"4.0.9"}}]}'
            fi
        fi
        exit 0 ;;
    --cellar) print -r -- "$prefix/Cellar/$2"; exit 0 ;;
    uses) print -rn -- "${TEST_BREW_USERS:-}"; exit 0 ;;
    list)
        kind=Cellar
        [[ "$2" != --cask ]] || kind=Caskroom
        package="$4"
        if [[ -n "$package" ]]; then
            package="${package:t}"
            [[ -f "$prefix/$kind/$package/1.0.0/data" ]] || exit 1
            print -r -- "$package 1.0.0"
        else
            for folder in "$prefix/$kind/"*(N/); do
                print -r -- "${folder:t} 1.0.0"
            done
        fi
        exit 0 ;;
    install|reinstall)
        [[ "${TEST_BREW_PERMISSION:-0}" != 1 ]] || { print -u2 EACCES; exit 13; }
        kind=Cellar
        [[ "$2" != --cask ]] || kind=Caskroom
        package="${3:t}"
        mkdir -p "$prefix/$kind/$package/1.0.0"
        print original > "$prefix/$kind/$package/1.0.0/data"
        if [[ "$package" == node* ]]; then
            /bin/rm -f "$TEST_ROOT/node-broken" "$TEST_ROOT/npm-missing" "$TEST_ROOT/engine-old"
            mkdir -p "$prefix/$kind/$package/1.0.0/bin"
            cp "$TEST_ROOT/node-source" "$prefix/$kind/$package/1.0.0/bin/node"
            cp "$TEST_ROOT/npm-source" "$prefix/$kind/$package/1.0.0/bin/npm"
            chmod u+x "$prefix/$kind/$package/1.0.0/bin/"*
            if [[ -n "${TEST_GLOBAL_NPM_CHANGE:-}" ]]; then
                bundled="$prefix/$kind/$package/1.0.0/libexec/lib/node_modules/npm"
                mkdir -p "$bundled/bin"
                print '{"name":"npm","version":"11.20.0"}' > "$bundled/package.json"
                printf '#!/bin/zsh\nprint 11.20.0\n' > "$bundled/bin/npm-cli.js"
                chmod u+x "$bundled/bin/npm-cli.js"
                /bin/rm -r -- "$prefix/lib/node_modules/npm"
                cp -pR "$bundled" "$prefix/lib/node_modules/npm"
                [[ "$TEST_GLOBAL_NPM_CHANGE" != foreign ]] || print '{"name":"npm","version":"99.0.0"}' > "$prefix/lib/node_modules/npm/package.json"
            fi
        elif [[ "$package" == ruby* ]]; then
            mkdir -p "$prefix/$kind/$package/1.0.0/bin"
            cp "$TEST_ROOT/ruby-source" "$prefix/$kind/$package/1.0.0/bin/ruby"
            cp "$TEST_ROOT/gem-source" "$prefix/$kind/$package/1.0.0/bin/gem"
            chmod u+x "$prefix/$kind/$package/1.0.0/bin/"*
        elif [[ "$package" == git-lfs ]]; then
            mkdir -p "$prefix/bin"
            printf '#!/bin/zsh\nprint fixture-lfs\nexit 0\n' > "$prefix/bin/git-lfs"
            chmod u+x "$prefix/bin/git-lfs"
        fi
        print -r -- "$*" >> "$TEST_ROOT/brew.calls"
        exit 0 ;;
    uninstall)
        kind=Cellar
        [[ "$2" != --cask ]] || kind=Caskroom
        package="${3:t}"
        /bin/rm -r -- "$prefix/$kind/$package"
        print -r -- "$*" >> "$TEST_ROOT/brew.calls"
        exit 0 ;;
esac
exit 98
"""


class Fixture:
    def __init__(self, root: Path, backend: Path):
        self.root = root
        self.home = root / "用户 HOME"
        self.bin = root / "bin"
        self.home.mkdir()
        self.bin.mkdir()
        (root / "brew/Cellar").mkdir(parents=True)
        (root / "brew/Caskroom").mkdir()
        self.write_command("node", NODE_STUB)
        self.write_command("npm", NPM_STUB)
        self.write_command("brew", BREW_STUB)
        root.joinpath("node-source").write_text(NODE_STUB)
        root.joinpath("npm-source").write_text(NPM_STUB)
        self.write_command("curl", '#!/bin/zsh\nprintf \'[{"version":"v26.13.1","lts":"Fixture"}]\\n\'\n')
        self.write_command("ruby", '#!/bin/zsh\n[[ "$1" != -rjson ]] || exec /usr/bin/ruby "$@"\nexit 0\n')
        self.write_command("gem", "#!/bin/zsh\n[[ \"$1\" == --version ]] && { print 3.7; exit 0; }\nprint -u2 EACCES\nexit 13\n")
        self.write_command("otool", "#!/bin/zsh\nprint -r -- \"$2:\"\nprint -r -- '\\t/usr/lib/libSystem.B.dylib (compatibility version 1.0.0)'\n")
        self.write_command("xcode-select", "#!/bin/zsh\nexit 1\n")
        self.write_command("xcrun", "#!/bin/zsh\nexit 1\n")
        self.write_command("xcodebuild", "#!/bin/zsh\nexit 1\n")
        self.write_command("git", '#!/bin/zsh\nfor arg in "$@"; do case "$arg" in clone|fetch|pull|push|ls-remote) print -u2 "isolated git network denied"; exit 97;; esac; done\nexec /usr/bin/git "$@"\n')
        root.joinpath("ruby-source").write_text('#!/bin/zsh\n[[ "$1" != -rjson ]] || exec /usr/bin/ruby "$@"\nexit 0\n')
        self.write_command("lsof", '#!/bin/zsh\n[[ ! -f "$TEST_ROOT/brew-busy" ]] || { print 12345; exit 0; }\nexit 1\n')
        root.joinpath("gem-source").write_text(
            '#!/bin/zsh\n[[ "$1" == --version ]] && { print 3.7; exit 0; }\n'
            'target=""\nwhile (( $# )); do [[ "$1" != --install-dir ]] || { shift; target="$1"; }; shift; done\n'
            '[[ -n "$target" ]] || exit 2\nmkdir -p "$target/bin"\nprintf \'#!/bin/zsh\\nprint 1.16.2\\n\' > "$target/bin/pod"\nchmod u+x "$target/bin/pod"\n'
        )
        self.backend = backend
        self.env = {
            "HOME": str(self.home),
            "PATH": f"{self.bin}:/usr/bin:/bin:/usr/sbin:/sbin",
            "LANG": "en_US.UTF-8",
            "TMPDIR": str(root),
            "TEST_ROOT": str(root),
            "JOBS_HOMEBREW_BIN": str(self.bin / "brew"),
            "NO_COLOR": "1",
            "JOBS_SETUP_RETRY_BASE_SECONDS": "1",
        }
        for key in ("TEST_NPM_FAIL", "TEST_BAD_BINARY", "TEST_BREW_USERS"):
            self.env.pop(key, None)

    def write_command(self, name: str, content: str) -> None:
        target = self.bin / name
        target.write_text(content, encoding="utf-8")
        target.chmod(0o755)

    def run(self, *arguments: str, success: bool = True) -> subprocess.CompletedProcess[str]:
        result = subprocess.run(
            ["/bin/zsh", str(self.backend), *arguments],
            cwd="/",
            env=self.env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=60,
            check=False,
        )
        if (result.returncode == 0) != success:
            raise AssertionError(f"Unexpected exit {result.returncode}: {arguments}\n{result.stdout}")
        return result

    def seed_receipt(self, component: str, kind: str, target: Path) -> None:
        """仅为难以下载复现的归属/内容门禁提供安装后夹具，不执行安装器。"""
        library = self.root / "backend-functions.zsh"
        content = self.backend.read_text()
        content = content.rsplit('\nmain "$@"', 1)[0]
        library.write_text(content)
        self.state.joinpath("receipts").mkdir(parents=True)
        command = (
            'source "$1"; initialize_paths; '
            'STATE_DIR="$HOME/Library/Application Support/JobsSystemSetup"; '
            'write_receipt "$2" "$3" "$4" fixture "$(tree_digest "$4")"'
        )
        result = subprocess.run(
            ["/bin/zsh", "-c", command, "fixture", str(library), component, kind, str(target)],
            cwd="/", env=self.env, text=True, capture_output=True, timeout=30, check=False,
        )
        assert result.returncode == 0, result.stderr

    @property
    def state(self) -> Path:
        return self.home / "Library/Application Support/JobsSystemSetup"


def test_npm_restore(fixture: Fixture) -> None:
    original = b"export CUSTOM='no newline'"
    profile = fixture.home / ".zprofile"
    profile.write_bytes(original)
    fixture.run("--install", "rea", "--yes")
    receipt = fixture.state / "receipts/rea.tsv"
    assert "\nkind\tnpm\n" in receipt.read_text()
    calls = (fixture.root / "npm.calls").read_text()
    assert "rea-agents@latest" in calls and "--engine-strict" in calls
    fixture.run("--uninstall", "rea", "--yes")
    assert profile.read_bytes() == original
    assert not receipt.exists()
    fixture.run("--uninstall", "rea", "--yes")
    assert profile.read_bytes() == original


def test_absent_and_incremental_profile(fixture: Fixture) -> None:
    profile = fixture.home / ".zprofile"
    fixture.run("--install", "quicktype", "--yes")
    fixture.run("--uninstall", "quicktype", "--yes")
    assert not profile.exists()
    fixture.run("--install", "quicktype", "--yes")
    addition = b"export USER_ADDED='yes'"
    with profile.open("ab") as stream:
        stream.write(addition)
    fixture.run("--uninstall", "quicktype", "--yes")
    assert profile.read_bytes() == addition


def test_modified_content(fixture: Fixture) -> None:
    fixture.run("--install", "rea", "--yes")
    prefix = fixture.home / ".local/share/jobs-system-setup/rea"
    prefix.joinpath("new-user-file").write_text("preserve")
    fixture.run("--uninstall", "rea", "--yes", success=False)
    assert prefix.joinpath("new-user-file").read_text() == "preserve"
    prefix.joinpath("new-user-file").unlink()
    fixture.run("--uninstall", "rea", "--yes")


def test_modified_profile(fixture: Fixture) -> None:
    fixture.run("--install", "rea", "--yes")
    profile = fixture.home / ".zprofile"
    profile.write_text(profile.read_text().replace(':"$PATH"', ':"/user/changed"'))
    fixture.run("--uninstall", "rea", "--yes", success=False)
    assert "/user/changed" in profile.read_text()
    assert (fixture.home / ".local/share/jobs-system-setup/rea").exists()


def test_failed_install_cleanup(fixture: Fixture) -> None:
    fixture.env["TEST_NPM_FAIL"] = "1"
    fixture.run("--install", "rea", "--yes", success=False)
    fixture.env.pop("TEST_NPM_FAIL")
    fixture.run("--uninstall", "rea", "--yes")
    assert not (fixture.home / ".local/share/jobs-system-setup/rea").exists()


def test_failed_binary_cleanup(fixture: Fixture) -> None:
    fixture.env["TEST_BAD_BINARY"] = "1"
    fixture.run("--install", "rea", "--yes", success=False)
    fixture.env.pop("TEST_BAD_BINARY")
    fixture.run("--uninstall", "rea", "--yes")


def test_validation_and_query(fixture: Fixture) -> None:
    result = fixture.run("--catalog")
    rows = result.stdout.splitlines()
    assert len(rows) > 40
    assert all(len(row.split("\t")) == 4 for row in rows)
    assert any(row.startswith("rea\t") for row in rows)
    fixture.run("--install", "rea", "--dry-run")
    fixture.run("--install", "rea", success=False)
    fixture.run("--install", "--yes", success=False)
    fixture.run("--install", "../escape", "--yes", success=False)
    fixture.run("--install", "rea", "--brew-location", success=False)
    assert not fixture.state.exists()
    assert not (fixture.root / "npm.calls").exists()


def test_preexisting_global(fixture: Fixture) -> None:
    fixture.write_command("rea", "#!/bin/zsh\nprint external\n")
    fixture.run("--install", "rea", "--yes")
    fixture.run("--uninstall", "rea", "--yes", success=False)
    assert (fixture.bin / "rea").exists()
    assert not (fixture.state / "receipts/rea.tsv").exists()


def test_managed_cli_runtime_broken(fixture: Fixture) -> None:
    fixture.run("--install", "rea", "--yes")
    prefix = fixture.home / ".local/share/jobs-system-setup/rea"
    executable = prefix / "bin/rea"
    original = executable.read_bytes()
    receipt = fixture.state / "receipts/rea.tsv"
    original_receipt = receipt.read_bytes()
    fixture.write_command("node", "#!/bin/zsh\nprint -u2 'fixture dynamic library failure'\nexit 9\n")
    fixture.env["TEST_BREW_PERMISSION"] = "1"
    result = fixture.run("--install", "rea", "--yes", success=False)
    assert "退出码 9" in result.stdout
    assert executable.read_bytes() == original
    assert receipt.read_bytes() == original_receipt


def test_preexisting_global_broken(fixture: Fixture) -> None:
    fixture.write_command("rea", "#!/bin/zsh\nprint -u2 broken-global\nexit 8\n")
    executable = fixture.bin / "rea"
    before = executable.read_bytes()
    result = fixture.run("--install", "rea", "--yes")
    assert "已有全局组件仍不健康" in result.stdout
    assert executable.read_bytes() == before
    assert (fixture.state / "receipts/rea.tsv").exists()
    assert (fixture.root / "npm.calls").exists()


def test_untracked_prefix_unready(fixture: Fixture) -> None:
    prefix = fixture.home / ".local/share/jobs-system-setup/quicktype"
    prefix.mkdir(parents=True)
    prefix.joinpath("keep").write_text("preserve")
    fixture.run("--install", "quicktype", "--yes", success=False)
    prefix.joinpath("bin").mkdir()
    prefix.joinpath("bin/quicktype").write_text("#!/bin/zsh\nexit 6\n")
    prefix.joinpath("bin/quicktype").chmod(0o755)
    fixture.run("--install", "quicktype", "--yes", success=False)
    assert prefix.joinpath("keep").read_text() == "preserve"
    assert not (fixture.state / "receipts/quicktype.tsv").exists()
    assert not (fixture.root / "npm.calls").exists()


def test_existing_support_targets_unready(fixture: Fixture) -> None:
    fixture.write_command("pod", "#!/bin/zsh\nexit 7\n")
    fixture.run("--install", "cocoapods", "--yes", success=False)
    pod_prefix = fixture.home / ".local/share/jobs-system-setup/cocoapods"
    pod_prefix.mkdir(parents=True)
    pod_prefix.joinpath("keep").write_text("preserve")
    fixture.run("--install", "cocoapods", "--yes", success=False)
    omz = fixture.home / ".oh-my-zsh"
    omz.mkdir()
    fixture.run("--install", "oh-my-zsh", "--yes", success=False)
    omz.joinpath("oh-my-zsh.sh").write_text("if ; then")
    fixture.run("--install", "oh-my-zsh", "--yes", success=False)
    repo = fixture.home / "Desktop/JobsKits/JobsSoftware.MacOS"
    repo.mkdir(parents=True)
    repo.joinpath("keep").write_text("preserve")
    fixture.run("--install", "jobs-software", "--yes", success=False)
    assert repo.joinpath("keep").read_text() == "preserve"
    assert pod_prefix.joinpath("keep").read_text() == "preserve"


def test_brew_receipt_and_shared(fixture: Fixture) -> None:
    fixture.run("--install", "brew.gh", "--yes")
    target = fixture.root / "brew/Cellar/gh"
    fixture.env["TEST_BREW_USERS"] = "shared-consumer\n"
    fixture.run("--uninstall", "brew.gh", "--yes", success=False)
    assert target.exists()
    fixture.env.pop("TEST_BREW_USERS")
    fixture.run("--uninstall", "brew.gh", "--yes")
    assert not target.exists()
    fixture.run("--uninstall", "brew.gh", "--yes")


def test_brew_modified(fixture: Fixture) -> None:
    fixture.run("--install", "brew.gh", "--yes")
    target = fixture.root / "brew/Cellar/gh/1.0.0/data"
    target.write_text("updated-by-other-process")
    fixture.run("--uninstall", "brew.gh", "--yes", success=False)
    assert target.exists()


def test_symlink_and_lock(fixture: Fixture) -> None:
    fixture.state.mkdir(parents=True)
    fixture.state.joinpath("transaction.lock").mkdir()
    fixture.run("--install", "rea", "--yes", success=False)
    assert not (fixture.root / "npm.calls").exists()
    fixture.state.joinpath("transaction.lock").rmdir()
    fixture.home.joinpath(".local").symlink_to(fixture.root / "foreign", target_is_directory=True)
    fixture.run("--install", "rea", "--yes", success=False)
    assert not (fixture.root / "foreign").exists()


def test_private_logs(fixture: Fixture) -> None:
    fixture.run("--install", "rea", "--yes")
    fixture.run("--uninstall", "rea", "--yes")
    logs = list((fixture.state / "logs").glob("session.*"))
    assert len(logs) >= 2
    assert all((path.stat().st_mode & 0o777) == 0o600 for path in logs)
    assert logs[0].read_text() and logs[1].read_text()


def test_homebrew_empty_owned_prefix(fixture: Fixture) -> None:
    prefix = fixture.home / ".local/homebrew"
    prefix.joinpath("bin").mkdir(parents=True)
    brew = prefix / "bin/brew"
    brew.write_text("#!/bin/zsh\n[[ \"$1\" == list ]] && exit 0\nexit 1\n")
    brew.chmod(0o755)
    fixture.seed_receipt("homebrew", "homebrew", prefix)
    fixture.run("--uninstall", "homebrew", "--yes")
    assert not prefix.exists()


def test_homebrew_added_file_preserved(fixture: Fixture) -> None:
    prefix = fixture.home / ".local/homebrew"
    prefix.joinpath("bin").mkdir(parents=True)
    brew = prefix / "bin/brew"
    brew.write_text("#!/bin/zsh\n[[ \"$1\" == list ]] && exit 0\nexit 1\n")
    brew.chmod(0o755)
    fixture.seed_receipt("homebrew", "homebrew", prefix)
    added = prefix / "user-added"
    added.write_text("preserve")
    fixture.run("--uninstall", "homebrew", "--yes", success=False)
    assert added.read_text() == "preserve"


def test_env_all_dispatch(fixture: Fixture) -> None:
    source = fixture.backend.read_text()
    local_backend = fixture.root / "🆕新系统配置/MacOS/【MacOS】🆕新系统配置.command/【MacOS】环境管理后端.command/【MacOS】环境管理后端.command"
    local_backend.parent.mkdir(parents=True)
    local_backend.write_text(source)
    env_backend = fixture.root / "🌍JobsMacEnvVarConfigs/【MacOS】环境管理后端.command/【MacOS】环境管理后端.command"
    env_backend.parent.mkdir(parents=True)
    env_backend.write_text(
        '#!/bin/zsh\nprintf "%s\\n" "$*" >> "$TEST_ROOT/env.calls"\nexit "${TEST_ENV_EXIT:-0}"\n'
    )
    fixture.backend = local_backend
    fixture.run("--install", "jobs-env", "--yes")
    fixture.run("--uninstall", "jobs-env", "--yes")
    fixture.env["TEST_ENV_EXIT"] = "3"
    result = fixture.run("--uninstall", "jobs-env", "--yes", success=False)
    assert "JOBS_MANAGER_EVENT\tjobs-env\tfailed\texit=3" in result.stdout
    calls = fixture.root.joinpath("env.calls").read_text().splitlines()
    assert calls == ["--install all --yes", "--uninstall all --yes", "--uninstall all --yes"]


def configure_node_provider(fixture: Fixture) -> None:
    prefix = fixture.root / "brew/Cellar/node/1.0.0"
    prefix.joinpath("bin").mkdir(parents=True)
    prefix.joinpath("data").write_text("original")
    for name, source in (("node", NODE_STUB), ("npm", NPM_STUB)):
        target = prefix / f"bin/{name}"
        target.write_text(source)
        target.chmod(0o755)
        fixture.bin.joinpath(name).unlink()
        fixture.bin.joinpath(name).symlink_to(target)
    dep = fixture.root / "brew/Cellar/simdutf/1.0.0"
    dep.joinpath("lib").mkdir(parents=True)
    dep.joinpath("data").write_text("healthy newer library")
    dep.joinpath("lib/libsimdutf.38.dylib").write_text("mock Mach-O")


def test_consumer_old_abi_repair(fixture: Fixture) -> None:
    configure_node_provider(fixture)
    fixture.root.joinpath("node-broken").touch()
    result = fixture.run("--install", "rea", "--yes")
    calls = fixture.root.joinpath("brew.calls").read_text()
    assert "reinstall --formula node" in calls
    assert "simdutf" not in calls
    assert "Node 引用了旧 ABI" in result.stdout
    assert not (fixture.state / "receipts/dependency.node.tsv").exists()
    assert (fixture.state / "receipts/rea.tsv").exists()


def test_missing_npm_repair(fixture: Fixture) -> None:
    configure_node_provider(fixture)
    fixture.root.joinpath("npm-missing").touch()
    fixture.run("--install", "quicktype", "--yes")
    assert not fixture.root.joinpath("npm-missing").exists()
    assert "reinstall --formula node" in fixture.root.joinpath("brew.calls").read_text()


def test_engine_upgrade_repair(fixture: Fixture) -> None:
    configure_node_provider(fixture)
    fixture.root.joinpath("engine-old").touch()
    fixture.run("--install", "rea", "--yes")
    assert not fixture.root.joinpath("engine-old").exists()
    calls = fixture.root.joinpath("brew.calls").read_text()
    assert "install --formula node@26" in calls
    assert "reinstall --formula node\n" not in calls


def test_new_runtime_visible_and_shared(fixture: Fixture) -> None:
    fixture.bin.joinpath("node").unlink()
    fixture.bin.joinpath("npm").unlink()
    fixture.run("--install", "rea", "--yes")
    result = fixture.run("--catalog")
    assert "dependency.node@26\t" in result.stdout
    fixture.run("--uninstall", "dependency.node@26", "--yes", success=False)
    fixture.run("--uninstall", "rea", "dependency.node@26", "--yes")
    assert not (fixture.state / "receipts/dependency.node@26.tsv").exists()


def test_network_retry_then_recover(fixture: Fixture) -> None:
    fixture.root.joinpath("network-left").write_text("2")
    result = fixture.run("--install", "rea", "--yes")
    assert "网络获取第 2 次失败" in result.stdout
    assert fixture.root.joinpath("npm.calls").read_text().count("install --global") == 3
    assert (fixture.state / "receipts/rea.tsv").exists()


def test_network_retry_cancel(fixture: Fixture) -> None:
    fixture.root.joinpath("network-left").write_text("100")
    process = subprocess.Popen(
        ["/bin/zsh", str(fixture.backend), "--install", "rea", "--yes"],
        cwd="/", env=fixture.env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    assert process.stdout is not None
    data = bytearray()
    deadline = time.monotonic() + 10
    try:
        while time.monotonic() < deadline:
            ready, _, _ = select.select([process.stdout], [], [], 0.1)
            if ready:
                data.extend(os.read(process.stdout.fileno(), 65536))
                if "自动重试".encode() in data:
                    break
        assert "自动重试".encode() in data
        os.killpg(process.pid, 15)
        assert process.wait(timeout=10) != 0
        assert not (fixture.home / ".local/share/jobs-system-setup/rea/bin/rea").exists()
        calls_before = fixture.root.joinpath("npm.calls").read_bytes()
        time.sleep(0.1)
        assert fixture.root.joinpath("npm.calls").read_bytes() == calls_before
    finally:
        if process.poll() is None:
            os.killpg(process.pid, 15)
            process.wait(timeout=10)


def test_permission_no_retry(fixture: Fixture) -> None:
    fixture.env["TEST_PERMISSION"] = "1"
    result = fixture.run("--install", "rea", "--yes", success=False)
    assert "确定错误" in result.stdout
    assert "自动重试" not in result.stdout
    assert fixture.root.joinpath("npm.calls").read_text().count("install --global") == 1


def test_healthy_repeat_and_readonly_no_heal(fixture: Fixture) -> None:
    fixture.run("--install", "rea", "--yes")
    receipt = fixture.state.joinpath("receipts/rea.tsv").read_bytes()
    calls = fixture.root.joinpath("npm.calls").read_bytes()
    fixture.run("--install", "rea", "--yes")
    assert fixture.root.joinpath("npm.calls").read_bytes() == calls
    assert fixture.state.joinpath("receipts/rea.tsv").read_bytes() == receipt
    fixture.root.joinpath("node-broken").touch()
    fixture.run("--catalog")
    fixture.run("--install", "rea", "--dry-run")
    fixture.run("--uninstall", "rea", "--yes")
    assert fixture.root.joinpath("node-broken").exists()
    assert not fixture.root.joinpath("brew.calls").exists()


def test_cooperative_stop_file(fixture: Fixture) -> None:
    fixture.root.joinpath("network-left").write_text("100")
    stop = fixture.root / "session-stop"
    process = subprocess.Popen(
        ["/bin/zsh", str(fixture.backend), "--install", "rea", "quicktype", "--yes", "--stop-request-file", str(stop)],
        cwd="/", env=fixture.env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )
    assert process.stdout is not None
    captured = bytearray()
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        ready, _, _ = select.select([process.stdout], [], [], 0.1)
        if ready:
            captured.extend(os.read(process.stdout.fileno(), 65536))
            if "自动重试".encode() in captured:
                break
    assert "自动重试".encode() in captured
    stop.write_text("stop")
    tail, _ = process.communicate(timeout=10)
    captured.extend(tail)
    assert process.returncode == 130
    assert b"JOBS_MANAGER_STOPPED" in captured
    assert b"JOBS_MANAGER_EVENT\trea\tskipped\tnot-started" in captured
    assert not (fixture.home / ".local/share/jobs-system-setup/rea").exists()


def test_transaction_lock_survives_subshells(fixture: Fixture) -> None:
    pause = fixture.root / "npm-pause"
    pause.touch()
    process = subprocess.Popen(
        ["/bin/zsh", str(fixture.backend), "--install", "rea", "--yes"],
        cwd="/", env=fixture.env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline and not fixture.root.joinpath("npm-ready").exists():
        time.sleep(0.05)
    assert fixture.root.joinpath("npm-ready").exists()
    lock = fixture.state / "transaction.lock"
    assert lock.is_dir()
    result = fixture.run("--install", "quicktype", "--yes", success=False)
    assert "另一个事务" in result.stdout
    assert lock.is_dir()
    pause.unlink()
    stdout, _ = process.communicate(timeout=30)
    assert process.returncode == 0, stdout.decode()
    assert not lock.exists()


def test_pinned_runtime_in_new_process(fixture: Fixture) -> None:
    fixture.bin.joinpath("node").unlink()
    fixture.bin.joinpath("npm").unlink()
    fixture.env["TEST_CLI_USES_NODE"] = "1"
    fixture.run("--install", "rea", "--yes")
    old_bin = fixture.root / "old-login-bin"
    old_bin.mkdir()
    old_bin.joinpath("node").write_text("#!/bin/zsh\nexit 19\n")
    old_bin.joinpath("node").chmod(0o755)
    cli = fixture.home / ".local/share/jobs-system-setup/rea/bin/rea"
    result = subprocess.run(
        [str(cli), "--version"], cwd="/",
        env={**fixture.env, "PATH": f"{old_bin}:/usr/bin:/bin"},
        capture_output=True, timeout=10, check=False,
    )
    assert result.returncode == 0, result.stderr


def test_ruby_and_git_lfs_auto_prepare(fixture: Fixture) -> None:
    fixture.write_command("ruby", "#!/bin/zsh\nexit 9\n")
    fixture.run("--install", "cocoapods", "--yes")
    assert "install --formula ruby" in fixture.root.joinpath("brew.calls").read_text()
    fixture.run("--install", "git-lfs-config", "--yes")
    assert "install --formula git-lfs" in fixture.root.joinpath("brew.calls").read_text()


def test_clt_request_once_then_continue(fixture: Fixture) -> None:
    fixture.write_command("xcode-select", '#!/bin/zsh\nif [[ "$1" == --install ]]; then print requested >> "$TEST_ROOT/clt.calls"; : > "$TEST_ROOT/clt-requested"; exit 0; fi\n[[ -f "$TEST_ROOT/clt-ready" ]]\n')
    fixture.write_command("xcrun", '#!/bin/zsh\n[[ -f "$TEST_ROOT/clt-ready" ]]\n')
    fixture.write_command("git", '#!/bin/zsh\n[[ -f "$TEST_ROOT/clt-ready" ]]\n')
    fixture.env["JOBS_SETUP_CLT_POLL_SECONDS"] = "1"
    process = subprocess.Popen(
        ["/bin/zsh", str(fixture.backend), "--install", "clt", "--yes"],
        cwd="/", env=fixture.env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline and not fixture.root.joinpath("clt-requested").exists():
        time.sleep(0.05)
    assert fixture.root.joinpath("clt-requested").exists()
    assert process.poll() is None
    fixture.root.joinpath("clt-ready").touch()
    stdout, _ = process.communicate(timeout=10)
    assert process.returncode == 0, stdout.decode()
    assert fixture.root.joinpath("clt.calls").read_text().count("requested") == 1


def test_old_ruby_error_does_not_trigger_repair(fixture: Fixture) -> None:
    logs = fixture.state / "logs"
    logs.mkdir(parents=True)
    logs.joinpath("download.old-session").write_text("old gem requires Ruby >= 3.2")
    result = fixture.run("--install", "cocoapods", "--yes", success=False)
    assert "EACCES" in result.stdout
    assert not fixture.root.joinpath("brew.calls").exists()


def test_direct_selected_node_heals_provider(fixture: Fixture) -> None:
    configure_node_provider(fixture)
    fixture.root.joinpath("node-broken").touch()
    fixture.run("--install", "brew.node", "--yes")
    assert not fixture.root.joinpath("node-broken").exists()
    assert "reinstall --formula node" in fixture.root.joinpath("brew.calls").read_text()
    assert not fixture.state.joinpath("receipts/brew.node.tsv").exists()


def test_healthy_ruby_incompatible_uses_parallel(fixture: Fixture) -> None:
    original = fixture.root / "brew/Cellar/ruby/1.0.0"
    original.mkdir(parents=True)
    original.joinpath("data").write_text("shared healthy Ruby untouched")
    fixture.write_command("ruby", '#!/bin/zsh\n[[ "$1" != -rjson ]] || exec /usr/bin/ruby "$@"\nexit 0\n')
    fixture.write_command("gem", '#!/bin/zsh\n[[ "$1" != --version ]] || { print 3.7; exit 0; }\nprint -u2 "requires Ruby >= 3.2"\nexit 1\n')
    fixture.run("--install", "cocoapods", "--yes")
    calls=fixture.root.joinpath("brew.calls").read_text()
    assert "install --formula ruby@3.4" in calls
    assert "reinstall --formula ruby\n" not in calls
    assert original.joinpath("data").read_text() == "shared healthy Ruby untouched"


def test_busy_provider_wait_then_recheck(fixture: Fixture) -> None:
    configure_node_provider(fixture)
    fixture.root.joinpath("node-broken").touch()
    busy=fixture.root / "brew-busy"
    busy.touch()
    lock=fixture.root / "brew/var/homebrew/locks/node.formula.lock"
    lock.parent.mkdir(parents=True)
    lock.touch()
    process = subprocess.Popen(
        ["/bin/zsh",str(fixture.backend),"--install","rea","--yes"],
        cwd="/",env=fixture.env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,
    )
    assert process.stdout is not None
    captured=bytearray()
    deadline=time.monotonic()+10
    while time.monotonic()<deadline:
        ready,_,_=select.select([process.stdout],[],[],0.1)
        if ready:
            captured.extend(os.read(process.stdout.fileno(),65536))
            if "等待其结束".encode() in captured:
                break
    assert "等待其结束".encode() in captured
    assert not fixture.root.joinpath("brew.calls").exists()
    fixture.root.joinpath("node-broken").unlink()
    busy.unlink()
    tail,_=process.communicate(timeout=20)
    assert process.returncode==0,(bytes(captured)+tail).decode()
    assert not fixture.root.joinpath("brew.calls").exists()
    assert not fixture.state.joinpath("receipts/dependency.node.tsv").exists()


def configure_global_npm(fixture: Fixture) -> Path:
    target=fixture.root / "brew/lib/node_modules/npm"
    target.joinpath("bin").mkdir(parents=True)
    target.joinpath("package.json").write_text('{"name":"npm","version":"12.2.2"}\n')
    target.joinpath("bin/npm-cli.js").write_text("#!/bin/zsh\nprint 12.2.2\n")
    target.joinpath("bin/npm-cli.js").chmod(0o755)
    bin_folder=fixture.root / "brew/bin"
    bin_folder.mkdir()
    for name in ("npm","npx"):
        bin_folder.joinpath(name).symlink_to("../lib/node_modules/npm/bin/npm-cli.js")
    other=fixture.root / "brew/lib/node_modules/custom"
    other.mkdir()
    other.joinpath("keep").write_text("preserve unrelated global module")
    return target


def test_shared_global_npm_preserved(fixture: Fixture) -> None:
    configure_node_provider(fixture)
    target=configure_global_npm(fixture)
    original=target.joinpath("package.json").read_bytes()
    fixture.root.joinpath("node-broken").touch()
    fixture.env["TEST_GLOBAL_NPM_CHANGE"]="bundled"
    fixture.run("--install","rea","--yes")
    assert target.joinpath("package.json").read_bytes()==original
    assert fixture.root.joinpath("brew/lib/node_modules/custom/keep").read_text()=="preserve unrelated global module"


def test_foreign_global_npm_not_overwritten(fixture: Fixture) -> None:
    configure_node_provider(fixture)
    target=configure_global_npm(fixture)
    fixture.root.joinpath("node-broken").touch()
    fixture.env["TEST_GLOBAL_NPM_CHANGE"]="foreign"
    result=fixture.run("--install","rea","--yes",success=False)
    assert "不能证明属于本次 provider" in result.stdout
    assert '"99.0.0"' in target.joinpath("package.json").read_text()
    backups=list((fixture.state/"backups").glob("npm-preserve.*/npm/package.json"))
    assert any('"12.2.2"' in path.read_text() for path in backups)


def test_alias_ruby_is_not_independent(fixture: Fixture) -> None:
    fixture.env["TEST_RUBY_ALIAS_ONLY"]="1"
    fixture.write_command("gem", '#!/bin/zsh\n[[ "$1" != --version ]] || { print 3.7; exit 0; }\nprint -u2 "requires Ruby >= 3.2"\nexit 1\n')
    result=fixture.run("--install","cocoapods","--yes",success=False)
    assert "没有可验证" in result.stdout
    assert not fixture.root.joinpath("brew.calls").exists()


def test_alias_node_is_not_independent(fixture: Fixture) -> None:
    configure_node_provider(fixture)
    fixture.env["TEST_NODE_ALIAS_ONLY"]="1"
    fixture.root.joinpath("engine-old").touch()
    result=fixture.run("--install","rea","--yes",success=False)
    assert "不是可核实的独立" in result.stdout
    assert not fixture.root.joinpath("brew.calls").exists()


def test_existing_managed_engine_is_checked(fixture: Fixture) -> None:
    configure_node_provider(fixture)
    fixture.run("--install","rea","--yes")
    fixture.root.joinpath("engine-old").touch()
    fixture.run("--install","rea","--yes")
    assert "install --formula node@26" in fixture.root.joinpath("brew.calls").read_text()
    assert not fixture.root.joinpath("engine-old").exists()
    assert list((fixture.state/"backups").glob("rea.prefix.*"))


def test_real_node_npm_semver_shapes(fixture: Fixture) -> None:
    """只读调用实际Node和npm自带semver，不执行npm命令、不联网或修复。"""
    node=shutil.which("node")
    npm=shutil.which("npm")
    assert node and npm,"实际semver集成验证需要已准备好的Node/npm；测试不自动安装"
    source=Path(__file__).resolve().parents[2]/"【MacOS】环境管理后端.command"
    library=fixture.root/"actual-semver-functions.zsh"
    library.write_text(source.read_text().rsplit('\nmain "$@"',1)[0])
    supported="^22.23.4 || ^24.22.1 || >=26.12.1"
    cases=[
        (supported,"26.13.1",0),
        ([supported],"26.13.1",0),
        ({"node":supported},"24.22.1",0),
        ({"engines":{"node":supported}},"22.23.4",0),
        ({"engines.node":supported},"22.23.3",42),
        ([supported],"24.22.0",42),
        ([supported,supported],"26.13.1",2),
        ([],"26.13.1",2),
        (None,"26.13.1",2),
        (False,"26.13.1",2),
        ({"unexpected":supported},"26.13.1",2),
        ("not-a-semver-range","26.13.1",2),
    ]
    command='source "$1"; NODE_BIN="$2"; NPM_BIN="$3"; check_package_engine fixture "$4" "$5"'
    for index,(payload,version,expected) in enumerate(cases):
        engine_file=fixture.root/f"actual-engine-{index}.json"
        engine_file.write_text(json.dumps(payload))
        result=subprocess.run(
            ["/bin/zsh","-c",command,"integration",str(library),node,npm,str(engine_file),version],
            cwd="/",env=fixture.env,text=True,capture_output=True,timeout=15,check=False,
        )
        assert result.returncode==expected,(payload,version,result.returncode,result.stdout,result.stderr)
    assert not fixture.state.exists()
    assert not fixture.root.joinpath("npm.calls").exists()
    assert not fixture.root.joinpath("brew.calls").exists()


def test_tree_digest_batch_compatible(fixture: Fixture) -> None:
    """真实文件系统上比较旧逐文件与新批量摘要，不执行安装业务。"""
    source=Path(__file__).resolve().parents[2]/"【MacOS】环境管理后端.command"
    current=source.read_text().rsplit('\nmain "$@"',1)[0]
    assert "find . -type f -exec /usr/bin/shasum -a 256 {} +" in current
    original=current.replace(
        "find . -type f -exec /usr/bin/shasum -a 256 {} +",
        "find . -type f -exec /usr/bin/shasum -a 256 {} \\;",1,
    ).replace(
        "find . -exec /usr/bin/stat -f '%N | %p | %u | %g | %Y' {} +",
        "find . -exec /usr/bin/stat -f '%N | %p | %u | %g | %Y' {} \\;",1,
    )
    libraries=[]
    for name,content in (("old",original),("batch",current)):
        library=fixture.root/f"digest-{name}.zsh"
        start=content.index("tree_digest() {")
        end=content.index("\nfile_digest() {",start)
        manifest=content[start:end].replace("tree_digest() {","tree_manifest() {",1).replace(
            ") | LC_ALL=C sort | /usr/bin/shasum -a 256 | awk '{print $1}'",
            ") | LC_ALL=C sort",
        )
        library.write_text(content+"\n"+manifest)
        libraries.append(library)
    target=fixture.root/"真实 中文 空格树"
    target.mkdir()
    target.joinpath("空目录").mkdir()
    target.joinpath("嵌套 目录").mkdir()
    special_names=["中文 空格.txt","换行\n文件.bin","反斜\\杠.data","-leading"]
    for index,name in enumerate(special_names):
        path=target/name
        path.write_bytes(bytes([index,0,255])+name.encode())
        path.chmod(0o640)
    for index in range(64):
        target.joinpath(f"嵌套 目录/file-{index}").write_bytes(f"data-{index}".encode())
    link=target/"符号 链接\n\\"
    link.symlink_to(special_names[0])
    target.joinpath("断链").symlink_to("missing\npath")
    target.joinpath("空目录").chmod(0o711)
    command='source "$1"; setopt PIPE_FAIL; tree_digest "$2"'
    evidence=[]

    def compare(label: str) -> str:
        values=[]
        seconds=[]
        for library in libraries:
            started=time.monotonic()
            result=subprocess.run(
                ["/bin/zsh","-c",command,"digest",str(library),str(target)],
                cwd="/",env=fixture.env,text=True,capture_output=True,timeout=30,check=False,
            )
            seconds.append(time.monotonic()-started)
            assert result.returncode==0,(label,result.stdout,result.stderr)
            values.append(result.stdout.strip())
        assert values[0]==values[1],(label,values)
        assert len(values[0])==64
        evidence.append({"case":label,"digest":values[0],"old_seconds":seconds[0],"batch_seconds":seconds[1]})
        return values[0]

    previous=compare("base")
    raw=[]
    for library in libraries:
        manifest_command='source "$1"; setopt PIPE_FAIL; tree_manifest "$2"'
        result=subprocess.run(
            ["/bin/zsh","-c",manifest_command,"manifest",str(library),str(target)],
            cwd="/",env=fixture.env,capture_output=True,timeout=30,check=False,
        )
        assert result.returncode==0,result.stderr
        raw.append(result.stdout)
    assert raw[0]==raw[1],"排序后的shasum/stat原始输出应逐字节一致"
    fixture.root.joinpath("manifest-old.bin").write_bytes(raw[0])
    fixture.root.joinpath("manifest-batch.bin").write_bytes(raw[1])
    content=target/special_names[1]
    content.write_bytes(content.read_bytes()+b"\0changed")
    changed=compare("content")
    assert changed!=previous
    previous=changed
    target.joinpath(special_names[2]).chmod(0o600)
    changed=compare("mode")
    assert changed!=previous
    previous=changed
    link.unlink()
    link.symlink_to(special_names[2])
    changed=compare("symlink")
    assert changed!=previous
    previous=changed
    target.joinpath("新增 空目录").mkdir()
    changed=compare("empty-directory")
    assert changed!=previous
    fixture.root.joinpath("digest-compatibility.json").write_text(json.dumps(evidence,ensure_ascii=False,indent=2))
    print(f"  digest兼容：5种实际状态逐字一致；baseline旧{evidence[0]['old_seconds']:.3f}s，新{evidence[0]['batch_seconds']:.3f}s")
    assert not fixture.state.exists()

def run_terminal_case(fixture: Fixture, mode: str) -> None:
    """使用真实 fzf 和 PTY，业务后端全部替换成只写夹具标记的假实现。"""
    fzf = shutil.which("fzf")
    assert fzf, "终端交互验证需要现有 fzf，不会自动安装"
    fixture.bin.joinpath("fzf").symlink_to(Path(fzf).resolve())
    source = Path(__file__).resolve().parents[4] / "【MacOS】↩️卸载新系统配置.command/【MacOS】↩️卸载新系统配置.command"
    entry = fixture.root / "迁移后 多平台/MacOS/【MacOS】↩️卸载新系统配置.command/【MacOS】↩️卸载新系统配置.command"
    entry.parent.mkdir(parents=True)
    shutil.copy2(source, entry)
    backend = entry.parent.parent / "【MacOS】🆕新系统配置.command/【MacOS】环境管理后端.command/【MacOS】环境管理后端.command"
    backend.parent.mkdir(parents=True)
    backend.write_text(
        '#!/bin/zsh\n'
        'if [[ "$1" == --catalog ]]; then printf "rea\\tREA\\tFixture\\tyes\\nquicktype\\tQuicktype\\tFixture\\tyes\\n"; exit 0; fi\n'
        'print -r -- "$*" >> "$TEST_ROOT/ui.calls"\n'
        'print -r -- "PLAN"\n'
    )
    env = {**fixture.env, "TERM": "xterm-256color"}
    pid, fd = pty.fork()
    if pid == 0:
        os.chdir("/")
        os.execve("/bin/zsh", ["/bin/zsh", str(entry)], env)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 160, 0, 0))
    transcript = bytearray()

    def await_text(label: str) -> None:
        deadline = time.monotonic() + 10
        recent = bytearray()
        while time.monotonic() < deadline:
            readable, _, _ = select.select([fd], [], [], 0.1)
            if readable:
                try:
                    part = os.read(fd, 65536)
                except OSError:
                    break
                recent.extend(part)
                transcript.extend(part)
                if label.encode() in recent:
                    return
        raise AssertionError(f"PTY未出现 {label}: {bytes(recent)[-3000:]!r}")

    try:
        await_text("按回车了解")
        os.write(fd, b"\r")
        await_text("反安装组件")
        if mode == "empty":
            os.write(fd, b" ")
        else:
            os.write(fd, b"\x1b[B\x1b[B\x1b[B\r ")
            await_text("最终确认")
            time.sleep(0.15)
            calls = fixture.root / "ui.calls"
            assert "--yes" not in calls.read_text()
            if mode == "back":
                os.write(fd, b"\x1b[D")
                await_text("反安装组件")
                time.sleep(0.15)
                os.write(fd, b"\x1b[B\x1b[B\x1b[B\r ")
                await_text("最终确认")
                time.sleep(0.15)
                assert "--yes" not in calls.read_text()
                os.write(fd, b"\x1b[B ")
            else:
                os.write(fd, b" ")
        deadline = time.monotonic() + 10
        result = None
        while time.monotonic() < deadline:
            child, status = os.waitpid(pid, os.WNOHANG)
            if child:
                result = os.waitstatus_to_exitcode(status)
                break
            readable, _, _ = select.select([fd], [], [], 0.1)
            if readable:
                try:
                    transcript.extend(os.read(fd, 65536))
                except OSError:
                    pass
        assert result is not None, "PTY退出超时"
        expected = 0 if mode == "back" else 130
        assert result == expected, f"PTY退出码 {result}，期待 {expected}"
        calls = fixture.root / "ui.calls"
        content = calls.read_text() if calls.exists() else ""
        if mode == "back":
            assert content.count("--uninstall rea --yes") == 1
        else:
            assert "--yes" not in content
    finally:
        fixture.root.joinpath("terminal-transcript.bin").write_bytes(transcript)
        os.close(fd)
        try:
            os.kill(pid, 15)
        except ProcessLookupError:
            pass


def test_terminal_back_and_execute(fixture: Fixture) -> None:
    run_terminal_case(fixture, "back")


def test_terminal_default_cancel(fixture: Fixture) -> None:
    run_terminal_case(fixture, "cancel")


def test_terminal_empty_selection(fixture: Fixture) -> None:
    run_terminal_case(fixture, "empty")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--yes", action="store_true", help="明确授权仅运行隔离夹具")
    parser.add_argument("--case", action="append", default=[], help="只运行指定test_函数名或省略test_前缀的名称")
    args = parser.parse_args()
    print("新系统配置后端隔离测试：临时 HOME、假 npm/brew，不操作本机包管理器。")
    if not args.yes:
        parser.error("需要 --yes；未创建测试目录")
    source = Path(__file__).resolve().parents[2] / "【MacOS】环境管理后端.command"
    print(f"受测业务源 SHA256：{hashlib.sha256(source.read_bytes()).hexdigest()}")
    root = Path(tempfile.mkdtemp(prefix="jobs-system-setup-tests."))
    copy = root / "中文 空格/配置包/【MacOS】环境管理后端.command"
    copy.parent.mkdir(parents=True)
    # 屏蔽开发机固定系统候选，保留受测业务，仅让发现落在本轮假提供者内。
    content = source.read_text().replace(
        "folders+=(/opt/homebrew/bin /usr/local/bin)",
        'folders+=("$TEST_ROOT/system-bin")',
    )
    content = content.replace(
        'for candidate in "${JOBS_HOMEBREW_BIN:-}" "$(command -v brew 2>/dev/null)" /opt/homebrew/bin/brew /usr/local/bin/brew "$HOME/.local/homebrew/bin/brew" "$HOME/.homebrew/bin/brew"; do',
        'for candidate in "${JOBS_HOMEBREW_BIN:-}" "$(command -v brew 2>/dev/null)"; do',
    )
    assert "/opt/homebrew/bin/brew /usr/local/bin/brew" not in content
    assert "folders+=(/opt/homebrew/bin /usr/local/bin)" not in content
    content = content.replace("/usr/bin/otool", "otool")
    content = content.replace("/usr/sbin/lsof", "lsof")
    copy.write_text(content)
    tests = [
        test_validation_and_query,
        test_npm_restore,
        test_absent_and_incremental_profile,
        test_modified_content,
        test_modified_profile,
        test_failed_install_cleanup,
        test_failed_binary_cleanup,
        test_preexisting_global,
        test_managed_cli_runtime_broken,
        test_preexisting_global_broken,
        test_untracked_prefix_unready,
        test_existing_support_targets_unready,
        test_brew_receipt_and_shared,
        test_brew_modified,
        test_symlink_and_lock,
        test_private_logs,
        test_homebrew_empty_owned_prefix,
        test_homebrew_added_file_preserved,
        test_env_all_dispatch,
        test_consumer_old_abi_repair,
        test_missing_npm_repair,
        test_engine_upgrade_repair,
        test_new_runtime_visible_and_shared,
        test_network_retry_then_recover,
        test_network_retry_cancel,
        test_permission_no_retry,
        test_healthy_repeat_and_readonly_no_heal,
        test_cooperative_stop_file,
        test_transaction_lock_survives_subshells,
        test_pinned_runtime_in_new_process,
        test_ruby_and_git_lfs_auto_prepare,
        test_clt_request_once_then_continue,
        test_old_ruby_error_does_not_trigger_repair,
        test_direct_selected_node_heals_provider,
        test_healthy_ruby_incompatible_uses_parallel,
        test_busy_provider_wait_then_recheck,
        test_shared_global_npm_preserved,
        test_foreign_global_npm_not_overwritten,
        test_alias_ruby_is_not_independent,
        test_alias_node_is_not_independent,
        test_existing_managed_engine_is_checked,
        test_real_node_npm_semver_shapes,
        test_tree_digest_batch_compatible,
        test_terminal_back_and_execute,
        test_terminal_default_cancel,
        test_terminal_empty_selection,
    ]
    if args.case:
        selected=set(args.case)
        unknown=selected-{name for test in tests for name in (test.__name__,test.__name__.removeprefix("test_"))}
        if unknown:
            parser.error("未知场景："+", ".join(sorted(unknown)))
        tests=[test for test in tests if test.__name__ in selected or test.__name__.removeprefix("test_") in selected]
    for test in tests:
        case_root = root / test.__name__
        case_root.mkdir()
        fixture = Fixture(case_root, copy)
        test(fixture)
        print(f"PASS {test.__name__}")
    print(f"通过 {len(tests)} 组；现场：{root}")


if __name__ == "__main__":
    main()

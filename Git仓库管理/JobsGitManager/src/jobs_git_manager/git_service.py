"""Git 仓库检查、可复核计划与安全执行；由 Jobs 维护。"""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import signal
import subprocess
import tempfile
import threading
import time
from dataclasses import dataclass, field
from datetime import datetime
from functools import wraps
import sys
from typing import Callable
from urllib.parse import urlsplit


class GitError(RuntimeError):
    """仓库状态不可靠或命令失败；已完成的操作不被冒充为已回滚。"""


class Cancelled(GitError):
    pass


SKIP_DIRS = {'.git', 'node_modules', 'Pods', '.dart_tool', 'build', 'DerivedData',
             '__pycache__', '.venv', 'venv', 'dist', '.pytest_cache'}
BAD_ENV = ('GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_COMMON_DIR')
PENDING = ('MERGE_HEAD', 'CHERRY_PICK_HEAD', 'REVERT_HEAD', 'rebase-apply',
           'rebase-merge', 'BISECT_LOG', 'index.lock', 'config.lock', 'HEAD.lock')
_CONTEXT = threading.local()


def _cancellable(function):
    @wraps(function)
    def wrapped(*args, **kwargs):
        previous = getattr(_CONTEXT, 'cancel', None)
        _CONTEXT.cancel = kwargs.get('cancel') or previous
        try:
            return function(*args, **kwargs)
        finally:
            _CONTEXT.cancel = previous
    return wrapped


def _find_tool(name: str) -> str | None:
    available = shutil.which(name)
    if available:
        return available
    if sys.platform == 'darwin':
        for directory in ('/opt/homebrew/bin', '/usr/local/bin'):
            candidate = Path(directory) / name
            if candidate.is_file() and os.access(candidate, os.X_OK):
                return str(candidate)
    return None


def redact(text: object) -> str:
    """Git 输出可能包含带口令的 URL；界面及日志只使用脱敏版本。"""
    value = str(text)
    value = re.sub(r'([a-zA-Z][a-zA-Z0-9+.-]*://)[^\s/@]+@', r'\1***@', value)
    value = re.sub(r'(?i)([?&](?:token|key|password|secret|access_token)=)[^\s&]+',
                   r'\1***', value)
    return re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', value)


def _environment() -> dict[str, str]:
    for key in BAD_ENV:
        if os.environ.get(key):
            raise GitError(f'{key} overrides the repository; clear it before continuing.')
    env = os.environ.copy()
    env.update(GIT_TERMINAL_PROMPT='0', GCM_INTERACTIVE='never',
               GIT_OPTIONAL_LOCKS='0', LC_ALL='C', LANG='C')
    return env


def _stop_process(proc: subprocess.Popen) -> None:
    if proc.poll() is not None:
        return
    if os.name == 'nt':
        # 只回收本次创建的进程树，不按进程名或端口匹配。
        subprocess.run(['taskkill', '/PID', str(proc.pid), '/T', '/F'],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       creationflags=subprocess.CREATE_NO_WINDOW, check=False)
    else:
        try:
            os.killpg(proc.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
    try:
        proc.wait(timeout=3)
    except subprocess.TimeoutExpired:
        if os.name != 'nt':
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        else:
            proc.kill()
        proc.wait(timeout=3)


def _run(root: Path, args: list[str], *, check=True, cancel=None, log=None,
         timeout=45, executable=None) -> subprocess.CompletedProcess:
    cancel = cancel or getattr(_CONTEXT, 'cancel', None)
    if cancel is not None and cancel.is_set():
        raise Cancelled('Cancelled before starting the next command.')
    binary = executable or _find_tool('git')
    if not binary:
        raise GitError('Git is not available on PATH. Install Git and reopen the panel.')
    command = [binary, *args] if executable else [binary, '-C', str(root), *args]
    if log:
        log(redact('$ ' + subprocess.list2cmdline(command)))
    kwargs = {'start_new_session': True} if os.name != 'nt' else {
        'creationflags': subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.CREATE_NO_WINDOW}
    try:
        proc = subprocess.Popen(command, cwd=root, env=_environment(),
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, **kwargs)
    except OSError as exc:
        raise GitError(redact(exc)) from exc
    # 读者线程持续排空管道，长克隆不会因管道填满而卡死。
    chunks: list[bytes] = []
    def collect():
        while True:
            data = proc.stdout.read1(4096)
            if not data:
                break
            chunks.append(data)
            if log:
                log(redact(data.decode('utf-8', errors='replace').rstrip()))
    reader = threading.Thread(target=collect, daemon=True)
    reader.start()
    started = time.monotonic()
    reason = None
    while proc.poll() is None:
        if cancel is not None and cancel.is_set():
            reason = 'cancel'
            break
        if time.monotonic() - started > timeout:
            reason = 'timeout'
            break
        time.sleep(0.01)
    if reason:
        _stop_process(proc)
    reader.join(timeout=5)
    proc.stdout.close()
    output = b''.join(chunks).decode('utf-8', errors='surrogateescape')
    if reason == 'cancel':
        raise Cancelled('Cancelled. Completed steps remain; inspect the log and repository.')
    if reason == 'timeout':
        raise GitError(f'Command timed out after {timeout}s. Completed steps remain.')
    result = subprocess.CompletedProcess(command, proc.returncode, output, '')
    if check and result.returncode:
        raise GitError(redact(f'Git exited {result.returncode}: {output.strip()}'))
    return result


def _git(root: Path, *args: str, **kwargs) -> str:
    return _run(root, list(args), **kwargs).stdout.rstrip('\n')


def _optional(root: Path, *args: str) -> str:
    result = _run(root, list(args), check=False)
    return result.stdout.rstrip('\n') if result.returncode == 0 else ''


def _digest(path: Path) -> str:
    if path.is_symlink():
        raise GitError(f'Refusing symlink metadata: {path}')
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else '-'


def _repo_root(root: str | Path) -> Path:
    path = Path(root).expanduser().resolve()
    if not path.is_dir():
        raise GitError(f'Repository directory does not exist: {path}')
    actual = Path(_git(path, 'rev-parse', '--show-toplevel')).resolve()
    if actual != path:
        raise GitError(f'Select the actual repository root: {actual}')
    if (path / '.git').is_symlink():
        raise GitError('The .git marker is a symlink; refusing this repository.')
    return path


def _gitdir(root: Path) -> Path:
    return Path(_git(root, 'rev-parse', '--absolute-git-dir')).resolve()


def _guard(root: Path) -> Path:
    gitdir = _gitdir(root)
    common = Path(_git(root, 'rev-parse', '--git-common-dir'))
    if not common.is_absolute():
        common = root / common
    if common.resolve() != gitdir:
        raise GitError(f'Linked worktrees require separate handling: {root}')
    for name in PENDING:
        if (gitdir / name).exists():
            raise GitError(f'Unfinished Git operation or lock: {root} / {name}')
    for item in (root / '.gitmodules', gitdir / 'index', gitdir / 'config',
                 gitdir / 'modules'):
        if item.is_symlink():
            raise GitError(f'Refusing symlink metadata: {item}')
    if (root / '.gitmodules').exists() and not (root / '.gitmodules').is_file():
        raise GitError('.gitmodules must be a regular file.')
    if _git(root, 'ls-files', '--unmerged'):
        raise GitError(f'Unresolved index conflicts: {root}')
    return gitdir


def _safe_child(root: Path, value: str) -> Path:
    if (not value or value.startswith('-') or '\\' in value or ':' in value
            or any(ord(c) < 32 for c in value)):
        raise GitError(f'Unsafe submodule path: {value!r}')
    parsed = PurePosixPath(value)
    if parsed.is_absolute() or str(parsed) != value or any(
            p in ('.', '..') or p.casefold() == '.git' for p in parsed.parts):
        raise GitError(f'Unsafe submodule path: {value!r}')
    candidate = root
    for position, part in enumerate(parsed.parts):
        candidate /= part
        if candidate.is_symlink():
            raise GitError(f'Submodule paths must not follow symlinks: {candidate}')
        if position < len(parsed.parts) - 1 and (candidate / '.git').exists():
            raise GitError(f'Submodule path crosses another repository: {value}')
    if not candidate.resolve().is_relative_to(root):
        raise GitError(f'Submodule path escapes the repository: {value}')
    return candidate


def _config_records(root: Path, file: Path) -> list[tuple[str, str]]:
    if not file.exists():
        return []
    raw = _git(root, 'config', '--null', '--no-includes', '--file', str(file), '--list')
    result = []
    for record in raw.split('\0'):
        if not record:
            continue
        key, sep, value = record.partition('\n')
        result.append((key, value if sep else ''))
    return result


def _modules(root: Path) -> dict[str, dict]:
    sections: dict[str, dict] = {}
    for key, value in _config_records(root, root / '.gitmodules'):
        match = re.fullmatch(r'submodule\.(.+)\.(path|url|branch)', key)
        if not match:
            continue
        name, attr = match.groups()
        parsed_name = PurePosixPath(name)
        if (any(ord(c) < 32 for c in name) or name.startswith('-')
                or '\\' in name or ':' in name or parsed_name.is_absolute()
                or str(parsed_name) != name or '..' in parsed_name.parts):
            raise GitError(f'Unsafe submodule section: {name!r}')
        item = sections.setdefault(name, {'name': name})
        if attr in item:
            raise GitError(f'Duplicate submodule field: {key}')
        item[attr] = value
    result = {}
    normalized = set()
    for item in sections.values():
        if 'path' not in item:
            raise GitError(f'Submodule section lacks a path: {item["name"]}')
        path = item['path']
        _safe_child(root, path)
        key = path.casefold()
        if key in normalized:
            raise GitError(f'Duplicate submodule path: {path}')
        normalized.add(key)
        result[path] = item
    for path in result:
        if any(path.startswith(other + '/') for other in result if other != path):
            raise GitError(f'Overlapping submodule paths: {path}')
    return result


def _actual_child(child: Path) -> bool:
    if not (child / '.git').exists():
        return False
    return Path(_git(child, 'rev-parse', '--show-toplevel')).resolve() == child.resolve()


def _check_child_metadata(parent: Path, child: Path) -> None:
    if not _actual_child(child):
        return
    _guard(child)
    if (child / '.git').is_file():
        metadata = _gitdir(child)
        base = _gitdir(parent) / 'modules'
        if not metadata.is_relative_to(base.resolve()):
            raise GitError(f'Child Git pointer targets external metadata: {child}')
        cursor = base
        for part in metadata.relative_to(base.resolve()).parts:
            cursor /= part
            if cursor.is_symlink():
                raise GitError(f'Child Git metadata follows a symlink: {cursor}')


def _discover(root: Path) -> set[str]:
    result = set()
    for current, folders, _files in os.walk(root, followlinks=False):
        here = Path(current)
        folders[:] = sorted(f for f in folders if f not in SKIP_DIRS
                            and not f.startswith('.') and not (here / f).is_symlink())
        if here == root:
            continue
        if (here / '.git').exists():
            if not _actual_child(here):
                raise GitError(f'Invalid nested repository marker: {here}')
            value = here.relative_to(root).as_posix()
            _safe_child(root, value)
            result.add(value)
            folders[:] = []
    return result


def _select_remote(root: Path, parent: Path | None = None) -> str:
    """按Git配置选择线路；不以平台名白名单或固定origin替代实际配置。"""
    remotes = _git(root, 'remote').splitlines()
    branch = _optional(root, 'symbolic-ref', '--short', 'HEAD')
    upstream = _optional(root, 'config', '--get', f'branch.{branch}.remote') if branch else ''
    if upstream in remotes:
        return upstream
    if upstream:
        raise GitError(f'Configured branch remote is not an external remote: {upstream} ({root})')
    if 'origin' in remotes:
        return 'origin'
    if len(remotes) == 1:
        return remotes[0]
    if parent is not None:
        try:
            preferred = _select_remote(parent)
        except GitError:
            preferred = ''
        if preferred in remotes:
            return preferred
    if not remotes:
        raise GitError(f'No Git remote is configured: {root}')
    raise GitError(f'Ambiguous Git remotes ({", ".join(remotes)}): configure the branch upstream first: {root}')


def _remote_url(root: Path, parent: Path | None = None) -> tuple[str, str]:
    name = _select_remote(root, parent)
    return name, _git(root, 'remote', 'get-url', name)


@_cancellable
def inspect_repo(root: str | Path, cancel=None) -> list[dict]:
    """只读扫描；普通中间目录会穿透，实际子 Git 工作树是本层边界。"""
    root = _repo_root(root)
    _guard(root)
    modules = _modules(root)
    paths = set(modules) | _discover(root)
    rows = []
    for path in sorted(paths, key=str.casefold):
        child = _safe_child(root, path)
        entry = modules.get(path, {})
        initialized = _actual_child(child)
        head = _optional(child, 'rev-parse', '--verify', 'HEAD') if initialized else ''
        branch = entry.get('branch', '')
        if not branch and initialized:
            branch = _optional(child, 'symbolic-ref', '--short', 'HEAD')
        url = entry.get('url', '')
        if not url and initialized:
            try:
                _remote, url = _remote_url(child, root)
            except GitError:
                url = ''
        dirty = bool(_git(child, 'status', '--porcelain=v1', '--untracked-files=normal')) if initialized else False
        status = ('unregistered' if path not in modules else
                  'missing' if not initialized else 'empty' if not head else
                  'dirty' if dirty else 'clean')
        rows.append(dict(path=path, name=entry.get('name', path), url=redact(url),
                         branch=branch, head=head, status=status,
                         registered=path in modules, dirty=dirty))
    return rows


def _snapshot(root: Path, paths: tuple[str, ...], recursive=False) -> str:
    roots = [root]
    for path in paths:
        child = _safe_child(root, path)
        if _actual_child(child):
            roots.append(child)
    visited = set()
    states = []
    while roots:
        here = roots.pop(0)
        if here in visited:
            continue
        visited.add(here)
        gitdir = _guard(here)
        record = [str(here), str(gitdir)]
        record += [_digest(p) for p in (here / '.gitmodules', gitdir / 'index',
                                       gitdir / 'config', gitdir / 'HEAD')]
        record += [_optional(here, 'rev-parse', '--verify', 'HEAD'),
                   _git(here, 'for-each-ref', '--format=%(refname) %(objectname)'),
                   _git(here, 'status', '--porcelain=v1', '--untracked-files=normal')]
        if (here / '.git').is_file():
            record.append(_digest(here / '.git'))
        states.append(record)
        if recursive and here != root:
            for subpath in _modules(here):
                sub = _safe_child(here, subpath)
                if _actual_child(sub):
                    roots.append(sub)
    return hashlib.sha256(json.dumps(states, ensure_ascii=True).encode()).hexdigest()


@dataclass(frozen=True)
class Plan:
    root: Path
    action: str
    paths: tuple[str, ...]
    recursive: bool
    remote: bool
    steps: tuple[str, ...]
    snapshot: str
    entries: dict = field(repr=False)

    @property
    def text(self) -> str:
        return '\n'.join((f'Repository: {self.root}', f'Action: {self.action}',
                          'No commit / push / reset / clean.', '', *self.steps))

    def describe(self) -> str:
        return self.text


def _index_entries(root: Path, path: str) -> list[tuple[str, str, str, str]]:
    raw = _git(root, 'ls-files', '--stage', '-z', '--', ':(literal)' + path)
    result = []
    for entry in raw.split('\0'):
        if entry:
            info, name = entry.split('\t', 1)
            mode, sha, stage = info.split(' ')
            result.append((mode, sha, stage, name))
    return result


def _validate_url(url: str) -> None:
    if not url or url.startswith('-') or any(ord(c) < 32 for c in url):
        raise GitError('A valid existing remote URL is required for registration.')
    if re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*::', url):
        raise GitError('External Git remote helper URLs are not supported by this panel.')


def _hosted_parts(url: str):
    if '://' in url:
        p = urlsplit(url)
        if not p.hostname:
            return None
        return (p.scheme, p.hostname.lower(), p.port), p.path.strip('/')
    m = re.fullmatch(r'(?:[^/@:]+@)?([^/:]+):(.+)', url)
    if m:
        return ('scp', m[1].lower(), None), m[2].strip('/')
    return None


def _registration_url(root: Path, child: Path, url: str) -> str:
    """仅在所有父子线路均能证明为同 namespace 兄弟仓时相对化。"""
    parents = [_hosted_parts(v) for k, v in _config_records(root, _gitdir(root) / 'config')
               if re.fullmatch(r'remote\..+\.url', k)]
    children = [_hosted_parts(v) for k, v in _config_records(child, _gitdir(child) / 'config')
                if re.fullmatch(r'remote\..+\.url', k)]
    if not parents or not children or not all(parents + children):
        return url
    def endpoint(item):
        host, path = item
        namespace, _, repo = path.rpartition('/')
        return host, namespace, repo.removesuffix('.git')
    pparts = [endpoint(v) for v in parents]
    cparts = [endpoint(v) for v in children]
    names = {v[2] for v in cparts}
    if len(names) == 1 and {(v[0], v[1]) for v in pparts} == {(v[0], v[1]) for v in cparts}:
        return '../' + next(iter(names)) + '.git'
    return url


def _download_preflight(root: Path, paths: tuple[str, ...], recursive: bool, *, allow_toc=False,
                        ignore_nested=False):
    for path in paths:
        child = _safe_child(root, path)
        if _actual_child(child):
            _check_child_metadata(root, child)
            configured_toc = allow_toc and bool(_optional(
                child, 'config', '--get', 'filter.jobs-markdown-toc.smudge'))
            status_args = ['status', '--porcelain=v1', '--untracked-files=normal']
            if recursive or ignore_nested:
                status_args.append('--ignore-submodules=all')
            if _git(child, *status_args) and not configured_toc:
                raise GitError(f'Local changes must be preserved; download blocked: {path}')
            if recursive:
                _download_preflight(child, tuple(_modules(child)), True, allow_toc=allow_toc)
        elif child.exists() and (not child.is_dir() or any(child.iterdir())):
            raise GitError(f'Uninitialized submodule path is not empty: {path}')


@_cancellable
def build_plan(root: str | Path, action: str, paths, recursive=True, remote=True, cancel=None) -> Plan:
    root = _repo_root(root)
    _guard(root)
    if action not in ('download', 'align', 'register'):
        raise GitError(f'Unknown operation: {action}')
    selected = tuple(sorted(set(paths), key=str.casefold))
    if not selected:
        raise GitError('Select at least one repository.')
    rows = {row['path']: row for row in inspect_repo(root)}
    modules = _modules(root)
    entries = {}
    steps = []
    if action == 'download':
        steps.append('Restore + verify configured Markdown TOC before and after each repository; unconfigured: skip.')
        steps.append('Remote branch latest (fast-forward only).' if remote else 'Parent gitlink revision (no rollback).')
        if recursive:
            steps.append('Recurse through registered descendants, including newly downloaded .gitmodules; apply the same safety checks.')
    for path in selected:
        child = _safe_child(root, path)
        if path not in rows:
            raise GitError(f'Repository disappeared or was not discovered: {path}')
        row = rows[path]
        if action == 'download':
            if path not in modules:
                raise GitError(f'Register this repository before downloading: {path}')
            _validate_url(modules[path].get('url', ''))
            entries[path] = modules[path].copy()
            source = modules[path]['url']
            remote_name = '(initialize from parent configuration)'
            if _actual_child(child) and remote:
                remote_name, source = _remote_url(child, root)
                entries[path]['remote'] = remote_name
            entries[path]['remote_name'] = remote_name
            entries[path]['source_url'] = redact(source)
            steps.append(f'Download {path} | remote={remote_name} | branch={modules[path].get("branch", "remote HEAD")} | source={redact(source)}')
            continue
        if not _actual_child(child) or not row['head']:
            raise GitError(f'An initialized child with a committed HEAD is required: {path}')
        _check_child_metadata(root, child)
        existing = _index_entries(root, path)
        if any(mode != '160000' or name != path or stage != '0'
               for mode, sha, stage, name in existing):
            raise GitError(f'Parent already tracks ordinary files or conflicts at {path}; resolve explicitly first.')
        if action == 'align':
            if path not in modules:
                raise GitError(f'Register this repository before aligning its gitlink: {path}')
            entries[path] = {'head': row['head']}
            old = existing[0][1] if existing else '(absent)'
            steps.append(f'INDEX only: {path} 160000 {old} -> {row["head"]}')
        else:
            if path in modules:
                raise GitError(f'Already registered; use alignment for this repository: {path}')
            _remote_name, url = _remote_url(child, root)
            _validate_url(url)
            url = _registration_url(root, child, url)
            name = path
            if any(v['name'] == name for v in modules.values()):
                raise GitError(f'Submodule section already exists: {name}')
            entries[path] = dict(name=name, path=path, url=url,
                                 branch=_optional(child, 'symbolic-ref', '--short', 'HEAD'),
                                 head=row['head'])
            steps.append(f'.gitmodules: add [{name}] path={path} url={redact(url)} branch={entries[path]["branch"] or "(unset)"}')
            steps.append(f'INDEX: add gitlink {path} 160000 {row["head"]}; .gitmodules remains unstaged.')
            steps.append(f'LOCAL config: init {path}; preserve child remote and branch.')
            if (child / '.git').is_dir():
                target = _gitdir(root) / 'modules' / name
                if target.exists():
                    raise GitError(f'Metadata target already exists; preserve and inspect manually: {target}')
                steps.append(f'METADATA: git submodule absorbgitdirs -- {path}')
            else:
                raise GitError(f'An independent .git directory is required for registration: {path}')
    if action == 'download':
        # 已配置TOC由执行阶段恢复，计划只允许该工具清单造成的差异；普通脏仓仍阻断。
        _download_preflight(root, selected, bool(recursive), allow_toc=True)
    if action == 'register':
        tracked = _run(root, ['ls-files', '--error-unmatch', '--', '.gitmodules'], check=False)
        if tracked.returncode == 0 and _run(root, ['diff', '--quiet', '--', '.gitmodules'], check=False).returncode:
            raise GitError('.gitmodules has unstaged changes; preserve its staging boundary before registration.')
    steps.append('Before writes: recheck preview snapshot and back up .gitmodules, index and local config.')
    return Plan(root, action, selected, bool(recursive), bool(remote), tuple(steps),
                _snapshot(root, selected, bool(recursive)), entries)


def _backup(plan: Plan) -> Path:
    gitdir = _gitdir(plan.root)
    base = gitdir / 'jobs-git-manager-backups'
    if base.is_symlink():
        raise GitError('Backup directory must not be a symlink.')
    base.mkdir(mode=0o700, exist_ok=True)
    target = Path(tempfile.mkdtemp(prefix=datetime.now().strftime('%Y%m%d-%H%M%S-'), dir=base))
    files = [('parent-gitmodules', plan.root / '.gitmodules'),
             ('parent-index', gitdir / 'index'), ('parent-config', gitdir / 'config')]
    children = [_safe_child(plan.root, path) for path in plan.paths]
    visited = set()
    i = 0
    while children:
        child = children.pop(0)
        if child in visited:
            continue
        visited.add(child)
        if _actual_child(child):
            cgit = _gitdir(child)
            files += [(f'child-{i}-gitmodules', child / '.gitmodules'),
                      (f'child-{i}-config', cgit / 'config'),
                      (f'child-{i}-index', cgit / 'index')]
            if (child / '.git').is_file():
                files.append((f'child-{i}-git-pointer', child / '.git'))
            if plan.recursive:
                children += [_safe_child(child, path) for path in _modules(child)]
            i += 1
    manifest = []
    for name, source in files:
        digest = _digest(source)
        manifest.append(dict(source=str(source), saved=name, sha256=digest))
        if source.is_file():
            destination = target / name
            shutil.copyfile(source, destination)
            destination.chmod(0o600)
    (target / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    (target / 'manifest.json').chmod(0o600)
    return target


def _toc(root: Path, log, cancel):
    configured = _optional(root, 'config', '--get', 'filter.jobs-markdown-toc.smudge')
    if not configured or configured.strip() in ('cat', 'false', ':'):
        log(f'TOC: skip (not configured): {root}')
        return
    process = _optional(root, 'config', '--get', 'filter.jobs-markdown-toc.process')
    if process:
        raise GitError(f'Conflicting TOC process filter: {root}')
    helper = root / '.jobs-markdown-toc' / 'MarkdownToc.mjs'
    if helper.is_symlink() or not helper.is_file():
        raise GitError(f'Configured TOC helper is missing or unsafe: {helper}')
    node = _find_tool('node')
    if not node:
        raise GitError(f'Node is required for the configured TOC filter: {root}')
    _guard(root)
    index = _index_semantics(root)
    head = _optional(root, 'rev-parse', '--verify', 'HEAD')
    for operation in ('restore', 'verify'):
        _run(root, [str(helper), operation], executable=node, log=log, cancel=cancel, timeout=120)
    if index != _index_semantics(root) or head != _optional(root, 'rev-parse', '--verify', 'HEAD'):
        raise GitError(f'TOC helper unexpectedly changed the index or HEAD: {root}')


def _index_semantics(root: Path) -> tuple[str, str]:
    # 两种标记分别覆盖assume-unchanged / skip-worktree与fsmonitor，忽略合法stat刷新。
    return (_git(root, 'ls-files', '--stage', '-v', '-z'),
            _git(root, 'ls-files', '--stage', '-f', '-z'))


def _restore_loaded_tree(root: Path, recursive: bool, log, cancel):
    _toc(root, log, cancel)
    if recursive:
        for path in _modules(root):
            child = _safe_child(root, path)
            if _actual_child(child):
                _check_child_metadata(root, child)
                _restore_loaded_tree(child, True, log, cancel)


def _download_one(parent: Path, path: str, remote: bool, recursive: bool, log, cancel):
    _guard(parent)
    item = _modules(parent)[path]
    _validate_url(item.get('url', ''))
    child = _safe_child(parent, path)
    if _actual_child(child):
        _restore_loaded_tree(child, recursive, log, cancel)
    _download_preflight(parent, (path,), recursive, ignore_nested=recursive)
    indexed = _index_entries(parent, path)
    if not indexed or indexed[0][0] != '160000':
        raise GitError(f'Missing parent gitlink: {path}; align before downloading.')
    initialized = _actual_child(child)
    log(f'Source: {path} | .gitmodules URL={redact(item["url"])} | branch={item.get("branch", "remote HEAD")}')
    if not initialized:
        args = ['-c', 'submodule.recurse=false', 'submodule', 'update', '--init', '--checkout', '--', ':(literal)' + path]
        _run(parent, args, log=log, cancel=cancel, timeout=900)
        if not _actual_child(child):
            raise GitError(f'Submodule initialization did not produce a repository: {path}')
    _check_child_metadata(parent, child)
    _toc(child, log, cancel)
    status_args = ['status', '--porcelain=v1', '--untracked-files=normal']
    if recursive:
        status_args.append('--ignore-submodules=all')
    if _git(child, *status_args):
        raise GitError(f'Local changes must be preserved; download blocked: {path}')
    if remote:
        branch = item.get('branch', '')
        if branch == '.':
            branch = _optional(parent, 'symbolic-ref', '--short', 'HEAD')
            if not branch:
                raise GitError(f'Parent HEAD is detached; branch="." cannot be resolved: {path}')
        remote_name = _select_remote(child, parent)
        if remote_name == '.' or remote_name.startswith('-'):
            raise GitError(f'Unsupported branch remote: {remote_name}')
        source = _git(child, 'remote', 'get-url', remote_name)
        log(f'Fetch: {path} | remote={remote_name} | URL={redact(source)} | branch={branch or "remote HEAD"}')
        args = ['fetch', '--no-recurse-submodules', remote_name]
        if branch:
            if _run(child, ['check-ref-format', 'refs/heads/' + branch], check=False).returncode:
                raise GitError(f'Unsafe or invalid branch: {branch}')
            args.append('refs/heads/' + branch)
        else:
            args.append('HEAD')
        _run(child, args, log=log, cancel=cancel, timeout=900)
        target = _git(child, 'rev-parse', '--verify', 'FETCH_HEAD^{commit}')
    else:
        target = indexed[0][1]
        if _run(child, ['cat-file', '-e', target + '^{commit}'], check=False).returncode:
            remote_name = _select_remote(child, parent)
            _run(child, ['fetch', '--no-recurse-submodules', remote_name, target],
                 log=log, cancel=cancel, timeout=900)
    head = _git(child, 'rev-parse', '--verify', 'HEAD')
    if head != target:
        if _run(child, ['merge-base', '--is-ancestor', head, target], check=False).returncode:
            raise GitError(f'Local commits or divergence preserved; cannot fast-forward {path}. Current={head}, requested={target}')
        if _optional(child, 'symbolic-ref', '--short', 'HEAD'):
            _run(child, ['-c', 'core.hooksPath=' + os.devnull, '-c', 'submodule.recurse=false',
                         'merge', '--ff-only', target], log=log, cancel=cancel)
        else:
            _run(child, ['-c', 'core.hooksPath=' + os.devnull, '-c', 'submodule.recurse=false',
                         'checkout', '--detach', target], log=log, cancel=cancel)
    _toc(child, log, cancel)
    if recursive:
        for subpath in _modules(child):
            _download_one(child, subpath, remote, True, log, cancel)
    log(f'Completed: {path} | HEAD={_git(child, "rev-parse", "HEAD")}')


def execute_plan(plan: Plan, log: Callable[[str], None] | None = None,
                 cancel: threading.Event | None = None) -> dict:
    """只执行已预览的计划；失败保留精确备份和实际已完成步骤供复核。"""
    log = log or (lambda _message: None)
    original_log = log
    log = lambda message: original_log(redact(message))
    if cancel is not None and cancel.is_set():
        raise Cancelled('Cancelled before changing the repository.')
    root = _repo_root(plan.root)
    if plan.snapshot != _snapshot(root, plan.paths, plan.recursive):
        raise GitError('Repository changed after preview. Refresh and create a new plan.')
    backup = _backup(plan)
    log(f'Backup: {backup}')
    gitdir = _gitdir(root)
    lock = gitdir / 'jobs-git-manager.lock'
    try:
        fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    except FileExistsError as exc:
        raise GitError(f'Another panel operation is active: {lock}') from exc
    completed = []
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as stream:
            stream.write(str(os.getpid()))
        # 备份期间发生的编辑也会使确认失效；不按旧计划覆盖。
        if plan.snapshot != _snapshot(root, plan.paths, plan.recursive):
            raise GitError('Repository changed while creating the backup; create a new plan.')
        if plan.action == 'download':
            _toc(root, log, cancel)
        for path in plan.paths:
            if cancel is not None and cancel.is_set():
                raise Cancelled('Cancelled. Completed steps remain; inspect the repository.')
            _guard(root)
            item = plan.entries[path]
            if plan.action == 'download':
                _download_one(root, path, plan.remote, plan.recursive, log, cancel)
            elif plan.action == 'align':
                _run(root, ['update-index', '--add', '--cacheinfo', '160000', item['head'], path],
                     log=log, cancel=cancel)
            else:
                # 原文件复制到同目录临时文件，通过 git config 只增量补新字段。
                temporary = root / ('.gitmodules.jobs-' + str(os.getpid()))
                if temporary.exists() or temporary.is_symlink():
                    raise GitError(f'Temporary config already exists: {temporary}')
                original = root / '.gitmodules'
                try:
                    temporary.write_bytes(original.read_bytes() if original.exists() else b'')
                    for attr in ('path', 'url', 'branch'):
                        if item.get(attr):
                            _run(root, ['config', '--file', str(temporary),
                                        f'submodule.{item["name"]}.{attr}', item[attr]], log=log, cancel=cancel)
                    os.replace(temporary, original)
                finally:
                    if temporary.is_file():
                        temporary.unlink()
                _run(root, ['update-index', '--add', '--cacheinfo', '160000', item['head'], path],
                     log=log, cancel=cancel)
                _run(root, ['submodule', 'init', '--', ':(literal)' + path], log=log, cancel=cancel)
                _run(root, ['submodule', 'absorbgitdirs', '--', ':(literal)' + path], log=log, cancel=cancel)
            completed.append(path)
        if plan.action == 'download':
            _toc(root, log, cancel)
        log(f'Completed {len(completed)} repositories. No commit or push. Backup: {backup}')
        return {'completed': completed, 'backup': str(backup)}
    except Exception:
        log(f'Failed/cancelled; completed={completed}. No automatic rollback. Backup: {backup}')
        raise
    finally:
        lock.unlink(missing_ok=True)

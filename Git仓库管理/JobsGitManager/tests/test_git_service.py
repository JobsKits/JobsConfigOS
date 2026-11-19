"""隔离临时仓库验证；不访问外网或用户仓库。"""
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[1] / 'src'
sys.path.insert(0, str(SOURCE))
from jobs_git_manager.git_service import (Cancelled, GitError, build_plan,
                                         execute_plan, inspect_repo, redact)
from jobs_git_manager import git_service


def git(root, *args, check=True):
    env = os.environ.copy()
    env.update(GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull,
               GIT_AUTHOR_NAME='Fixture', GIT_AUTHOR_EMAIL='fixture@example.invalid',
               GIT_COMMITTER_NAME='Fixture', GIT_COMMITTER_EMAIL='fixture@example.invalid')
    return subprocess.run(['git', '-C', str(root), *args], env=env, capture_output=True,
                          text=True, check=check).stdout.strip()


def create_repo(path):
    path.mkdir(parents=True)
    git(path, 'init', '-b', 'main')
    (path / 'README.md').write_text('fixture\n', encoding='utf-8')
    git(path, 'add', 'README.md')
    git(path, 'commit', '-m', 'initial')
    return path


class GitServiceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='Jobs Git 中文 ')
        self.base = Path(self.temp.name).resolve()
        self.env = patch.dict(os.environ, {'GIT_CONFIG_NOSYSTEM': '1',
                                           'GIT_CONFIG_GLOBAL': os.devnull})
        self.env.start()
        self.root = create_repo(self.base / 'parent 仓库')

    def tearDown(self):
        self.env.stop()
        self.temp.cleanup()

    def child(self, name='group/child 子仓', remote='https://git.example/team/child.git'):
        path = create_repo(self.root / name)
        if remote:
            git(path, 'remote', 'add', 'origin', remote)
        return path

    def register(self, child):
        path = child.relative_to(self.root).as_posix()
        plan = build_plan(self.root, 'register', [path])
        execute_plan(plan)
        return path

    def test_empty_and_actual_root(self):
        self.assertEqual(inspect_repo(self.root), [])
        with self.assertRaises(GitError):
            build_plan(self.root, 'align', [])
        ordinary = self.root / 'ordinary'
        ordinary.mkdir()
        with self.assertRaises(GitError):
            inspect_repo(ordinary)

    def test_nested_discovery_and_registration(self):
        child = self.child()
        nested = self.child('group/child 子仓/nested', remote='https://git.example/team/nested.git')
        # 真正子Git边界内的孙仓不在本层重复登记。
        rows = inspect_repo(self.root)
        self.assertEqual([r['path'] for r in rows], ['group/child 子仓'])
        self.assertEqual(rows[0]['status'], 'unregistered')
        head = git(child, 'rev-parse', 'HEAD')
        path = self.register(child)
        self.assertTrue((child / '.git').is_file())
        self.assertEqual(git(child, 'remote', 'get-url', 'origin'), 'https://git.example/team/child.git')
        self.assertEqual(git(child, 'rev-parse', 'HEAD'), head)
        self.assertIn('160000 ' + head, git(self.root, 'ls-files', '--stage', path))
        self.assertEqual(git(self.root, '-c', 'core.quotePath=false', 'diff', '--cached', '--name-only'), path)
        self.assertNotIn('.gitmodules', git(self.root, 'diff', '--cached', '--name-only'))
        self.assertTrue(inspect_repo(self.root)[0]['registered'])
        self.assertTrue(nested.exists())

    def test_register_many_and_preserve_staged_content(self):
        first, second = self.child('one'), self.child('two')
        (self.root / 'README.md').write_text('staged edit\n', encoding='utf-8')
        git(self.root, 'add', 'README.md')
        before = git(self.root, 'show', ':README.md')
        plan = build_plan(self.root, 'register', ['one', 'two'])
        self.assertIn('absorbgitdirs', plan.text)
        result = execute_plan(plan)
        self.assertEqual(result['completed'], ['one', 'two'])
        self.assertEqual(git(self.root, 'show', ':README.md'), before)
        backup = Path(result['backup'])
        self.assertTrue((backup / 'parent-index').is_file())
        self.assertTrue((backup / 'manifest.json').is_file())
        self.assertEqual(len(inspect_repo(self.root)), 2)

    def test_relative_url_proven_on_all_endpoints(self):
        git(self.root, 'remote', 'add', 'origin', 'ssh://git@git.example:2222/a/team/parent.git')
        child = self.child('one', 'ssh://git@git.example:2222/a/team/real-name.git')
        plan = build_plan(self.root, 'register', ['one'])
        self.assertEqual(plan.entries['one']['url'], '../real-name.git')
        git(child, 'remote', 'add', 'other', 'https://other.example/team/renamed.git')
        plan = build_plan(self.root, 'register', ['one'])
        self.assertEqual(plan.entries['one']['url'], 'ssh://git@git.example:2222/a/team/real-name.git')

    def test_align_changes_only_requested_gitlink(self):
        child = self.child('one')
        self.register(child)
        git(self.root, 'add', '.gitmodules')
        git(self.root, 'commit', '-m', 'registered')
        (child / 'new.txt').write_text('child change\n', encoding='utf-8')
        git(child, 'add', 'new.txt')
        git(child, 'commit', '-m', 'next')
        head = git(child, 'rev-parse', 'HEAD')
        (self.root / 'README.md').write_text('preserve stage\n', encoding='utf-8')
        git(self.root, 'add', 'README.md')
        before = git(self.root, 'show', ':README.md')
        execute_plan(build_plan(self.root, 'align', ['one']))
        self.assertIn(head, git(self.root, 'ls-files', '--stage', 'one'))
        self.assertEqual(git(self.root, 'show', ':README.md'), before)
        self.assertEqual(git(child, 'branch', '--show-current'), 'main')

    def test_stale_plan_refuses_write(self):
        child = self.child('one')
        plan = build_plan(self.root, 'register', ['one'])
        (self.root / 'README.md').write_text('concurrent\n', encoding='utf-8')
        with self.assertRaisesRegex(GitError, 'changed after preview'):
            execute_plan(plan)
        self.assertFalse((self.root / '.gitmodules').exists())
        self.assertTrue((child / '.git').is_dir())

    def test_parent_regular_files_are_not_replaced(self):
        child = self.child('one')
        git(self.root, 'update-index', '--add', '--cacheinfo', '100644',
            git(self.root, 'rev-parse', 'HEAD:README.md'), 'one/tracked.txt')
        with self.assertRaisesRegex(GitError, 'ordinary files'):
            build_plan(self.root, 'register', ['one'])

    def test_no_url_refuses_registration(self):
        self.child('one', remote='')
        with self.assertRaisesRegex(GitError, 'No Git remote'):
            build_plan(self.root, 'register', ['one'])

    def test_symlink_and_traversal_and_duplicate_mapping_refused(self):
        outside = create_repo(self.base / 'outside')
        (self.root / 'link').symlink_to(outside, target_is_directory=True)
        self.assertEqual(inspect_repo(self.root), [])
        for path in ('../outside', '/outside', 'link', 'a/../outside', 'C:/outside'):
            with self.subTest(path=path), self.assertRaises(GitError):
                build_plan(self.root, 'register', [path])
        (self.root / '.gitmodules').write_text('[submodule "a"]\n path = same\n url = a\n[submodule "b"]\n path = same\n url = b\n')
        with self.assertRaisesRegex(GitError, 'Duplicate'):
            inspect_repo(self.root)

    def test_unfinished_operation_and_environment_are_refused(self):
        (self.root / '.git' / 'MERGE_HEAD').write_text('pending')
        with self.assertRaisesRegex(GitError, 'Unfinished'):
            inspect_repo(self.root)
        (self.root / '.git' / 'MERGE_HEAD').unlink()
        with patch.dict(os.environ, {'GIT_INDEX_FILE': str(self.base / 'evil')}):
            with self.assertRaisesRegex(GitError, 'GIT_INDEX_FILE'):
                inspect_repo(self.root)

    def test_cancel_before_write(self):
        child = self.child('one')
        plan = build_plan(self.root, 'register', ['one'])
        event = threading.Event()
        event.set()
        with self.assertRaises(Cancelled):
            execute_plan(plan, cancel=event)
        self.assertFalse((self.root / '.gitmodules').exists())

    def test_dirty_download_blocked_without_reset(self):
        child = self.child('one')
        self.register(child)
        (child / 'README.md').write_text('keep me\n', encoding='utf-8')
        with self.assertRaisesRegex(GitError, 'Local changes'):
            build_plan(self.root, 'download', ['one'])
        self.assertEqual((child / 'README.md').read_text(), 'keep me\n')

    def test_local_remote_fast_forward_and_divergence(self):
        origin = create_repo(self.base / 'local origin')
        child = self.root / 'one'
        git(self.root, 'clone', str(origin), str(child))
        self.register(child)
        (origin / 'new.txt').write_text('remote\n')
        git(origin, 'add', 'new.txt')
        git(origin, 'commit', '-m', 'remote next')
        parent_index = (self.root / '.git' / 'index').read_bytes()
        execute_plan(build_plan(self.root, 'download', ['one'], recursive=False, remote=True))
        self.assertEqual(git(child, 'rev-parse', 'HEAD'), git(origin, 'rev-parse', 'HEAD'))
        self.assertEqual((self.root / '.git' / 'index').read_bytes(), parent_index)
        (child / 'local.txt').write_text('local\n')
        git(child, 'add', 'local.txt')
        git(child, 'commit', '-m', 'local only')
        local_head = git(child, 'rev-parse', 'HEAD')
        with self.assertRaisesRegex(GitError, 'Local commits'):
            execute_plan(build_plan(self.root, 'download', ['one'], recursive=False, remote=True))
        self.assertEqual(git(child, 'rev-parse', 'HEAD'), local_head)

    def test_missing_checkout_initializes_from_local_gitlink(self):
        origin = create_repo(self.base / 'local origin')
        git(self.root, 'config', '--file', '.gitmodules', 'submodule.one.path', 'one')
        git(self.root, 'config', '--file', '.gitmodules', 'submodule.one.url', str(origin))
        git(self.root, 'config', '--file', '.gitmodules', 'submodule.one.branch', 'main')
        git(self.root, 'update-index', '--add', '--cacheinfo', '160000', git(origin, 'rev-parse', 'HEAD'), 'one')
        plan = build_plan(self.root, 'download', ['one'], remote=False)
        with patch.dict(os.environ, {'GIT_CONFIG_COUNT': '1', 'GIT_CONFIG_KEY_0': 'protocol.file.allow',
                                     'GIT_CONFIG_VALUE_0': 'always'}):
            execute_plan(plan)
        self.assertEqual(git(self.root / 'one', 'rev-parse', 'HEAD'), git(origin, 'rev-parse', 'HEAD'))

    def test_redaction(self):
        value = redact('https://person:password@git.example/team/repo?token=secret&x=1')
        self.assertNotIn('password', value)
        self.assertNotIn('secret', value)
        self.assertIn('git.example', value)

    def test_pin_will_not_discard_new_local_commit(self):
        child = self.child('one')
        self.register(child)
        (child / 'local.txt').write_text('local\n')
        git(child, 'add', 'local.txt')
        git(child, 'commit', '-m', 'local commit')
        head = git(child, 'rev-parse', 'HEAD')
        with self.assertRaisesRegex(GitError, 'Local commits'):
            execute_plan(build_plan(self.root, 'download', ['one'], recursive=False, remote=False))
        self.assertEqual(git(child, 'rev-parse', 'HEAD'), head)

    def test_external_metadata_pointer_refused(self):
        outside = create_repo(self.base / 'external metadata')
        child = self.root / 'one'
        child.mkdir()
        (child / '.git').write_text('gitdir: ' + str(outside / '.git') + '\n')
        git(outside, 'config', 'core.worktree', str(child))
        git(self.root, 'config', '--file', '.gitmodules', 'submodule.one.path', 'one')
        git(self.root, 'config', '--file', '.gitmodules', 'submodule.one.url', str(outside))
        with self.assertRaisesRegex(GitError, 'external metadata'):
            build_plan(self.root, 'align', ['one'])

    def test_unknown_plan_and_stale_child_head_refused(self):
        child = self.child('one')
        path = self.register(child)
        with self.assertRaisesRegex(GitError, 'Unknown'):
            build_plan(self.root, 'unknown', [path])
        plan = build_plan(self.root, 'align', [path])
        (child / 'next.txt').write_text('next\n')
        git(child, 'add', 'next.txt')
        git(child, 'commit', '-m', 'concurrent child commit')
        with self.assertRaisesRegex(GitError, 'changed after preview'):
            execute_plan(plan)

    def test_toc_unconfigured_skips_and_configured_failure_blocks(self):
        child = self.child('one')
        self.register(child)
        logs = []
        execute_plan(build_plan(self.root, 'download', ['one'], remote=False), log=logs.append)
        self.assertTrue(any('TOC: skip' in value for value in logs))
        git(child, 'config', 'filter.jobs-markdown-toc.smudge', 'untrusted shell must not be evaluated')
        logs.clear()
        with self.assertRaisesRegex(GitError, 'helper is missing'):
            execute_plan(build_plan(self.root, 'download', ['one'], remote=False), log=logs.append)
        self.assertFalse(any('untrusted shell' in value for value in logs))

    @unittest.skipUnless(__import__('shutil').which('node'), 'Node unavailable')
    def test_toc_restores_generated_content_before_dirty_check(self):
        child = self.child('one')
        helper = child / '.jobs-markdown-toc' / 'MarkdownToc.mjs'
        helper.parent.mkdir()
        helper.write_text("import fs from 'node:fs';\n"
                          "if(process.argv[2]==='restore'){\n"
                          " const p='README.md'; const s=fs.readFileSync(p,'utf8');\n"
                          " fs.writeFileSync(p,s.replace('GENERATED\\n',''));\n"
                          "}\n"
                          "if(process.argv[2]==='verify' && fs.readFileSync('README.md','utf8').includes('GENERATED')) process.exit(9);\n")
        git(child, 'add', '.jobs-markdown-toc')
        git(child, 'commit', '-m', 'fixture toc helper')
        self.register(child)
        git(child, 'config', 'filter.jobs-markdown-toc.smudge', 'not evaluated')
        (child / 'README.md').write_text('fixture\nGENERATED\n')
        index = Path(git(child, 'rev-parse', '--absolute-git-dir')) / 'index'
        before = index.read_bytes()
        execute_plan(build_plan(self.root, 'download', ['one'], remote=False))
        self.assertEqual((child / 'README.md').read_text(), 'fixture\n')
        self.assertEqual(index.read_bytes(), before)
        # 用户正文不被工具从HEAD覆盖，仍判定为脏并阻断下载。
        (child / 'README.md').write_text('user prose\nGENERATED\n')
        with self.assertRaisesRegex(GitError, 'Local changes'):
            execute_plan(build_plan(self.root, 'download', ['one'], remote=False))
        self.assertEqual((child / 'README.md').read_text(), 'user prose\n')

    def test_subprocess_timeout_and_cancellation(self):
        with self.assertRaisesRegex(GitError, 'timed out'):
            git_service._run(self.root, ['-c', 'import time; time.sleep(10)'],
                             executable=sys.executable, timeout=0.1)
        event = threading.Event()
        timer = threading.Timer(0.1, event.set)
        timer.start()
        try:
            with self.assertRaises(Cancelled):
                git_service._run(self.root, ['-c', 'import time; time.sleep(10)'],
                                 executable=sys.executable, cancel=event)
        finally:
            timer.cancel()

    def test_recursive_first_checkout_uses_each_parent_configuration(self):
        grand_origin = create_repo(self.base / 'grand origin')
        origin = create_repo(self.base / 'child origin')
        git(origin, '-c', 'protocol.file.allow=always', 'submodule', 'add',
            str(grand_origin), 'folder/grand')
        git(origin, 'add', '.gitmodules', 'folder/grand')
        git(origin, 'commit', '-m', 'nested module')
        child = self.root / 'one'
        git(self.root, 'clone', str(origin), str(child))
        self.register(child)
        with patch.dict(os.environ, {'GIT_CONFIG_COUNT': '1', 'GIT_CONFIG_KEY_0': 'protocol.file.allow',
                                     'GIT_CONFIG_VALUE_0': 'always'}):
            execute_plan(build_plan(self.root, 'download', ['one'], recursive=True, remote=False))
        grand = child / 'folder' / 'grand'
        self.assertEqual(git(grand, 'rev-parse', '--show-toplevel'), str(grand))
        self.assertEqual(git(grand, 'rev-parse', 'HEAD'), git(grand_origin, 'rev-parse', 'HEAD'))
        self.assertEqual(git(grand, 'remote', 'get-url', 'origin'), str(grand_origin))
        (grand_origin / 'latest.txt').write_text('latest\n')
        git(grand_origin, 'add', 'latest.txt')
        git(grand_origin, 'commit', '-m', 'grandchild remote advance')
        execute_plan(build_plan(self.root, 'download', ['one'], recursive=True, remote=True))
        # 远端递归更新会让孙仓HEAD偏离子仓gitlink；第二次运行仍应安全可重入。
        execute_plan(build_plan(self.root, 'download', ['one'], recursive=True, remote=True))
        self.assertEqual(git(grand, 'rev-parse', 'HEAD'), git(grand_origin, 'rev-parse', 'HEAD'))

    def test_non_origin_remote_selection_and_ambiguous_refusal(self):
        git(self.root, 'remote', 'add', 'primary', 'https://git.example/team/parent.git')
        git(self.root, 'remote', 'add', 'mirror', 'https://mirror.example/team/parent.git')
        git(self.root, 'config', 'branch.main.remote', 'primary')
        child = self.child('one')
        git(child, 'remote', 'rename', 'origin', 'primary')
        self.assertEqual(git_service._select_remote(child, self.root), 'primary')
        git(child, 'remote', 'add', 'mirror', 'https://mirror.example/team/child.git')
        self.assertEqual(git_service._select_remote(child, self.root), 'primary')
        git(child, 'config', 'branch.main.remote', 'mirror')
        self.assertEqual(git_service._select_remote(child, self.root), 'mirror')
        git(child, 'config', '--unset', 'branch.main.remote')
        git(child, 'checkout', '--detach')
        self.assertEqual(git_service._select_remote(child, self.root), 'primary')
        plan = build_plan(self.root, 'register', ['one'])
        self.assertEqual(plan.entries['one']['url'], '../child.git')
        git(self.root, 'config', '--unset', 'branch.main.remote')
        with self.assertRaisesRegex(GitError, 'Ambiguous'):
            build_plan(self.root, 'register', ['one'])

    def test_download_without_origin_uses_upstream_then_parent_route(self):
        origin = create_repo(self.base / 'local primary')
        child = self.root / 'one'
        git(self.root, 'clone', str(origin), str(child))
        git(child, 'remote', 'rename', 'origin', 'primary')
        git(self.root, 'remote', 'add', 'primary', str(origin))
        git(self.root, 'config', 'branch.main.remote', 'primary')
        self.register(child)
        (origin / 'next.txt').write_text('next\n')
        git(origin, 'add', 'next.txt')
        git(origin, 'commit', '-m', 'next')
        plan = build_plan(self.root, 'download', ['one'], remote=True)
        self.assertIn('remote=primary', plan.text)
        execute_plan(plan)
        self.assertEqual(git(child, 'rev-parse', 'HEAD'), git(origin, 'rev-parse', 'HEAD'))
        git(child, 'remote', 'add', 'mirror', str(origin))
        git(child, 'checkout', '--detach')
        execute_plan(build_plan(self.root, 'download', ['one'], remote=True))


if __name__ == '__main__':
    unittest.main()

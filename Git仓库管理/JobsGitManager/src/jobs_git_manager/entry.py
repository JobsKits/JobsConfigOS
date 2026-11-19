"""Frozen entry point; the package's imports stay absolute when bundled."""
from jobs_git_manager.app import main

if __name__ == "__main__":
    raise SystemExit(main())

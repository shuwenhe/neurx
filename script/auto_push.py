#!/usr/bin/env python3

import argparse
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path


def run_git(repo_root: Path, args: list[str], check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", *args],
        cwd=repo_root,
        check=check,
        text=True,
        capture_output=True,
    )


def repo_has_changes(repo_root: Path) -> bool:
    result = run_git(repo_root, ["status", "--porcelain"], check=True)
    return bool(result.stdout.strip())


def repo_status_snapshot(repo_root: Path) -> str:
    result = run_git(repo_root, ["status", "--porcelain"], check=True)
    return result.stdout.strip()


def current_branch(repo_root: Path) -> str:
    result = run_git(repo_root, ["branch", "--show-current"], check=True)
    branch = result.stdout.strip()
    if not branch:
        raise RuntimeError("Detached HEAD is not supported for auto-push")
    return branch


def ensure_remote(repo_root: Path, remote: str) -> None:
    result = run_git(repo_root, ["remote"], check=True)
    remotes = {line.strip() for line in result.stdout.splitlines() if line.strip()}
    if remote not in remotes:
        raise RuntimeError(f"Git remote not found: {remote}")


def staged_paths(repo_root: Path) -> list[Path]:
    result = run_git(repo_root, ["diff", "--cached", "--name-only", "-z"], check=True)
    raw_paths = [item for item in result.stdout.split("\x00") if item]
    return [repo_root / item for item in raw_paths]


def unstage_large_files(repo_root: Path, max_file_size_bytes: int) -> list[str]:
    skipped = []
    for path in staged_paths(repo_root):
        if not path.exists() or not path.is_file():
            continue
        if path.stat().st_size <= max_file_size_bytes:
            continue

        relative_path = str(path.relative_to(repo_root))
        run_git(repo_root, ["reset", "-q", "HEAD", "--", relative_path], check=True)
        skipped.append(relative_path)
    return skipped


def auto_commit_and_push(
    repo_root: Path,
    remote: str,
    branch: str,
    message_prefix: str,
    max_file_size_bytes: int,
) -> None:
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    message = f"{message_prefix} {timestamp}"

    run_git(repo_root, ["add", "-A"], check=True)
    skipped = unstage_large_files(repo_root, max_file_size_bytes)
    if skipped:
        print("Skipped large files:")
        for path in skipped:
            print(f"  - {path}")

    commit = run_git(repo_root, ["commit", "-m", message], check=False)
    combined_output = (commit.stdout or "") + (commit.stderr or "")
    if commit.returncode != 0:
        if "nothing to commit" in combined_output.lower():
            print("No changes to commit after staging.")
            return
        raise RuntimeError(combined_output.strip() or "git commit failed")

    print(commit.stdout.strip())

    push = run_git(repo_root, ["push", remote, branch], check=False)
    if push.returncode != 0:
        combined_output = (push.stdout or "") + (push.stderr or "")
        raise RuntimeError(combined_output.strip() or "git push failed")

    if push.stdout.strip():
        print(push.stdout.strip())
    if push.stderr.strip():
        print(push.stderr.strip())


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Watch the repository and auto-push changes")
    parser.add_argument("--repo", default=".", help="Repository root to watch")
    parser.add_argument("--remote", default="origin", help="Git remote to push to")
    parser.add_argument("--interval", type=float, default=2.0, help="Polling interval in seconds")
    parser.add_argument("--debounce", type=float, default=5.0, help="Quiet period before commit in seconds")
    parser.add_argument(
        "--message-prefix",
        default="auto: sync",
        help="Commit message prefix used for automatic commits",
    )
    parser.add_argument(
        "--max-file-size-mb",
        type=float,
        default=25.0,
        help="Skip staged files larger than this size in MiB",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    repo_root = Path(args.repo).resolve()

    ensure_remote(repo_root, args.remote)
    branch = current_branch(repo_root)

    print(f"Watching {repo_root}")
    print(f"Remote: {args.remote}")
    print(f"Branch: {branch}")
    print(f"Interval: {args.interval}s, debounce: {args.debounce}s")
    print(f"Max file size: {args.max_file_size_mb} MiB")
    print("Press Ctrl+C to stop.")

    last_snapshot = ""
    last_snapshot_changed_at = None

    try:
        while True:
            snapshot = repo_status_snapshot(repo_root)
            now = time.monotonic()

            if snapshot:
                if snapshot != last_snapshot:
                    last_snapshot = snapshot
                    last_snapshot_changed_at = now
                    print("Change detected, waiting for quiet period...")
                elif last_snapshot_changed_at is not None and now - last_snapshot_changed_at >= args.debounce:
                    print("Quiet period reached, committing and pushing...")
                    auto_commit_and_push(
                        repo_root,
                        args.remote,
                        branch,
                        args.message_prefix,
                        int(args.max_file_size_mb * 1024 * 1024),
                    )
                    last_snapshot = ""
                    last_snapshot_changed_at = None
            else:
                last_snapshot = ""
                last_snapshot_changed_at = None

            time.sleep(args.interval)
    except KeyboardInterrupt:
        print("Stopped auto-push watcher.")
        return 0


if __name__ == "__main__":
    sys.exit(main())
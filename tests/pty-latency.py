#!/usr/bin/env python3
"""Measure new-shell readiness and first-key ZLE redraw through a real PTY."""

from __future__ import annotations

import argparse
import fcntl
import os
import pty
import select
import statistics
import struct
import subprocess
import termios
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
ZDOTDIR = ROOT / "tests" / "latency-zdotdir"


def percentile(values: list[float], fraction: float) -> float:
    ordered = sorted(values)
    return ordered[round((len(ordered) - 1) * fraction)]


def one_sample(timeout: float) -> tuple[float, float]:
    master, slave = pty.openpty()
    read_fd, write_fd = os.pipe()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))

    env = os.environ.copy()
    env.update(
        {
            "ZDOTDIR": str(ZDOTDIR),
            "TERM": "xterm-256color",
            "HISTFILE": "/dev/null",
            "DOTFILES_BENCH_FD": str(write_fd),
        }
    )

    def child_setup() -> None:
        os.setsid()
        fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

    started = time.monotonic_ns()
    process = subprocess.Popen(
        ["/bin/zsh", "-i"],
        stdin=slave,
        stdout=slave,
        stderr=slave,
        cwd="/private/tmp",
        env=env,
        pass_fds=(write_fd,),
        preexec_fn=child_setup,
    )
    os.close(slave)
    os.close(write_fd)
    marker_buffer = b""

    def wait_marker(predicate) -> int:
        nonlocal marker_buffer
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            ready, _, _ = select.select([master, read_fd], [], [], 0.1)
            now = time.monotonic_ns()
            if master in ready:
                try:
                    os.read(master, 65536)
                except OSError:
                    pass
            if read_fd in ready:
                chunk = os.read(read_fd, 4096)
                if not chunk:
                    break
                marker_buffer += chunk
                while b"\n" in marker_buffer:
                    line, marker_buffer = marker_buffer.split(b"\n", 1)
                    marker = line.decode("utf-8", "replace")
                    if predicate(marker):
                        return now
        raise TimeoutError("timed out waiting for ZLE marker")

    try:
        ready_at = wait_marker(lambda marker: marker == "LINE_INIT")
        key_started = time.monotonic_ns()
        os.write(master, b"q")
        redrawn_at = wait_marker(lambda marker: marker == "REDRAW:1:1")
        return (ready_at - started) / 1_000_000, (redrawn_at - key_started) / 1_000_000
    finally:
        try:
            os.write(master, b"\x03\x04")
        except OSError:
            pass
        try:
            process.wait(timeout=0.5)
        except subprocess.TimeoutExpired:
            process.terminate()
            try:
                process.wait(timeout=1)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=1)
        os.close(master)
        os.close(read_fd)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--samples", type=int, default=30)
    parser.add_argument("--timeout", type=float, default=10.0)
    args = parser.parse_args()
    if args.samples < 1:
        parser.error("--samples must be positive")

    startup: list[float] = []
    first_key: list[float] = []
    for _ in range(args.samples):
        ready_ms, key_ms = one_sample(args.timeout)
        startup.append(ready_ms)
        first_key.append(key_ms)

    print(f"samples={args.samples}")
    print(
        "startup_to_zle_ms "
        f"median={statistics.median(startup):.3f} p95={percentile(startup, 0.95):.3f}"
    )
    print(
        "first_key_to_redraw_ms "
        f"median={statistics.median(first_key):.3f} p95={percentile(first_key, 0.95):.3f}"
    )


if __name__ == "__main__":
    main()

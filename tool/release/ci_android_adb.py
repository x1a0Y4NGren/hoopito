#!/usr/bin/env python3
"""Bound adb APK installs on the API 24 CI emulator."""

import os
import shlex
import subprocess
import sys
import time
from pathlib import Path


def run_bounded(command, timeout, log):
    start = time.monotonic()
    try:
        result = subprocess.run(command, capture_output=True, timeout=timeout)
    except subprocess.TimeoutExpired as error:
        result = None
        stdout, stderr = error.stdout, error.stderr
        status = f'timed out after {timeout}s'
    else:
        stdout, stderr = result.stdout, result.stderr
        status = f'exited {result.returncode} after {time.monotonic() - start:.1f}s'

    print(f'[API 24 adb] {shlex.join(command)}: {status}', file=log)
    for output in (stdout, stderr):
        if output:
            print(output.decode(errors='replace').rstrip(), file=log)
    log.flush()
    return result


def run_install(adb, args, log, *, timeout=90):
    # A line-buffered client records its chosen install mode even if it hangs.
    client = ['stdbuf', '-oL', '-eL', adb]
    result = run_bounded([*client, *args], timeout, log)
    if result is not None:
        return result, False

    device = [adb, *args[:2]]
    for probe in (
        [adb, 'version'],
        [*device, 'get-state'],
        [*device, 'features'],
        [*device, 'shell', 'df', '/data'],
        [*device, 'logcat', '-d', '-t', '100'],
    ):
        run_bounded(probe, 5, log)

    fallback = [*client, *args[:3], '--no-streaming', *args[3:]]
    return run_bounded(fallback, timeout, log), True


def main():
    adb = os.environ['HOOPITO_CI_ADB_ORIGINAL']
    args = sys.argv[1:]
    if args[:3] != ['-s', os.environ['HOOPITO_CI_ADB_DEVICE'], 'install']:
        os.execv(adb, [adb, *args])

    failed_fallback = Path(os.environ['HOOPITO_CI_ADB_FAILED_FALLBACK'])
    if failed_fallback.exists():
        print('API 24 adb recovery already failed in this job.', file=sys.stderr)
        return int(failed_fallback.read_text())

    with open(os.environ['HOOPITO_CI_ADB_LOG'], 'a', encoding='utf-8') as log:
        result, used_fallback = run_install(adb, args, log)
    if result is None:
        print('API 24 adb install timed out after non-streaming recovery.', file=sys.stderr)
        status = 124
    else:
        sys.stdout.buffer.write(result.stdout)
        sys.stderr.buffer.write(result.stderr)
        status = result.returncode if result.returncode >= 0 else 128 - result.returncode
        if used_fallback and not status and any(
            line.startswith(b'Failure') for line in result.stdout.splitlines()
        ):
            status = 1

    if used_fallback and status:
        # Flutter can retry installation after uninstalling an existing app.
        # A failed recovery must remain a failure even in that path.
        failed_fallback.write_text(str(status))
    return status


if __name__ == '__main__':
    sys.exit(main())

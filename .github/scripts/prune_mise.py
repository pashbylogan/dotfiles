#!/usr/bin/env python3
"""Clean unused mise versions while retaining detected live consumers. [D-CI]"""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import textwrap


def status(symbol, message, color="cyan", error=False):
    # Match lib/style.sh and Makefile; keep redirected and NO_COLOR logs plain.
    stream = sys.stderr if error else sys.stdout
    colors = {"cyan": "0;36", "green": "0;32", "yellow": "1;33", "red": "0;31"}
    styled = stream.isatty() and "NO_COLOR" not in os.environ
    marker = f"\033[{colors[color]}m{symbol}\033[0m" if styled else symbol
    print(f"{marker} {message}", file=stream, flush=True)


def candidates():
    result = subprocess.run(
        ["mise", "ls", "--prunable", "--json"], check=True, capture_output=True, text=True
    )
    return {
        str(Path(version["install_path"]).resolve()): f"{tool}@{version['version']}"
        for tool, versions in json.loads(result.stdout).items()
        for version in versions
    }


def consumers(roots):
    """Use kernel paths as well as argv to catch native binaries and scripts."""
    matches = []
    unreadable = []
    for proc in Path("/proc").iterdir():
        if not proc.name.isdecimal():
            continue
        try:
            if proc.stat().st_uid != os.getuid():
                continue
            paths = []
            restricted = False
            for name in ("exe", "cwd"):
                try:
                    paths.append(os.readlink(proc / name))
                except FileNotFoundError:
                    pass
                except PermissionError:
                    restricted = True
            argv = (proc / "cmdline").read_bytes().split(b"\0")
            try:
                cwd = os.readlink(proc / "cwd")
            except PermissionError:
                cwd = None
                restricted = True
            for arg in argv:
                value = os.fsdecode(arg)
                if value.startswith("/"):
                    paths.append(str(Path(value).resolve()))
                elif cwd and "/" in value and not value.startswith("-"):
                    paths.append(str((Path(cwd) / value).resolve()))
            try:
                for line in (proc / "maps").read_text().splitlines():
                    fields = line.split(None, 5)
                    if len(fields) == 6:
                        paths.append(fields[5])
            except PermissionError:
                restricted = True
            try:
                for fd in (proc / "fd").iterdir():
                    try:
                        paths.append(os.readlink(fd))
                    except FileNotFoundError:
                        pass
                    except PermissionError:
                        restricted = True
            except PermissionError:
                restricted = True
            used = {
                label
                for root, label in roots.items()
                if any(
                    p.removesuffix(" (deleted)") == root or p.startswith(root + "/")
                    for p in paths
                )
            }
            name = (proc / "comm").read_text().strip()
            if used:
                matches.append((int(proc.name), name, sorted(used)))
            if restricted:
                unreadable.append(f"{proc.name} ({name})")
        except (FileNotFoundError, ProcessLookupError):
            continue  # Processes can exit during the scan.
        except PermissionError:
            try:
                name = (proc / "comm").read_text().strip()
            except OSError:
                name = "unknown"
            unreadable.append(f"{proc.name} ({name})")
    return sorted(matches), unreadable


def unused(roots, report=True):
    matches, unreadable = consumers(roots)
    if matches and report:
        status("ℹ", "Keeping versions still in use")
        grouped = {}
        for pid, name, tools in matches:
            for tool in tools:
                grouped.setdefault(tool, {}).setdefault(name, []).append(str(pid))
        width = max(40, min(shutil.get_terminal_size().columns, 100))
        for tool, processes in sorted(grouped.items()):
            print(f"  {tool}", flush=True)
            for name, pids in sorted(processes.items()):
                print(
                    textwrap.fill(
                        f"{name} · PIDs {', '.join(pids)}",
                        width=width,
                        initial_indent="    ",
                        subsequent_indent="      ",
                    ),
                    flush=True,
                )
    if unreadable and report:
        status("⚠", "Protected processes not fully inspected: " + ", ".join(unreadable), "yellow")
    busy = {tool for _, _, tools in matches for tool in tools}
    return {root: tool for root, tool in roots.items() if tool not in busy}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run", action="store_true", help="report without removing versions"
    )
    args = parser.parse_args(argv)
    roots = candidates()
    if not roots:
        status("✔", "Mise cleanup: no unused versions", "green")
        return 0
    removable = unused(roots)
    removed = failed = 0
    kept = len(roots) - len(removable)
    for root, tool in removable.items():
        if args.dry_run:
            status("ℹ", f"Would remove {tool}")
            continue
        # Never hand mise a broad prune: revalidate each exact candidate just
        # before uninstalling, so retained versions cannot enter its removal set.
        current = candidates()
        if current.get(root) != tool:
            status("ℹ", f"Keeping {tool}: no longer a prune candidate")
            kept += 1
            continue
        if root not in unused({root: tool}, report=False):
            status("ℹ", f"Keeping {tool}: a live consumer appeared")
            kept += 1
            continue
        status("ℹ", f"Removing {tool}")
        result = subprocess.run(["mise", "uninstall", "--yes", "--quiet", tool])
        if result.returncode:
            failed += 1
            status("⚠", f"Could not remove {tool}; continuing", "yellow", error=True)
        else:
            removed += 1
    if args.dry_run:
        status("ℹ", f"Mise cleanup preview: {len(removable)} removable, {kept} kept")
    elif failed:
        status("⚠", f"Mise cleanup: {removed} removed, {kept} kept, {failed} failed", "yellow")
    else:
        status("✔", f"Mise cleanup: {removed} removed, {kept} kept", "green")
    return int(bool(failed))


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (subprocess.CalledProcessError, OSError, ValueError, KeyError) as error:
        status("✖", f"Mise cleanup failed: {error}", "red", error=True)
        sys.exit(1)

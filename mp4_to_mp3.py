#!/usr/bin/env python3
"""mp4_to_mp3.py

Simple command-line tool to convert MP4 files to MP3 audio or re-encode to AVI using ffmpeg.

No Python packages required — ffmpeg must be installed and available in PATH.
"""

from __future__ import annotations

import argparse
import glob
import os
import shutil
import subprocess
import sys
from pathlib import Path


def find_ffmpeg() -> str | None:
    """Return the path to ffmpeg executable or None if not found.

    If running inside a PyInstaller one-file bundle, prefer the bundled ffmpeg inside
    the temporary extraction folder pointed to by `sys._MEIPASS`.
    """
    # Check for bundled ffmpeg when running from PyInstaller onefile
    meipass = getattr(sys, "_MEIPASS", None)
    if meipass:
        for name in ("ffmpeg.exe", "ffmpeg"):
            candidate = Path(meipass) / name
            if candidate.exists():
                return str(candidate)

    # Fallback to PATH
    return shutil.which("ffmpeg")


__version__ = "1.0.0"


def convert_file(
    in_path: Path,
    out_path: Path,
    bitrate: str = "192k",
    force: bool = False,
    quiet: bool = False,
    output_format: str = "mp3",
) -> bool:
    ffmpeg = find_ffmpeg()
    if not ffmpeg:
        raise EnvironmentError(
            "ffmpeg not found in PATH. Install ffmpeg and try again."
        )

    if out_path.exists() and not force:
        if not quiet:
            print(f"Skipping existing: {out_path}")
        return False

    out_path.parent.mkdir(parents=True, exist_ok=True)

    if output_format == "mp3":
        cmd = [
            ffmpeg,
            "-hide_banner",
            "-loglevel",
            "error" if quiet else "info",
            # overwrite behavior
            "-y" if force else "-n",
            "-i",
            str(in_path),
            "-vn",  # drop video
            "-ab",
            bitrate,
            str(out_path),
        ]
    elif output_format == "avi":
        # Re-encode to AVI using mpeg4 + mp3 for wide compatibility
        cmd = [
            ffmpeg,
            "-hide_banner",
            "-loglevel",
            "error" if quiet else "info",
            "-y" if force else "-n",
            "-i",
            str(in_path),
            "-c:v",
            "mpeg4",
            "-qscale:v",
            "5",
            "-c:a",
            "libmp3lame",
            "-qscale:a",
            "4",
            str(out_path),
        ]
    else:
        raise ValueError(f"Unsupported output format: {output_format}")

    if not quiet:
        print("\nRunning:", " ".join(cmd))

    proc = subprocess.run(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
    )
    if proc.returncode != 0:
        if not quiet:
            print(f"Error converting {in_path} -> {out_path}")
            print(proc.stderr.strip())
        return False

    if not quiet:
        print(f"Converted: {in_path} -> {out_path}")
    return True


def iter_input_files(path: str, recursive: bool) -> list[Path]:
    p = Path(path)
    files: list[Path] = []

    if p.is_file():
        files.append(p)
        return files

    # treat as glob or directory
    if any(ch in path for ch in "*?["):
        files = [
            Path(fp)
            for fp in glob.glob(path, recursive=recursive)
            if Path(fp).suffix.lower() == ".mp4"
        ]
    elif p.is_dir():
        pattern = "**/*.mp4" if recursive else "*.mp4"
        files = list(p.glob(pattern))
    else:
        # try to expand as glob
        files = [
            Path(fp)
            for fp in glob.glob(path, recursive=recursive)
            if Path(fp).suffix.lower() == ".mp4"
        ]

    return files


def build_output_path(
    input_path: Path, output_dir: Path | None, output_format: str = "mp3"
) -> Path:
    base = input_path.stem
    ext = ".mp3" if output_format == "mp3" else ".avi"
    if output_dir:
        return output_dir / f"{base}{ext}"
    return input_path.with_suffix(ext)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convert MP4 files to MP3 or AVI using ffmpeg"
    )
    parser.add_argument(
        "input", help="Input file, directory, or glob pattern (e.g., '*.mp4')"
    )
    parser.add_argument("-o", "--output", help="Output directory (optional)")
    parser.add_argument(
        "-F",
        "--format",
        choices=["mp3", "avi"],
        default="mp3",
        help="Output format: mp3 (audio) or avi (video) (default: mp3)",
    )
    parser.add_argument(
        "-b",
        "--bitrate",
        default="192k",
        help="Audio bitrate when outputting mp3 (default: 192k)",
    )
    parser.add_argument(
        "-f", "--force", action="store_true", help="Overwrite existing output files"
    )
    parser.add_argument(
        "-r", "--recursive", action="store_true", help="Search directories recursively"
    )
    parser.add_argument("-q", "--quiet", action="store_true", help="Minimal output")
    parser.add_argument(
        "-V",
        "--version",
        action="store_true",
        help="Print version and detected ffmpeg path and exit",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    ffmpeg = find_ffmpeg()

    # Support a quick self-check
    if getattr(args, "version", False):
        print(f"mp4_to_mp3 version: {__version__}")
        print(f"ffmpeg: {ffmpeg if ffmpeg else '<not found>'}")
        return 0

    if not ffmpeg:
        print(
            "ffmpeg not found. The bundled exe build attempts to include ffmpeg; if you're running the script directly, install ffmpeg and ensure it's on PATH: https://ffmpeg.org/download.html"
        )
        return 2

    files = iter_input_files(args.input, args.recursive)
    if not files:
        print("No MP4 files found for the given input.")
        return 1

    output_dir = Path(args.output) if args.output else None
    success = 0
    failed = 0

    for in_fp in files:
        out_fp = build_output_path(in_fp, output_dir, output_format=args.format)
        try:
            ok = convert_file(
                in_fp,
                out_fp,
                bitrate=args.bitrate,
                force=args.force,
                quiet=args.quiet,
                output_format=args.format,
            )
            if ok:
                success += 1
            else:
                failed += 1
        except Exception as e:
            if not args.quiet:
                print(f"Failed: {in_fp} -> {e}")
            failed += 1

    if not args.quiet:
        print(f"\nSummary: {success} succeeded, {failed} failed")

    return 0 if success > 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())

# MP4 -> MP3 / AVI Converter 🔧

A small command-line Python script to convert MP4 video files to MP3 audio or re-encode to AVI using ffmpeg.

## Features ✅
- Convert a single file, a directory, or use glob patterns
- Optional recursive directory traversal
- Set audio bitrate and control overwriting
- No Python dependencies — uses `ffmpeg` (must be installed)


## Requirements 💡
- Python 3.7+
- ffmpeg available in your PATH (not a Python package)

Windows: download a build from https://ffmpeg.org/download.html and add the `bin` folder containing `ffmpeg.exe` to your PATH.


## Usage 🔊

Basic single file (MP3 output):

```
python mp4_to_mp3.py "video.mp4"
```

Convert to AVI (video re-encode):

```
python mp4_to_mp3.py "video.mp4" -F avi
```

Convert all mp4 in a directory (non-recursive):

```
python mp4_to_mp3.py "./videos"
```

Convert recursively and put output in `out/` directory:

```
python mp4_to_mp3.py "./videos" -r -o ./out
```

Set bitrate (only for MP3 output) and force overwrite:

```
python mp4_to_mp3.py "video.mp4" -b 256k -f
```


## Notes ⚠️
- The script calls `ffmpeg` directly via subprocess. If you prefer a Python wrapper, consider using `pydub` or `moviepy` but those still require ffmpeg on the system.

- If `ffmpeg` isn't found, the script will print an instruction on how to install it.

## Building a Windows .exe release 🧾

You can build a single-file Windows executable using PyInstaller and optionally bundle `ffmpeg.exe` alongside the exe.

Local build (Windows PowerShell):

```
# creates venv, installs pyinstaller and builds dist\mp4_to_mp3.exe
./build_exe.ps1

# optionally supply a ZIP containing ffmpeg.exe to bundle it next to the exe
./build_exe.ps1 -FFmpegZip ./ffmpeg-windows.zip
```

Convenience (Windows):

```
build_exe.bat
```

CI / GitHub Releases

- A GitHub Actions workflow (`.github/workflows/build_release_windows.yml`) is included. Create a tag like `v1.0.0` and push it to create a release.
- You can optionally trigger the workflow with a `workflow_dispatch` and pass an `ffmpeg_url` input (URL to a Windows ffmpeg ZIP) so the release contains both `mp4_to_mp3.exe` and `ffmpeg.exe`.

**Important:** The exe does not embed `ffmpeg` by default — the release can include `ffmpeg.exe` as a separate file next to the exe so it continues to work out of the box.


## Feedback
If you'd like a version that installs ffmpeg for you, adds parallel conversions, or includes tests, tell me which you'd prefer and I can add it. 🎯

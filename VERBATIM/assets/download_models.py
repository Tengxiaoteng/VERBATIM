#!/usr/bin/env python3
"""Download FunASR models to the app's local models directory.

Usage:
    python3 download_models.py --model-dir /path/to/models

The script sets MODELSCOPE_CACHE to <model-dir> before importing funasr,
so all model files are stored in that directory instead of the default
~/.cache/modelscope location.

A sentinel file <model-dir>/.downloaded is written on success so the
Flutter app can quickly detect that models are already present.
"""

import argparse
import os
import sys


def main():
    parser = argparse.ArgumentParser(description="Download FunASR ASR models")
    parser.add_argument(
        "--model-dir",
        required=True,
        help="Directory to store downloaded models (used as MODELSCOPE_CACHE)",
    )
    args = parser.parse_args()

    model_dir = os.path.expanduser(args.model_dir)
    os.makedirs(model_dir, exist_ok=True)

    # Must be set before importing funasr so modelscope uses our directory.
    os.environ["MODELSCOPE_CACHE"] = model_dir

    flag_file = os.path.join(model_dir, ".downloaded")

    print("DOWNLOAD_START", flush=True)
    print(f"模型目录: {model_dir}", flush=True)
    print("注意: 首次下载约 300~500 MB，请保持网络畅通。", flush=True)
    print("", flush=True)

    try:
        # Import after MODELSCOPE_CACHE is set so modelscope picks up the path.
        from funasr import AutoModel  # noqa: PLC0415

        print("正在下载/检查语音识别模型 (paraformer-zh)...", flush=True)
        AutoModel(
            model="paraformer-zh",
            vad_model="fsmn-vad",
            punc_model="ct-punc",
            disable_update=True,
        )

        # Write sentinel file to mark successful download.
        with open(flag_file, "w") as f:
            f.write("ok")

        print("", flush=True)
        print("DOWNLOAD_COMPLETE", flush=True)

    except Exception as e:
        print(f"DOWNLOAD_ERROR: {e}", flush=True)
        sys.exit(1)


if __name__ == "__main__":
    main()

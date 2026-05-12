#!/usr/bin/env python3
"""Wrapper script inside the bicep-generator folder.
It adds the local `src` directory to ``sys.path`` and forwards all
command‑line arguments to the real CLI implementation located in
``src/cli.py``.
"""
import sys
import os
from pathlib import Path

def main() -> None:
    # Directory of this script (bicep-generator)
    root = Path(__file__).resolve().parent
    src_dir = root / "src"

    if not src_dir.is_dir():
        sys.stderr.write(f"[Error] src directory not found at {src_dir}\n")
        sys.exit(1)

    # Prepend src to sys.path so we can import cli
    sys.path.insert(0, str(src_dir))

    try:
        from cli import main as cli_main  # type: ignore
    except Exception as exc:
        sys.stderr.write(f"[Error] Failed to import CLI: {exc}\n")
        sys.exit(1)

    # Forward arguments (preserve script name as argv[0])
    sys.argv = [sys.argv[0]] + sys.argv[1:]
    cli_main()

if __name__ == "__main__":
    main()

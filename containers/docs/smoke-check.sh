#!/usr/bin/env bash
set -euo pipefail

echo "[smoke] python"
python3 --version
pip --version

echo "[smoke] git"
git --version

echo "[smoke] typst"
typst --version

echo "[smoke] typstyle"
typstyle --version

echo "[smoke] hunspell"
hunspell -v

# Verify dictionaries are resolvable and usable.
echo "ciao" | hunspell -d it_IT -a >/dev/null
echo "hello" | hunspell -d en_US -a >/dev/null

echo "[smoke] plantuml and java"
plantuml -version
java -version

echo "[smoke] ok"

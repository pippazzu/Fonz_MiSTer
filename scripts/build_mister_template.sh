#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Full MiSTer compile of the Template_MiSTer core (mister/Fonz.qpf) with a
# local Quartus 17.0 (Lite is enough), the version MiSTer's template is made
# for. No patching: the project compiles in place, reading the
# trace from rtl/ (mister/files.qip). Opening mister/Fonz.qpf in the Quartus
# GUI and pressing Compile gives the same RBF.
#
# Checks first that files.qip is current and that mister/sys/ is the pinned
# template (scripts/template_project.py --check), compiles, and fails on a
# failed compile or any negative slack. Writes
# build/release/YYYYMMDD/Fonz_YYYYMMDD.rbf.
#
# Runs in Git Bash on Windows or bash on Linux.
# Usage: bash scripts/build_mister_template.sh
# Environment: QUARTUS_BIN (default /c/intelFPGA_lite/17.0/quartus/bin64 when
#              it exists, else quartus_sh on PATH), SEED (fitter seed, default 1),
#              PYTHON (default python3, else python)
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
PY=${PYTHON:-$(command -v python3 || command -v python)}
if [ -z "$QUARTUS_BIN" ] && [ -d /c/intelFPGA_lite/17.0/quartus/bin64 ]; then
    QUARTUS_BIN=/c/intelFPGA_lite/17.0/quartus/bin64
fi
[ -n "$QUARTUS_BIN" ] && PATH=$QUARTUS_BIN:$PATH
command -v quartus_sh >/dev/null || { echo "quartus_sh not found (set QUARTUS_BIN)" >&2; exit 1; }

"$PY" "$ROOT/scripts/template_project.py" --check

PRJ=$ROOT/mister
LOG=$ROOT/build/mister_template.log
mkdir -p "$ROOT/build"
cd "$PRJ"
rm -rf db incremental_db output_files
SEED_ARGS=()
[ -n "$SEED" ] && SEED_ARGS=(--set "SEED=$SEED")
quartus_sh --flow compile Fonz "${SEED_ARGS[@]}" > "$LOG" 2>&1 || true
# quartus_sh --set writes the seed into the .qsf; put the tracked file back
git -C "$ROOT" checkout -- mister/Fonz.qsf 2>/dev/null || true
grep -q "Full Compilation was successful" "$LOG" || { grep -m 20 "^Error" "$LOG"; echo "FAIL: see $LOG"; exit 1; }
grep "Worst-case.*slack" "$LOG" || true
if grep "Worst-case.*slack is -" "$LOG"; then echo "FAIL: negative slack"; exit 1; fi
STAMP=$(date +%Y%m%d)
OUT=$ROOT/build/release/$STAMP
mkdir -p "$OUT"
cp output_files/Fonz.rbf "$OUT/Fonz_$STAMP.rbf"
echo "PASS: $OUT/Fonz_$STAMP.rbf"

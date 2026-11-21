"""Run every check on the tree: lint, unit test benches, raster, board frames.

    python scripts/run_tests.py            # everything
    python scripts/run_tests.py raster     # only steps whose name contains "raster"
    python scripts/run_tests.py --list     # show the steps

Steps, in order:
  lint          scripts/lint_trace.py (pyslang parse and elaboration)
  mra           tests/test_prom_load.py: mra/The Fonz.mra matches scripts/make_mra.py
  ic_count      scripts/ic_count.py --check: the IC-type count in
                rtl/fonz_board.v matches its chip list
  net_names     scripts/check_net_names.py --check: every wire name uses real
                pins of its chip type, gate comments match the package, and
                each wire has one name in rtl/, sim/, tests/ and tb/
  fpga          scripts/make_fpga_board.py --check: rtl/fpga/ matches rtl/
  pots          scripts/pot_settings.py --check: the pot table, the CONF_STR
                in mister/Fonz.sv and docs/POT_SETTINGS.md agree
  template      scripts/template_project.py --check: mister/files.qip is
                current, and mister/sys/ is Template_MiSTer
                at TEMPLATE_REVISION, unchanged
  tb_<name>     every tests/tb_*.v unit test bench, with Icarus Verilog
  raster        tests/tb_raster.v: 454 pixel clocks a line, 261 lines a frame
  board         tests/tb_board.v: runs the board with the stand-in timing
                models and writes one image a frame to build/frames/
                (frame_NNN.pgm, plus frame_NNN.png when Pillow is installed)

A test bench passes when vvp exits 0, prints a line starting with PASS
and prints no line starting with FAIL. Logs go to build/tests/. Shared simulation models in tests/models/*.v are
compiled with every bench.
The script exits non-zero if any step fails.

Icarus (iverilog, vvp) is taken from --iverilog-dir, then PATH, then
C:/iverilog/bin, the default Windows install. Missing PROM hex files are
written first with scripts/extract_proms.py.
"""
import argparse
import os
import pathlib
import shutil
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build' / 'tests'
ICARUS_DIRS = [pathlib.Path('C:/iverilog/bin')]
# Test benches run as their own named steps after the unit benches.
ORDERED_LAST = ['tb_raster', 'tb_board']
STEP_NAMES = {'tb_raster': 'raster', 'tb_board': 'board'}
FRAMES = ROOT / 'build' / 'frames'
PROM_HEX = ['pr-09.49.hex', 'pr-08.50.hex', 'ic86.86.hex', 'ic87.87.hex']


def find_tool(name, extra_dir):
    dirs = [pathlib.Path(extra_dir)] if extra_dir else []
    for directory in dirs:
        for candidate in (directory / name, directory / (name + '.exe')):
            if candidate.is_file():
                return str(candidate)
    found = shutil.which(name)
    if found:
        return found
    for directory in ICARUS_DIRS:
        for candidate in (directory / name, directory / (name + '.exe')):
            if candidate.is_file():
                return str(candidate)
    return None


def run(command, log):
    result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True)
    log.parent.mkdir(parents=True, exist_ok=True)
    log.write_text(result.stdout, encoding='utf-8')
    return result.returncode, result.stdout


def rtl_sources():
    return sorted(str(p.relative_to(ROOT)) for p in (ROOT / 'rtl').rglob('*.v'))


def include_dirs():
    # Icarus does not always look beside the including file, so pass every
    # directory that holds a .vh header.
    dirs = sorted({str(p.parent.relative_to(ROOT)) for d in ('rtl', 'tests')
                   for p in (ROOT / d).rglob('*.vh')})
    return ['-I' + d for d in dirs]


def model_sources():
    return sorted(str(p.relative_to(ROOT)) for p in (ROOT / 'tests' / 'models').glob('*.v'))


def board_plusargs(frames):
    """Empty build/frames/ and point the board bench at it."""
    FRAMES.mkdir(parents=True, exist_ok=True)
    for old in FRAMES.glob('frame_*'):
        old.unlink()
    return [f'+frames={frames}', '+outdir=' + FRAMES.relative_to(ROOT).as_posix()]


def frames_to_png():
    """Write a PNG beside each PGM if Pillow is available."""
    pgms = sorted(FRAMES.glob('frame_*.pgm'))
    try:
        from PIL import Image
    except ImportError:
        return f'{len(pgms)} PGM frames (no Pillow, no PNG)'
    for pgm in pgms:
        Image.open(pgm).save(pgm.with_suffix('.png'))
    return f'{len(pgms)} frames as PGM and PNG'


def lint_step():
    code, output = run([sys.executable, 'scripts/lint_trace.py'], BUILD / 'lint.log')
    lines = output.strip().splitlines()
    return code == 0, lines[-1] if lines else 'no output'


def mra_step():
    code, output = run([sys.executable, '-m', 'unittest', 'tests.test_prom_load'],
                       BUILD / 'mra.log')
    lines = output.strip().splitlines()
    return code == 0, lines[-1] if lines else 'no output'


def script_check_step(script, log):
    def step():
        code, output = run([sys.executable, script, '--check'], BUILD / log)
        lines = output.strip().splitlines()
        return code == 0, lines[-1] if lines else 'no output'
    return step


def bench_step(bench, iverilog, vvp, frames=3):
    def step():
        if not iverilog or not vvp:
            return False, 'Icarus Verilog not found (see --iverilog-dir)'
        name = bench.stem
        image = BUILD / (name + '.vvp')
        BUILD.mkdir(parents=True, exist_ok=True)
        code, output = run([iverilog, '-g2012'] + include_dirs()
                           + ['-s', name, '-o', str(image),
                            str(bench.relative_to(ROOT))] + model_sources()
                           + rtl_sources(),
                           BUILD / (name + '.compile.log'))
        if code != 0:
            return False, 'compile failed: ' + first_line(output)
        plusargs = board_plusargs(frames) if name == 'tb_board' else []
        code, output = run([vvp, '-n', str(image)] + plusargs,
                           BUILD / (name + '.log'))
        lines = output.splitlines()
        fails = [l for l in lines if l.lstrip().startswith(('FAIL', 'FATAL'))]
        passes = [l for l in lines if l.startswith('PASS')]
        if code != 0 or fails or not passes:
            return False, (fails[0].strip() if fails else
                           f'vvp exit {code}, no PASS line')
        if name == 'tb_board':
            return True, passes[-1] + '; ' + frames_to_png()
        return True, passes[-1]
    return step


def first_line(text):
    for line in text.splitlines():
        if line.strip():
            return line.strip()
    return 'no output'


def ensure_proms():
    if all((ROOT / 'rom' / name).is_file() for name in PROM_HEX):
        return True
    print('PROM hex files missing; running scripts/extract_proms.py')
    code, output = run([sys.executable, 'scripts/extract_proms.py'],
                       BUILD / 'extract_proms.log')
    if code != 0:
        print(output)
    return code == 0


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('only', nargs='*',
                        help='run only steps whose name contains one of these')
    parser.add_argument('--iverilog-dir',
                        default=os.environ.get('IVERILOG_DIR'),
                        help='directory holding iverilog and vvp '
                             '(default: PATH, then C:/iverilog/bin)')
    parser.add_argument('--list', action='store_true', help='list the steps')
    parser.add_argument('--frames', type=int, default=3,
                        help='frames the board step writes (default 3, '
                             'about 5 s each)')
    args = parser.parse_args()

    iverilog = find_tool('iverilog', args.iverilog_dir)
    vvp = find_tool('vvp', args.iverilog_dir)
    benches = sorted((ROOT / 'tests').glob('tb_*.v'),
                     key=lambda p: (p.stem in ORDERED_LAST,
                                    ORDERED_LAST.index(p.stem)
                                    if p.stem in ORDERED_LAST else 0,
                                    p.stem))
    steps = [('lint', lint_step), ('mra', mra_step),
             ('ic_count', script_check_step('scripts/ic_count.py', 'ic_count.log')),
             ('net_names', script_check_step('scripts/check_net_names.py', 'net_names.log')),
             ('fpga', script_check_step('scripts/make_fpga_board.py', 'fpga.log')),
             ('pots', script_check_step('scripts/pot_settings.py', 'pots.log')),
             ('template', script_check_step('scripts/template_project.py', 'template.log'))]
    no_iverilog = ('lint', 'mra', 'ic_count', 'net_names', 'fpga', 'pots', 'template')
    steps += [(STEP_NAMES.get(b.stem, b.stem), bench_step(b, iverilog, vvp, args.frames))
              for b in benches]
    if args.only:
        steps = [s for s in steps if any(o in s[0] for o in args.only)]
    if args.list:
        for name, _ in steps:
            print(name)
        return 0
    if not steps:
        print('no steps match', ' '.join(args.only))
        return 1

    print(f'Icarus: {iverilog or "not found"}')
    if any(name not in no_iverilog for name, _ in steps) and not ensure_proms():
        print('FAIL: could not write the PROM hex files')
        return 1

    failed = []
    for name, step in steps:
        start = time.monotonic()
        try:
            ok, detail = step()
        except Exception as error:  # a missing pyslang, for example
            ok, detail = False, f'{type(error).__name__}: {error}'
        print(f'{"PASS" if ok else "FAIL"}  {name:<12} '
              f'{time.monotonic() - start:6.1f}s  {detail}')
        if not ok:
            failed.append(name)
    print(f'{len(steps) - len(failed)}/{len(steps)} steps passed'
          + (f'; failed: {", ".join(failed)}' if failed else '')
          + f'. Logs in {BUILD.relative_to(ROOT).as_posix()}/')
    return int(bool(failed))


if __name__ == '__main__':
    raise SystemExit(main())

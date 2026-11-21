"""Build and run sim/tb_throttle.v with Icarus Verilog; exit 1 on failure."""
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]


def main():
    out = ROOT / 'build'
    out.mkdir(exist_ok=True)
    vvp = out / 'tb_throttle.vvp'
    sources = [ROOT / 'sim' / 'tb_throttle.v',
               ROOT / 'rtl' / 'fonz_accel_input.v',
               ROOT / 'rtl' / 'fonz_throttle.v']
    subprocess.run(['iverilog', '-g2012', '-o', str(vvp), *map(str, sources)], check=True)
    run = subprocess.run(['vvp', '-n', str(vvp)], capture_output=True, text=True)
    print(run.stdout, end='')
    return 0 if run.returncode == 0 and 'PASS' in run.stdout.splitlines() else 1


if __name__ == '__main__':
    raise SystemExit(main())

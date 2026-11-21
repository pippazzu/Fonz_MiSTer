"""Parse and elaborate every traced Verilog fragment with slang.

Requires pyslang. A workspace-local install in tools/python is supported.
This checks HDL consistency; it does not prove schematic connectivity.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools' / 'python'))

def main():
    import pyslang
    files = sorted((ROOT / 'rtl').rglob('*.v'))
    # rtl/analog holds the shared .vh tables (the pot settings among them),
    # which files in other folders include too; Quartus searches rtl/analog for them.
    pp = pyslang.parsing.PreprocessorOptions()
    pp.additionalIncludePaths = [str(ROOT / 'rtl' / 'analog')]
    bag = pyslang.Bag([pp])
    sm = pyslang.SourceManager()
    compilation = pyslang.ast.Compilation()
    for source in files:
        compilation.addSyntaxTree(pyslang.syntax.SyntaxTree.fromFile(str(source), sm, bag))
    root = compilation.getRoot()
    diagnostics = compilation.getAllDiagnostics()
    report = pyslang.DiagnosticEngine.reportAll(compilation.sourceManager, diagnostics)
    target = ROOT / 'build'
    target.mkdir(exist_ok=True)
    (target / 'lint.txt').write_text(report, encoding='utf-8')
    errors = sum(d.isError() for d in diagnostics)
    if report:
        print(report)
    print(f'{len(files)} Verilog files; {len(root.topInstances)} elaborated roots; '
          f'{errors} errors; {len(diagnostics)-errors} warnings')
    return int(errors != 0)

if __name__ == '__main__':
    raise SystemExit(main())

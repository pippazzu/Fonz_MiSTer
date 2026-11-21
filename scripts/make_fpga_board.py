"""Generate the single-clock board (rtl/fpga/) from the traced event model.

Every rtl/fonz_*.v sheet module is copied to rtl/fpga/ with "_fpga"
appended to its module name and two ports added in front, clk_sys and rst.
Inside each copy:

* board sub-modules are instantiated by their _fpga names, with clk_sys and
  rst passed down;
* event-model TTL cells are swapped for their single-clock equivalents
  (fonz_ttl_ce.v), which take clk_sys and rst first and keep
  every original port;
* fonz_74192 becomes fonz_74192_sync, clocked by clk_sys;
* the combinational 7442 and 7448 cells are kept as they are.

Nothing else changes: nets, pins, gates and comments are copied verbatim, so
a wiring fix made in rtl/ reaches the FPGA board by rerunning this script.
fonz_board_fpga (rtl/fpga/fonz_board_fpga.v) is generated as well, from
fonz_board's port list: it makes the crystal net from clk_sys and wraps
fonz_board_core_fpga, the copy of fonz_board. Hand-written files in
rtl/fpga/ (fonz_rc_edge_ce.v, fonz_prom_comb.v) are left alone.

Run from the repository root:  python scripts/make_fpga_board.py
Add --check to fail (exit 1) when rtl/fpga/ is out of date instead of
rewriting it.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SRC = ROOT / 'rtl'
DST = ROOT / 'rtl' / 'fpga'

CE_CELLS = {
    'fonz_74161', 'fonz_74107', 'fonz_74393_half', 'fonz_74390_half',
    'fonz_74153', 'fonz_74279', 'fonz_prom',
}
COMBINATIONAL_CELLS = {'fonz_7442', 'fonz_7448'}
# Event-model cells with a hand-written clk_sys version in rtl/fpga/ (they
# win over CE_CELLS; see each file for why).
CE_MODELS = {'fonz_rc_edge': 'fonz_rc_edge_ce', 'fonz_prom': 'fonz_prom_comb'}
# Sheets that are simulation models only (real arithmetic, # delays). Their
# modules are replaced through CE_MODELS and they are not copied.
SKIP = {'fonz_input_conditioning.v'}
# MiSTer-side input models that already run on their own clock and enable
#; they are not board sheets and have no _fpga copy.
SKIP |= {'fonz_accel_input.v', 'fonz_throttle.v', 'fonz_cabinet_inputs.v'}
# The generated copy of fonz_board is renamed so that the hand-written
# fonz_board_fpga can own the crystal and keep the board's pin names.
RENAME = {'fonz_board': 'fonz_board_core_fpga'}

# Retiming changes that are not a cell swap. Each is (source file, exact
# text in the generated copy, replacement); a missing text stops the script
# so a changed trace cannot silently drop a cut.
PATCHES = [
    # Timer load loop, IC75/76 /BORROW -> IC82.13 -> IC61.8 -> IC81.6 ->
    # /LOAD (docs/74192_SYNC.md). With fonz_74192_sync it is combinational,
    # so IC82.13 is registered on clk_sys; every load of it (IC61.10, IC60.9,
    # IC82.9) takes the registered copy and each reload lands one clk_sys late.
    ('fonz_score.v',
     'assign IC82_pin13_TIME_UP=~(IC75_pin13_IC82_pin12 | IC76_pin13_BORROW_n); // pins12,11 ->13, NOR',
     'wire IC82_pin13_TIME_UP_now=~(IC75_pin13_IC82_pin12 | IC76_pin13_BORROW_n); // pins12,11 ->13, NOR\n'
     '    // Loop cut: IC82.13 registered on clk_sys.\n'
     '    reg IC82_pin13_TIME_UP_reg=1\'b0;\n'
     '    always @(posedge clk_sys) IC82_pin13_TIME_UP_reg<=rst ? 1\'b0 : IC82_pin13_TIME_UP_now;\n'
     '    assign IC82_pin13_TIME_UP=IC82_pin13_TIME_UP_reg;'),
    # IC69 holds its own count at 99: its /CARRY (with IC91's) reaches
    # IC92.9 through IC47.10 and stops the IC92.8 clock on IC69 UP. With the
    # sync 74192 that is combinational. IC92.9 takes IC47.10 one clk_sys
    # late; IC25.4 keeps the direct net.
    ('fonz_motion.v',
     '    assign IC92_pin8_IC69_pin5=~(IC47_pin10_HOLD | IC67_pin6_BIT_CLEAR | IC9_pin5_UPPER_OSC);',
     '    // Loop cut: IC47.10 -> IC92.9 registered on clk_sys.\n'
     '    reg IC47_pin10_HOLD_reg=1\'b0;\n'
     '    always @(posedge clk_sys) IC47_pin10_HOLD_reg<=rst ? 1\'b0 : IC47_pin10_HOLD;\n'
     '    assign IC92_pin8_IC69_pin5=~(IC47_pin10_HOLD_reg | IC67_pin6_BIT_CLEAR | IC9_pin5_UPPER_OSC);'),
    # IC18 stops at its limits by gating its own UP/DOWN clocks with decodes
    # of its count (IC39.11, IC62.12). Registered for the gates only.
    ('fonz_motion.v',
     '    assign IC19_pin8_IC18_pin5=~(IC28_pin8_STEER_GATE & IC34_pin4_ACCEL_n & IC39_pin11_IC19_pin10);',
     '    // Loop cut: the IC18 count decodes reach IC19 pins 10\n'
     '    // and 1 one clk_sys late.\n'
     '    reg IC39_pin11_IC19_pin10_reg=1\'b1, IC62_pin12_IC19_pin1_reg=1\'b1;\n'
     '    always @(posedge clk_sys) begin\n'
     '        IC39_pin11_IC19_pin10_reg<=rst ? 1\'b1 : IC39_pin11_IC19_pin10;\n'
     '        IC62_pin12_IC19_pin1_reg<=rst ? 1\'b1 : IC62_pin12_IC19_pin1;\n'
     '    end\n'
     '    assign IC19_pin8_IC18_pin5=~(IC28_pin8_STEER_GATE & IC34_pin4_ACCEL_n & IC39_pin11_IC19_pin10_reg);'),
    ('fonz_motion.v',
     '    assign IC19_pin12_IC18_pin4=~(IC28_pin8_STEER_GATE & IC37_pin12_ACCEL & IC62_pin12_IC19_pin1);',
     '    assign IC19_pin12_IC18_pin4=~(IC28_pin8_STEER_GATE & IC37_pin12_ACCEL & IC62_pin12_IC19_pin1_reg);'),
    # IC38 cross-coupled NAND coin latch: IC38.11 registered.
    ('fonz_game_control.v',
     '    assign IC38_pin11_COIN_LATCH_n=~(IC38_pin3_COIN_LATCH & CN20_IC38_pin13);',
     '    // Loop cut: the latch\'s IC38.11 side is a flop.\n'
     '    reg IC38_pin11_COIN_LATCH_n_reg=1\'b1;\n'
     '    always @(posedge clk_sys) IC38_pin11_COIN_LATCH_n_reg<=rst ? 1\'b1 : ~(IC38_pin3_COIN_LATCH & CN20_IC38_pin13);\n'
     '    assign IC38_pin11_COIN_LATCH_n=IC38_pin11_COIN_LATCH_n_reg;'),
]

PARAMS = r'(?:#\s*\((?:[^()]|\([^()]*\))*\)\s*)?'
MODULE_RE = re.compile(r'\bmodule\s+(fonz_\w+)(\s*' + PARAMS + r')\(')
INST_RE = re.compile(r'\b(fonz_\w+)(\s*' + PARAMS + r')(\s+)(\w+)(\s*)\(')

HEADER = ('// GENERATED by scripts/make_fpga_board.py from {src}. Do not edit:\n'
          '// change the event-model sheet and rerun the script.\n')


def fpga_name(name):
    return RENAME.get(name, name + '_fpga')


def convert(text, board_modules, src_name):
    def module_sub(m):
        return f'module {fpga_name(m.group(1))}{m.group(2)}(\n    input wire clk_sys,rst,'

    def inst_sub(m):
        cell, params, gap, inst, gap2 = m.groups()
        if cell in CE_MODELS:
            return f'{CE_MODELS[cell]}{params}{gap}{inst}{gap2}(.clk_sys(clk_sys),.rst(rst),'
        if cell in board_modules:
            return f'{fpga_name(cell)}{params}{gap}{inst}{gap2}(.clk_sys(clk_sys),.rst(rst),'
        if cell in CE_CELLS:
            return f'{cell}_ce{params}{gap}{inst}{gap2}(.clk_sys(clk_sys),.rst(rst),'
        if cell == 'fonz_74192':
            return f'fonz_74192_sync{params}{gap}{inst}{gap2}(.clk(clk_sys),'
        if cell in COMBINATIONAL_CELLS:
            return m.group(0)
        raise SystemExit(f'{src_name}: no single-clock mapping for {cell} {inst}')

    # Module headers may span lines (a #( parameter list), so rename them on
    # the whole text first; instances are then rewritten line by line, with
    # comments left alone.
    text = MODULE_RE.sub(module_sub, text)
    out = []
    for line in text.split('\n'):
        code, sep, comment = line.partition('//')
        if not code.lstrip().startswith('module '):
            code = INST_RE.sub(inst_sub, code)
        out.append(code + sep + comment)
    return HEADER.format(src=src_name) + '\n'.join(out)


TOP_TEMPLATE = """\
// SPDX-License-Identifier: GPL-3.0-or-later
// GENERATED by scripts/make_fpga_board.py from the port list of
// rtl/fonz_board.v. Do not edit: change the script or the board.
//
// Single-clock Fonz board for the FPGA. Every flip-flop runs on
// clk_sys (48 MHz). The pins and their meanings are those of fonz_board,
// except that the crystal input IC45 pin 8 is made here from clk_sys and is
// an output. docs/FPGA_BOARD.md describes the build.
//
// The crystal net toggles on a phase accumulator at 2 x 14.305 MHz, so it
// lasts one or two clk_sys per level and IC67A divides it to the
// 7.1525 MHz pixel rate exactly on average. ce_pix is one clk_sys wide at
// each rising edge of IC67 Q (pin 3), the pixel counter clock.
`timescale 1ns/1ps
`default_nettype none
module fonz_board_fpga #(
    parameter integer CLK_SYS_HZ=48000000,
    parameter integer CRYSTAL_HZ=14305000
)(
    input wire clk_sys,rst,
    output reg ce_pix=1'b0,
    output wire ic45_8,
{ports}
);
    // Crystal: one level change per accumulator wrap, 2*CRYSTAL_HZ a second.
    // It keeps running through rst, as the oscillator does on the board.
    localparam integer STEP=2*CRYSTAL_HZ;
    reg [31:0] phase=32'd0;
    reg crystal=1'b0;
    always @(posedge clk_sys)
        if (phase+STEP>=CLK_SYS_HZ) begin
            phase<=phase+STEP-CLK_SYS_HZ;
            crystal<=~crystal;
        end else
            phase<=phase+STEP;
    assign ic45_8=crystal;

    // Pixel clock enable, taken from the IC67A output inside the trace.
    // rst holds every flip-flop of the trace, IC67 included, but the
    // video path needs a pixel enable and sync while the core is held in
    // reset: without one the screen would get no sync at all. So in reset ce_pix comes from the crystal
    // divided by two, at the same rate as IC67.
    reg IC67_pin3_seen=1'b0,crystal_seen=1'b0,crystal_half=1'b0;
    always @(posedge clk_sys) begin
        IC67_pin3_seen<=IC67_pin3_PIXEL_CLK;
        crystal_seen<=crystal;
        if (crystal && !crystal_seen) crystal_half<=~crystal_half;
        ce_pix<=rst ? crystal && !crystal_seen && crystal_half
                    : IC67_pin3_PIXEL_CLK && !IC67_pin3_seen;
    end

    fonz_board_core_fpga core(.clk_sys(clk_sys),.rst(rst),.ic45_8(ic45_8),
{conns});
endmodule
`default_nettype wire
"""


def make_top(board_text):
    """fonz_board_fpga: fonz_board's ports less ic45_8, wired to the core."""
    head = re.search(r'module\s+fonz_board\s*\((.*?)\);', board_text, re.S).group(1)
    lines, names = [], []
    for line in head.split('\n'):
        code, sep, comment = line.partition('//')
        decl = re.match(r'\s*(input|output)\s+wire\s*(\[[^]]*\])?\s*(.*)', code)
        if not decl:
            if code.strip():
                raise SystemExit(f'fonz_board header: cannot read "{line.strip()}"')
            if comment:
                lines.append(line)
            continue
        ids = [n for n in re.findall(r'\w+', decl.group(3)) if n != 'ic45_8']
        if not ids:
            continue
        names += ids
        width = (decl.group(2) + ' ') if decl.group(2) else ''
        lines.append(f'    {decl.group(1)} wire {width}{",".join(ids)},' +
                     (f' //{comment}' if comment else ''))
    last = lines[-1] if not lines[-1].lstrip().startswith('//') else None
    # drop the comma after the final declaration
    for i in range(len(lines) - 1, -1, -1):
        if not lines[i].lstrip().startswith('//'):
            code, sep, comment = lines[i].partition(' //')
            lines[i] = code.rstrip(',') + (sep + comment if sep else '')
            break
    conns = ',\n'.join(f'        .{n}({n})' for n in names)
    return TOP_TEMPLATE.format(ports='\n'.join(lines), conns=conns)


def main():
    check = '--check' in sys.argv[1:]
    sources = sorted(p for p in SRC.glob('fonz_*.v') if p.name not in SKIP)
    board_modules = set()
    for source in sources:
        board_modules |= {m.group(1) for m in MODULE_RE.finditer(
            source.read_text(encoding='utf-8'))}
    DST.mkdir(exist_ok=True)
    stale = []
    expected = set()
    for source in sources:
        target = DST / (fpga_name(source.stem) + '.v')
        expected.add(target.name)
        text = convert(source.read_text(encoding='utf-8'), board_modules,
                       f'rtl/{source.name}')
        for name, old, new in PATCHES:
            if name == source.name:
                if text.count(old) != 1:
                    raise SystemExit(f'{name}: retiming patch no longer applies: {old}')
                text = text.replace(old, new)
        current = target.read_text(encoding='utf-8') if target.exists() else None
        if current != text:
            stale.append(target.name)
            if not check:
                target.write_text(text, encoding='utf-8', newline='\n')
    top = DST / 'fonz_board_fpga.v'
    expected.add(top.name)
    text = make_top((SRC / 'fonz_board.v').read_text(encoding='utf-8'))
    if (top.read_text(encoding='utf-8') if top.exists() else None) != text:
        stale.append(top.name)
        if not check:
            top.write_text(text, encoding='utf-8', newline='\n')
    for orphan in DST.glob('fonz_*_fpga.v'):
        if orphan.name not in expected and orphan.read_text(
                encoding='utf-8').startswith('// GENERATED'):
            stale.append(orphan.name)
            if not check:
                orphan.unlink()
    if check and stale:
        print('rtl/fpga is out of date: ' + ', '.join(sorted(stale)))
        print('run: python scripts/make_fpga_board.py')
        return 1
    print(f'{len(sources)} sheet files; {len(stale)} '
          f'{"stale" if check else "rewritten"}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

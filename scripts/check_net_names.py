#!/usr/bin/env python3
"""Check the wire names in rtl/fonz_*.v against the chip pinouts.

    python scripts/check_net_names.py            # report
    python scripts/check_net_names.py --check    # exit 1 on any error

The names follow docs/NET_NAMES.md (ICa_pinX_ICb_pinY and friends). This
script reads the IC types from the chip list in rtl/fonz_board.v and checks
every name against the DIP pinout of its type:

  pin      every pin number in a name is a real signal pin of the package
           (not VCC or GND, not past the last pin);
  driver   the first pin of a name is an output pin (open-collector,
           monostable and 556 outputs included);
  load     the pin after the driver (ICa_pinX_ICb_pinY) is an input pin;
  bus      a counter or decoder bus (ICn_pinA_B_C_D) lists output pins of
           one section, bit 0 (QA) first;
  gate     an assign whose comment says "pinsA,B ->C" names the inputs and
           output of one gate of that package;
  port     a sub-sheet port connected to a single wire has that wire's name;
  one name every wire driven by an output pin has one name in the whole tree
           (rtl/, sim/, tests/, tb/), so the MiSTer top, the analogue models
           and the benches call it what the board sheets call it.

A wired-AND or contact-input name (load pins first) is reported as a note,
not an error. It cannot check that a two-ended name really has two ends;
docs/NET_CHECKS.md and the schematic are the reference for that.
"""
import argparse
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
BOARD = ROOT / 'rtl' / 'fonz_board.v'
# fonz_cabinet_inputs.v is the MiSTer pad adapter, not a board sheet
SHEETS = sorted(p for p in (ROOT / 'rtl').glob('fonz_*.v') if p.name != 'fonz_cabinet_inputs.v')

# Gate packages: list of (inputs, output). Power is 7/14.
G2_00 = [((1, 2), 3), ((4, 5), 6), ((9, 10), 8), ((12, 13), 11)]
G2_02 = [((2, 3), 1), ((5, 6), 4), ((8, 9), 10), ((11, 12), 13)]
G1_04 = [((1,), 2), ((3,), 4), ((5,), 6), ((9,), 8), ((11,), 10), ((13,), 12)]
G3_10 = [((1, 2, 13), 12), ((3, 4, 5), 6), ((9, 10, 11), 8)]
G8_30 = [((1, 2, 3, 4, 5, 6, 11, 12), 8)]
G4_25 = [((1, 2, 3, 4, 5), 6), ((9, 10, 11, 12, 13), 8)]  # 3, 11 strobes
GATES = {'7400': G2_00, '7403': G2_00, '7408': G2_00, '7486': G2_00,
         '7402': G2_02, '7404': G1_04, '7406': G1_04, '7414': G1_04,
         '7410': G3_10, '7427': G3_10, '7430': G8_30, '7425': G4_25}

# MSI parts: pin count, outputs (in sections, bit 0 first), inputs.
# 7448 segments run g..a, bit 0 first, as in the abcdefg port.
MSI = {
    '74107': (14, [(3,), (2,), (5,), (6,)], [1, 4, 8, 9, 10, 11, 12, 13]),
    '74161': (16, [(14, 13, 12, 11), (15,)], [1, 2, 3, 4, 5, 6, 7, 9, 10]),
    '74192': (16, [(3, 2, 6, 7), (12,), (13,)], [1, 4, 5, 9, 10, 11, 14, 15]),
    '74393': (14, [(3, 4, 5, 6), (11, 10, 9, 8)], [1, 2, 12, 13]),
    '74390': (16, [(3, 5, 6, 7), (13, 11, 10, 9)], [1, 2, 4, 12, 14, 15]),
    '74123': (16, [(13,), (4,), (5,), (12,)], [1, 2, 3, 9, 10, 11, 6, 7, 14, 15]),
    '7442': (16, [(1, 2, 3, 4, 5, 6, 7, 9, 10, 11)], [12, 13, 14, 15]),
    '7448': (16, [(14, 15, 9, 10, 11, 12, 13), (4,)], [1, 2, 3, 4, 5, 6, 7]),
    '74153': (16, [(7,), (9,)], [1, 2, 3, 4, 5, 6, 10, 11, 12, 13, 14, 15]),
    '74279': (16, [(4,), (7,), (9,), (13,)], [1, 2, 3, 5, 6, 10, 11, 12, 14, 15]),
    '556': (14, [(5,), (9,), (1,), (13,)], [2, 3, 4, 6, 8, 10, 11, 12]),
    '74S287': (16, [(12, 11, 10, 9)], [1, 2, 3, 4, 5, 6, 7, 13, 14, 15]),
    'MMI6306': (16, [(12, 11, 10, 9)], [1, 2, 3, 4, 5, 6, 7, 13, 14, 15]),
}


def chip_types():
    text = BOARD.read_text(encoding='utf-8')
    block = text.split('// ---- chip list: begin ----')[1].split('// ---- chip list: end ----')[0]
    types = {}
    for line in block.strip().splitlines():
        ic, kind = line[2:].split()[:2]
        types[int(ic[2:])] = kind
    return types


def pins_of(kind):
    """(signal pins, output pins, input pins) of a package type."""
    if kind in GATES:
        outs = {o for _, o in GATES[kind]}
        ins = {i for g, _ in GATES[kind] for i in g}
        return outs | ins, outs, ins
    count, sections, ins = MSI[kind]
    outs = {p for s in sections for p in s}
    power = {count // 2, count}
    return set(range(1, count + 1)) - power, outs, set(ins)


NAME = re.compile(r'\b(?:[A-Z]+[0-9]+_)*IC[0-9]+_pin[0-9A-Za-z_]*\b')
PART = re.compile(r'IC(\d+)_pin((?:\d+_)*\d+)(?=_|$)')
BUS_SPLIT = re.compile(r'IC(\d+)_pin(\d+(?:_\d+)+)')


def parse(name):
    """[(ic, [pins])] in name order."""
    return [(int(m.group(1)), [int(p) for p in m.group(2).split('_')])
            for m in PART.finditer(name)]


def in_order(pins, section):
    """pins is a run of one output section, low bit first (QB..QD of a
    counter whose QA goes elsewhere is fine)."""
    n = len(pins)
    return any(tuple(pins) == section[i:i + n] for i in range(len(section) - n + 1))


def check_name(name, types, errors, notes):
    parts = parse(name)
    lead_ic = None if name.startswith('IC') else name.split('_')[0]
    for ic, pins in parts:
        kind = types.get(ic)
        if kind is None:
            errors.append(f'{name}: IC{ic} is not on the chip list')
            continue
        valid, _, _ = pins_of(kind)
        for p in pins:
            if p not in valid:
                errors.append(f'{name}: IC{ic} ({kind}) has no signal pin {p}')
    if not parts or lead_ic:
        return  # R/C node or connector input: load pins only
    ic, pins = parts[0]
    kind = types.get(ic)
    if kind is None:
        return
    _, outs, ins = pins_of(kind)
    if len(pins) > 1:
        if all(p in ins for p in pins) and not any(p in outs for p in pins):
            notes.append(f'{name}: load pins first (wired AND / several loads)')
        elif kind in GATES:
            if not all(p in outs for p in pins):
                errors.append(f'{name}: bus pins {pins} are not all {kind} outputs')
        elif not any(in_order(pins, s) for s in MSI[kind][1]):
            errors.append(f'{name}: bus pins {pins} are not one {kind} section, QA first')
        return
    p = pins[0]
    if p not in outs:
        if p in ins:
            notes.append(f'{name}: starts at input pin {p} of IC{ic} ({kind}); name the driver first')
        return
    if len(parts) > 1 and len(parts[1][1]) == 1:
        ic2, (p2,) = parts[1]
        kind2 = types.get(ic2)
        if kind2 and p2 not in pins_of(kind2)[2] and p2 in pins_of(kind2)[1]:
            errors.append(f'{name}: second end IC{ic2} pin {p2} is an output of a {kind2}')


GATE_COMMENT = re.compile(r'(?:pins|^|[\s:(])\s*(\d+(?:\s*,\s*\d+)*)\s*->\s*(\d+)\b')


def check_gates(path, text, types, errors):
    checked = 0
    for m in re.finditer(r'assign\s+(IC(\d+)_pin(\d+)\w*)\s*=([^;]*);\s*//([^\n]*)', text):
        lhs, ic, out, comment = m.group(1), int(m.group(2)), int(m.group(3)), m.group(5)
        c = GATE_COMMENT.search(comment)
        kind = types.get(ic)
        if not c or kind not in GATES:
            continue
        checked += 1
        cin = {int(x) for x in re.findall(r'\d+', c.group(1))}
        cout = int(c.group(2))
        line = text[:m.start()].count('\n') + 1
        where = f'{path.name}:{line}'
        if cout != out:
            errors.append(f'{where}: {lhs} drives pin {out}, comment says ->{cout}')
        gate = [g for g in GATES[kind] if g[1] == cout]
        if not gate:
            errors.append(f'{where}: pin {cout} is not a {kind} output')
        elif not cin <= set(gate[0][0]):
            errors.append(f'{where}: IC{ic} ({kind}) gate ->{cout} has inputs '
                          f'{sorted(gate[0][0])}, comment says {sorted(cin)}')
        # Wire names on the right that end at this gate must name its inputs.
        for name in NAME.findall(m.group(4)):
            for ic2, pins in parse(name)[1:]:
                if ic2 == ic and len(pins) == 1 and gate and pins[0] not in gate[0][0]:
                    errors.append(f'{where}: {name} feeds IC{ic} gate ->{cout}, '
                                  f'but pin {pins[0]} is not one of its inputs')
    return checked


def check_ports(path, text, errors):
    for m in re.finditer(r'\.((?:[A-Z]+\d+_)*IC\d+_pin\w+)\s*\(\s*([A-Za-z_]\w*)(\s*\[\s*(\d+)\s*\])?\s*\)', text):
        port, wire, bit = m.group(1), m.group(2), m.group(4)
        line = text[:m.start()].count('\n') + 1
        if bit is None:
            if port != wire and NAME.fullmatch(wire):
                errors.append(f'{path.name}:{line}: port .{port} carries {wire}')
            continue
        bus = BUS_SPLIT.match(wire)
        if bus:
            pin = int(bus.group(2).split('_')[int(bit)])
            want = f'IC{bus.group(1)}_pin{pin}'
            if not port.startswith(want + '_') and port != want:
                errors.append(f'{path.name}:{line}: port .{port} carries {wire}[{bit}] (pin {pin})')


# Copies of a wire kept in a register by the single-clock FPGA sheets, not
# second names for the wire.
COPY_SUFFIX = re.compile(r'_(reg|now|seen|prev)$')
# Known second names, kept until fonz_board's legacy ports are renamed:
# ic99_4/ic99_10 and ic105_6 are extra board outputs for the IC30.12 and
# IC25.12 nets, so the MiSTer top needs a separate wire name for them.
ALLOW = {'IC30_pin12_IC99_pin4_pin10', 'IC25_pin12_IC105_pin6'}
TREE = ['rtl', 'sim', 'tests', 'tb']


def check_one_name(errors):
    seen = {}
    for top in TREE:
        for path in sorted((ROOT / top).rglob('*.v')):
            code = re.sub(r'//[^\n]*', '', path.read_text(encoding='utf-8', errors='replace'))
            for name in re.findall(r'\bIC\d+_pin\d+_[A-Za-z]\w*', code):
                if COPY_SUFFIX.search(name) or name in ALLOW:
                    continue
                key = re.match(r'IC\d+_pin\d+', name).group(0)
                seen.setdefault(key, {}).setdefault(name, path.relative_to(ROOT).as_posix())
    for key, names in sorted(seen.items()):
        if len(names) > 1:
            listed = ', '.join(f'{n} ({f})' for n, f in sorted(names.items()))
            errors.append(f'{key} has {len(names)} names: {listed}')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--notes', action='store_true', help='also list notes')
    args = ap.parse_args()
    types = chip_types()
    errors, notes, names, gates = [], [], set(), 0
    for path in SHEETS:
        text = path.read_text(encoding='utf-8')
        code = re.sub(r'//[^\n]*', '', text)
        names |= set(NAME.findall(code))
        gates += check_gates(path, text, types, errors)
        check_ports(path, code, errors)
    for name in sorted(names):
        check_name(name, types, errors, notes)
    check_one_name(errors)
    errors = sorted(set(errors))
    for e in errors:
        print('ERROR', e)
    if args.notes:
        for n in sorted(set(notes)):
            print('note ', n)
    print(f'{len(names)} names, {gates} gate comments, {len(errors)} errors, {len(set(notes))} notes')
    return int(args.check and bool(errors))


if __name__ == '__main__':
    sys.exit(main())

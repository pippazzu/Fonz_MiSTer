"""Work out The Fonz video mixer levels and the grey values used in HDL.

Mixer (TRACE.md, docs/NET_CHECKS.md): IC5.11 -> R13 1k, IC7.8 -> R26 470,
IC7.12 -> VR13 2k (variable) + R3 1k. The three resistors meet at one
junction that R27 220 pulls up to +5 V; C16 4.7 uF couples the junction to
connector pin 7.

Driver model (standard TTL totem-pole, 7486 and 7427):
  low  = 0.2 V source (V_OL), sink resistance ignored;
  high = 3.4 V source (V_OH) behind the output diode, so it can only source
         current. Above 3.4 V the output is cut off and carries nothing.
The junction is taken unloaded: C16 blocks DC and the monitor's input
impedance is not on the drawing. Only the levels relative to blank matter
after AC coupling, so the grey scale is (V - V_blank) / (V_white - V_blank).

Run with --verilog to print the case tables used in rtl/fonz_video_mixer.v.
"""
import itertools
import sys

VCC, V_OL, V_OH = 5.0, 0.2, 3.4
R27 = 220.0
R13, R26, R3, VR13_MAX = 1000.0, 470.0, 1000.0, 2000.0
SETTINGS = (('min', 0.0), ('mid', 1000.0), ('max', 2000.0))


def junction(bits, vr13):
    """Junction voltage for (IC5.11, IC7.8, IC7.12) = bits."""
    branches = [(VCC, R27, False)]
    for level, r in zip(bits, (R13, R26, R3 + vr13)):
        branches.append((V_OH, r, True) if level else (V_OL, r, False))
    on = [True] * len(branches)
    while True:
        g = sum(1 / r for (v, r, d), o in zip(branches, on) if o)
        i = sum(v / r for (v, r, d), o in zip(branches, on) if o)
        vj = i / g
        # A high output whose diode would be reverse biased drops out.
        new = [not d or v > vj for (v, r, d) in branches]
        if new == on:
            return vj
        on = new


def table(vr13):
    rows = {}
    for bits in itertools.product((0, 1), repeat=3):
        rows[bits] = junction(bits, vr13)
    blank = rows[(1, 0, 0)]
    white = rows[(1, 1, 1)]
    grey = {}
    for bits, v in rows.items():
        g = round(255 * (v - blank) / (white - blank))
        # IC5.11 low is sync. IC27.11 and IC25.12 can only fall while
        # IC4.Q5 or IC3.Q5 is high, which holds IC7.8 and IC7.12 low, so
        # 000 is the only sync state the board produces. All sync states
        # map to black.
        grey[bits] = 0 if bits[0] == 0 else max(0, min(255, g))
    return rows, grey


def main():
    if '--verilog' in sys.argv:
        for name, vr13 in SETTINGS:
            _, grey = table(vr13)
            print(f'// VR13 {name}')
            for bits in itertools.product((0, 1), repeat=3):
                print(f"3'b{''.join(map(str, bits))}: grey = 8'd{grey[bits]};")
        return
    for name, vr13 in SETTINGS:
        rows, grey = table(vr13)
        blank = rows[(1, 0, 0)]
        print(f'VR13 {name} ({vr13:.0f} ohm, branch {R3 + vr13:.0f} ohm)')
        print('IC5.11 IC7.8 IC7.12   V_junction  V-V_blank  grey')
        for bits in itertools.product((0, 1), repeat=3):
            v = rows[bits]
            print(f'  {bits[0]}      {bits[1]}      {bits[2]}      {v:6.3f} V   '
                  f'{v - blank:+6.3f} V   {grey[bits]:3d}')
        print()


if __name__ == '__main__':
    main()

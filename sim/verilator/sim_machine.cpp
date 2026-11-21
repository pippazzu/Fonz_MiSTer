// SPDX-License-Identifier: GPL-3.0-or-later
// The whole machine (rtl/mister/fonz_machine_fpga.v) in Verilator, about
// a hundred times faster than Icarus: seconds of play in minutes.
//
//   bash sim/verilator/build.sh
//   build/vl_machine/Vfonz_machine_fpga [frames=N] [coin=F] [accel=F0-F1[,..]]
//       [left=F0-F1] [right=F0-F1] [every=K] [outdir=DIR] [pots=HEX]
//
// Writes one 454 x 261 PGM (blanking included) every K frames, as
// DIR/vl_NNNNN.pgm. coin=F presses the coin switch for six frames from F;
// accel/left/right hold that control from frame F0 to F1.
#include "Vfonz_machine_fpga.h"
#include "verilated.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

struct Span { int a, b; };
static std::vector<Span> spans(const char *s) {
    std::vector<Span> v;
    while (s && *s) {
        Span p; char *e;
        p.a = strtol(s, &e, 10); p.b = p.a;
        if (*e == '-') p.b = strtol(e + 1, &e, 10);
        v.push_back(p);
        s = (*e == ',') ? e + 1 : e;
        if (e == s && *s) break;
    }
    return v;
}
static bool in(const std::vector<Span> &v, int f) {
    for (auto &p : v) if (f >= p.a && f <= p.b) return true;
    return false;
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    int frames = 60, coin = -1, every = 1;
    unsigned long long pots = 0;  // pots=HEX: OSD pot codes, status[103:64]
    std::string outdir = "build/frames_vl";
    std::vector<Span> accel, left, right;
    for (int i = 1; i < argc; i++) {
        if (!strncmp(argv[i], "frames=", 7)) frames = atoi(argv[i] + 7);
        else if (!strncmp(argv[i], "coin=", 5)) coin = atoi(argv[i] + 5);
        else if (!strncmp(argv[i], "every=", 6)) every = atoi(argv[i] + 6);
        else if (!strncmp(argv[i], "outdir=", 7)) outdir = argv[i] + 7;
        else if (!strncmp(argv[i], "pots=", 5)) pots = strtoull(argv[i] + 5, nullptr, 16);
        else if (!strncmp(argv[i], "accel=", 6)) accel = spans(argv[i] + 6);
        else if (!strncmp(argv[i], "left=", 5)) left = spans(argv[i] + 5);
        else if (!strncmp(argv[i], "right=", 6)) right = spans(argv[i] + 6);
    }
    const int W = 454, H = 261;
    std::vector<unsigned char> img(W * H, 0);
    Vfonz_machine_fpga *top = new Vfonz_machine_fpga;
    top->rst = 1; top->overlay_enable = 1; top->stick_sel = 0;
    top->pots = pots;  // OSD pot codes, status[103:64] (docs/POT_SETTINGS.md)
    int frame = 0, x = 0, y = 0, hs_l = 0, vs_l = 0;
    long cycle = 0;
    while (frame <= frames) {
        top->clk_sys = 0; top->eval();
        top->clk_sys = 1; top->eval();
        if (++cycle == 20) top->rst = 0;
        if (!top->ce_pix) continue;
        if (top->hs && !hs_l) { x = 0; y++; }
        hs_l = top->hs;
        if (top->vs && !vs_l) {
            if (frame > 0 && frame % every == 0) {
                char name[512];
                snprintf(name, sizeof name, "%s/vl_%05d.pgm", outdir.c_str(), frame);
                FILE *f = fopen(name, "wb");
                if (!f) { perror(name); return 1; }
                fprintf(f, "P5\n%d %d\n255\n", W, H);
                fwrite(img.data(), 1, img.size(), f);
                fclose(f);
            }
            if (frame % 30 == 0)
                printf("frame %5d  game %s  time %02x  score %04x  pin 3 %4d mV\n", frame,
                       top->IC83_pin9_GAME_LATCH ? "off" : "on ", (top->game_digits >> 16) & 0xff,
                       top->game_digits & 0xffff, top->IC105_pin3_mv);
            fflush(stdout);
            frame++; y = 0;
            top->pad_coin = (frame >= coin && frame < coin + 6 && coin >= 0);
            top->pad_accel = in(accel, frame);
            top->pad_left = in(left, frame);
            top->pad_right = in(right, frame);
        }
        vs_l = top->vs;
        if (x < W && y < H) img[y * W + x] = top->grey;
        x++;
    }
    top->final();
    delete top;
    return 0;
}

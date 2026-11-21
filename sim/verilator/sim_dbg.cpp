// SPDX-License-Identifier: GPL-3.0-or-later
// Debug driver for fonz_dbg_top (sim/verilator/build_dbg.sh): one line a
// frame with the collision chain (IC47.1 edges, IC29 count, IC30 halves),
// the opponent and player bounding boxes, their overlap, and the shape
// oscillators. chase=F steers the player under the opponent from frame F.
// Same arguments as sim_machine.cpp, plus chase=F and verbose=1.
#include "Vfonz_dbg_top.h"
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
    int frames = 60, coin = -1, every = 1, verbose = 0, chase = -1;
    unsigned long long pots = 0;  // pots=HEX: OSD pot codes, status[103:64]
    std::string outdir = "build/frames_vl";
    std::vector<Span> accel, left, right;
    for (int i = 1; i < argc; i++) {
        if (!strncmp(argv[i], "frames=", 7)) frames = atoi(argv[i] + 7);
        else if (!strncmp(argv[i], "coin=", 5)) coin = atoi(argv[i] + 5);
        else if (!strncmp(argv[i], "every=", 6)) every = atoi(argv[i] + 6);
        else if (!strncmp(argv[i], "verbose=", 8)) verbose = atoi(argv[i] + 8);
        else if (!strncmp(argv[i], "chase=", 6)) chase = atoi(argv[i] + 6);
        else if (!strncmp(argv[i], "outdir=", 7)) outdir = argv[i] + 7;
        else if (!strncmp(argv[i], "pots=", 5)) pots = strtoull(argv[i] + 5, nullptr, 16);
        else if (!strncmp(argv[i], "accel=", 6)) accel = spans(argv[i] + 6);
        else if (!strncmp(argv[i], "left=", 5)) left = spans(argv[i] + 5);
        else if (!strncmp(argv[i], "right=", 6)) right = spans(argv[i] + 6);
    }
    const int W = 454, H = 261;
    std::vector<unsigned char> img(W * H, 0);
    Vfonz_dbg_top *top = new Vfonz_dbg_top;
    top->rst = 1; top->overlay_enable = 1; top->stick_sel = 0;
    top->pots = pots;  // OSD pot codes (docs/POT_SETTINGS.md)
    int frame = 0, x = 0, y = 0, hs_l = 0, vs_l = 0;
    long cycle = 0;
    int e47 = 0, max29 = 0, c30a = 0, c30b = 0, ovl = 0, ovl20 = 0, us = 0, ls = 0, ls1 = 0;
    int usy0 = 999, usy1 = -1, lsy0 = 999, lsy1 = -1, l47 = 0;
    int usx0 = 999, usx1 = -1, lsx0 = 999, lsx1 = -1;
    int o9 = 0, o106 = 0, l9 = 0, l106 = 0, mv9min = 99999, mv106min = 99999, g9 = 0, g106 = 0;
    while (frame <= frames) {
        top->clk_sys = 0; top->eval();
        top->clk_sys = 1; top->eval();
        if (++cycle == 20) top->rst = 0;
        { int v47 = top->dbg_47_1; if (v47 && !l47) e47++; l47 = v47;
          if (top->dbg_ic29 > max29) max29 = top->dbg_ic29;
          c30a |= top->dbg_30a; c30b |= top->dbg_30b;
          if (top->dbg_ic9_osc && !l9) o9++; l9 = top->dbg_ic9_osc;
          if (top->dbg_ic106_osc && !l106) o106++; l106 = top->dbg_ic106_osc;
          if (top->dbg_ic9_mv < mv9min) mv9min = top->dbg_ic9_mv; if (top->dbg_ic106_mv < mv106min) mv106min = top->dbg_ic106_mv;
          g9 += !top->dbg_ic9_gate; g106 += !top->dbg_ic106_gate; }
        if (!top->ce_pix) continue;
        { int u = top->dbg_us1 | top->dbg_us2, l2 = top->dbg_ls2, k = top->dbg_k20_5;
          if (u) { us++; if (y < usy0) usy0 = y; if (y > usy1) usy1 = y; if (x < usx0) usx0 = x; if (x > usx1) usx1 = x; }
          if (l2) { ls++; if (y < lsy0) lsy0 = y; if (y > lsy1) lsy1 = y; if (x < lsx0) lsx0 = x; if (x > lsx1) lsx1 = x; }
          if (top->dbg_ls1) ls1++;
          if (u && l2) ovl++; if (k && l2) ovl20++; }
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
            if (verbose || !top->IC83_pin9_GAME_LATCH || frame % 30 == 0)
                printf("f %5d %s t %02x e47 %3d max29 %3d 30a %d 30b %d | opp %4d y %3d-%3d x %3d-%3d | ply %4d/%4d y %3d-%3d x %3d-%3d | ovl %3d road %3d | IC18 %d IC90 %02x IC51 %02x pos %02x\n",
                    frame, top->IC83_pin9_GAME_LATCH ? "off" : "on ", (top->game_digits >> 16) & 0xff,
                    e47, max29, c30a, c30b, us, usy0, usy1, usx0, usx1, ls1, ls, lsy0, lsy1, lsx0, lsx1, ovl, ovl20,
                    top->dbg_ic18, top->dbg_ic90, top->dbg_ic51, top->dbg_pos64_42);
            if (verbose || !top->IC83_pin9_GAME_LATCH || frame % 30 == 0)
                printf("      osc9 %5.2f MHz ctl %4d..%4d mV gate %5.1f%% | osc106 %5.2f MHz ctl %4d..%4d mV gate %5.1f%%\n",
                    o9 / 16566.0, mv9min, top->dbg_ic9_mv, g9 / 9487.0, o106 / 16566.0, mv106min, top->dbg_ic106_mv, g106 / 9487.0);
            fflush(stdout);
            frame++; y = 0;
            top->pad_coin = (frame >= coin && frame < coin + 6 && coin >= 0);
            top->pad_accel = in(accel, frame);
            top->pad_left = in(left, frame);
            top->pad_right = in(right, frame);
            if (0) {}
            if (chase >= 0 && frame >= chase && usx1 >= 0 && lsx1 >= 0) {
                int oc = (usx0 + usx1) / 2, pc = (lsx0 + lsx1) / 2;
                if (oc - pc > 30 || pc - oc > 30 || usy0 > lsy0) {}   // too far, or below: leave it
                else if (oc < pc - 1) top->pad_left = 1; else if (oc > pc + 1) top->pad_right = 1;
            }
            e47 = max29 = c30a = c30b = ovl = ovl20 = us = ls = ls1 = 0;
            usy0 = lsy0 = usx0 = lsx0 = 999; usy1 = lsy1 = usx1 = lsx1 = -1;
            o9 = o106 = g9 = g106 = 0; mv9min = mv106min = 99999;
        }
        vs_l = top->vs;
        if (x < W && y < H) img[y * W + x] = top->grey;
        x++;
    }
    top->final();
    delete top;
    return 0;
}

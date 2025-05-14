// donut.c by Andy Sloane (@a1k0n)
// https://gist.github.com/a1k0n/8ea6516b4946ab36348fb61703dc3194
// Bruno Levy: added ANSI "pseudo-graphics", and RISC-V statistics

#define CPU_NAME "FonTamSOC" // Name of your CPU and FPGA board

#include <stdint.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <math.h>

const char* colormap[34] = {
    "0",
    "8;5;232",
    "8;5;233",
    "8;5;234",
    "8;5;235",
    "8;5;236",
    "8;5;237",
    "8;5;238",
    "8;5;239",
    "8;5;240",
    "8;5;241",
    "8;5;242",
    "8;5;243",
    "8;5;244",
    "8;5;245",
    "8;5;246",
    "8;5;247",
    "8;5;248",
    "8;5;249",
    "8;5;250",
    "8;5;251",
    "8;5;252",
    "8;5;253",
    "8;5;254",
    "8;5;255",
    "7",
    "8;5;16",
    "8;5;17",
    "8;5;18",
    "8;5;19",
    "8;5;20",
    "8;5;21",
    "8;5;22",
    "8;5;23",
};

char scanline[80];

static uint64_t my_rdcycle() {
    uint64_t result;
    uint32_t a0,a1,t0;
    {
        __asm__ __volatile__ ("rdcycleh %0" : "=r" (a1));
        __asm__ __volatile__ ("rdcycle %0" : "=r" (a0));
        __asm__ __volatile__ ("rdcycleh %0" : "=r" (t0));
    } while(t0 != a1);

    return ((uint64_t)a1 << 32) | a0;
}

static uint64_t my_rdinstret() {
    uint64_t result;
    uint32_t a0,a1,t0;
    {
        __asm__ __volatile__ ("rdinstreth %0" : "=r" (a1));
        __asm__ __volatile__ ("rdinstret %0" : "=r" (a0));
        __asm__ __volatile__ ("rdinstreth %0" : "=r" (t0));
    } while(t0 != a1);

    return ((uint64_t)a1 << 32) | a0;
}

uint64_t frame = 0;

__thread uint64_t stats_cycles_init = 0;
__thread uint64_t stats_instructions_init = 0;
__thread uint64_t stats_frame_init = 0;
__thread uint64_t stats_cycles = 0;
__thread uint64_t stats_instructions = 0;
__thread uint64_t stats_frame = 0;

static void stats_reset() {
    stats_cycles_init       = my_rdcycle();
    stats_instructions_init = my_rdinstret();
    stats_frame_init        = frame;
}

static void stats_update() {
    stats_instructions = (my_rdinstret() - stats_instructions_init);
    stats_cycles       = (my_rdcycle() - stats_cycles_init);
    stats_frame        = (frame - stats_frame_init);
}

#include <_os.h>
#define SERIAL0_ADDR (0xf80 /* By convention, the first UART is located at 0xf80 */)
void print (const char *s) {
  _preempt_disable();
  for (char c; (c = *s); ++s)
    *(volatile char *)SERIAL0_ADDR = c;
  _preempt_enable();
}

__thread char fb[80*24*16];
__thread int fbidx = 0;

int fbprintf (const char *fmt, ...) {
  va_list args;
  va_start(args, fmt);
  int n = vsnprintf(&fb[fbidx], (sizeof(fb) - fbidx), fmt, args);
  va_end(args);
  fbidx += n;
  return n;
}

static inline void setcolors(int fg, int bg) {
    fbprintf("\033[4%s;3%sm",colormap[bg],colormap[fg]);
}

__thread int prev_color1=0;
__thread int prev_color2=0;

static inline void setpixel(int x, int y, int color) {
    if(y&1){
        int color1 = scanline[x];
        int color2 = color;
        if(color1 == color2) {
            if(prev_color1 == color1) {
                fbprintf(" ");
            } else {
                fbprintf("\033[4%sm ",colormap[color1]);
                prev_color1 = color1;
            }
        } else {
            if(prev_color1 != color1 && prev_color2 != color2) {
                fbprintf("\033[4%s;3%sm",colormap[color1],colormap[color2]);
                prev_color1 = color1;
                prev_color2 = color2;
            } else if(prev_color1 != color1) {
                fbprintf("\033[4%sm",colormap[color1]);
                prev_color1 = color1;
            } else if(prev_color2 != color2) {
                fbprintf("\033[3%sm",colormap[color2]);
                prev_color2 = color2;
            }
            fbprintf("\u2583");
        }
    } else {
        scanline[x] = color;
    }
}

// "Magic circle algorithm"? DDA? I've seen this formulation in a few places;
// first in Hal Chamberlain's Musical Applications of Microprocessors, but not
// sure what to call it, or how to justify it theoretically. It seems to
// correctly rotate around a point "near" the origin, without losing magnitude
// over long periods of time, as long as there are enough bits of precision in x
// and y. I use 14 bits here.
#define R(s,x,y) x-=(y>>s); y+=(x>>s)

// #define PRECISE // Define for a more accurate result (but it costs a bit)

// CORDIC algorithm to find magnitude of |x,y| by rotating the x,y vector onto
// the x axis. This also brings vector (x2,y2) along for the ride, and writes
// back to x2 -- this is used to rotate the lighting vector from the normal of
// the torus surface towards the camera, and thus determine the lighting amount.
// We only need to keep one of the two lighting normal coordinates.
static int length_cordic(int16_t x, int16_t y, int16_t *x2_, int16_t y2) {

#ifdef PRECISE
   #define NIT 10
#else
   #define NIT 5
#endif

  int x2 = *x2_;
  if (x < 0) { // start in right half-plane
    x = -x;
    x2 = -x2;
  }
  for (int i = 0; i<NIT; i++) {
    int t = x;
    int t2 = x2;
    if (y < 0) {
      x -= y >> i;
      y += t >> i;
      x2 -= y2 >> i;
      y2 += t2 >> i;
    } else {
      x += y >> i;
      y -= t >> i;
      x2 += y2 >> i;
      y2 -= t2 >> i;
    }
  }
  // divide by 0.625 as a cheap approximation to the 0.607 scaling factor factor
  // introduced by this algorithm (see https://en.wikipedia.org/wiki/CORDIC)
  *x2_ = (x2 >> 1) + (x2 >> 3);
  return (x >> 1) + (x >> 3)
     #ifdef PRECISE
         - (x >> 6) // get nrearer to 0.607 [Inigo Quilez]
     #endif
       ;
}

uintptr_t NCPU = 0;
uintptr_t MHZ = 0;

void thrd_fn (void) {

  uintptr_t FPS  = 0;
  uintptr_t CPI  = 0;
  uintptr_t MIPS = 0;

  // torus radii and distance from camera
  // these are pretty baked-in to other constants now, so it probably won't work
  // if you change them too much.
  const int dz = 5, r1 = 1, r2 = 2;

  // high-precision rotation directions, sines and cosines and their products
  int16_t sB = 0, cB = 16384;
  int16_t sA = 11583, cA = 11583;
  int16_t sAsB = 0, cAsB = 0;
  int16_t sAcB = 11583, cAcB = 11583;

  stats_reset();

  for (;;) {

    int x1_16 = cAcB << 2;

    // yes this is a multiply but dz is 5 so it's (sb + (sb<<2)) >> 6 effectively
    int p0x = dz * sB >> 6;
    int p0y = dz * sAcB >> 6;
    int p0z = -dz * cAcB >> 6;

    const int r1i = r1*256;
    const int r2i = r2*256;

    int16_t yincC = (cA >> 6) + (cA >> 5);      // 12*cA >> 8;
    int16_t yincS = (sA >> 6) + (sA >> 5);      // 12*sA >> 8;
    int16_t xincX = (cB >> 7) + (cB >> 6);      // 6*cB >> 8;
    int16_t xincY = (sAsB >> 7) + (sAsB >> 6);  // 6*sAsB >> 8;
    int16_t xincZ = (cAsB >> 7) + (cAsB >> 6);  // 6*cAsB >> 8;
    int16_t ycA = -((cA >> 1) + (cA >> 4));     // -12 * yinc1 = -9*cA >> 4;
    int16_t ysA = -((sA >> 1) + (sA >> 4));     // -12 * yinc2 = -9*sA >> 4;
    //int dmin = INT_MAX, dmax = -INT_MAX;

    int xsAsB = (sAsB >> 4) - sAsB;  // -40*xincY
    int xcAsB = (cAsB >> 4) - cAsB;  // -40*xincZ;

    for (int j = 0; j < 46; j++, ycA += yincC>>1, ysA += yincS>>1) {

      int16_t vxi14 = (cB >> 4) - cB - sB; // -40*xincX - sB;
      int16_t vyi14 = ycA - xsAsB - sAcB;
      int16_t vzi14 = ysA + xcAsB + cAcB;

      for (int i = 0; i < 79; i++, vxi14 += xincX, vyi14 -= xincY, vzi14 += xincZ) {
        int t = 512; // (256 * dz) - r2i - r1i;
        int16_t px = p0x + (vxi14 >> 5); // assuming t = 512, t*vxi>>8 == vxi<<1
        int16_t py = p0y + (vyi14 >> 5);
        int16_t pz = p0z + (vzi14 >> 5);
        int16_t lx0 = sB >> 2;
        int16_t ly0 = (sAcB - cA) >> 2;
        int16_t lz0 = (-cAcB - sA) >> 2;
        for (;;) {
          int t0, t1, t2, d;
          int16_t lx = lx0, ly = ly0, lz = lz0;
          t0 = length_cordic(px, py, &lx, ly);
          t1 = t0 - r2i;
          t2 = length_cordic(pz, t1, &lz, lx);
          d = t2 - r1i;
          t += d;

          if (t > 8*256) {
            /* display */ {
              int N = (((j-frame)>>3)^(((i+frame)>>3)))&1;
              setpixel(i,j,(N<<2)+26);
            }
            break;
          } else if (d < 2) {
            /* display */ {
              int N = lz >> 8;
              N = N > 0 ? N < 26 ? N : 25 : 0;
              setpixel(i,j,N);
            }
            break;
          }
          px += d*vxi14 >> 14;
	      py += d*vyi14 >> 14;
	      pz += d*vzi14 >> 14;
        }
      }

      /* display */ {
        if (j&1) fbprintf("\n");
      }
    }

    stats_update();

    if (stats_cycles >= _clkfreq()) {
      FPS  = stats_frame;
      CPI  = ((stats_cycles * 1000) / stats_instructions);
      MIPS = ((stats_instructions * _clkfreq() * 1000) / (stats_cycles * 1000000));
      stats_reset();
    }

    /* display */ {
      fbprintf("\033[0m"); // reset colors
      setcolors(25,33);
      //fbprintf(" %s %dMHz %dCPU%s FRAME#%d ", CPU_NAME, MHZ, NCPU, ((NCPU > 1) ? "s" : ""), (int)frame);
      fbprintf(" %s %dMHz FRAME#%d ", CPU_NAME, MHZ, (int)frame);
      if (FPS) {
        setcolors(25,0);
        fbprintf(" %u FPS ", FPS);
        setcolors(0,25);
        fbprintf(" %u CPIx1000 ", CPI);
        setcolors(25,0);
        fbprintf(" %u MIPSx1000 ", MIPS);
      }
      fbprintf("\r\x1b[23A");
    }

    print(fb);

    _atomic_inc(&frame);

    fbidx = 0;

    prev_color1=-1;
    prev_color2=-1;

    // rotate sines, cosines, and products thereof
    // this animates the torus rotation about two axes
    R(5, cA, sA);
    R(5, cAsB, sAsB);
    R(5, cAcB, sAcB);
    R(6, cB, sB);
    R(6, cAcB, cAsB);
    R(6, sAcB, sAsB);
  }
}

int main () {
  NCPU = _ncpu();
  MHZ  = (_clkfreq()/1000000);
  print("\033[48;5;16m" // set background color black
        "\033[38;5;15m" // set foreground color white
        "\033[H"        // home
        "\033[?25l"     // hide cursor
        "\033[2J");     // clear screen
  thrd_fn();
}

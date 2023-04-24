//--------------------------------------------------------------------------------
// LiteX (b367c271) on 2023-04-14 23:05:19
//--------------------------------------------------------------------------------
// This file is Copyright (c) 2013-2020 Florent Kermarrec <florent@enjoy-digital.fr>
// This file is Copyright (c) 2013-2014 Sebastien Bourdeauducq <sb@m-labs.hk>
// This file is Copyright (c) 2018 Chris Ballance <chris.ballance@physics.ox.ac.uk>
// This file is Copyright (c) 2018 Dolu1990 <charles.papon.90@gmail.com>
// This file is Copyright (c) 2019 Gabriel L. Somlo <gsomlo@gmail.com>
// This file is Copyright (c) 2018 Jean-François Nguyen <jf@lambdaconcept.fr>
// This file is Copyright (c) 2018 Sergiusz Bazanski <q3k@q3k.org>
// This file is Copyright (c) 2018 Tim 'mithro' Ansell <me@mith.ro>
// This file is Copyright (c) 2021 Antmicro <www.antmicro.com>
// This file is Copyright (c) 2022 William Fonkou Tambe <fontamsoc@gmail.com>
// License: BSD

// Used to stringify.
#define __xstr__(s) __str__(s)
#define __str__(s) #s

#define __STACKSZ 256 /* computed from -fstack-usage outputs */

static unsigned long __stack[__STACKSZ] __attribute__((used));

// Substitute for crt0.S since this is built using -nostdlib.
__asm__ (
	".section .text._start\n"
	".global  _start\n"
	".type    _start, @function\n"
	".p2align 1\n"
	"_start:\n"

	// Initialize %sp and %fp.
	"rli16 %sp, __stack + "__xstr__(__STACKSZ)"\n"
	//"li8 %fp, 0\n" // ### Disabled, as it is unnecessary.
	"rli16 %sr, main\n"
	"j %sr\n" // ### Note that %rp is expected to have been properly set.

	".size    _start, (. - _start)\n");

#include <stdint.h>

#include "csr.h"
#include "lfsr.h"
#include "sdram_phy.h"

#ifdef CSR_SDRAM_BASE

#ifdef SDRAM_WRITE_LATENCY_CALIBRATION_DEBUG
#define SDRAM_WLC_DEBUG 1
#else
#define SDRAM_WLC_DEBUG 0
#endif // SDRAM_WRITE_LATENCY_CALIBRATION_DEBUG

#ifdef SDRAM_DELAY_PER_DQ
#define DQ_COUNT SDRAM_PHY_DQ_DQS_RATIO
#else
#define DQ_COUNT 1
#endif

#if SDRAM_PHY_DELAYS > 32
#define MODULO (SDRAM_PHY_DELAYS/32)
#else
#define MODULO (1)
#endif // SDRAM_PHY_DELAYS > 32

/*-----------------------------------------------------------------------*/
/* Helpers                                                               */
/*-----------------------------------------------------------------------*/

#define max(x, y) (((x) > (y)) ? (x) : (y))
#define min(x, y) (((x) < (y)) ? (x) : (y))

__attribute__((unused)) void cdelay(int i) {
#ifndef CONFIG_BIOS_NO_DELAYS
	asm volatile ( // At least 2 clock-cycles each loop.
		"rli8 %%sr, 0f; rli8 %1, 1f; jz %0, %1;\n"
		"0: inc8 %0, -1; jnz %0, %%sr; 1:\n"
		:: "r"(i), "r"((int){0}));
#endif // CONFIG_BIOS_NO_DELAYS
}

#define LITEDRAM_DEBUG
#ifdef LITEDRAM_DEBUG
#define __SERIAL0_ADDR (0x0ff8 /* By convention, the first UART is located at 0x0ff8 */)
#define __SERIAL0_BAUD 115200
#include <hwdrvchar/hwdrvchar.h>
static hwdrvchar serial0_hwdrvchar = {.addr = (void *)__SERIAL0_ADDR};
void serial0_init (void) {
	hwdrvchar_init (&serial0_hwdrvchar, __SERIAL0_BAUD);
}
static int putchar (int c) {
	while (!hwdrvchar_write(&serial0_hwdrvchar, &c, 1));
	return c;
}
static int puts (char *s) {
	char *_s = s;
	unsigned char c;
	while (c = *_s) {
		putchar(c);
		++_s;
	}
	return ((int)_s - (int)s);
}
#define puts_hex(I) ({ \
	inline unsigned char digit (unsigned char c) { \
		c = (c+((c>=10)?('a'-10):'0')); \
		return c; \
	} \
	typeof(I) Ival = (I); \
	unsigned Isz = sizeof(I); \
	unsigned i, j; \
	if (!(Ival)) \
		putchar('0'); \
	else for (i = 0, j = 0; i < (2*Isz); ++i) { \
		unsigned char c = (Ival>>(((8*Isz)-4)-(i*4))); \
		if (j |= c) \
			putchar(digit(c&0xf)); \
	} \
	i; \
})
#else /* LITEDRAM_DEBUG */
#define putchar(C) (0)
#define puts(S) (0)
#define puts_hex(I) (0)
#endif /* LITEDRAM_DEBUG */

/*-----------------------------------------------------------------------*/
/* Constants                                                             */
/*-----------------------------------------------------------------------*/

#define DFII_PIX_DATA_BYTES SDRAM_PHY_DFI_DATABITS/8

int sdram_get_databits(void) {
	return SDRAM_PHY_DATABITS;
}

int sdram_get_freq(void) {
	return SDRAM_PHY_XDR*SDRAM_PHY_PHASES*CONFIG_CLOCK_FREQUENCY;
}

int sdram_get_cl(void) {
#ifdef SDRAM_PHY_CL
	return SDRAM_PHY_CL;
#else // not SDRAM_PHY_CL
	return -1;
#endif // SDRAM_PHY_CL
}

int sdram_get_cwl(void) {
#ifdef SDRAM_PHY_CWL
	return SDRAM_PHY_CWL;
#else
	return -1;
#endif // SDRAM_PHY_CWL
}

/*-----------------------------------------------------------------------*/
/* DFII                                                                  */
/*-----------------------------------------------------------------------*/

#ifdef CSR_DDRPHY_BASE
static unsigned char sdram_dfii_get_rdphase(void) {
#ifdef CSR_DDRPHY_RDPHASE_ADDR
	return ddrphy_rdphase_read();
#else
	return SDRAM_PHY_RDPHASE;
#endif // CSR_DDRPHY_RDPHASE_ADDR
}

static unsigned char sdram_dfii_get_wrphase(void) {
#ifdef CSR_DDRPHY_WRPHASE_ADDR
	return ddrphy_wrphase_read();
#else
	return SDRAM_PHY_WRPHASE;
#endif // CSR_DDRPHY_WRPHASE_ADDR
}

static void sdram_dfii_pix_address_write(unsigned char phase, unsigned int value) {
#if (SDRAM_PHY_PHASES > 8)
	#error "More than 8 DFI phases not supported"
#endif // (SDRAM_PHY_PHASES > 8)
	switch (phase) {
#if (SDRAM_PHY_PHASES > 4)
	case 7: sdram_dfii_pi7_address_write(value); break;
	case 6: sdram_dfii_pi6_address_write(value); break;
	case 5: sdram_dfii_pi5_address_write(value); break;
	case 4: sdram_dfii_pi4_address_write(value); break;
#endif // (SDRAM_PHY_PHASES > 4)
#if (SDRAM_PHY_PHASES > 2)
	case 3: sdram_dfii_pi3_address_write(value); break;
	case 2: sdram_dfii_pi2_address_write(value); break;
#endif // (SDRAM_PHY_PHASES > 2)
#if (SDRAM_PHY_PHASES > 1)
	case 1: sdram_dfii_pi1_address_write(value); break;
#endif // (SDRAM_PHY_PHASES > 1)
	default: sdram_dfii_pi0_address_write(value);
	}
}

static void sdram_dfii_pird_address_write(unsigned int value) {
	unsigned char rdphase = sdram_dfii_get_rdphase();
	sdram_dfii_pix_address_write(rdphase, value);
}

static void sdram_dfii_piwr_address_write(unsigned int value) {
	unsigned char wrphase = sdram_dfii_get_wrphase();
	sdram_dfii_pix_address_write(wrphase, value);
}

static void sdram_dfii_pix_baddress_write(unsigned char phase, unsigned int value) {
#if (SDRAM_PHY_PHASES > 8)
	#error "More than 8 DFI phases not supported"
#endif // (SDRAM_PHY_PHASES > 8)
	switch (phase) {
#if (SDRAM_PHY_PHASES > 4)
	case 7: sdram_dfii_pi7_baddress_write(value); break;
	case 6: sdram_dfii_pi6_baddress_write(value); break;
	case 5: sdram_dfii_pi5_baddress_write(value); break;
	case 4: sdram_dfii_pi4_baddress_write(value); break;
#endif // (SDRAM_PHY_PHASES > 4)
#if (SDRAM_PHY_PHASES > 2)
	case 3: sdram_dfii_pi3_baddress_write(value); break;
	case 2: sdram_dfii_pi2_baddress_write(value); break;
#endif // (SDRAM_PHY_PHASES > 2)
#if (SDRAM_PHY_PHASES > 1)
	case 1: sdram_dfii_pi1_baddress_write(value); break;
#endif // (SDRAM_PHY_PHASES > 1)
	default: sdram_dfii_pi0_baddress_write(value);
	}
}

static void sdram_dfii_pird_baddress_write(unsigned int value) {
	unsigned char rdphase = sdram_dfii_get_rdphase();
	sdram_dfii_pix_baddress_write(rdphase, value);
}

static void sdram_dfii_piwr_baddress_write(unsigned int value) {
	unsigned char wrphase = sdram_dfii_get_wrphase();
	sdram_dfii_pix_baddress_write(wrphase, value);
}

static void command_px(unsigned char phase, unsigned int value) {
#if (SDRAM_PHY_PHASES > 8)
	#error "More than 8 DFI phases not supported"
#endif // (SDRAM_PHY_PHASES > 8)
	switch (phase) {
#if (SDRAM_PHY_PHASES > 4)
	case 7: command_p7(value); break;
	case 6: command_p6(value); break;
	case 5: command_p5(value); break;
	case 4: command_p4(value); break;
#endif // (SDRAM_PHY_PHASES > 4)
#if (SDRAM_PHY_PHASES > 2)
	case 3: command_p3(value); break;
	case 2: command_p2(value); break;
#endif // (SDRAM_PHY_PHASES > 2)
#if (SDRAM_PHY_PHASES > 1)
	case 1: command_p1(value); break;
#endif // (SDRAM_PHY_PHASES > 1)
	default: command_p0(value);
	}
}

static void command_prd(unsigned int value) {
	unsigned char rdphase = sdram_dfii_get_rdphase();
	command_px(rdphase, value);
}

static void command_pwr(unsigned int value) {
	unsigned char wrphase = sdram_dfii_get_wrphase();
	command_px(wrphase, value);
}
#endif // CSR_DDRPHY_BASE

/*-----------------------------------------------------------------------*/
/* Software/Hardware Control                                             */
/*-----------------------------------------------------------------------*/

#define DFII_CONTROL_SOFTWARE (DFII_CONTROL_CKE|DFII_CONTROL_ODT|DFII_CONTROL_RESET_N)
#define DFII_CONTROL_HARDWARE (DFII_CONTROL_SEL)

void sdram_software_control_on(void) {
	unsigned int previous;
	previous = sdram_dfii_control_read();
	/* Switch DFII to software control */
	if (previous != DFII_CONTROL_SOFTWARE) {
		sdram_dfii_control_write(DFII_CONTROL_SOFTWARE);
		puts("Switching SDRAM to software control.\n");
	}

#if CSR_DDRPHY_EN_VTC_ADDR
	/* Disable Voltage/Temperature compensation */
	ddrphy_en_vtc_write(0);
#endif // CSR_DDRPHY_EN_VTC_ADDR
}

void sdram_software_control_off(void) {
	unsigned int previous;
	previous = sdram_dfii_control_read();
	/* Switch DFII to hardware control */
	if (previous != DFII_CONTROL_HARDWARE) {
		sdram_dfii_control_write(DFII_CONTROL_HARDWARE);
		puts("Switching SDRAM to hardware control.\n");
	}
#if CSR_DDRPHY_EN_VTC_ADDR
	/* Enable Voltage/Temperature compensation */
	ddrphy_en_vtc_write(1);
#endif // CSR_DDRPHY_EN_VTC_ADDR
}

/*-----------------------------------------------------------------------*/
/*  Mode Register                                                        */
/*-----------------------------------------------------------------------*/

void sdram_mode_register_write(char reg, int value) {
	sdram_dfii_pi0_address_write(value);
	sdram_dfii_pi0_baddress_write(reg);
	command_p0(DFII_COMMAND_RAS|DFII_COMMAND_CAS|DFII_COMMAND_WE|DFII_COMMAND_CS);
}

#ifdef CSR_DDRPHY_BASE

/*-----------------------------------------------------------------------*/
/* Leveling Centering (Common for Read/Write Leveling)                   */
/*-----------------------------------------------------------------------*/

static void sdram_activate_test_row(void) {
	sdram_dfii_pi0_address_write(0);
	sdram_dfii_pi0_baddress_write(0);
	command_p0(DFII_COMMAND_RAS|DFII_COMMAND_CS);
	cdelay(15);
}

static void sdram_precharge_test_row(void) {
	sdram_dfii_pi0_address_write(0);
	sdram_dfii_pi0_baddress_write(0);
	command_p0(DFII_COMMAND_RAS|DFII_COMMAND_WE|DFII_COMMAND_CS);
	cdelay(15);
}

// Count number of bits in a 32-bit word, faster version than a while loop
// see: https://www.johndcook.com/blog/2020/02/21/popcount/
static unsigned int popcount(unsigned int x) {
	x -= ((x >> 1) & 0x55555555);
	x = (x & 0x33333333) + ((x >> 2) & 0x33333333);
	x = (x + (x >> 4)) & 0x0F0F0F0F;
	x += (x >> 8);
	x += (x >> 16);
	return x & 0x0000003F;
}

static void print_scan_errors(unsigned int errors) {
#ifdef SDRAM_LEVELING_SCAN_DISPLAY_HEX_DIV
	// Display '.' for no errors, errors/div in hex if it is a single char, else show 'X'
	errors = errors / SDRAM_LEVELING_SCAN_DISPLAY_HEX_DIV;
	if (errors == 0)
		putchar('.');
	else if (errors > 0xf)
		putchar('X');
	else
		puts_hex(errors);
#else
		puts_hex(errors == 0);
#endif // SDRAM_LEVELING_SCAN_DISPLAY_HEX_DIV
}

#define READ_CHECK_TEST_PATTERN_MAX_ERRORS (8*SDRAM_PHY_PHASES*DFII_PIX_DATA_BYTES/SDRAM_PHY_MODULES)
#define MODULE_BITMASK ((1<<SDRAM_PHY_DQ_DQS_RATIO)-1)

static unsigned int sdram_write_read_check_test_pattern(int module, unsigned int seed, int dq_line) {
	int p, i, bit;
	unsigned int errors;
	unsigned int prv;
	unsigned char value;
	unsigned char tst[DFII_PIX_DATA_BYTES];
	unsigned char prs[SDRAM_PHY_PHASES][DFII_PIX_DATA_BYTES];

	/* Generate pseudo-random sequence */
	prv = seed;
	for(p=0;p<SDRAM_PHY_PHASES;p++) {
		for(i=0;i<DFII_PIX_DATA_BYTES;i++) {
			value = 0;
			for (bit=0;bit<8;bit++) {
				prv = lfsr(32, prv);
				value |= (prv&1) << bit;
			}
			prs[p][i] = value;
		}
	}

	/* Activate */
	sdram_activate_test_row();

	/* Write pseudo-random sequence */
	for(p=0;p<SDRAM_PHY_PHASES;p++) {
		csr_wr_buf_uint8(sdram_dfii_pix_wrdata_addr(p), prs[p], DFII_PIX_DATA_BYTES);
	}
	sdram_dfii_piwr_address_write(0);
	sdram_dfii_piwr_baddress_write(0);
	command_pwr(DFII_COMMAND_CAS|DFII_COMMAND_WE|DFII_COMMAND_CS|DFII_COMMAND_WRDATA);
	cdelay(15);

#if defined(SDRAM_PHY_ECP5DDRPHY) || defined(SDRAM_PHY_GW2DDRPHY)
	ddrphy_burstdet_clr_write(1);
#endif // defined(SDRAM_PHY_ECP5DDRPHY) || defined(SDRAM_PHY_GW2DDRPHY)

	/* Read/Check pseudo-random sequence */
	sdram_dfii_pird_address_write(0);
	sdram_dfii_pird_baddress_write(0);
	command_prd(DFII_COMMAND_CAS|DFII_COMMAND_CS|DFII_COMMAND_RDDATA);
	cdelay(15);

	/* Precharge */
	sdram_precharge_test_row();

	errors = 0;
	for(p=0;p<SDRAM_PHY_PHASES;p++) {
		/* Read back test pattern */
		csr_rd_buf_uint8(sdram_dfii_pix_rddata_addr(p), tst, DFII_PIX_DATA_BYTES);
		/* Verify bytes matching current 'module' */
		int pebo;   // module's positive_edge_byte_offset
		int nebo;   // module's negative_edge_byte_offset, could be undefined if SDR DRAM is used
		int ibo;    // module's in byte offset (x4 ICs)
		int mask;   // Check data lines

		mask = MODULE_BITMASK;

#ifdef SDRAM_DELAY_PER_DQ
		mask = 1 << dq_line;
#endif // SDRAM_DELAY_PER_DQ

		/* Values written into CSR are Big Endian */
		/* SDRAM_PHY_XDR is define 1 if SDR and 2 if DDR*/
		nebo = (DFII_PIX_DATA_BYTES / SDRAM_PHY_XDR) - 1 - (module * SDRAM_PHY_DQ_DQS_RATIO)/8;
		pebo = nebo + DFII_PIX_DATA_BYTES / SDRAM_PHY_XDR;
		/* When DFII_PIX_DATA_BYTES is 1 and SDRAM_PHY_XDR is 2, pebo and nebo are both -1s,
		* but only correct value is 0. This can happen when single x4 IC is used */
		if ((DFII_PIX_DATA_BYTES/SDRAM_PHY_XDR) == 0) {
			pebo = 0;
			nebo = 0;
		}

		ibo = (module * SDRAM_PHY_DQ_DQS_RATIO)%8; // Non zero only if x4 ICs are used

		errors += popcount(((prs[p][pebo] >> ibo) & mask) ^
		                   ((tst[pebo] >> ibo) & mask));
		if (SDRAM_PHY_DQ_DQS_RATIO == 16)
			errors += popcount(((prs[p][pebo+1] >> ibo) & mask) ^
			                   ((tst[pebo+1] >> ibo) & mask));


#if SDRAM_PHY_XDR == 2
		if (DFII_PIX_DATA_BYTES == 1) // Special case for x4 single IC
			ibo = 0x4;
		errors += popcount(((prs[p][nebo] >> ibo) & mask) ^
		                   ((tst[nebo] >> ibo) & mask));
		if (SDRAM_PHY_DQ_DQS_RATIO == 16)
			errors += popcount(((prs[p][nebo+1] >> ibo) & mask) ^
			                   ((tst[nebo+1] >> ibo) & mask));
#endif // SDRAM_PHY_XDR == 2
	}

#if defined(SDRAM_PHY_ECP5DDRPHY) || defined(SDRAM_PHY_GW2DDRPHY)
	if (((ddrphy_burstdet_seen_read() >> module) & 0x1) != 1)
		errors += 1;
#endif // defined(SDRAM_PHY_ECP5DDRPHY) || defined(SDRAM_PHY_GW2DDRPHY)

	return errors;
}

static int _seed_array[] = {42, 84, 36};
static int _seed_array_length = sizeof(_seed_array) / sizeof(_seed_array[0]);

static int run_test_pattern(int module, int dq_line) {
	int errors = 0;
	for (int i = 0; i < _seed_array_length; i++) {
		errors += sdram_write_read_check_test_pattern(module, _seed_array[i], dq_line);
	}
	return errors;
}

void sdram_select(int module, int dq_line) {
	ddrphy_dly_sel_write(1 << module);

#ifdef SDRAM_DELAY_PER_DQ
	/* Select DQ line */
	ddrphy_dq_dly_sel_write(1 << dq_line);
#endif
}

void sdram_deselect(int module, int dq_line) {
	ddrphy_dly_sel_write(0);

#if defined(SDRAM_PHY_ECP5DDRPHY) || defined(SDRAM_PHY_GW2DDRPHY)
	/* Sync all DQSBUFM's, By toggling all dly_sel (DQSBUFM.PAUSE) lines. */
	ddrphy_dly_sel_write(0xff);
	ddrphy_dly_sel_write(0);
#endif //SDRAM_PHY_ECP5DDRPHY

#ifdef SDRAM_DELAY_PER_DQ
	/* Un-select DQ line */
	ddrphy_dq_dly_sel_write(0);
#endif
}

typedef void (*action_callback)(int module);

void sdram_leveling_action(int module, int dq_line, action_callback action) {
	/* Select module */
	sdram_select(module, dq_line);

	/* Action */
	action(module);

	/* Un-select module */
	sdram_deselect(module, dq_line);
}

static void sdram_leveling_center_module(
	int module, int show_short, int show_long, action_callback rst_delay,
	action_callback inc_delay, int dq_line) {

	int i;
	int show;
	int working, last_working;
	unsigned int errors;
	int delay, delay_mid, delay_range;
	int delay_min = -1, delay_max = -1, cur_delay_min = -1;

	if (show_long)
#ifdef SDRAM_DELAY_PER_DQ
		putchar('m'), puts_hex(module), puts(" dq_line:"), puts_hex(dq_line), puts(": |");
#else
		putchar('m'), puts_hex(module), puts(": |");
#endif // SDRAM_DELAY_PER_DQ

	/* Find smallest working delay */
	delay = 0;
	working = 0;
	sdram_leveling_action(module, dq_line, rst_delay);
	while(1) {
		errors = run_test_pattern(module, dq_line);
		last_working = working;
		working = errors == 0;
		show = show_long && (delay%MODULO == 0);
		if (show)
			print_scan_errors(errors);
		if(working && last_working && delay_min < 0) {
			delay_min = delay - 1; // delay on edges can be spotty
			break;
		}
		delay++;
		if(delay >= SDRAM_PHY_DELAYS)
			break;
		sdram_leveling_action(module, dq_line, inc_delay);
	}

	delay_max = delay_min;
	cur_delay_min = delay_min;
	/* Find largest working delay range */
	while(1) {
		errors = run_test_pattern(module, dq_line);
		working = errors == 0;
		show = show_long && (delay%MODULO == 0);
		if (show)
			print_scan_errors(errors);

		if (working) {
			int cur_delay_length = delay - cur_delay_min;
			int best_delay_length = delay_max - delay_min;
			if (cur_delay_length > best_delay_length) {
				delay_min = cur_delay_min;
				delay_max = delay;
			}
		} else {
			cur_delay_min = delay + 1;
		}
		delay++;
		if(delay >= SDRAM_PHY_DELAYS)
			break;
		sdram_leveling_action(module, dq_line, inc_delay);
	}
	if(delay_max < 0) {
		delay_max = delay;
	}

	if (show_long)
		puts("| ");

	delay_mid   = (delay_min+delay_max)/2 % SDRAM_PHY_DELAYS;
	delay_range = (delay_max-delay_min)/2;
	if (show_short) {
		if (delay_min < 0)
			puts("delays: -");
		else
			puts("delays: "), puts_hex(delay_mid), puts("+-"), puts_hex(delay_range);
	}

	if (show_long)
		putchar('\n');

	/* Set delay to the middle and check */
	if (delay_min >= 0) {
		int retries = 8; /* Do N configs/checks and give up if failing */
		while (retries > 0) {
			/* Set delay. */
			sdram_leveling_action(module, dq_line, rst_delay);
			cdelay(100);
			for(i = 0; i < delay_mid; i++) {
				sdram_leveling_action(module, dq_line, inc_delay);
				cdelay(100);
			}

			/* Check */
			errors = run_test_pattern(module, dq_line);
			if (errors == 0)
				break;
			retries--;
		}
	}
}

/*-----------------------------------------------------------------------*/
/* Write Leveling                                                        */
/*-----------------------------------------------------------------------*/

#ifdef SDRAM_PHY_WRITE_LEVELING_CAPABLE

int _sdram_tck_taps;

int _sdram_write_leveling_cmd_scan  = 1;
int _sdram_write_leveling_cmd_delay = 0;

int _sdram_write_leveling_cdly_range_start = -1;
int _sdram_write_leveling_cdly_range_end   = -1;

static void sdram_write_leveling_on(void) {
	// Flip write leveling bit in the Mode Register, as it is disabled by default
	sdram_dfii_pi0_address_write(DDRX_MR_WRLVL_RESET ^ (1 << DDRX_MR_WRLVL_BIT));
	sdram_dfii_pi0_baddress_write(DDRX_MR_WRLVL_ADDRESS);
	command_p0(DFII_COMMAND_RAS|DFII_COMMAND_CAS|DFII_COMMAND_WE|DFII_COMMAND_CS);

#ifdef SDRAM_PHY_DDR4_RDIMM
	sdram_dfii_pi0_address_write((DDRX_MR_WRLVL_RESET ^ (1 << DDRX_MR_WRLVL_BIT)) ^ 0x2BF8) ;
	sdram_dfii_pi0_baddress_write(DDRX_MR_WRLVL_ADDRESS ^ 0xF);
	command_p0(DFII_COMMAND_RAS|DFII_COMMAND_CAS|DFII_COMMAND_WE|DFII_COMMAND_CS);
#endif // SDRAM_PHY_DDR4_RDIMM

	ddrphy_wlevel_en_write(1);
}

static void sdram_write_leveling_off(void) {
	sdram_dfii_pi0_address_write(DDRX_MR_WRLVL_RESET);
	sdram_dfii_pi0_baddress_write(DDRX_MR_WRLVL_ADDRESS);
	command_p0(DFII_COMMAND_RAS|DFII_COMMAND_CAS|DFII_COMMAND_WE|DFII_COMMAND_CS);

#ifdef SDRAM_PHY_DDR4_RDIMM
	sdram_dfii_pi0_address_write(DDRX_MR_WRLVL_RESET ^ 0x2BF8);
	sdram_dfii_pi0_baddress_write(DDRX_MR_WRLVL_ADDRESS ^ 0xF);
	command_p0(DFII_COMMAND_RAS|DFII_COMMAND_CAS|DFII_COMMAND_WE|DFII_COMMAND_CS);
#endif // SDRAM_PHY_DDR4_RDIMM

	ddrphy_wlevel_en_write(0);
}

void sdram_write_leveling_rst_cmd_delay(int show) {
	_sdram_write_leveling_cmd_scan = 1;
	if (show)
		puts("Reseting Cmd delay\n");
}

int sdram_clock_delay;
void sdram_inc_clock_delay(void) {
	sdram_clock_delay = (sdram_clock_delay + 1) & (SDRAM_PHY_DELAYS - 1);
	ddrphy_cdly_inc_write(1);
	cdelay(100);
}

void sdram_rst_clock_delay(void) {
	sdram_clock_delay = 0;
	ddrphy_cdly_rst_write(1);
	cdelay(100);
}

void sdram_write_leveling_force_cmd_delay(int taps, int show) {
	int i;
	_sdram_write_leveling_cmd_scan  = 0;
	_sdram_write_leveling_cmd_delay = taps;
	if (show)
		puts("Forcing Cmd delay to "), puts_hex(taps), puts(" taps\n");
	sdram_rst_clock_delay();
	for (i=0; i<taps; i++) {
		sdram_inc_clock_delay();
	}
}

int write_dq_delay[SDRAM_PHY_MODULES];
void write_inc_dq_delay(int module) {
	/* Increment DQ delay */
	write_dq_delay[module] = (write_dq_delay[module] + 1) & (SDRAM_PHY_DELAYS - 1);
	ddrphy_wdly_dq_inc_write(1);
	cdelay(100);
}

void write_rst_dq_delay(int module) {
#if defined(SDRAM_PHY_USDDRPHY) || defined(SDRAM_PHY_USPDDRPHY)
	/* Reset DQ delay */
	int dq_count = ddrphy_wdly_dqs_inc_count_read();
	while (dq_count != SDRAM_PHY_DELAYS) {
		ddrphy_wdly_dq_inc_write(1);
		cdelay(100);
		dq_count++;
	}
#else
	/* Reset DQ delay */
	ddrphy_wdly_dq_rst_write(1);
	cdelay(100);
#endif //defined(SDRAM_PHY_USDDRPHY) || defined(SDRAM_PHY_USPDDRPHY)
	write_dq_delay[module] = 0;
}

void write_inc_dqs_delay(int module) {
	/* Increment DQS delay */
	ddrphy_wdly_dqs_inc_write(1);
	cdelay(100);
}

void write_rst_dqs_delay(int module) {
#if defined(SDRAM_PHY_USDDRPHY) || defined(SDRAM_PHY_USPDDRPHY)
	/* Reset DQS delay */
	while (ddrphy_wdly_dqs_inc_count_read() != 0) {
		ddrphy_wdly_dqs_inc_write(1);
		cdelay(100);
	}
#else
	/* Reset DQS delay */
	ddrphy_wdly_dqs_rst_write(1);
	cdelay(100);
#endif //defined(SDRAM_PHY_USDDRPHY) || defined(SDRAM_PHY_USPDDRPHY)
}

void write_inc_delay(int module) {
	/* Increment DQ/DQS delay */
	write_inc_dq_delay(module);
	write_inc_dqs_delay(module);
}

void write_rst_delay(int module) {
	write_rst_dq_delay(module);
	write_rst_dqs_delay(module);
}
int _sdram_write_leveling_dat_delays[16];

void sdram_write_leveling_rst_dat_delay(int module, int show) {
	_sdram_write_leveling_dat_delays[module] = -1;
	if (show)
		puts("Reseting Dat delay of module "), puts_hex(module), putchar('\n');
}

static int sdram_write_leveling_scan(int *delays, int loops, int show) {
	int i, j, k, dq_line;

	int err_ddrphy_wdly;

	unsigned char taps_scan[SDRAM_PHY_DELAYS];

	int one_window_active;
	int one_window_start, one_window_best_start;
	int one_window_count, one_window_best_count;

	unsigned char buf[DFII_PIX_DATA_BYTES];

	int ok;

	err_ddrphy_wdly = SDRAM_PHY_DELAYS - _sdram_tck_taps/4;

	sdram_write_leveling_on();
	cdelay(100);
	for(i=0;i<SDRAM_PHY_MODULES;i++) {
		for (dq_line = 0; dq_line < DQ_COUNT; dq_line++) {
			if (show)
#ifdef SDRAM_DELAY_PER_DQ
				puts("  m"), puts_hex(i), puts(" dq"), puts_hex(dq_line), puts(": |");
#else
				puts("  m"), puts_hex(i), puts(": |");
#endif // SDRAM_DELAY_PER_DQ

			/* Reset delay */
			sdram_leveling_action(i, dq_line, write_rst_delay);
			cdelay(100);

			/* Scan write delay taps */
			for(j=0;j<err_ddrphy_wdly;j++) {
				int zero_count = 0;
				int one_count = 0;
				int show_iter = (j%MODULO == 0) && show;

				for (k=0; k<loops; k++) {
					ddrphy_wlevel_strobe_write(1);
					cdelay(100);
					csr_rd_buf_uint8(sdram_dfii_pix_rddata_addr(0), buf, DFII_PIX_DATA_BYTES);
#if SDRAM_PHY_DQ_DQS_RATIO == 4
					/* For x4 memories, we need to test individual nibbles, not bytes */

					/* Extract the byte containing the nibble from the tested module */
					int module_byte = buf[SDRAM_PHY_MODULES-1-(i/2)];
					/* Shift the byte by 4 bits right if the module number is odd */
					module_byte >>= 4 * (i % 2);
					/* Extract the nibble from the tested module */
					if ((module_byte & 0xf) != 0)
#else // SDRAM_PHY_DQ_DQS_RATIO != 4
					if (buf[SDRAM_PHY_MODULES-1-i] != 0)
#endif // SDRAM_PHY_DQ_DQS_RATIO == 4
						one_count++;
					else
						zero_count++;
				}
				if (one_count > zero_count)
					taps_scan[j] = 1;
				else
					taps_scan[j] = 0;
				if (show_iter)
					puts_hex(taps_scan[j]);
				sdram_leveling_action(i, dq_line, write_inc_delay);
				cdelay(100);
			}
			if (show)
				puts("|");

			/* Find longer 1 window and set delay at the 0/1 transition */
			one_window_active = 0;
			one_window_start = 0;
			one_window_count = 0;
			one_window_best_start = 0;
			one_window_best_count = -1;
			delays[i] = -1;
			for(j=0;j<err_ddrphy_wdly+1;j++) {
				if (one_window_active) {
					if ((j == err_ddrphy_wdly) || (taps_scan[j] == 0)) {
						one_window_active = 0;
						one_window_count = j - one_window_start;
						if (one_window_count > one_window_best_count) {
							one_window_best_start = one_window_start;
							one_window_best_count = one_window_count;
						}
					}
				} else {
					if (j != err_ddrphy_wdly && taps_scan[j]) {
						one_window_active = 1;
						one_window_start = j;
					}
				}
			}

			/* Reset delay */
			sdram_leveling_action(i, dq_line, write_rst_delay);
			cdelay(100);

			/* Use forced delay if configured */
			if (_sdram_write_leveling_dat_delays[i] >= 0) {
				delays[i] = _sdram_write_leveling_dat_delays[i];

				/* Configure write delay */
				for(j=0; j<delays[i]; j++)  {
					sdram_leveling_action(i, dq_line, write_inc_delay);
					cdelay(100);
				}
			/* Succeed only if the start of a 1s window has been found: */
			} else if (
				/* Start of 1s window directly seen after 0. */
				((one_window_best_start) > 0 && (one_window_best_count > 0)) ||
				/* Start of 1s window indirectly seen before 0. */
				((one_window_best_start == 0) && (one_window_best_count > _sdram_tck_taps/4))
			) {
#if SDRAM_PHY_DELAYS > 32
				/* Ensure write delay is just before transition */
				one_window_start -= min(one_window_start, 16);
#endif // SDRAM_PHY_DELAYS > 32
				delays[i] = one_window_best_start;

				/* Configure write delay */
				for(j=0; j<delays[i]; j++) {
					sdram_leveling_action(i, dq_line, write_inc_delay);
					cdelay(100);
				}
			}
			if (show) {
				if (delays[i] == -1)
					puts(" delay: -\n");
				else
					puts(" delay: "), puts_hex(delays[i]), putchar('\n');
			}
		}
	}

	sdram_write_leveling_off();

	ok = 1;
	for(i=SDRAM_PHY_MODULES-1;i>=0;i--) {
		if(delays[i] < 0)
			ok = 0;
	}

	return ok;
}

static void sdram_write_leveling_find_cmd_delay(
	unsigned int *best_error, unsigned int *best_count, int *best_cdly,
	int cdly_start, int cdly_stop, int cdly_step) {
	int cdly;
	int delays[SDRAM_PHY_MODULES];
#ifndef SDRAM_WRITE_LEVELING_CMD_DELAY_DEBUG
	int ok;
#endif // SDRAM_WRITE_LEVELING_CMD_DELAY_DEBUG

	/* Scan through the range */
	sdram_rst_clock_delay();
	for (cdly = cdly_start; cdly < cdly_stop; cdly += cdly_step) {
		/* Increment cdly to current value */
		while (sdram_clock_delay < cdly)
			sdram_inc_clock_delay();

		/* Write level using this delay */
#ifdef SDRAM_WRITE_LEVELING_CMD_DELAY_DEBUG
		puts("Cmd/Clk delay: "), puts_hex(cdly), putchar('\n');
		sdram_write_leveling_scan(delays, 8, 1);
#else
		ok = sdram_write_leveling_scan(delays, 8, 0);
#endif // SDRAM_WRITE_LEVELING_CMD_DELAY_DEBUG
		/* Use the mean of delays for error calulation */
		int delay_mean  = 0;
		int delay_count = 0;
		for (int i=0; i < SDRAM_PHY_MODULES; ++i) {
			if (delays[i] != -1) {
				delay_mean  += delays[i]*256 + _sdram_tck_taps*64;
				delay_count += 1;
			}
		}
		if (delay_count != 0)
			delay_mean /= delay_count;

		/* We want the higher number of valid modules and delay to be centered */
		int ideal_delay = SDRAM_PHY_DELAYS*128 - _sdram_tck_taps*32;
		int error = ideal_delay - delay_mean;
		if (error < 0)
			error *= -1;

		if (delay_count >= *best_count) {
			if (error < *best_error) {
				*best_cdly  = cdly;
				*best_error = error;
				*best_count = delay_count;
			}
		}
#ifdef SDRAM_WRITE_LEVELING_CMD_DELAY_DEBUG
		puts("Delay mean: "), puts_hex(delay_mean), puts("/ff, ideal: "), puts_hex(ideal_delay), puts("/ff\n");
#else
		puts_hex(ok);
#endif // SDRAM_WRITE_LEVELING_CMD_DELAY_DEBUG
	}
}

int sdram_write_leveling(void) {
	int delays[SDRAM_PHY_MODULES];
	unsigned int best_error = ~0u;
	unsigned int best_count = 0;
	int best_cdly = -1;
	int cdly_range_start;
	int cdly_range_end;
	int cdly_range_step;

	_sdram_tck_taps = ddrphy_half_sys8x_taps_read()*4;
	puts("  tCK equivalent taps: "), _sdram_tck_taps, putchar('\n');

	if (_sdram_write_leveling_cmd_scan) {
		/* Center write leveling by varying cdly. Searching through all possible
		 * values is slow, but we can use a simple optimization method of iterativly
		 * scanning smaller ranges with decreasing step */
		if (_sdram_write_leveling_cdly_range_start != -1)
			cdly_range_start = _sdram_write_leveling_cdly_range_start;
		else
			cdly_range_start = 0;
		if (_sdram_write_leveling_cdly_range_end != -1)
			cdly_range_end = _sdram_write_leveling_cdly_range_end;
		else
			cdly_range_end = _sdram_tck_taps/2; /* Limit Clk/Cmd scan to 1/2 tCK */

		puts("  Cmd/Clk scan ("), puts_hex(cdly_range_start), putchar('-'), puts_hex(cdly_range_end), puts(")\n");
		if (SDRAM_PHY_DELAYS > 32)
			cdly_range_step = SDRAM_PHY_DELAYS/8;
		else
			cdly_range_step = 1;
		while (cdly_range_step > 0) {
			puts("  |");
			sdram_write_leveling_find_cmd_delay(&best_error, &best_count, &best_cdly,
					cdly_range_start, cdly_range_end, cdly_range_step);

			/* Small optimization - stop if we have zero error */
			if (best_error == 0)
				break;

			/* Use best result as the middle of next range */
			cdly_range_start = best_cdly - cdly_range_step;
			cdly_range_end = best_cdly + cdly_range_step + 1;
			if (cdly_range_start < 0)
				cdly_range_start = 0;
			if (cdly_range_end > 512)
				cdly_range_end = 512;

			cdly_range_step /= 4;
		}
		puts("| best: "), puts_hex(best_cdly), putchar('\n');
	} else {
		best_cdly = _sdram_write_leveling_cmd_delay;
	}
	puts("  Setting Cmd/Clk delay to "), puts_hex(best_cdly), puts(" taps.\n");
	/* Set working or forced delay */
	if (best_cdly >= 0) {
		sdram_rst_clock_delay();
		for (int i = 0; i < best_cdly; ++i) {
			sdram_inc_clock_delay();
		}
	}

	puts("  Data scan:\n");

	/* Re-run write leveling the final time */
	if (!sdram_write_leveling_scan(delays, 128, 1))
		return 0;

	return best_cdly >= 0;
}
#endif /*  SDRAM_PHY_WRITE_LEVELING_CAPABLE */

/*-----------------------------------------------------------------------*/
/* Read Leveling                                                         */
/*-----------------------------------------------------------------------*/

#if defined(SDRAM_PHY_WRITE_DQ_DQS_TRAINING_CAPABLE) || defined(SDRAM_PHY_WRITE_LATENCY_CALIBRATION_CAPABLE) || defined(SDRAM_PHY_READ_LEVELING_CAPABLE)

int read_dq_delay[SDRAM_PHY_MODULES];
void read_inc_dq_delay(int module) {
	/* Increment delay */
	read_dq_delay[module] = (read_dq_delay[module] + 1) & (SDRAM_PHY_DELAYS - 1);
	ddrphy_rdly_dq_inc_write(1);
}

void read_rst_dq_delay(int module) {
	/* Reset delay */
	read_dq_delay[module] = 0;
	ddrphy_rdly_dq_rst_write(1);
}

static unsigned int sdram_read_leveling_scan_module(int module, int bitslip, int show, int dq_line) {
	const unsigned int max_errors = _seed_array_length*READ_CHECK_TEST_PATTERN_MAX_ERRORS;
	int i;
	unsigned int score;
	unsigned int errors;

	/* Check test pattern for each delay value */
	score = 0;
	if (show)
		puts("  m"), puts_hex(module), puts(", b"), puts_hex(bitslip), puts(": |");
	sdram_leveling_action(module, dq_line, read_rst_dq_delay);
	for(i=0;i<SDRAM_PHY_DELAYS;i++) {
		int working;
		int _show = (i%MODULO == 0) & show;
		errors = run_test_pattern(module, dq_line);
		working = errors == 0;
		/* When any scan is working then the final score will always be higher then if no scan was working */
		score += (working * max_errors*SDRAM_PHY_DELAYS) + (max_errors - errors);
		if (_show) {
			print_scan_errors(errors);
		}
		sdram_leveling_action(module, dq_line, read_inc_dq_delay);
	}
	if (show)
		puts("| ");

	return score;
}

#endif // defined(SDRAM_PHY_WRITE_DQ_DQS_TRAINING_CAPABLE) || defined(SDRAM_PHY_WRITE_LATENCY_CALIBRATION_CAPABLE) || defined(SDRAM_PHY_READ_LEVELING_CAPABLE)

#ifdef SDRAM_PHY_READ_LEVELING_CAPABLE

int read_dq_bitslip[SDRAM_PHY_MODULES];
void read_inc_dq_bitslip(int module) {
	/* Increment bitslip */
	read_dq_bitslip[module] = (read_dq_bitslip[module] + 1) & (SDRAM_PHY_BITSLIPS - 1);
	ddrphy_rdly_dq_bitslip_write(1);
}

void read_rst_dq_bitslip(int module) {
/* Reset bitslip */
	read_dq_bitslip[module] = 0;
	ddrphy_rdly_dq_bitslip_rst_write(1);
}

void sdram_read_leveling(void) {
	int module;
	int bitslip;
	int dq_line;
	unsigned int score;
	unsigned int best_score;
	int best_bitslip;

	for(module=0; module<SDRAM_PHY_MODULES; module++) {
		for (dq_line = 0; dq_line < DQ_COUNT; dq_line++) {
			/* Scan possible read windows */
			best_score = 0;
			best_bitslip = 0;
			sdram_leveling_action(module, dq_line, read_rst_dq_bitslip);
			for(bitslip=0; bitslip<SDRAM_PHY_BITSLIPS; bitslip++) {
				/* Compute score */
				score = sdram_read_leveling_scan_module(module, bitslip, 1, dq_line);
				sdram_leveling_center_module(module, 1, 0,
					read_rst_dq_delay, read_inc_dq_delay, dq_line);
				putchar('\n');
				if (score > best_score) {
					best_bitslip = bitslip;
					best_score = score;
				}
				/* Exit */
				if (bitslip == SDRAM_PHY_BITSLIPS-1)
					break;
				/* Increment bitslip */
				sdram_leveling_action(module, dq_line, read_inc_dq_bitslip);
			}

			/* Select best read window */
#ifdef SDRAM_DELAY_PER_DQ
			puts("  best: m"), puts_hex(module), puts(", b"), puts_hex(best_bitslip), puts(", dq_line"), puts_hex(dq_line), putchar(' ');
#else
			puts("  best: m"), puts_hex(module), puts(", b"), puts_hex(best_bitslip), putchar(' ');
#endif // SDRAM_DELAY_PER_DQ
			sdram_leveling_action(module, dq_line, read_rst_dq_bitslip);
			for (bitslip=0; bitslip<best_bitslip; bitslip++)
				sdram_leveling_action(module, dq_line, read_inc_dq_bitslip);

			/* Re-do leveling on best read window*/
			sdram_leveling_center_module(module, 1, 0,
				read_rst_dq_delay, read_inc_dq_delay, dq_line);
			putchar('\n');
		}
	}
}

#endif // SDRAM_PHY_READ_LEVELING_CAPABLE

#endif /* CSR_DDRPHY_BASE */

/*-----------------------------------------------------------------------*/
/* Write latency calibration                                             */
/*-----------------------------------------------------------------------*/

#ifdef SDRAM_PHY_WRITE_LATENCY_CALIBRATION_CAPABLE

int write_dq_bitslip[SDRAM_PHY_MODULES];
void write_inc_dq_bitslip(int module) {
	/* Increment bitslip */
	write_dq_bitslip[module] = (write_dq_bitslip[module] + 1) & (SDRAM_PHY_BITSLIPS - 1);
	ddrphy_wdly_dq_bitslip_write(1);
}

void write_rst_dq_bitslip(int module) {
	/* Increment bitslip */
	write_dq_bitslip[module] = 0;
	ddrphy_wdly_dq_bitslip_rst_write(1);
}

int _sdram_write_leveling_bitslips[16];
void sdram_write_leveling_rst_bitslip(int module, int show) {
	_sdram_write_leveling_bitslips[module] = -1;
	if (show)
		puts("Reseting Bitslip of module "), puts_hex(module), putchar('\n');
}

static void sdram_write_latency_calibration(void) {
	int i;
	int module;
	int bitslip;
	int dq_line;
	unsigned int score;
	unsigned int subscore;
	unsigned int best_score;
	int best_bitslip;

	for(module = 0; module < SDRAM_PHY_MODULES; module++) {
		for (dq_line = 0; dq_line < DQ_COUNT; dq_line++) {
			/* Scan possible write windows */
			best_score   = 0;
			best_bitslip = -1;
			for(bitslip=0; bitslip<SDRAM_PHY_BITSLIPS; bitslip+=2) { /* +2 for tCK steps */
				if (SDRAM_WLC_DEBUG)
					putchar('m'), puts_hex(module), puts(" wb"), puts_hex(bitslip), puts(":\n");

				sdram_leveling_action(module, dq_line, write_rst_dq_bitslip);
				for (i=0; i<bitslip; i++) {
					sdram_leveling_action(module, dq_line, write_inc_dq_bitslip);
				}

				score = 0;
				sdram_leveling_action(module, dq_line, read_rst_dq_bitslip);

				for(i=0; i<SDRAM_PHY_BITSLIPS; i++) {
					/* Compute score */
					const int debug = SDRAM_WLC_DEBUG; // Local variable should be optimized out
					subscore = sdram_read_leveling_scan_module(module, i, debug, dq_line);
					// If SDRAM_WRITE_LATENCY_CALIBRATION_DEBUG was not defined, SDRAM_WLC_DEBUG will be defined as 0, so if(0) should be optimized out
					if (debug)
						putchar('\n');
					score = subscore > score ? subscore : score;
					/* Increment bitslip */
					sdram_leveling_action(module, dq_line, read_inc_dq_bitslip);
				}
				if (score > best_score) {
					best_bitslip = bitslip;
					best_score = score;
				}
			}

#ifdef SDRAM_PHY_WRITE_LEVELING_CAPABLE
			if (_sdram_write_leveling_bitslips[module] < 0)
				bitslip = best_bitslip;
			else
				bitslip = _sdram_write_leveling_bitslips[module];
#else
			bitslip = best_bitslip;
#endif // SDRAM_PHY_WRITE_LEVELING_CAPABLE
			if (bitslip == -1)
				putchar('m'), puts_hex(module), puts(":- ");
			else
#ifdef SDRAM_DELAY_PER_DQ
				putchar('m'), puts_hex(module), puts(" dq"), puts_hex(dq_line), putchar(':'), puts_hex(bitslip), putchar(' ');
#else
				putchar('m'), puts_hex(module), putchar(':'), puts_hex(bitslip), putchar(' ');
#endif // SDRAM_DELAY_PER_DQ

			if (SDRAM_WLC_DEBUG)
				putchar('\n');

			/* Reset bitslip */
			sdram_leveling_action(module, dq_line, write_rst_dq_bitslip);
			for (i=0; i<bitslip; i++) {
				sdram_leveling_action(module, dq_line, write_inc_dq_bitslip);
			}
#ifdef SDRAM_DELAY_PER_DQ
		putchar('\n');
#endif
		}
	}
#ifndef SDRAM_DELAY_PER_DQ
	putchar('\n');
#endif

}

#endif // SDRAM_PHY_WRITE_LATENCY_CALIBRATION_CAPABLE

/*-----------------------------------------------------------------------*/
/* Write DQ-DQS training                                                 */
/*-----------------------------------------------------------------------*/

#ifdef SDRAM_PHY_WRITE_DQ_DQS_TRAINING_CAPABLE

static void sdram_read_leveling_best_bitslip(int module, int dq_line) {
	unsigned int score;
	int bitslip;
	int best_bitslip = 0;
	unsigned int best_score = 0;

	sdram_leveling_action(module, dq_line, read_rst_dq_bitslip);
	for(bitslip=0; bitslip<SDRAM_PHY_BITSLIPS; bitslip++) {
		score = sdram_read_leveling_scan_module(module, bitslip, 0, dq_line);
		sdram_leveling_center_module(module, 0, 0,
			read_rst_dq_delay, read_inc_dq_delay, dq_line);
		if (score > best_score) {
			best_bitslip = bitslip;
			best_score = score;
		}
		if (bitslip == SDRAM_PHY_BITSLIPS-1)
			break;
		sdram_leveling_action(module, dq_line, read_inc_dq_bitslip);
	}

	/* Select best read window and re-center it */
	sdram_leveling_action(module, dq_line, read_rst_dq_bitslip);
	for (bitslip=0; bitslip<best_bitslip; bitslip++)
		sdram_leveling_action(module, dq_line, read_inc_dq_bitslip);
	sdram_leveling_center_module(module, 0, 0,
		read_rst_dq_delay, read_inc_dq_delay, dq_line);
}

static void sdram_write_dq_dqs_training(void) {
	int module;
	int dq_line;

	for(module=0; module<SDRAM_PHY_MODULES; module++) {
		for (dq_line = 0; dq_line < DQ_COUNT; dq_line++) {
			/* Find best bitslip */
			sdram_read_leveling_best_bitslip(module, dq_line);
			/* Center DQ-DQS window */
			sdram_leveling_center_module(module, 1, 1,
				write_rst_dq_delay, write_inc_dq_delay, dq_line);
		}
	}
}

#endif /* SDRAM_PHY_WRITE_DQ_DQS_TRAINING_CAPABLE */

/*-----------------------------------------------------------------------*/
/* Leveling                                                              */
/*-----------------------------------------------------------------------*/

int sdram_leveling(void) {
	int module;
	int dq_line;
	sdram_software_control_on();

	for(module=0; module<SDRAM_PHY_MODULES; module++) {
		for (dq_line = 0; dq_line < DQ_COUNT; dq_line++) {
#ifdef SDRAM_PHY_WRITE_LEVELING_CAPABLE
			sdram_leveling_action(module, dq_line, write_rst_delay);
#ifdef SDRAM_PHY_BITSLIPS
			sdram_leveling_action(module, dq_line, write_rst_dq_bitslip);
#endif // SDRAM_PHY_BITSLIPS
#endif // SDRAM_PHY_WRITE_LEVELING_CAPABLE

#ifdef SDRAM_PHY_READ_LEVELING_CAPABLE
			sdram_leveling_action(module, dq_line, read_rst_dq_delay);
#ifdef SDRAM_PHY_BITSLIPS
			sdram_leveling_action(module, dq_line, read_rst_dq_bitslip);
#endif // SDRAM_PHY_BITSLIPS
#endif // SDRAM_PHY_READ_LEVELING_CAPABLE
		}
	}

#ifdef SDRAM_PHY_WRITE_LEVELING_CAPABLE
	puts("Write leveling:\n");
	sdram_write_leveling();
#endif // SDRAM_PHY_WRITE_LEVELING_CAPABLE

#ifdef SDRAM_PHY_WRITE_LATENCY_CALIBRATION_CAPABLE
	puts("Write latency calibration:\n");
	sdram_write_latency_calibration();
#endif // SDRAM_PHY_WRITE_LATENCY_CALIBRATION_CAPABLE

#ifdef SDRAM_PHY_WRITE_DQ_DQS_TRAINING_CAPABLE
	puts("Write DQ-DQS training:\n");
	sdram_write_dq_dqs_training();
#endif // SDRAM_PHY_WRITE_DQ_DQS_TRAINING_CAPABLE

#ifdef SDRAM_PHY_READ_LEVELING_CAPABLE
	puts("Read leveling:\n");
	sdram_read_leveling();
#endif // SDRAM_PHY_READ_LEVELING_CAPABLE

	sdram_software_control_off();

	return 1;
}

/*-----------------------------------------------------------------------*/
/* Initialization                                                        */
/*-----------------------------------------------------------------------*/

int main(void) {
	#ifdef LITEDRAM_DEBUG
	serial0_init();
	#endif
	/* Reset Cmd/Dat delays */
#ifdef SDRAM_PHY_WRITE_LEVELING_CAPABLE
	int i;
	sdram_write_leveling_rst_cmd_delay(0);
	for (i=0; i<16; i++) sdram_write_leveling_rst_dat_delay(i, 0);
#ifdef SDRAM_PHY_BITSLIPS
	for (i=0; i<16; i++) sdram_write_leveling_rst_bitslip(i, 0);
#endif // SDRAM_PHY_BITSLIPS
#endif // SDRAM_PHY_WRITE_LEVELING_CAPABLE
	/* Reset Read/Write phases */
#ifdef CSR_DDRPHY_RDPHASE_ADDR
	ddrphy_rdphase_write(SDRAM_PHY_RDPHASE);
#endif // CSR_DDRPHY_RDPHASE_ADDR
#ifdef CSR_DDRPHY_WRPHASE_ADDR
	ddrphy_wrphase_write(SDRAM_PHY_WRPHASE);
#endif // CSR_DDRPHY_WRPHASE_ADDR
	/* Set Cmd delay if enforced at build time */
#ifdef SDRAM_PHY_CMD_DELAY
	_sdram_write_leveling_cmd_scan  = 0;
	_sdram_write_leveling_cmd_delay = SDRAM_PHY_CMD_DELAY;
#endif // SDRAM_PHY_CMD_DELAY
	puts("\nInitializing SDRAM @ 0x"), puts_hex(MAIN_RAM_BASE), putchar('\n');
	sdram_software_control_on();
#if CSR_DDRPHY_RST_ADDR
	ddrphy_rst_write(1);
	cdelay(1000);
	ddrphy_rst_write(0);
	cdelay(1000);
#endif // CSR_DDRPHY_RST_ADDR

#ifdef CSR_DDRCTRL_BASE
	ddrctrl_init_done_write(0);
	ddrctrl_init_error_write(0);
#endif // CSR_DDRCTRL_BASE
	init_sequence();
#if defined(SDRAM_PHY_WRITE_LEVELING_CAPABLE) || defined(SDRAM_PHY_READ_LEVELING_CAPABLE)
	sdram_leveling();
#endif // defined(SDRAM_PHY_WRITE_LEVELING_CAPABLE) || defined(SDRAM_PHY_READ_LEVELING_CAPABLE)
	sdram_software_control_off();
#ifdef CSR_DDRCTRL_BASE
	ddrctrl_init_done_write(1);
#endif // CSR_DDRCTRL_BASE

	return 1;
}

#endif // CSR_SDRAM_BASE

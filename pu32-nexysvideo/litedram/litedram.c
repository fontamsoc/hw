// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe
// Written using litex/soc/software/liblitedram/sdram.c

#include <stdint.h>

// Used to stringify.
#define __xstr__(s) __str__(s)
#define __str__(s) #s

static unsigned long stack[STACKSZ] __attribute__((used));

// Substitute for crt0.S since this is built using -nostdlib.
__asm__ (
	".section .text._start\n"
	".global  _start\n"
	".type    _start, @function\n"
	".p2align 1\n"
	"_start:\n"

	// Initialize %sp and %fp.
	"rli16 %sp, stack + "__xstr__(STACKSZ)"\n" // ### Manually encoding rli16 since linker-relaxation is not yet implemented.
	//"li8 %fp, 0\n" // ### Disabled, as it is unnecessary.
	"rli16 %sr, main\n" // ### Manually encoding rli16 since linker-relaxation is not yet implemented.
	"j %sr\n" // ### Note that %rp is expected to have been properly set.

	".size    _start, (. - _start)\n");

//#define LITEDRAM_DEBUG
#ifdef LITEDRAM_DEBUG
#define UARTADDR (0x0ff8 /* By convention, the first UART is located at 0x0ff8 */)
#define UARTBAUD 115200
#include <hwdrvchar/hwdrvchar.h>
hwdrvchar hwdrvchar_dev = {.addr = (void *)UARTADDR};
int putchar (int c) {
	while (!hwdrvchar_write(&hwdrvchar_dev, &c, 1));
	return c;
}
#include <print/print.h>
#endif

static void cdelay (unsigned long i) {
	asm volatile ( // At least 4 clock-cycles each loop.
		"rli8 %%sr, 0f; rli8 %1, 1f; 0:\n"
		"jz %0, %1; inc8 %0, -1; j %%sr; 1:\n"
		:: "r"(i), "r"((unsigned long){0}));
}

#define DFII_CONTROL_SEL        0x01
#define DFII_CONTROL_CKE        0x02
#define DFII_CONTROL_ODT        0x04
#define DFII_CONTROL_RESET_N    0x08

#define DFII_COMMAND_CS         0x01
#define DFII_COMMAND_WE         0x02
#define DFII_COMMAND_CAS        0x04
#define DFII_COMMAND_RAS        0x08
#define DFII_COMMAND_WRDATA     0x10
#define DFII_COMMAND_RDDATA     0x20

/* CSR subregisters (a.k.a. "simple CSRs") are embedded inside uint32_t
 * aligned locations: */
#define MMPTR(a) (*((volatile uint32_t *)(a)))

static unsigned long csr_read_simple (unsigned long a) {
	return MMPTR(a);
}
static void csr_write_simple (unsigned long v, unsigned long a) {
	MMPTR(a) = v;
}

#define CONFIG_CSR_DATA_WIDTH 8
#define CSR_SDRAM_DFII_PI0_WRDATA_SIZE 4
#define SDRAM_PHY_DFI_DATABITS 32
#define DFII_PIX_DATA_BYTES SDRAM_PHY_DFI_DATABITS/8
#define SDRAM_PHY_DATABITS 16
#define SDRAM_PHY_MODULES (SDRAM_PHY_DATABITS/8)

#define CSR_DW_BYTES (CONFIG_CSR_DATA_WIDTH/8)
#define CSR_OFFSET_BYTES 4
static inline int num_subregs (int csr_bytes) {
	return (csr_bytes - 1) / CSR_DW_BYTES + 1;
}
static inline uint64_t _csr_rd (unsigned long a, int csr_bytes) {
	uint64_t r = csr_read_simple(a);
	for (int i = 1; i < num_subregs(csr_bytes); i++) {
		r <<= CONFIG_CSR_DATA_WIDTH;
		a += CSR_OFFSET_BYTES;
		r |= csr_read_simple(a);
	}
	return r;
}
/* Read a CSR located at address 'a' into an array 'buf' of 'cnt' elements.
 * NOTE: Since CSR_DW_BYTES is a constant here, we might be tempted to further
 * optimize things by leaving out one or the other of the if() branches below,
 * depending on each unsigned type width;
 * However, this code is also meant to serve as a reference for how CSRs are
 * to be manipulated by other programs (e.g., an OS kernel), which may benefit
 * from dynamically handling multiple possible CSR subregister data widths
 * (e.g., by passing a value in through the Device Tree).
 * Ultimately, if CSR_DW_BYTES is indeed a constant, the compiler should be
 * able to determine on its own whether it can automatically optimize away one
 * of the if() branches! */
#define _csr_rd_buf(a, buf, cnt) { \
	int i, j, offset, nsubregs, nsubelems; \
	uint64_t r; \
	if (sizeof(buf[0]) >= CSR_DW_BYTES) { \
		/* One or more subregisters per element */ \
		for (i=0; i<cnt; i++) { \
			buf[i] = _csr_rd(a, sizeof(buf[0])); \
			a += CSR_OFFSET_BYTES * num_subregs(sizeof(buf[0])); \
		} \
	} else { \
		/* Multiple elements per subregister (2, 4, or 8) */ \
		nsubregs  = num_subregs(sizeof(buf[0]) * cnt); \
		nsubelems = CSR_DW_BYTES / sizeof(buf[0]); \
		offset    = nsubregs*nsubelems - cnt; \
		for (i=0; i<nsubregs; i++) { \
			r = csr_read_simple(a);	\
			for (j= nsubelems - 1; j >= 0; j--) { \
				if ((i * nsubelems + j - offset) >= 0) { \
					buf[i * nsubelems + j - offset] = r; \
					r >>= sizeof(buf[0]) * 8; \
				} \
			} \
			a += CSR_OFFSET_BYTES;	\
		} \
	} \
}
static inline void _csr_wr (unsigned long a, uint64_t v, int csr_bytes) {
	int ns = num_subregs(csr_bytes);
	for (int i = 0; i < ns; i++) {
		csr_write_simple(v >> (CONFIG_CSR_DATA_WIDTH * (ns - 1 - i)), a);
		a += CSR_OFFSET_BYTES;
	}
}
/* Write an array 'buf' of 'cnt' elements to a CSR located at address 'a'.
 * NOTE: The same optimization considerations apply here as with _csr_rd_buf()
 * above. */
#define _csr_wr_buf(a, buf, cnt) { \
	int i, j, offset, nsubregs, nsubelems; \
	uint64_t v; \
	if (sizeof(buf[0]) >= CSR_DW_BYTES) { \
		/* One or more subregisters per element */ \
		for (i = 0; i < cnt; i++) { \
			_csr_wr(a, buf[i], sizeof(buf[0])); \
			a += CSR_OFFSET_BYTES * num_subregs(sizeof(buf[0])); \
		} \
	} else { \
		/* Multiple elements per subregister (2, 4, or 8) */ \
		nsubregs  = num_subregs(sizeof(buf[0]) * cnt); \
		nsubelems = CSR_DW_BYTES / sizeof(buf[0]); \
		offset    = nsubregs*nsubelems - cnt; \
		for (i = 0; i < nsubregs; i++) { \
			v = 0; \
			for (j= 0; j < nsubelems; j++) { \
				if ((i * nsubelems + j - offset) >= 0) { \
					v <<= sizeof(buf[0]) * 8; \
					v |= buf[i * nsubelems + j - offset]; \
				} \
			} \
			csr_write_simple(v, a); \
			a += CSR_OFFSET_BYTES;	\
		} \
	} \
}
static inline void csr_wr_buf_uint8 (unsigned long a, const uint8_t *buf, int cnt) {
	_csr_wr_buf(a, buf, cnt);
}
static inline void csr_rd_buf_uint8 (unsigned long a, uint8_t *buf, int cnt) {
	_csr_rd_buf(a, buf, cnt);
}

#define CSR_SDRAM_DFII_PI0_ADDRESS_ADDR (CSR_BASE + 0x100cL)
static void sdram_dfii_pi0_address_write (unsigned long v) {
	csr_write_simple(v >> 8, CSR_SDRAM_DFII_PI0_ADDRESS_ADDR);
	csr_write_simple(v, (CSR_SDRAM_DFII_PI0_ADDRESS_ADDR+CSR_OFFSET_BYTES));
}

#define CSR_SDRAM_DFII_PI0_BADDRESS_ADDR (CSR_BASE + 0x1014L)
static void sdram_dfii_pi0_baddress_write (unsigned long v) {
	csr_write_simple(v, CSR_SDRAM_DFII_PI0_BADDRESS_ADDR);
}

#define CSR_SDRAM_DFII_CONTROL_ADDR (CSR_BASE + 0x1000L)
static unsigned long sdram_dfii_control_read (void) {
	return csr_read_simple(CSR_SDRAM_DFII_CONTROL_ADDR);
}
static void sdram_dfii_control_write (unsigned long v) {
	csr_write_simple(v, CSR_SDRAM_DFII_CONTROL_ADDR);
}

#define CSR_SDRAM_DFII_PI0_COMMAND_ADDR (CSR_BASE + 0x1004L)
static void sdram_dfii_pi0_command_write (unsigned long v) {
	csr_write_simple(v, CSR_SDRAM_DFII_PI0_COMMAND_ADDR);
}

#define CSR_SDRAM_DFII_PI0_COMMAND_ISSUE_ADDR (CSR_BASE + 0x1008L)
static void sdram_dfii_pi0_command_issue_write (unsigned long v) {
	csr_write_simple(v, CSR_SDRAM_DFII_PI0_COMMAND_ISSUE_ADDR);
}

#define CSR_SDRAM_DFII_PI1_ADDRESS_ADDR (CSR_BASE + 0x1040L)
static void sdram_dfii_pi1_address_write (unsigned long v) {
	csr_write_simple(v >> 8, CSR_SDRAM_DFII_PI1_ADDRESS_ADDR);
	csr_write_simple(v, (CSR_SDRAM_DFII_PI1_ADDRESS_ADDR+CSR_OFFSET_BYTES));
}

#define CSR_SDRAM_DFII_PI1_BADDRESS_ADDR (CSR_BASE + 0x1048L)
static void sdram_dfii_pi1_baddress_write (unsigned long v) {
	csr_write_simple(v, CSR_SDRAM_DFII_PI1_BADDRESS_ADDR);
}

#define CSR_DDRPHY_RDPHASE_ADDR (CSR_BASE + 0x82cL)
static unsigned long ddrphy_rdphase_read (void) {
	return csr_read_simple(CSR_DDRPHY_RDPHASE_ADDR);
}
static void ddrphy_rdphase_write (unsigned long v) {
	csr_write_simple(v, CSR_DDRPHY_RDPHASE_ADDR);
}

#define CSR_DDRPHY_WRPHASE_ADDR (CSR_BASE + 0x830L)
static unsigned long ddrphy_wrphase_read (void) {
	return csr_read_simple(CSR_DDRPHY_WRPHASE_ADDR);
}
static void ddrphy_wrphase_write (unsigned long v) {
	csr_write_simple(v, CSR_DDRPHY_WRPHASE_ADDR);
}

#define CSR_SDRAM_DFII_PI1_COMMAND_ADDR (CSR_BASE + 0x1038L)
static void sdram_dfii_pi1_command_write (unsigned long v) {
	csr_write_simple(v, CSR_SDRAM_DFII_PI1_COMMAND_ADDR);
}

#define CSR_SDRAM_DFII_PI1_COMMAND_ISSUE_ADDR (CSR_BASE + 0x103cL)
static void sdram_dfii_pi1_command_issue_write (unsigned long v) {
	csr_write_simple(v, CSR_SDRAM_DFII_PI1_COMMAND_ISSUE_ADDR);
}

#define CSR_DDRPHY_RST_ADDR (CSR_BASE + 0x800L)
static void ddrphy_rst_write (unsigned long v) {
	csr_write_simple(v, CSR_DDRPHY_RST_ADDR);
}

#define CSR_DDRCTRL_INIT_DONE_ADDR (CSR_BASE + 0x0L)
static void ddrctrl_init_done_write (unsigned long v) {
	csr_write_simple(v, CSR_DDRCTRL_INIT_DONE_ADDR);
}

#define CSR_DDRCTRL_INIT_ERROR_ADDR (CSR_BASE + 0x4L)
static void ddrctrl_init_error_write (unsigned long v) {
	csr_write_simple(v, CSR_DDRCTRL_INIT_ERROR_ADDR);
}

#define CSR_DDRPHY_DLY_SEL_ADDR (CSR_BASE + 0x810L)
static void ddrphy_dly_sel_write (unsigned long v) {
	csr_write_simple(v, CSR_DDRPHY_DLY_SEL_ADDR);
}

#define CSR_DDRPHY_RDLY_DQ_RST_ADDR (CSR_BASE + 0x814L)
static void ddrphy_rdly_dq_rst_write (unsigned long v) {
	csr_write_simple(v, CSR_DDRPHY_RDLY_DQ_RST_ADDR);
}

#define CSR_DDRPHY_RDLY_DQ_BITSLIP_RST_ADDR (CSR_BASE + 0x81cL)
static void ddrphy_rdly_dq_bitslip_rst_write (unsigned long v) {
	csr_write_simple(v, CSR_DDRPHY_RDLY_DQ_BITSLIP_RST_ADDR);
}

#define CSR_DDRPHY_WDLY_DQ_BITSLIP_RST_ADDR (CSR_BASE + 0x824L)
static void ddrphy_wdly_dq_bitslip_rst_write (unsigned long v) {
	csr_write_simple(v, CSR_DDRPHY_WDLY_DQ_BITSLIP_RST_ADDR);
}

#define CSR_DDRPHY_WDLY_DQ_BITSLIP_ADDR (CSR_BASE + 0x828L)
static void ddrphy_wdly_dq_bitslip_write (unsigned long v) {
	csr_write_simple(v, CSR_DDRPHY_WDLY_DQ_BITSLIP_ADDR);
}

#define CSR_DDRPHY_RDLY_DQ_INC_ADDR (CSR_BASE + 0x818L)
static void ddrphy_rdly_dq_inc_write (unsigned long v) {
	csr_write_simple(v, CSR_DDRPHY_RDLY_DQ_INC_ADDR);
}

#define CSR_DDRPHY_RDLY_DQ_BITSLIP_ADDR (CSR_BASE + 0x820L)
static void ddrphy_rdly_dq_bitslip_write (unsigned long v) {
	csr_write_simple(v, CSR_DDRPHY_RDLY_DQ_BITSLIP_ADDR);
}

#define CSR_SDRAM_DFII_PI2_ADDRESS_ADDR (CSR_BASE + 0x1074L)
static void sdram_dfii_pi2_address_write (unsigned long v) {
	csr_write_simple(v >> 8, CSR_SDRAM_DFII_PI2_ADDRESS_ADDR);
	csr_write_simple(v, (CSR_SDRAM_DFII_PI2_ADDRESS_ADDR+CSR_OFFSET_BYTES));
}

#define CSR_SDRAM_DFII_PI2_BADDRESS_ADDR (CSR_BASE + 0x107cL)
static void sdram_dfii_pi2_baddress_write (unsigned long v) {
	csr_write_simple(v, CSR_SDRAM_DFII_PI2_BADDRESS_ADDR);
}

#define CSR_SDRAM_DFII_PI2_COMMAND_ADDR (CSR_BASE + 0x106cL)
static void sdram_dfii_pi2_command_write (unsigned long v) {
	csr_write_simple(v, CSR_SDRAM_DFII_PI2_COMMAND_ADDR);
}

#define CSR_SDRAM_DFII_PI2_COMMAND_ISSUE_ADDR (CSR_BASE + 0x1070L)
static void sdram_dfii_pi2_command_issue_write (unsigned long v) {
	csr_write_simple(v, CSR_SDRAM_DFII_PI2_COMMAND_ISSUE_ADDR);
}

#define CSR_SDRAM_DFII_PI3_ADDRESS_ADDR (CSR_BASE + 0x10a8L)
static void sdram_dfii_pi3_address_write (unsigned long v) {
	csr_write_simple(v >> 8, CSR_SDRAM_DFII_PI3_ADDRESS_ADDR);
	csr_write_simple(v, (CSR_SDRAM_DFII_PI3_ADDRESS_ADDR+CSR_OFFSET_BYTES));
}

#define CSR_SDRAM_DFII_PI3_BADDRESS_ADDR (CSR_BASE + 0x10b0L)
static void sdram_dfii_pi3_baddress_write (unsigned long v) {
	csr_write_simple(v, CSR_SDRAM_DFII_PI3_BADDRESS_ADDR);
}

#define CSR_SDRAM_DFII_PI3_COMMAND_ADDR (CSR_BASE + 0x10a0L)
static void sdram_dfii_pi3_command_write (unsigned long v) {
	csr_write_simple(v, CSR_SDRAM_DFII_PI3_COMMAND_ADDR);
}

#define CSR_SDRAM_DFII_PI3_COMMAND_ISSUE_ADDR (CSR_BASE + 0x10a4L)
static void sdram_dfii_pi3_command_issue_write (unsigned long v) {
	csr_write_simple(v, CSR_SDRAM_DFII_PI3_COMMAND_ISSUE_ADDR);
}

#define SDRAM_PHY_PHASES 4

#define CSR_SDRAM_DFII_PI0_WRDATA_ADDR (CSR_BASE + 0x1018L)
#define CSR_SDRAM_DFII_PI1_WRDATA_ADDR (CSR_BASE + 0x104cL)
#define CSR_SDRAM_DFII_PI2_WRDATA_ADDR (CSR_BASE + 0x1080L)
#define CSR_SDRAM_DFII_PI3_WRDATA_ADDR (CSR_BASE + 0x10b4L)
const unsigned long sdram_dfii_pix_wrdata_addr[SDRAM_PHY_PHASES] = {
	CSR_SDRAM_DFII_PI0_WRDATA_ADDR,
	CSR_SDRAM_DFII_PI1_WRDATA_ADDR,
	CSR_SDRAM_DFII_PI2_WRDATA_ADDR,
	CSR_SDRAM_DFII_PI3_WRDATA_ADDR
};

#define CSR_SDRAM_DFII_PI0_RDDATA_ADDR (CSR_BASE + 0x1028L)
#define CSR_SDRAM_DFII_PI1_RDDATA_ADDR (CSR_BASE + 0x105cL)
#define CSR_SDRAM_DFII_PI2_RDDATA_ADDR (CSR_BASE + 0x1090L)
#define CSR_SDRAM_DFII_PI3_RDDATA_ADDR (CSR_BASE + 0x10c4L)
const unsigned long sdram_dfii_pix_rddata_addr[SDRAM_PHY_PHASES] = {
	CSR_SDRAM_DFII_PI0_RDDATA_ADDR,
	CSR_SDRAM_DFII_PI1_RDDATA_ADDR,
	CSR_SDRAM_DFII_PI2_RDDATA_ADDR,
	CSR_SDRAM_DFII_PI3_RDDATA_ADDR
};

static void sdram_dfii_pix_address_write (unsigned long phase, unsigned long value) {
	#if (SDRAM_PHY_PHASES > 8)
		#error "More than 8 DFI phases not supported"
	#endif
	switch (phase) {
		#if (SDRAM_PHY_PHASES > 4)
		case 7: sdram_dfii_pi7_address_write(value); break;
		case 6: sdram_dfii_pi6_address_write(value); break;
		case 5: sdram_dfii_pi5_address_write(value); break;
		case 4: sdram_dfii_pi4_address_write(value); break;
		#endif
		#if (SDRAM_PHY_PHASES > 2)
		case 3: sdram_dfii_pi3_address_write(value); break;
		case 2: sdram_dfii_pi2_address_write(value); break;
		#endif
		#if (SDRAM_PHY_PHASES > 1)
		case 1: sdram_dfii_pi1_address_write(value); break;
		#endif
		default: sdram_dfii_pi0_address_write(value);
	}
}

static void sdram_dfii_pird_address_write (unsigned long value) {
	unsigned long rdphase = ddrphy_rdphase_read();
	sdram_dfii_pix_address_write(rdphase, value);
}

static void sdram_dfii_piwr_address_write (unsigned long value) {
	unsigned long wrphase = ddrphy_wrphase_read();
	sdram_dfii_pix_address_write(wrphase, value);
}

static void sdram_dfii_pix_baddress_write (unsigned long phase, unsigned long value) {
	#if (SDRAM_PHY_PHASES > 8)
		#error "More than 8 DFI phases not supported"
	#endif
	switch (phase) {
		#if (SDRAM_PHY_PHASES > 4)
		case 7: sdram_dfii_pi7_baddress_write(value); break;
		case 6: sdram_dfii_pi6_baddress_write(value); break;
		case 5: sdram_dfii_pi5_baddress_write(value); break;
		case 4: sdram_dfii_pi4_baddress_write(value); break;
		#endif
		#if (SDRAM_PHY_PHASES > 2)
		case 3: sdram_dfii_pi3_baddress_write(value); break;
		case 2: sdram_dfii_pi2_baddress_write(value); break;
		#endif
		#if (SDRAM_PHY_PHASES > 1)
		case 1: sdram_dfii_pi1_baddress_write(value); break;
		#endif
		default: sdram_dfii_pi0_baddress_write(value);
	}
}

static void sdram_dfii_pird_baddress_write (unsigned long value) {
	unsigned long rdphase = ddrphy_rdphase_read();
	sdram_dfii_pix_baddress_write(rdphase, value);
}

static void sdram_dfii_piwr_baddress_write (unsigned long value) {
	unsigned long wrphase = ddrphy_wrphase_read();
	sdram_dfii_pix_baddress_write(wrphase, value);
}

static void command_p0 (unsigned long cmd) {
	sdram_dfii_pi0_command_write(cmd);
	sdram_dfii_pi0_command_issue_write(1);
}

static void command_p1 (unsigned long cmd) {
	sdram_dfii_pi1_command_write(cmd);
	sdram_dfii_pi1_command_issue_write(1);
}

static void command_p2 (unsigned long cmd) {
	sdram_dfii_pi2_command_write(cmd);
	sdram_dfii_pi2_command_issue_write(1);
}

static void command_p3 (unsigned long cmd) {
	sdram_dfii_pi3_command_write(cmd);
	sdram_dfii_pi3_command_issue_write(1);
}

static void command_px (unsigned long phase, unsigned long value) {
	#if (SDRAM_PHY_PHASES > 8)
		#error "More than 8 DFI phases not supported"
	#endif
	switch (phase) {
		#if (SDRAM_PHY_PHASES > 4)
		case 7: command_p7(value); break;
		case 6: command_p6(value); break;
		case 5: command_p5(value); break;
		case 4: command_p4(value); break;
		#endif
		#if (SDRAM_PHY_PHASES > 2)
		case 3: command_p3(value); break;
		case 2: command_p2(value); break;
		#endif
		#if (SDRAM_PHY_PHASES > 1)
		case 1: command_p1(value); break;
		#endif
		default: command_p0(value);
	}
}

static void command_prd (unsigned long value) {
	unsigned long rdphase = ddrphy_rdphase_read();
	command_px(rdphase, value);
}

static void command_pwr (unsigned long value) {
	unsigned long wrphase = ddrphy_wrphase_read();
	command_px(wrphase, value);
}

#define DFII_CONTROL_SOFTWARE (DFII_CONTROL_CKE|DFII_CONTROL_ODT|DFII_CONTROL_RESET_N)
#define DFII_CONTROL_HARDWARE (DFII_CONTROL_SEL)

static void sdram_software_control_on (void) {
	unsigned long previous;
	previous = sdram_dfii_control_read();
	/* Switch DFII to software control */
	if (previous != DFII_CONTROL_SOFTWARE) {
		sdram_dfii_control_write(DFII_CONTROL_SOFTWARE);
	}
}

static void sdram_software_control_off (void) {
	unsigned long previous;
	previous = sdram_dfii_control_read();
	/* Switch DFII to hardware control */
	if (previous != DFII_CONTROL_HARDWARE) {
		sdram_dfii_control_write(DFII_CONTROL_HARDWARE);
	}
}

static void sdram_read_leveling_rst_delay (unsigned long module) {
	/* Select module */
	ddrphy_dly_sel_write(1 << module);
	/* Reset delay */
	ddrphy_rdly_dq_rst_write(1);
	/* Un-select module */
	ddrphy_dly_sel_write(0);
}

static void sdram_read_leveling_rst_bitslip (unsigned long m) {
	/* Select module */
	ddrphy_dly_sel_write(1 << m);
	/* Reset delay */
	ddrphy_rdly_dq_bitslip_rst_write(1);
	/* Un-select module */
	ddrphy_dly_sel_write(0);
}

static void sdram_activate_test_row (void) {
	sdram_dfii_pi0_address_write(0);
	sdram_dfii_pi0_baddress_write(0);
	command_p0(DFII_COMMAND_RAS|DFII_COMMAND_CS);
	cdelay(15);
}

static void sdram_precharge_test_row (void) {
	sdram_dfii_pi0_address_write(0);
	sdram_dfii_pi0_baddress_write(0);
	command_p0(DFII_COMMAND_RAS|DFII_COMMAND_WE|DFII_COMMAND_CS);
	cdelay(15);
}

#include "lfsr.h"

// Count number of bits in a 32-bit word, faster version than a while loop
// see: https://www.johndcook.com/blog/2020/02/21/popcount/
static unsigned int popcount (unsigned int x) {
	x -= ((x >> 1) & 0x55555555);
	x = (x & 0x33333333) + ((x >> 2) & 0x33333333);
	x = (x + (x >> 4)) & 0x0F0F0F0F;
	x += (x >> 8);
	x += (x >> 16);
	return x & 0x0000003F;
}

static unsigned int sdram_write_read_check_test_pattern (int module, unsigned int seed) {
	int p, i;
	unsigned int errors;
	unsigned int prv;
	unsigned char tst[DFII_PIX_DATA_BYTES];
	unsigned char prs[SDRAM_PHY_PHASES][DFII_PIX_DATA_BYTES];
	/* Generate pseudo-random sequence */
	prv = seed;
	for(p=0;p<SDRAM_PHY_PHASES;p++) {
		for(i=0;i<DFII_PIX_DATA_BYTES;i++) {
			prv = lfsr(32, prv);
			prs[p][i] = prv;
		}
	}
	/* Activate */
	sdram_activate_test_row();
	/* Write pseudo-random sequence */
	for(p=0;p<SDRAM_PHY_PHASES;p++)
		csr_wr_buf_uint8(sdram_dfii_pix_wrdata_addr[p], prs[p], DFII_PIX_DATA_BYTES);
	sdram_dfii_piwr_address_write(0);
	sdram_dfii_piwr_baddress_write(0);
	command_pwr(DFII_COMMAND_CAS|DFII_COMMAND_WE|DFII_COMMAND_CS|DFII_COMMAND_WRDATA);
	cdelay(15);
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
		csr_rd_buf_uint8(sdram_dfii_pix_rddata_addr[p], tst, DFII_PIX_DATA_BYTES);
		/* Verify bytes matching current 'module' */
		for (int i = 0; i < DFII_PIX_DATA_BYTES; ++i) {
			int j = p * DFII_PIX_DATA_BYTES + i;
			if (j % SDRAM_PHY_MODULES == SDRAM_PHY_MODULES-1-module) {
				errors += popcount(prs[p][i] ^ tst[i]);
			}
		}
	}
	return errors;
}

static void sdram_read_leveling_inc_delay (unsigned long module) {
	/* Select module */
	ddrphy_dly_sel_write(1 << module);
	/* Increment delay */
	ddrphy_rdly_dq_inc_write(1);
	/* Un-select module */
	ddrphy_dly_sel_write(0);
}

#define READ_CHECK_TEST_PATTERN_MAX_ERRORS (8*SDRAM_PHY_PHASES*DFII_PIX_DATA_BYTES/SDRAM_PHY_MODULES)

#define SDRAM_PHY_DELAYS 32

static unsigned int sdram_read_leveling_scan_module (int module) {
	const unsigned int max_errors = 2*READ_CHECK_TEST_PATTERN_MAX_ERRORS;
	int i;
	unsigned int score;
	unsigned int errors;
	/* Check test pattern for each delay value */
	score = 0;
	sdram_read_leveling_rst_delay(module);
	for(i=0;i<SDRAM_PHY_DELAYS;i++) {
		int working;
		errors  = sdram_write_read_check_test_pattern(module, 42);
		errors += sdram_write_read_check_test_pattern(module, 84);
		working = errors == 0;
		/* When any scan is working then the final score will always be higher then if no scan was working */
		score += (working * max_errors*SDRAM_PHY_DELAYS) + (max_errors - errors);
		sdram_read_leveling_inc_delay(module);
	}
	return score;
}

static void sdram_read_leveling_inc_bitslip (unsigned long m) {
	/* Select module */
	ddrphy_dly_sel_write(1 << m);
	/* Increment delay */
	ddrphy_rdly_dq_bitslip_write(1);
	/* Un-select module */
	ddrphy_dly_sel_write(0);
}

typedef void (*delay_callback)(unsigned long module);

static void sdram_leveling_center_module (int module, delay_callback rst_delay, delay_callback inc_delay) {
	int i;
	int show;
	int working;
	unsigned int errors;
	int delay, delay_mid, delay_range;
	int delay_min = -1, delay_max = -1;
	/* Find smallest working delay */
	delay = 0;
	rst_delay(module);
	while(1) {
		errors  = sdram_write_read_check_test_pattern(module, 42);
		errors += sdram_write_read_check_test_pattern(module, 84);
		working = errors == 0;
		if(working && delay_min < 0) {
			delay_min = delay;
			break;
		}
		delay++;
		if(delay >= SDRAM_PHY_DELAYS)
			break;
		inc_delay(module);
	}
	/* Get a bit further into the working zone */
	delay++;
	inc_delay(module);
	/* Find largest working delay */
	while(1) {
		errors  = sdram_write_read_check_test_pattern(module, 42);
		errors += sdram_write_read_check_test_pattern(module, 84);
		working = errors == 0;
		if(!working && delay_max < 0) {
			delay_max = delay;
		}
		delay++;
		if(delay >= SDRAM_PHY_DELAYS)
			break;
		inc_delay(module);
	}
	if(delay_max < 0) {
		delay_max = delay;
	}
	delay_mid = (delay_min+delay_max)/2 % SDRAM_PHY_DELAYS;
	delay_range = (delay_max-delay_min)/2;
	/* Set delay to the middle */
	rst_delay(module);
	cdelay(100);
	for(i = 0; i < delay_mid; i++) {
		inc_delay(module);
		cdelay(100);
	}
}

#define SDRAM_PHY_BITSLIPS 8

void sdram_read_leveling (void) {
	int module;
	int bitslip;
	unsigned int score;
	unsigned int best_score;
	int best_bitslip;
	for(module=0; module<SDRAM_PHY_MODULES; module++) {
		/* Scan possible read windows */
		best_score = 0;
		best_bitslip = 0;
		sdram_read_leveling_rst_bitslip(module);
		for(bitslip=0; bitslip<SDRAM_PHY_BITSLIPS; bitslip++) {
			/* Compute score */
			score = sdram_read_leveling_scan_module(module);
			sdram_leveling_center_module(module, sdram_read_leveling_rst_delay, sdram_read_leveling_inc_delay);
			if (score > best_score) {
				best_bitslip = bitslip;
				best_score = score;
			}
			/* Exit */
			if (bitslip == SDRAM_PHY_BITSLIPS-1)
				break;
			/* Increment bitslip */
			sdram_read_leveling_inc_bitslip(module);
		}
		/* Select best read window */
		sdram_read_leveling_rst_bitslip(module);
		for (bitslip=0; bitslip<best_bitslip; bitslip++)
			sdram_read_leveling_inc_bitslip(module);
		/* Re-do leveling on best read window*/
		sdram_leveling_center_module(module, sdram_read_leveling_rst_delay, sdram_read_leveling_inc_delay);
	}
}

static void sdram_write_latency_calibration (void) {
	int i;
	int module;
	int bitslip;
	unsigned int score;
	unsigned int subscore;
	unsigned int best_score;
	int best_bitslip;
	for(module=0; module<SDRAM_PHY_MODULES; module++) {
		#ifdef LITEDRAM_DEBUG
		printstr(".");
		#endif
		/* Scan possible write windows */
		best_score   = 0;
		best_bitslip = -1;
		for (bitslip=0; bitslip<SDRAM_PHY_BITSLIPS; bitslip+=2) { /* +2 for tCK steps */
			#ifdef LITEDRAM_DEBUG
			printstr("+");
			#endif
			score = 0;
			/* Select module */
			ddrphy_dly_sel_write(1 << module);
			/* Reset bitslip */
			ddrphy_wdly_dq_bitslip_rst_write(1);
			for (i=0; i<bitslip; i++) {
				#ifdef LITEDRAM_DEBUG
				printstr("-");
				#endif
				ddrphy_wdly_dq_bitslip_write(1);
			}
			/* Un-select module */
			ddrphy_dly_sel_write(0);
			score = 0;
			sdram_read_leveling_rst_bitslip(module);
			for(i=0; i<SDRAM_PHY_BITSLIPS; i++) {
				#ifdef LITEDRAM_DEBUG
				printstr("=");
				#endif
				/* Compute score */
				subscore = sdram_read_leveling_scan_module(module);
				score = subscore > score ? subscore : score;
				/* Increment bitslip */
				sdram_read_leveling_inc_bitslip(module);
			}
			#ifdef LITEDRAM_DEBUG
			printstr(" $ "); printhex(score); printstr(" | "); printhex(best_score);
			#endif
			if (score > best_score) {
				best_bitslip = bitslip;
				best_score = score;
			}
		}
		bitslip = best_bitslip;
		/* Select best write window */
		ddrphy_dly_sel_write(1 << module);
		/* Reset bitslip */
		ddrphy_wdly_dq_bitslip_rst_write(1);
		for (i=0; i<bitslip; i++) {
			#ifdef LITEDRAM_DEBUG
			printstr(" # "); printhex(i); printstr("/"); printhex(bitslip);
			#endif
			ddrphy_wdly_dq_bitslip_write(1);
		}
		/* Un-select module */
		ddrphy_dly_sel_write(0);
	}
}

void sdram_leveling (void) {
	sdram_software_control_on();
	for (unsigned long module=0; module<SDRAM_PHY_MODULES; module++) {
		sdram_read_leveling_rst_delay(module);
		sdram_read_leveling_rst_bitslip(module);
	}
	#ifdef LITEDRAM_DEBUG
	printstr("ram initialization: 2\n");
	#endif
	sdram_write_latency_calibration();
	#ifdef LITEDRAM_DEBUG
	printstr("\n");
	printstr("ram initialization: 3\n");
	#endif
	sdram_read_leveling();
	#ifdef LITEDRAM_DEBUG
	printstr("\n");
	printstr("ram initialization: 4\n");
	#endif
}

static void init_sequence (void) {
	/* Release reset */
	sdram_dfii_pi0_address_write(0x0);
	sdram_dfii_pi0_baddress_write(0);
	sdram_dfii_control_write(DFII_CONTROL_ODT|DFII_CONTROL_RESET_N);
	cdelay(50000);
	/* Bring CKE high */
	sdram_dfii_pi0_address_write(0x0);
	sdram_dfii_pi0_baddress_write(0);
	sdram_dfii_control_write(DFII_CONTROL_CKE|DFII_CONTROL_ODT|DFII_CONTROL_RESET_N);
	cdelay(10000);
	/* Load Mode Register 2, CWL=5 */
	sdram_dfii_pi0_address_write(0x200);
	sdram_dfii_pi0_baddress_write(2);
	command_p0(DFII_COMMAND_RAS|DFII_COMMAND_CAS|DFII_COMMAND_WE|DFII_COMMAND_CS);
	/* Load Mode Register 3 */
	sdram_dfii_pi0_address_write(0x0);
	sdram_dfii_pi0_baddress_write(3);
	command_p0(DFII_COMMAND_RAS|DFII_COMMAND_CAS|DFII_COMMAND_WE|DFII_COMMAND_CS);
	/* Load Mode Register 1 */
	sdram_dfii_pi0_address_write(0x6);
	sdram_dfii_pi0_baddress_write(1);
	command_p0(DFII_COMMAND_RAS|DFII_COMMAND_CAS|DFII_COMMAND_WE|DFII_COMMAND_CS);
	/* Load Mode Register 0, CL=7, BL=8 */
	sdram_dfii_pi0_address_write(0x930);
	sdram_dfii_pi0_baddress_write(0);
	command_p0(DFII_COMMAND_RAS|DFII_COMMAND_CAS|DFII_COMMAND_WE|DFII_COMMAND_CS);
	cdelay(200);
	/* ZQ Calibration */
	sdram_dfii_pi0_address_write(0x400);
	sdram_dfii_pi0_baddress_write(0);
	command_p0(DFII_COMMAND_WE|DFII_COMMAND_CS);
	cdelay(200);
}

#define SDRAM_PHY_RDPHASE 2
#define SDRAM_PHY_WRPHASE 3

void main (void) {
	#ifdef LITEDRAM_DEBUG
	hwdrvchar_init (&hwdrvchar_dev, UARTBAUD);
	printstr("begin ram initialization\n");
	#endif
	ddrphy_rdphase_write(SDRAM_PHY_RDPHASE);
	ddrphy_wrphase_write(SDRAM_PHY_WRPHASE);
	sdram_software_control_on();
	ddrphy_rst_write(1);
	cdelay(1000);
	ddrphy_rst_write(0);
	cdelay(1000);
	ddrctrl_init_done_write(0);
	ddrctrl_init_error_write(0);
	#ifdef LITEDRAM_DEBUG
	printstr("ram initialization: 0\n");
	#endif
	init_sequence();
	#ifdef LITEDRAM_DEBUG
	printstr("ram initialization: 1\n");
	#endif
	sdram_leveling();
	sdram_software_control_off();
	ddrctrl_init_done_write(1);
	#ifdef LITEDRAM_DEBUG
	printstr("litedram initialized\n");
	#endif
}

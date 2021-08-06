// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe
// Written using litex/soc/software/liblitedram/sdram.c

#include <stdint.h>

#define __xstr__(s) __str__(s)
#define __str__(s) #s

static unsigned long stack[STACKSZ] __attribute__((used));

__asm__ (
	".section .text._start\n"
	".global  _start\n"
	".type    _start, @function\n"
	".p2align 1\n"
	"_start:\n"

	"rli16 %sr, _end\n"
	"setksl %sr\n"
	"rli16 %sp, stack + "__xstr__(STACKSZ)"\n"
	"rli16 %sr, main\n"
	"j %sr\n"

	".size    _start, (. - _start)\n");

static void cdelay (unsigned long i) {
	asm volatile (
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

#define MMPTR(a) (*((volatile uint32_t *)(a)))

static unsigned long csr_read_simple (unsigned long a) {
	return MMPTR(a);
}
static void csr_write_simple (unsigned long v, unsigned long a) {
	MMPTR(a) = v;
}

#define CONFIG_CSR_DATA_WIDTH 8
#define CSR_SDRAM_DFII_PI0_WRDATA_SIZE 4
#define DFII_PIX_DATA_SIZE CSR_SDRAM_DFII_PI0_WRDATA_SIZE
#define DFII_PIX_DATA_BYTES DFII_PIX_DATA_SIZE*CONFIG_CSR_DATA_WIDTH/8
#define SDRAM_PHY_MODULES DFII_PIX_DATA_BYTES/2

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
#define _csr_rd_buf(a, buf, cnt) \
{ \
	int i, j, nsubs, n_sub_elem; \
	uint64_t r; \
	if (sizeof(buf[0]) >= CSR_DW_BYTES) { \
		/* one or more subregisters per element */ \
		for (i = 0; i < cnt; i++) { \
			buf[i] = _csr_rd(a, sizeof(buf[0])); \
			a += CSR_OFFSET_BYTES * num_subregs(sizeof(buf[0])); \
		} \
	} else { \
		/* multiple elements per subregister (2, 4, or 8) */ \
		nsubs = num_subregs(sizeof(buf[0]) * cnt); \
		n_sub_elem = CSR_DW_BYTES / sizeof(buf[0]); \
		for (i = 0; i < nsubs; i++) { \
			r = csr_read_simple(a);		\
			for (j = n_sub_elem - 1; j >= 0; j--) { \
				if (i * n_sub_elem + j < cnt) \
					buf[i * n_sub_elem + j] = r; \
				r >>= sizeof(buf[0]) * 8; \
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
#define _csr_wr_buf(a, buf, cnt) \
{ \
	int i, j, nsubs, n_sub_elem; \
	uint64_t v; \
	if (sizeof(buf[0]) >= CSR_DW_BYTES) { \
		/* one or more subregisters per element */ \
		for (i = 0; i < cnt; i++) { \
			_csr_wr(a, buf[i], sizeof(buf[0])); \
			a += CSR_OFFSET_BYTES * num_subregs(sizeof(buf[0])); \
		} \
	} else { \
		/* multiple elements per subregister (2, 4, or 8) */ \
		nsubs = num_subregs(sizeof(buf[0]) * cnt); \
		n_sub_elem = CSR_DW_BYTES / sizeof(buf[0]); \
		for (i = 0; i < nsubs; i++) { \
			v = buf[i * n_sub_elem + 0]; \
			for (j = 1; j < n_sub_elem; j++) { \
				if (i * n_sub_elem + j == cnt) \
					break; \
				v <<= sizeof(buf[0]) * 8; \
				v |= buf[i * n_sub_elem + j]; \
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

#define CSR_SDRAM_DFII_PI0_ADDRESS_ADDR (CSR_BASE + 0x80cL)
static void sdram_dfii_pi0_address_write (unsigned long v) {
	csr_write_simple(v >> 8, CSR_SDRAM_DFII_PI0_ADDRESS_ADDR);
	csr_write_simple(v, (CSR_SDRAM_DFII_PI0_ADDRESS_ADDR+CSR_OFFSET_BYTES));
}

#define CSR_SDRAM_DFII_PI0_BADDRESS_ADDR (CSR_BASE + 0x814L)
static void sdram_dfii_pi0_baddress_write (unsigned long v) {
	csr_write_simple(v, CSR_SDRAM_DFII_PI0_BADDRESS_ADDR);
}

#define CSR_SDRAM_DFII_CONTROL_ADDR (CSR_BASE + 0x800L)
static unsigned long sdram_dfii_control_read (void) {
	return csr_read_simple(CSR_SDRAM_DFII_CONTROL_ADDR);
}
static void sdram_dfii_control_write (unsigned long v) {
	csr_write_simple(v, CSR_SDRAM_DFII_CONTROL_ADDR);
}

#define CSR_SDRAM_DFII_PI0_COMMAND_ADDR (CSR_BASE + 0x804L)
static void sdram_dfii_pi0_command_write (unsigned long v) {
	csr_write_simple(v, CSR_SDRAM_DFII_PI0_COMMAND_ADDR);
}

#define CSR_SDRAM_DFII_PI0_COMMAND_ISSUE_ADDR (CSR_BASE + 0x808L)
static void sdram_dfii_pi0_command_issue_write (unsigned long v) {
	csr_write_simple(v, CSR_SDRAM_DFII_PI0_COMMAND_ISSUE_ADDR);
}

#define CSR_SDRAM_DFII_PI1_ADDRESS_ADDR (CSR_BASE + 0x840L)
static void sdram_dfii_pi1_address_write (unsigned long v) {
	csr_write_simple(v >> 8, CSR_SDRAM_DFII_PI1_ADDRESS_ADDR);
	csr_write_simple(v, (CSR_SDRAM_DFII_PI1_ADDRESS_ADDR+CSR_OFFSET_BYTES));
}

#define CSR_SDRAM_DFII_PI1_BADDRESS_ADDR (CSR_BASE + 0x848L)
static void sdram_dfii_pi1_baddress_write (unsigned long v) {
	csr_write_simple(v, CSR_SDRAM_DFII_PI1_BADDRESS_ADDR);
}

#define CSR_DDRPHY_RDPHASE_ADDR (CSR_BASE + 0x2cL)
static unsigned long ddrphy_rdphase_read (void) {
	return csr_read_simple(CSR_DDRPHY_RDPHASE_ADDR);
}
static void ddrphy_rdphase_write (unsigned long v) {
	csr_write_simple(v, CSR_DDRPHY_RDPHASE_ADDR);
}

#define CSR_DDRPHY_WRPHASE_ADDR (CSR_BASE + 0x30L)
static unsigned long ddrphy_wrphase_read (void) {
	return csr_read_simple(CSR_DDRPHY_WRPHASE_ADDR);
}
static void ddrphy_wrphase_write (unsigned long v) {
	csr_write_simple(v, CSR_DDRPHY_WRPHASE_ADDR);
}

#define CSR_SDRAM_DFII_PI1_COMMAND_ADDR (CSR_BASE + 0x838L)
static void sdram_dfii_pi1_command_write (unsigned long v) {
	csr_write_simple(v, CSR_SDRAM_DFII_PI1_COMMAND_ADDR);
}

#define CSR_SDRAM_DFII_PI1_COMMAND_ISSUE_ADDR (CSR_BASE + 0x83cL)
static void sdram_dfii_pi1_command_issue_write (unsigned long v) {
	csr_write_simple(v, CSR_SDRAM_DFII_PI1_COMMAND_ISSUE_ADDR);
}

#define CSR_DDRPHY_RST_ADDR (CSR_BASE + 0x0L)
static void ddrphy_rst_write (unsigned long v) {
	csr_write_simple(v, CSR_DDRPHY_RST_ADDR);
}

#define CSR_DDRCTRL_INIT_DONE_ADDR (CSR_BASE + 0x1000L)
static void ddrctrl_init_done_write (unsigned long v) {
	csr_write_simple(v, CSR_DDRCTRL_INIT_DONE_ADDR);
}

#define CSR_DDRCTRL_INIT_ERROR_ADDR (CSR_BASE + 0x1004L)
static void ddrctrl_init_error_write (unsigned long v) {
	csr_write_simple(v, CSR_DDRCTRL_INIT_ERROR_ADDR);
}

#define CSR_DDRPHY_DLY_SEL_ADDR (CSR_BASE + 0x10L)
static void ddrphy_dly_sel_write (unsigned long v) {
	csr_write_simple(v, CSR_DDRPHY_DLY_SEL_ADDR);
}

#define CSR_DDRPHY_RDLY_DQ_RST_ADDR (CSR_BASE + 0x14L)
static void ddrphy_rdly_dq_rst_write (unsigned long v) {
	csr_write_simple(v, CSR_DDRPHY_RDLY_DQ_RST_ADDR);
}

#define CSR_DDRPHY_RDLY_DQ_BITSLIP_RST_ADDR (CSR_BASE + 0x1cL)
static void ddrphy_rdly_dq_bitslip_rst_write (unsigned long v) {
	csr_write_simple(v, CSR_DDRPHY_RDLY_DQ_BITSLIP_RST_ADDR);
}

#define CSR_DDRPHY_WDLY_DQ_BITSLIP_RST_ADDR (CSR_BASE + 0x24L)
static void ddrphy_wdly_dq_bitslip_rst_write (unsigned long v) {
	csr_write_simple(v, CSR_DDRPHY_WDLY_DQ_BITSLIP_RST_ADDR);
}

#define CSR_DDRPHY_WDLY_DQ_BITSLIP_ADDR (CSR_BASE + 0x28L)
static void ddrphy_wdly_dq_bitslip_write (unsigned long v) {
	csr_write_simple(v, CSR_DDRPHY_WDLY_DQ_BITSLIP_ADDR);
}

#define CSR_DDRPHY_RDLY_DQ_INC_ADDR (CSR_BASE + 0x18L)
static void ddrphy_rdly_dq_inc_write (unsigned long v) {
	csr_write_simple(v, CSR_DDRPHY_RDLY_DQ_INC_ADDR);
}

#define CSR_DDRPHY_RDLY_DQ_BITSLIP_ADDR (CSR_BASE + 0x20L)
static void ddrphy_rdly_dq_bitslip_write (unsigned long v) {
	csr_write_simple(v, CSR_DDRPHY_RDLY_DQ_BITSLIP_ADDR);
}

#define SDRAM_PHY_PHASES 2

#define CSR_SDRAM_DFII_PI0_WRDATA_ADDR (CSR_BASE + 0x818L)
#define CSR_SDRAM_DFII_PI1_WRDATA_ADDR (CSR_BASE + 0x84cL)
const unsigned long sdram_dfii_pix_wrdata_addr[SDRAM_PHY_PHASES] = {
	CSR_SDRAM_DFII_PI0_WRDATA_ADDR,
	CSR_SDRAM_DFII_PI1_WRDATA_ADDR
};

#define CSR_SDRAM_DFII_PI0_RDDATA_ADDR (CSR_BASE + 0x828L)
#define CSR_SDRAM_DFII_PI1_RDDATA_ADDR (CSR_BASE + 0x85cL)
const unsigned long sdram_dfii_pix_rddata_addr[SDRAM_PHY_PHASES] = {
	CSR_SDRAM_DFII_PI0_RDDATA_ADDR,
	CSR_SDRAM_DFII_PI1_RDDATA_ADDR
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
	if (previous != DFII_CONTROL_SOFTWARE) {
		sdram_dfii_control_write(DFII_CONTROL_SOFTWARE);
	}
}

static void sdram_software_control_off (void) {
	unsigned long previous;
	previous = sdram_dfii_control_read();
	if (previous != DFII_CONTROL_HARDWARE) {
		sdram_dfii_control_write(DFII_CONTROL_HARDWARE);
	}
}

static void sdram_read_leveling_rst_delay (unsigned long module) {
	ddrphy_dly_sel_write(1 << module);
	ddrphy_rdly_dq_rst_write(1);
	ddrphy_dly_sel_write(0);
}

static void sdram_read_leveling_rst_bitslip (unsigned long m) {
	ddrphy_dly_sel_write(1 << m);
	ddrphy_rdly_dq_bitslip_rst_write(1);
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

static unsigned long sdram_write_read_check_test_pattern (unsigned long module, unsigned long seed) {
	int p, i;
	unsigned int prv;
	unsigned char tst[DFII_PIX_DATA_BYTES];
	unsigned char prs[SDRAM_PHY_PHASES][DFII_PIX_DATA_BYTES];
	prv = seed;
	for(p=0;p<SDRAM_PHY_PHASES;p++) {
		for(i=0;i<DFII_PIX_DATA_BYTES;i++) {
			prv = lfsr(32, prv);
			prs[p][i] = prv;
		}
	}
	sdram_activate_test_row();
	for(p=0;p<SDRAM_PHY_PHASES;p++)
		csr_wr_buf_uint8(sdram_dfii_pix_wrdata_addr[p], prs[p], DFII_PIX_DATA_BYTES);
	sdram_dfii_piwr_address_write(0);
	sdram_dfii_piwr_baddress_write(0);
	command_pwr(DFII_COMMAND_CAS|DFII_COMMAND_WE|DFII_COMMAND_CS|DFII_COMMAND_WRDATA);
	cdelay(15);
	sdram_dfii_pird_address_write(0);
	sdram_dfii_pird_baddress_write(0);
	command_prd(DFII_COMMAND_CAS|DFII_COMMAND_CS|DFII_COMMAND_RDDATA);
	cdelay(15);
	sdram_precharge_test_row();
	for(p=0;p<SDRAM_PHY_PHASES;p++) {
		csr_rd_buf_uint8(sdram_dfii_pix_rddata_addr[p], tst, DFII_PIX_DATA_BYTES);
		if (	prs[p][  SDRAM_PHY_MODULES-1-module] != tst[  SDRAM_PHY_MODULES-1-module] ||
			prs[p][2*SDRAM_PHY_MODULES-1-module] != tst[2*SDRAM_PHY_MODULES-1-module])
			return 0;
	}
	return 1;
}

static void sdram_read_leveling_inc_delay (unsigned long module) {
	ddrphy_dly_sel_write(1 << module);
	ddrphy_rdly_dq_inc_write(1);
	ddrphy_dly_sel_write(0);
}

#define SDRAM_PHY_DELAYS 32

static long sdram_read_leveling_scan_module (unsigned long module) {
	unsigned long score = 0;
	sdram_read_leveling_rst_delay(module);
	for (unsigned long i=0;i<SDRAM_PHY_DELAYS;i++) {
		unsigned long working;
		working  = sdram_write_read_check_test_pattern(module, 42);
		working &= sdram_write_read_check_test_pattern(module, 84);
		score += working;
		sdram_read_leveling_inc_delay(module);
	}
	return score;
}

static void sdram_read_leveling_inc_bitslip (unsigned long m) {
	ddrphy_dly_sel_write(1 << m);
	ddrphy_rdly_dq_bitslip_write(1);
	ddrphy_dly_sel_write(0);
}

static void sdram_read_leveling_module (unsigned long module) {
	long i;
	long working;
	long delay, delay_min, delay_max;
	delay = 0;
	sdram_read_leveling_rst_delay(module);
	while(1) {
		working  = sdram_write_read_check_test_pattern(module, 42);
		working &= sdram_write_read_check_test_pattern(module, 84);
		if(working)
			break;
		delay++;
		if(delay >= SDRAM_PHY_DELAYS)
			break;
		sdram_read_leveling_inc_delay(module);
	}
	delay_min = delay;
	delay++;
	sdram_read_leveling_inc_delay(module);
	while (1) {
		working  = sdram_write_read_check_test_pattern(module, 42);
		working &= sdram_write_read_check_test_pattern(module, 84);
		if(!working)
			break;
		delay++;
		if(delay >= SDRAM_PHY_DELAYS)
			break;
		sdram_read_leveling_inc_delay(module);
	}
	delay_max = delay;
	sdram_read_leveling_rst_delay(module);
	for (i=0;i<(delay_min+delay_max)/2;i++) {
		sdram_read_leveling_inc_delay(module);
		cdelay(100);
	}
}

static void init_sequence (void) {
	sdram_dfii_pi0_address_write(0x0);
	sdram_dfii_pi0_baddress_write(0);
	sdram_dfii_control_write(DFII_CONTROL_CKE|DFII_CONTROL_ODT|DFII_CONTROL_RESET_N);
	cdelay(20000);
	sdram_dfii_pi0_address_write(0x400);
	sdram_dfii_pi0_baddress_write(0);
	command_p0(DFII_COMMAND_RAS|DFII_COMMAND_WE|DFII_COMMAND_CS);
	sdram_dfii_pi0_address_write(0x0);
	sdram_dfii_pi0_baddress_write(3);
	command_p0(DFII_COMMAND_RAS|DFII_COMMAND_CAS|DFII_COMMAND_WE|DFII_COMMAND_CS);
	sdram_dfii_pi0_address_write(0x0);
	sdram_dfii_pi0_baddress_write(2);
	command_p0(DFII_COMMAND_RAS|DFII_COMMAND_CAS|DFII_COMMAND_WE|DFII_COMMAND_CS);
	sdram_dfii_pi0_address_write(0x0);
	sdram_dfii_pi0_baddress_write(1);
	command_p0(DFII_COMMAND_RAS|DFII_COMMAND_CAS|DFII_COMMAND_WE|DFII_COMMAND_CS);
	sdram_dfii_pi0_address_write(0x532);
	sdram_dfii_pi0_baddress_write(0);
	command_p0(DFII_COMMAND_RAS|DFII_COMMAND_CAS|DFII_COMMAND_WE|DFII_COMMAND_CS);
	cdelay(200);
	sdram_dfii_pi0_address_write(0x400);
	sdram_dfii_pi0_baddress_write(0);
	command_p0(DFII_COMMAND_RAS|DFII_COMMAND_WE|DFII_COMMAND_CS);
	sdram_dfii_pi0_address_write(0x0);
	sdram_dfii_pi0_baddress_write(0);
	command_p0(DFII_COMMAND_RAS|DFII_COMMAND_CAS|DFII_COMMAND_CS);
	cdelay(4);
	sdram_dfii_pi0_address_write(0x0);
	sdram_dfii_pi0_baddress_write(0);
	command_p0(DFII_COMMAND_RAS|DFII_COMMAND_CAS|DFII_COMMAND_CS);
	cdelay(4);
	sdram_dfii_pi0_address_write(0x432);
	sdram_dfii_pi0_baddress_write(0);
	command_p0(DFII_COMMAND_RAS|DFII_COMMAND_CAS|DFII_COMMAND_WE|DFII_COMMAND_CS);
	cdelay(200);
	sdram_dfii_pi0_address_write(0x380);
	sdram_dfii_pi0_baddress_write(1);
	command_p0(DFII_COMMAND_RAS|DFII_COMMAND_CAS|DFII_COMMAND_WE|DFII_COMMAND_CS);
	sdram_dfii_pi0_address_write(0x0);
	sdram_dfii_pi0_baddress_write(1);
	command_p0(DFII_COMMAND_RAS|DFII_COMMAND_CAS|DFII_COMMAND_WE|DFII_COMMAND_CS);
}

#ifdef LITEDRAM_DEBUG
#define UARTADDR 0x0ff8
#define UARTBAUD 115200
#include <hwdrvchar/hwdrvchar.h>
hwdrvchar hwdrvchar_dev = {.addr = (void *)UARTADDR};
int putchar (int c) {
	while (!hwdrvchar_write_(&hwdrvchar_dev, &c, 1));
	return c;
}
#include <print/print.h>
#endif

#define SDRAM_PHY_RDPHASE 1
#define SDRAM_PHY_WRPHASE 0

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
	{
		sdram_software_control_on();
		for (unsigned long module=0; module<SDRAM_PHY_MODULES; module++) {
			sdram_read_leveling_rst_delay(module);
			sdram_read_leveling_rst_bitslip(module);
		}
		#ifdef LITEDRAM_DEBUG
		printstr("ram initialization: 2\n");
		#endif
		#define SDRAM_PHY_BITSLIPS 8
		{
			long bitslip;
			long score;
			long best_score;
			long best_bitslip;
			for (unsigned long module=0; module<SDRAM_PHY_MODULES; module++) {
				#ifdef LITEDRAM_DEBUG
				printstr(".");
				#endif
				best_score = 0;
				best_bitslip = -1;
				for (bitslip=0; bitslip<SDRAM_PHY_BITSLIPS; bitslip+=2) {
					#ifdef LITEDRAM_DEBUG
					printstr("+");
					#endif
					score = 0;
					ddrphy_dly_sel_write(1 << module);
					ddrphy_wdly_dq_bitslip_rst_write(1);
					for (unsigned long i=0; i<bitslip; i++) {
						#ifdef LITEDRAM_DEBUG
						printstr("-");
						#endif
						ddrphy_wdly_dq_bitslip_write(1);
					}
					ddrphy_dly_sel_write(0);
					score = 0;
					sdram_read_leveling_rst_bitslip(module);
					for (unsigned long i=0; i<SDRAM_PHY_BITSLIPS; i++) {
						#ifdef LITEDRAM_DEBUG
						printstr("=");
						#endif
						score += sdram_read_leveling_scan_module(module);
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
				ddrphy_dly_sel_write(1 << module);
				ddrphy_wdly_dq_bitslip_rst_write(1);
				for (unsigned long i=0; i<bitslip; i++) {
					#ifdef LITEDRAM_DEBUG
					printstr(" # "); printhex(i); printstr("/"); printhex(bitslip);
					#endif
					ddrphy_wdly_dq_bitslip_write(1);
				}
				ddrphy_dly_sel_write(0);
			}
		}
		#ifdef LITEDRAM_DEBUG
		printstr("\n");
		printstr("ram initialization: 3\n");
		#endif
		{
			long bitslip;
			long score;
			long best_score;
			long best_bitslip;
			for (unsigned long module=0; module<SDRAM_PHY_MODULES; module++) {
				#ifdef LITEDRAM_DEBUG
				printstr(".");
				#endif
				best_score = 0;
				best_bitslip = 0;
				for (bitslip=0; bitslip<SDRAM_PHY_BITSLIPS; bitslip++) {
					#ifdef LITEDRAM_DEBUG
					printstr("+");
					#endif
					score = sdram_read_leveling_scan_module(module);
					sdram_read_leveling_module(module);
					#ifdef LITEDRAM_DEBUG
					printstr(" $ "); printhex(score); printstr(" | "); printhex(best_score);
					#endif
					if (score > best_score) {
						best_bitslip = bitslip;
						best_score = score;
					}
					if (bitslip == SDRAM_PHY_BITSLIPS-1)
						break;
					sdram_read_leveling_inc_bitslip(module);
				}
				sdram_read_leveling_rst_bitslip(module);
				for (bitslip=0; bitslip<best_bitslip; bitslip++)
					#ifdef LITEDRAM_DEBUG
					printstr("-"),
					#endif
					sdram_read_leveling_inc_bitslip(module);
				sdram_read_leveling_module(module);
			}
		}
		#ifdef LITEDRAM_DEBUG
		printstr("\n");
		printstr("ram initialization: 4\n");
		#endif
	}
	sdram_software_control_off();
	ddrctrl_init_done_write(1);
	#ifdef LITEDRAM_DEBUG
	printstr("litedram initialized\n");
	#endif
}

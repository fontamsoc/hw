# SPDX-License-Identifier: GPL-2.0-only
# 20261120 (c) William Fonkou Tambe

include $(sort $(wildcard $(BR2_EXTERNAL_NEXYSA7100_PATH)/package/*/*.mk))

# Buildroot selects BR2_SOFT_FLOAT for no RISC-V target, hence uclibc.mk
# configures uClibc-ng for a FPU, with its floating-point environment, whose
# riscv32 sources use instructions of the F extension, which rv32ima lacks: the
# build fails at libm/riscv32/fegetround.c. UCLIBC_FLOAT_CONFIG is redefined
# here as uclibc.mk defines it for a soft-float target; this file is included
# after the packages, and the recipe of the configuration expands the variable.
ifeq ($(BR2_riscv):$(BR2_RISCV_ISA_RVF),y:)
define UCLIBC_FLOAT_CONFIG
	$(call KCONFIG_DISABLE_OPT,UCLIBC_HAS_FPU)
	$(call KCONFIG_ENABLE_OPT,UCLIBC_HAS_FLOATS)
	$(call KCONFIG_ENABLE_OPT,DO_C99_MATH)
endef
endif

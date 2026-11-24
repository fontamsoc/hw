# SPDX-License-Identifier: GPL-2.0-only
# 20261120 (c) William Fonkou Tambe

include $(sort $(wildcard $(BR2_EXTERNAL_NEXYSA7100_PATH)/package/*/*.mk))

# The package linux installs the kernel as Image, which it builds; it is renamed
# vmlinux.bin, the name under which the package linux-smp installs its kernel, and
# which post-image.sh uses, right after it is installed: the package installs the
# kernel only when it builds it, whereas post-image.sh runs at every build.
define NEXYSA7100_LINUX_IMAGE_RENAME
	mv -f $(BINARIES_DIR)/Image $(BINARIES_DIR)/vmlinux.bin
endef
LINUX_POST_INSTALL_IMAGES_HOOKS += NEXYSA7100_LINUX_IMAGE_RENAME

# The package linux also installs the device trees of both kernels, which it
# builds from dts/; the multi-hart one is moved to smp/, where post-image.sh
# makes the images of the multi-hart kernel, right after it is installed, as
# above.
define NEXYSA7100_LINUX_SMP_DTB_MOVE
	mkdir -p $(BINARIES_DIR)/smp
	mv -f $(BINARIES_DIR)/nexysa7100-smp.dtb $(BINARIES_DIR)/smp/
endef
LINUX_POST_INSTALL_IMAGES_HOOKS += NEXYSA7100_LINUX_SMP_DTB_MOVE

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

# coremark.mk gives the compiler TARGET_CFLAGS, but not TARGET_LDFLAGS, which
# holds the stack that BR2_TARGET_LDFLAGS gives the FLAT binaries: CoreMark
# would get the 4096 bytes of elf2flt. Buildroot puts the stack of
# <PKG>_FLAT_STACKSIZE in TARGET_CFLAGS; it is set to that of the defconfig.
COREMARK_FLAT_STACKSIZE = 32768

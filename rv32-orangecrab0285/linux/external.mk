# SPDX-License-Identifier: GPL-2.0-only
# 20261122 (c) William Fonkou Tambe

include $(sort $(wildcard $(BR2_EXTERNAL_ORANGECRAB0285_PATH)/package/*/*.mk))

# The package linux installs the kernel as Image, which it builds; it is renamed
# vmlinux.bin, the name under which the package linux-smp installs its kernel, and
# which post-image.sh uses, right after it is installed: the package installs the
# kernel only when it builds it, whereas post-image.sh runs at every build.
define ORANGECRAB0285_LINUX_IMAGE_RENAME
	mv -f $(BINARIES_DIR)/Image $(BINARIES_DIR)/vmlinux.bin
endef
LINUX_POST_INSTALL_IMAGES_HOOKS += ORANGECRAB0285_LINUX_IMAGE_RENAME

# The package linux also installs the device trees of both kernels, which it
# builds from dts/; the multi-hart one is moved to smp/, where post-image.sh
# makes the images of the multi-hart kernel, right after it is installed, as
# above.
define ORANGECRAB0285_LINUX_SMP_DTB_MOVE
	mkdir -p $(BINARIES_DIR)/smp
	mv -f $(BINARIES_DIR)/orangecrab0285-smp.dtb $(BINARIES_DIR)/smp/
endef
LINUX_POST_INSTALL_IMAGES_HOOKS += ORANGECRAB0285_LINUX_SMP_DTB_MOVE

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

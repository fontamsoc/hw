################################################################################
#
# linux-smp
#
################################################################################

# The sources of the package linux, in a tree of their own, as Kbuild refuses
# O= on the tree which the package linux built in; its patches are those of
# the package linux, patches/linux-smp being a link to patches/linux.
LINUX_SMP_VERSION = $(LINUX_VERSION)
LINUX_SMP_SOURCE = $(LINUX_SOURCE)
LINUX_SMP_SITE = $(LINUX_SITE)
LINUX_SMP_DL_SUBDIR = linux
LINUX_SMP_LICENSE = GPL-2.0
LINUX_SMP_LICENSE_FILES = COPYING
LINUX_SMP_DEPENDENCIES = linux
LINUX_SMP_INSTALL_TARGET = NO
LINUX_SMP_INSTALL_IMAGES = YES

define LINUX_SMP_CONFIGURE_CMDS
	cp $(BR2_EXTERNAL_NEXYSA7100_PATH)/linux.config $(@D)/.config
	cd $(@D) && $(LINUX_MAKE_ENV) ./scripts/kconfig/merge_config.sh -m .config \
		$(BR2_EXTERNAL_NEXYSA7100_PATH)/linux-smp.config
	$(LINUX_MAKE_ENV) $(BR2_MAKE) $(LINUX_MAKE_FLAGS) -C $(@D) olddefconfig
endef

define LINUX_SMP_BUILD_CMDS
	$(LINUX_MAKE_ENV) $(BR2_MAKE) $(LINUX_MAKE_FLAGS) -C $(@D) Image
endef

define LINUX_SMP_INSTALL_IMAGES_CMDS
	$(INSTALL) -D -m 0644 $(@D)/arch/riscv/boot/Image $(BINARIES_DIR)/smp/Image
endef

$(eval $(generic-package))

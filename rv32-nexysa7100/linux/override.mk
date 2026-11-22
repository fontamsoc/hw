# SPDX-License-Identifier: GPL-2.0-only
# 20261121 (c) William Fonkou Tambe

# Buildroot's package override file, as the defconfig sets: Buildroot includes
# it right after it defines BINARIES_DIR, its directory of the images, and
# before the makefiles which use it, whereas external.mk comes after the rules
# of the root file systems; the images go to the directory images of this tree.
# BR2_EXTERNAL_NEXYSA7100_PATH is still quoted here, as .config sets it.
BINARIES_DIR := $(call qstrip,$(BR2_EXTERNAL_NEXYSA7100_PATH))/images

# The package override file which Buildroot uses by default, for the
# definitions of <pkg>_OVERRIDE_SRCDIR.
-include $(CONFIG_DIR)/local.mk

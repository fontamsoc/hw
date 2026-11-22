#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# 20261120 (c) William Fonkou Tambe

# Buildroot's post-image script of rv32-nexysa7100: for the single-hart kernel,
# in BINARIES_DIR, and for the multi-hart kernel, in BINARIES_DIR/smp, when the
# package linux-smp built it:
# - vmlinux.bldr.bin, which tools/mkBootldrDat.py formats for apps/bootldr from
#   vmlinux.bin, the Image, which the packages install under that name, to be
#   written at the start of the partition 3 of the SD card, the partition 4
#   holding the root file system;
# - bootldr.32.hex, the image of apps/bootldr for SRAM_INITFILE, built in its
#   resident mode for the SD card in SD mode, loading the partition 3, the
#   entry 2 of the MBR (BOOTLDR_FIRSTU32=-2), to 0x41000, the device tree blob
#   of the kernel as its stack data.
# The kernel must be linked at 0x41000, CONFIG_PHYS_RAM_BASE, where bootldr
# copies it; the script checks it.

set -euo pipefail

HW=$(cd "$(dirname "$0")/../.." && pwd)
BOOTLDR_LOADADDR=0x41000
TOOLCHAIN=/opt/ftpu-toolchain/bin

# The .config of a kernel built by Buildroot, from its build directory.
kconfig() {
	local d
	for d in "${BUILD_DIR}/$1-custom" "${BUILD_DIR}/$1-"[0-9]*; do
		if [ -f "${d}/.config" ]; then
			echo "${d}/.config"
			return 0
		fi
	done
	return 1
}

# The images of one kernel: its directory, the name of its package, the path of
# its DTB, which the package linux installs for both kernels, the multi-hart one
# in smp/, as external.mk moves it.
images() {
	local dir=$1 pkg=$2 dtb=$3 cfg base n
	cfg=$(kconfig "${pkg}") || { echo "post-image: no .config of ${pkg}" >&2; exit 1; }
	base=$(sed -n 's/^CONFIG_PHYS_RAM_BASE=//p' "${cfg}")
	if [ "$((base))" != "$((BOOTLDR_LOADADDR))" ]; then
		echo "post-image: ${pkg} is linked at ${base:-?}, not ${BOOTLDR_LOADADDR}" >&2
		exit 1
	fi
	python3 "${HW}/tools/mkBootldrDat.py" -o "${dir}/vmlinux.bldr.bin" "${dir}/vmlinux.bin"

	# bootldr, built in a copy of its directory; litedram.c includes its
	# headers from its own directory.
	local b="${BUILD_DIR}/bootldr-${pkg}"
	rm -rf "${b}"
	cp -r "${HW}/rv32-nexysa7100/apps/bootldr" "${b}"
	(
		cd "${b}"
		export PATH="${TOOLCHAIN}:${PATH}"
		make clean > /dev/null
		CFLAGS="-DBOOTLDR_DEVTYPE=2 -DBOOTLDR_DEVADDR=0xe00 -DBOOTLDR_FIRSTU32=-2 -DBOOTLDR_LOADADDR=${BOOTLDR_LOADADDR} -DBOOTLDR_STACKDATA=\\\"${dtb}\\\"" \
			SRCS="bootldr_init_array.c ${HW}/rv32-nexysa7100/litedram/litedram.c" make > build.log
	)
	cp "${b}/bootldr.32.hex" "${dir}/bootldr.32.hex"

	n=$(stat -c %s "${dir}/vmlinux.bldr.bin")
	echo "post-image: ${dir}: vmlinux.bin $(stat -c %s "${dir}/vmlinux.bin") B," \
		"vmlinux.bldr.bin ${n} B: the partition 3 must hold at least $(( (n + 511) / 512 )) blocks;" \
		"bootldr.32.hex for SRAM_INITFILE, stack data $(basename "${dtb}")"
}

images "${BINARIES_DIR}" linux "${BINARIES_DIR}/nexysa7100.dtb"
if [ -f "${BINARIES_DIR}/smp/vmlinux.bin" ]; then
	images "${BINARIES_DIR}/smp" linux-smp "${BINARIES_DIR}/smp/nexysa7100-smp.dtb"
fi

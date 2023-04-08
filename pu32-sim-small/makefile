# SPDX-License-Identifier: GPL-2.0-only
# (c) William Fonkou Tambe

.PHONY: run clean

run: obj_dir/Vsim smem.hex
	@echo ---- run ${TB} ----
	@date; time ./obj_dir/Vsim

smem.hex: smem.rtk/rtk.bin
	if [ ! -e smem.rtk ]; then cp -a ../plain.rtk smem.rtk;	make -C smem.rtk/; fi
	hexdump -v -e '/4 "%08x "' smem.rtk/rtk.bin > smem.hex

obj_dir/Vsim: sim.v sim.cpp
	verilator --version
	verilator -cc --relative-includes -I.. -Wno-lint sim.v --exe sim.cpp
	make -C obj_dir -f Vsim.mk Vsim

clean:
	rm -rf obj_dir *.hex

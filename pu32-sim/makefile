# SPDX-License-Identifier: GPL-2.0-only
# (c) William Fonkou Tambe

.PHONY: sim
sim:
	make TB=sim obj_dir/Vsim

.PHONY: sim_use_vcd
sim_use_vcd:
	make TB=sim_use_vcd TBFLAGS=--trace obj_dir/Vsim

obj_dir/Vsim: sim.v ${TB}.cpp
	cp ../dev/bootldr/bootldr*.hex .
	verilator --version
	verilator ${TBFLAGS} -cc --relative-includes -I.. -Wno-lint sim.v --exe ${TB}.cpp
	make -C obj_dir -f Vsim.mk Vsim

.PHONY: run
run:
	@date; time ./obj_dir/Vsim

.PHONY: clean
clean:
	rm -rf obj_dir *.vcd

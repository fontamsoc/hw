# SPDX-License-Identifier: GPL-2.0-only
# (c) William Fonkou Tambe

ifndef TB
TB := sim
endif

ifeq (${TB},sim)
else ifeq (${TB},sim_use_vcd)
TBFLAGS := --trace
else
$(error set TB to either of: "sim" "sim_use_vcd")
endif

.PHONY: run clean

run: obj_dir/Vsim
	@echo ---- run ${TB} ----
	@date; time ./obj_dir/Vsim

obj_dir/Vsim: sim.v ${TB}.cpp
	cp ../dev/bootldr/bootldr*.hex .
	verilator --version
	verilator ${TBFLAGS} -cc --relative-includes -I.. -Wno-lint sim.v --exe ${TB}.cpp
	make -C obj_dir -f Vsim.mk Vsim

clean:
	rm -rf obj_dir *.vcd

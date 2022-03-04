# SPDX-License-Identifier: GPL-2.0-only
# (c) William Fonkou Tambe

.PHONY: clean

VERILATOR_ROOT ?= $(shell pwd)/../verilator/

PATH := ${VERILATOR_ROOT}/bin/:${PATH}

SUDO := $(shell test $$(id -u) -eq 0 || echo -n sudo)

sim: verilator sim.cpp obj_dir
	make -C smem/
	make -C obj_dir -f Vsim.mk
	g++ -o sim \
		-Iobj_dir \
		-I${VERILATOR_ROOT}/include \
		-I${VERILATOR_ROOT}/include/vltstd \
		sim.cpp obj_dir/Vsim__ALL.a \
		${VERILATOR_ROOT}/include/verilated.cpp \
		${VERILATOR_ROOT}/include/verilated_vcd_c.cpp

obj_dir: sim.v
	VERILATOR_ROOT="${VERILATOR_ROOT}" verilator --version
	VERILATOR_ROOT="${VERILATOR_ROOT}" verilator --trace -cc --relative-includes -I.. -Wno-lint sim.v
	touch obj_dir

verilator:
	if [ ! -e ${VERILATOR_ROOT} ]; then \
		${SUDO} apt install -y libfl2 libfl-dev zlib1g zlib1g-dev autoconf flex bison && \
		git clone https://github.com/verilator/verilator.git ${VERILATOR_ROOT} && \
		cd ${VERILATOR_ROOT} && git reset --hard v4.214 && autoconf && VERILATOR_ROOT="${VERILATOR_ROOT}" ./configure && \
		make -j $(shell nproc) && make test; fi

clean:
	make -C smem/ clean
	rm -rf obj_dir sim sim_use_vcd sim.vcd

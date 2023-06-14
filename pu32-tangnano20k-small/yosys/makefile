# SPDX-License-Identifier: GPL-2.0-only
# (c) William Fonkou Tambe

PROJ=tangnano20k
FAMILY=GW2AR-18C
DEVICE=GW2AR-LV18QN88C8/I7

.PHONY: all
all: ${PROJ}.fs

%.json: ../%.v
	if [ ! -e ../smem.rtk ]; then cp -a ../../plain.rtk ../smem.rtk; make -C ../smem.rtk/; fi
	hexdump -v -e '/4 "%08x "' ../smem.rtk/rtk.bin > smem.hex
	yosys -p "read_verilog -I../../ $<; synth_gowin -top ${PROJ} -json $@" &>0.$@.log
%_pnr.json: %.json ../%.cst
	nextpnr-gowin --json $< --write $@ --freq 27 --device ${DEVICE} --family ${FAMILY} --cst ../${PROJ}.cst &>1.$@.log
%.fs: %_pnr.json
	gowin_pack -d ${FAMILY} -o $@ $< &>2.$@.log

.PHONY: prog
prog: ${PROJ}.fs
	openFPGALoader -b ${PROJ} $< -f

.PHONY: clean
clean:
	rm -rf *.log *.fs *.json *.hex
	#if [ -e ../smem.rtk ]; then make -C ../smem.rtk/ clean; fi

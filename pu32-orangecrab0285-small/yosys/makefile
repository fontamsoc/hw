# SPDX-License-Identifier: GPL-2.0-only
# (c) William Fonkou Tambe

PROJ=orangecrab0285

.PHONY: all
all: ${PROJ}.dfu

%.json: ../%.v
	if [ ! -e ../sram.rtk ]; then cp -a ../../plain.rtk ../sram.rtk; make -C ../sram.rtk/; fi
	hexdump -v -e '/4 "%08x "' ../sram.rtk/rtk.bin > sram32.hex
	hexdump -v -e '/4 "%08x "' ../sram.rtk/rtk.bin | \
		{ while IFS=' ' read -n 18 V0 V1; do echo -n "$$V1$$V0 "; done; } > sram64.hex
	hexdump -v -e '/4 "%08x "' ../sram.rtk/rtk.bin | \
		{ while IFS=' ' read -n 36 V0 V1 V2 V3; do echo -n "$$V3$$V2$$V1$$V0 "; done; } > sram128.hex
	hexdump -v -e '/4 "%08x "' ../sram.rtk/rtk.bin | \
		{ while IFS=' ' read -n 72 V0 V1 V2 V3 V4 V5 V6 V7; do echo -n "$$V7$$V6$$V5$$V4$$V3$$V2$$V1$$V0 "; done; } > sram256.hex
	yosys -p "read_verilog ../../lib/ecp5pll.sv; read_verilog -I../../ $<; synth_ecp5 -top ${PROJ} -no-rw-check -json $@" &>0.$@.log
%_out.config: %.json ../%.lpf
	nextpnr-ecp5 --json $< --textcfg $@ --85k --package CSFBGA285 --lpf ../${PROJ}.lpf &>1.$@.log
	rm -rf abc.history # Remove empty file that gets created sometime.
%.bit: %_out.config
	ecppack --compress --freq 38.8 --input $< --bit $@ &>2.$@.log
%.dfu : %.bit
	cp -a $< $@
	dfu-suffix -v 1209 -p 5af0 -a $@ &>3.$@.log

.PHONY: prog
prog: ${PROJ}.dfu
	# While holding the button on the OrangeCrab, plug it in;
	# it enters the bootloader and enables programming a new bitstream.
	dfu-util --alt 0 -D $<

.PHONY: clean
clean:
	rm -rf *.log *.dfu *.bit *_out.config *.json *.hex
	#if [ -e ../sram.rtk ]; then make -C ../sram.rtk/ clean; fi

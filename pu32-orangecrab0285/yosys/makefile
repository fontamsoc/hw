# SPDX-License-Identifier: GPL-2.0-only
# (c) William Fonkou Tambe

PROJ=orangecrab0285

all: ${PROJ}.dfu

prog: ${PROJ}.dfu
	# While holding the button on the OrangeCrab, plug it in;
	# it enters the bootloader and enables programming a new bitstream.
	dfu-util --alt 0 -D $<

%.json: ../%.v
	cp ../../dev/bootldr/bootldr*.hex .
	cp ../litedram/litedram.hex .
	yosys -p "read_verilog ../../lib/ecp5pll.sv; read_verilog -I../../ $<; synth_ecp5 -json $@" &>0.$@.log
%_out.config: %.json ../%.lpf
	nextpnr-ecp5 --json $< --textcfg $@ --85k --package CSFBGA285 --lpf ../${PROJ}.lpf &>1.$@.log
	rm -rf abc.history # Remove empty file that gets created sometime.
%.bit: %_out.config
	ecppack --compress --freq 38.8 --input $< --bit $@ &>2.$@.log
%.dfu : %.bit
	cp -a $< $@
	dfu-suffix -v 1209 -p 5af0 -a $@ &>3.$@.log

clean:
	rm -rf *.log *.dfu *.bit *_out.config *.json *.hex

.PHONY: all prog clean

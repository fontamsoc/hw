# SPDX-License-Identifier: GPL-2.0-only
# (c) William Fonkou Tambe

PROJ=orangecrab0225

.PHONY: all
all: ${PROJ}.dfu

%.json: ../%.v
	cp ../../dev/bootldr/*.hex .
	cp ../litedram/*.hex .
	yosys -p "read_verilog ../../lib/ecp5pll.sv; read_verilog -I../../ $<; synth_ecp5 -top ${PROJ} -json $@" &>0.$@.log
%_out.config: %.json ../%.lpf
	cp $<{,.bak}
	cntr=0; until \
		nextpnr-ecp5 -r --json $< --textcfg $@ --25k --package CSFBGA285 --lpf ../${PROJ}.lpf &>1.$@.log; \
	do \
		echo --; \
		fgrep 'ERROR: Max frequency' 1.$@.log; \
		((cntr++)); [[ cntr -eq 5 ]] && exit 1; \
		cp $<{.bak,}; \
	done
	rm -rf $<.bak abc.history # empty file that gets created sometime.
%.bit: %_out.config
	ecppack --compress --freq 38.8 --input $< --bit $@ &>2.$@.log
%.dfu : %.bit
	cp -a $< $@
	dfu-suffix -v 1209 -p 5af0 -a $@ &>3.$@.log

.PHONY: prog
prog: ${PROJ}.dfu
	# While holding the button on the OrangeCrab, plug it in;
	# it enters the bootloader and enables programming a new bitstream.
	dfu-util -D $<

.PHONY: clean
clean:
	rm -rf *.log *.dfu *.bit *_out.config *.json *.hex

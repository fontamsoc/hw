# SPDX-License-Identifier: GPL-2.0-only
# (c) William Fonkou Tambe

TOP ?= orangecrab0285

CPU_COUNT ?= 1
XWORDBITSZ ?= 32
SRAM_KBSIZE ?= 256
SRAM_INITFILE ?= ../../rv32-sim/apps/coremark/rv32/coremark.${XWORDBITSZ}.hex

RETRY_COUNT ?= 10

.PHONY: all
all: ${TOP}.dfu

.PHONY: updsram
updsram: ${TOP}.sram.hex ${TOP}.bak.config
	ecpbram --from ${TOP}.sram.hex --to ${SRAM_INITFILE} --input ${TOP}.bak.config --output ${TOP}.out.config
	ecppack --compress --freq 38.8 --input ${TOP}.out.config --bit ${TOP}.dfu
	dfu-suffix -v 1209 -p 5af0 -a ${TOP}.dfu &>/dev/null
	@rm ${TOP}.out.config

%.json: ../%.sv
	@ecpbram --generate ${TOP}.sram.hex --width ${XWORDBITSZ} --depth $$((${SRAM_KBSIZE}*1024/4))
	yosys -p "verilog_defines -DCPU_COUNT=${CPU_COUNT} -DXWORDBITSZ=${XWORDBITSZ} -DSRAM_KBSIZE=${SRAM_KBSIZE} -DSRAM_INITFILE=\"${TOP}.sram.hex\"; \
		read_verilog -sv -I../../ $<; synth_ecp5 -top ${TOP} -dff -json $@" &>$*.synth.log
%.out.config: %.json ../%.lpf
	$(info # Running nextpnr-ecp5 ...)
	@cntr=0; until \
		nextpnr-ecp5 -r --ignore-rel-clk --json $< --textcfg $@ --85k --package CSFBGA285 --lpf ../${TOP}.lpf &>$*.pnr.log; \
	do \
		fgrep 'ERROR: Max frequency' $*.pnr.log; \
		((cntr++)); [[ cntr -eq ${RETRY_COUNT} ]] && exit 1; \
	done; fgrep 'Max frequency' $*.pnr.log | fgrep PASS; test -f $@ # using `test` to workaround unexpected fail.
	@rm -rf abc.history # empty file that gets created sometime.
%.dfu: %.out.config
	@mv $< ${TOP}.bak.config
	ecpbram --from ${TOP}.sram.hex --to ${SRAM_INITFILE} --input ${TOP}.bak.config --output ${TOP}.out.config
	ecppack --compress --freq 38.8 --input $< --bit $@
	dfu-suffix -v 1209 -p 5af0 -a $@ &>/dev/null

.PHONY: prog
prog: ${TOP}.dfu
	# While holding the button on the OrangeCrab, plug it in;
	# it enters the bootloader and enables programming a new bitstream.
	dfu-util --alt 0 -D $<

.PHONY: clean
clean:
	rm -rf *.log *.dfu *.config *.json *.hex

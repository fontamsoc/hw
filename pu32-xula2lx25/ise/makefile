# SPDX-License-Identifier: GPL-2.0-only
# (c) William Fonkou Tambe

ifeq ($(ISE_XTCLSH),)
ISE_XTCLSH := "/cygdrive/c/Xilinx/14.7/ISE_DS/ISE/bin/nt64/xtclsh.exe"
endif

all:
	# Tcl script generated from ISE menu "Project"->"Generate Tcl Script..."
	${ISE_XTCLSH} pu32-xula2lx25.tcl rebuild_project

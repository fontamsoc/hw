# SPDX-License-Identifier: GPL-2.0-only
# (c) William Fonkou Tambe

all:
	echo "localparam SOCVERSION = 'h$$(var=$$(git log -n1 --pretty=format:'%H'); echo $${var:0:8});" > version.v

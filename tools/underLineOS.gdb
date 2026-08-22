# SPDX-License-Identifier: GPL-2.0-only
# 20260822 (c) William Fonkou Tambe

set arch riscv:rv32
set remotetimeout unlimited
set breakpoint always-inserted on
define gn
set var __gdbstub_tp = __gdbstub_next()
end
define gl
set var __gdbstub_tp = __gdbstub_last()
end
define gx
if $argc == 1
set var __gdbstub_tp = $arg0
else
printf "usage: gx <_thread_t *>\n"
end
end

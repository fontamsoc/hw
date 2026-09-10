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
define reload
echo reload: if the next line fails with "No symbol", the image is not linked with -lgdbstub\n
echo reload: delete your breakpoints first (delete): inserted ones are carried into the loaded image\n
set var __gdbstub_reload = 1
print __gdbstub_reload
echo reload: resetting; now ^C, then file <elf>, load, continue (or continue alone to reboot)\n
set $pc = _sysreset
continue
end

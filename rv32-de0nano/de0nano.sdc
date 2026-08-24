
create_clock -name clk50mhz_i -period 20.000 [get_ports {clk50mhz_i}]

derive_clock_uncertainty

## rst_n and the UART pins are asynchronous to clk50mhz_i and have no external timing budget.
## Uncomment to silence the unconstrained-I/O warnings once the core logic closes timing.
#set_false_path -from [get_ports {rst_n}]   -to [all_registers]
#set_false_path -from [get_ports {uart_rx}] -to [all_registers]
#set_false_path -from [all_registers]       -to [get_ports {uart_tx}]

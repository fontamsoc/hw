//--------------------------------------------------------------------------------
// Auto-generated by LiteX (1989d85b) on 2022-04-12 17:56:48
//--------------------------------------------------------------------------------
#ifndef __GENERATED_SOC_H
#define __GENERATED_SOC_H
#define CONFIG_CLOCK_FREQUENCY 48000000
#define CONFIG_CPU_TYPE_NONE
#define CONFIG_CPU_VARIANT_STANDARD
#define CONFIG_CPU_HUMAN_NAME "Unknown"
#define CONFIG_CSR_DATA_WIDTH 32
#define CONFIG_CSR_ALIGNMENT 32
#define CONFIG_BUS_STANDARD "WISHBONE"
#define CONFIG_BUS_DATA_WIDTH 32
#define CONFIG_BUS_ADDRESS_WIDTH 32

#ifndef __ASSEMBLER__
static inline int config_clock_frequency_read(void) {
	return 48000000;
}
static inline const char * config_cpu_human_name_read(void) {
	return "Unknown";
}
static inline int config_csr_data_width_read(void) {
	return 32;
}
static inline int config_csr_alignment_read(void) {
	return 32;
}
static inline const char * config_bus_standard_read(void) {
	return "WISHBONE";
}
static inline int config_bus_data_width_read(void) {
	return 32;
}
static inline int config_bus_address_width_read(void) {
	return 32;
}
#endif // !__ASSEMBLER__

#endif

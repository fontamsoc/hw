// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Opcodes values range from 0 to 31, and are numbered as shown below,
// in such a way as to use the least amount of logic for sequencing.
// ei: Opcodes are 5bits and all system instructions have the msb
// of their opcode value always 0.
// 
// Unassigned opcode values, when used, the instruction pointer
// register get incremented and no operation is performed.
// Opcode values less than 16 are in the system instructions
// range, and generate a sysop interrupt when used in usermode.
// 
// System instructions.
// 	
// 	OPSWITCHCTX		0
// 	OPGETSYSREG1		2
// 	OPGETSYSREG		5
// 	OPSETSYSREG		7
// 	OPNOTAVAIL		8
// 	OPVLOADORSTORE		14
// 	OPSETGPR		15
// 
// General purpose instructions.
// 	
// 	OPLI8A			16
// 	OPLI8B			17
//	OPINC8A			18
//	OPINC8B			19
// 	OPINC			20
// 	OPIMM			21
// 	OPALU0			22
// 	OPALU1			23
// 	OPALU2			24
// 	OPMULDIV		25
// 	OPJ			26
// 	OPFLOAT			27
// 	OPRLI8A			28
// 	OPRLI8B			29
// 	OPLOADORSTORE		30
// 	OPLDST			31

// Load immediate opcodes.
localparam OPLI8A		= 16;
localparam OPLI8B		= 17;
localparam OPINC8A		= 18;
localparam OPINC8B		= 19;
localparam OPRLI8A		= 28;
localparam OPRLI8B		= 29;
localparam OPINC		= 20;
localparam OPIMM		= 21;
// Single-cycle opcodes.
localparam OPALU0		= 22; // sgt, sgte, sgtu, sgteu.
localparam OPALU1		= 23; // add, sub, seq, sne, slt, slte, sltu, slteu.
localparam OPALU2		= 24; // sll, srl, sra, and, or, xor, not, cpy.
localparam OPJ			= 26;
localparam OPSWITCHCTX		= 0;
localparam OPGETSYSREG1		= 2;
localparam OPGETSYSREG		= 5;
localparam OPSETSYSREG		= 7;
localparam OPNOTAVAIL		= 8;
localparam OPSETGPR		= 15;
// Multi-cycle opcodes.
localparam OPVLOADORSTORE	= 14;
localparam OPLOADORSTORE	= 30;
localparam OPLDST		= 31;
localparam OPMULDIV		= 25;
localparam OPFLOAT		= 27;

// There is no bitwise rotation instructions because rare are languages
// that have an operator for it; it can be done using shift instructions.
// The following example rotate left an integer "value" a "count" amount:
// (value << count) | (value >> (32 - count));
// The following example rotate right an integer "value" a "count" amount:
// (value >> count) | (value << (32 - count));

// There is no instruction that swap the values of two regiters;
// because not only it is complex to implement (2 registers
// to modify at the same time), it is not used by languages,
// and can be achieved using 3 xor operations; ei:
// %gpr1 ^= %gpr2;
// %gpr2 ^= %gpr1;
// %gpr1 ^= %gpr2;
// The above example will swap the values of %gpr1 and %gpr2.

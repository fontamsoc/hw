// SPDX-License-Identifier: GPL-2.0-only
// 20260802 (c) William Fonkou Tambe

#ifndef HWDRVIRQCTRL_H
#define HWDRVIRQCTRL_H

// Commands are sent to the controller writing to it with the
// following expected format | arg: (WORDBITSZ-2) bits | cmd: 2 bit |
// where the field "cmd" values are CMDDEVRDY(2'b00), CMDACKIRQ(2'b01),
// CMDINTDST(2'b10) and CMDENAIRQ(2'b11). The result of a previously
// sent command is retrieved from the controller reading from it and
// has the following format
// | resp: (WORDBITSZ-3) bits | rsvd: 1 bit | cmd: 2 bit |, where the fields
// "cmd" and "resp" are the command and its result, while the field "rsvd"
// is reserved and null.
// Two memory operations, a write followed by a read are needed to send
// a command to the controller and retrieve its result.
// The controller has accepted a command only if "cmd" in its result
// is CMDDEVRDY, otherwise sending the command CMDDEVRDY is needed.
//
// The description of commands is as follow:
// 	CMDDEVRDY: Make the controller accept a new command.
// 	"resp" in the result gets set to 0.
// 	CMDACKIRQ: Acknowledges an interrupt source; field "arg" is expected
// 	to have following format | idx: (WORDBITSZ-3) bits | en: 1 bit |
// 	where "idx" is the interrupt destination index, "en" enables/disables
// 	further interrupt delivery to the interrupt destination "idx".
// 	"resp" in the result gets set to the interrupt source index, or -2
// 	if there are no pending interrupts for the destination "idx", or -1
// 	for an interrupt triggered by CMDINTDST.
// 	CMDINTDST: Triggers an interrupt targeting a specific destination;
// 	field "arg" is expected to have following format
// 	| idx: (WORDBITSZ-3) bits | rsvd: 1 bit | where "idx" is the interrupt
// 	destination index to target, "rsvd" is reserved and ignored.
// 	"resp" in the result gets set to the interrupt destination index
// 	if valid, -2 if not ready due to an interrupt pending ack, or -1 if invalid.
// 	CMDENAIRQ: Enable/Disable an interrupt source; field "arg" is expected
// 	to have following format | idx: (WORDBITSZ-3) bits | en: 1 bit |
// 	where "idx" is the interrupt source index, "en" enables/disables
// 	interrupts from the interrupt source "idx".
// 	"resp" in the result gets set to the interrupt source index, or -1
// 	if invalid.
//
// To be multi core proof, an atomic read-write must be used to send
// a command to the controller until CMDDEVRDY is returned, then another
// atomic read-write sending CMDDEVRDY must be used to retrieve the
// result while making the controller ready for the next command.
//
// An interrupt must be acknowledged as soon as possible so
// that the irqctrl can dispatch another interrupt request.

#define IRQCTRLADDR ((uintptr_t *)0xf00 /* By convention, the interrupt controller is located at 0xf00 */)

static inline uintptr_t hwdrvirqctrl_ack (uintptr_t idx, uintptr_t en) {
	uintptr_t irqsrc;
	do {
		irqsrc = ((idx<<3) | ((en&1)<<2) | 0b01);
		irqsrc = _xchg(IRQCTRLADDR, irqsrc);
	} while (irqsrc & 0b11);
	irqsrc = 0;
	irqsrc = _xchg(IRQCTRLADDR, irqsrc);
	return ((intptr_t)irqsrc >> 3);
}

static inline uintptr_t hwdrvirqctrl_int (uintptr_t idx) {
	uintptr_t irqdst;
	do {
		irqdst = ((idx<<3) | 0b10);
		irqdst = _xchg(IRQCTRLADDR, irqdst);
	} while (irqdst & 0b11);
	irqdst = 0;
	irqdst = _xchg(IRQCTRLADDR, irqdst);
	return ((intptr_t)irqdst >> 3);
}

static inline uintptr_t hwdrvirqctrl_ena (uintptr_t idx, uintptr_t en) {
	uintptr_t irqsrc;
	do {
		irqsrc = ((idx<<3) | ((en&1)<<2) | 0b11);
		irqsrc = _xchg(IRQCTRLADDR, irqsrc);
	} while (irqsrc & 0b11);
	irqsrc = 0;
	irqsrc = _xchg(IRQCTRLADDR, irqsrc);
	return ((intptr_t)irqsrc >> 3);
}

#endif /* HWDRVIRQCTRL_H */

.include "header.inc"
.include "misc_macros.inc"
.bank 0 slot 1

.ramsection "lfsr_vars" SLOT RAM_SLOT
	lfsr_state: dw
.ends

.section "lfsr" FREE

.16BIT

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Simple pseudo-random number generator.
	;
	; Based on https://en.wikipedia.org/wiki/Linear-feedback_shift_register#Galois_LFSRs
	;
	; Input: None
	; Output: A (or AB) = lfsr_state
	;
lfsr_tick:
	php

	A16

	; Make sure it is never 0. With this lfsr_state does not
	; need to be initialized.
	lda lfsr_state
	beq _init

	asl		; Carry = MSB
	bcc	_skip
	eor #$002D
_skip:
	sta lfsr_state

	plp
	rts

_init:
	lda #$ACE1
	sta lfsr_state
	plp
	rts

.ends

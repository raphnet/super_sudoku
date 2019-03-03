.include "header.inc"
.include "snesregs.inc"
.include "misc_macros.inc"
.include "zeropage.inc"

.bank 0
.section "Effects" FREE

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Performa fade-in using INIDISP bits 3-0 (master brightness)
	;
effect_fadein:
	pha
	phx
	php

	A8
	XY8

	ldx #0 ; black screen, not blanked
	stx INIDISP

	; Bits 3-0 : Master brightness. 0 = black, 15 = max
@loop:
	; Halt until next vblank
	wai

	; Increment brightness every 4 frames
	lda framecount
	and #3 ; will be 0 every 4 cycles
	bne @loop

	inx
	stx INIDISP

	cpx #15
	beq @done

	bra @loop

@done:

	plp
	plx
	pla

	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Performa fade-out using INIDISP bits 3-0 (master brightness)
	;
effect_fadeout:
	pha
	phx
	php

	A8
	XY8

	ldx #15 ; black screen, not blanked

	; Bits 3-0 : Master brightness. 0 = black, 15 = max
@loop:
	; Halt until next vblank
	wai

	; Decrement brightness every 4 frames
	lda framecount
	and #3 ; will be 0 every 4 cycles
	bne @loop

	dex
	stx INIDISP

	cpx #0
	beq @done

	bra @loop

@done:

	plp
	plx
	pla

	rts


.ends



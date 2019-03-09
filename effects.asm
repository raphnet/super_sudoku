.include "header.inc"
.include "snesregs.inc"
.include "misc_macros.inc"
.include "zeropage.inc"

.bank 0
.section "Effects" FREE


effect_mosaic_pulse:
	pha
	phx
	phy
	php

	A8
	XY8

	; ramp up
	lda #07
@lp1:
	wai
	sta MOSAIC
	clc
	adc #$20
	bcc @lp1

	; ramp down
	lda #$e7
@lp2:
	wai
	sta MOSAIC
	sec
	sbc #$20
	bit #$f0
	bne @lp2

	stz MOSAIC

	plp
	ply
	plx
	pla

	rts


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
	and #1 ; will be 0 every 2 cycles
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
	and #1 ; will be 0 every 2 cycles
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



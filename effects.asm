.include "header.inc"
.include "snesregs.inc"
.include "misc_macros.inc"
.include "zeropage.inc"

.16BIT

.bank 0

.ramsection "effects_variables" SLOT RAM_SLOT

; Pointer to the effect routine that must be called from vblank (see effects_dovblank)
effects_cur_routine:	dw

; Effect state and varibles (shared between different effects)
effects_state:			dw
effects_tmp:			dw

; Options for mosaic effects: BG mask (for the 4 lower bits of MOSAIC/$2106)
effects_mosaic_bgmask:	dw

.ends


.section "Effects" FREE

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Run the active non-blocking effect.
	;
	; To be called from vblank.
	;
effects_dovblank:
	jmp (effects_cur_routine)
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Initialize the non blocking effect helper
	;
effects_init:
	pushall

	A16
	lda #_effects_nop
	sta effects_cur_routine

	popall
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Start a "mosaic pulse" effect.
	;
	; Not bad to signal errors. Similar to a visual bell.
	;
effect_mosaic_pulse:
	pushall

	A16
	lda #_effects_mosaic_do
	sta effects_cur_routine
	stz effects_state
	stz effects_tmp

	lda #4
	sta effects_mosaic_bgmask

	popall
	rts


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Internal no-operation routine used as a placeholder when there
	; is no active effect.
	;
_effects_nop:
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Internal function for the mosaic pulse effect.
	;
_effects_mosaic_do:
	pushall

	A8

	lda effects_state
	bne @shrinking

@growing:
	lda effects_tmp
	inc A
	cmp #7
	beq @done_growing
	sta effects_tmp
	asl
	asl
	asl
	asl
	ora effects_mosaic_bgmask
	sta MOSAIC
	bra @done
@done_growing:
	inc effects_state
	bra @done

@shrinking:
	lda effects_tmp
	dec A
	bmi @done_shrinking
	sta effects_tmp
	asl
	asl
	asl
	asl
	ora effects_mosaic_bgmask
	sta MOSAIC
	bra @done
@done_shrinking:
	A16
	lda #_effects_nop		; Replace this routine by the nop
	sta effects_cur_routine ; routine, stop being called.

@done:

	popall
	rts


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
	; BLOCKING
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
	; BLOCKING
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



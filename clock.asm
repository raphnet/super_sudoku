.include "header.inc"
.include "misc_macros.inc"
.include "zeropage.inc"

.bank 0 slot 1

.ramsection "clock_vars" SLOT RAM_SLOT
	tmr_tick:		db
	tmr_seconds:	db
	tmr_minutes:	db
	tmr_hours:		db
.ends

.16BIT

.section "clock code" FREE

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	;
	;
clock_tick:
	pha
	php
	A8

	lda tmr_tick
	inc A
	sta tmr_tick
	cmp #60
	bne @done
	stz tmr_tick

	lda tmr_seconds
	inc A
	sta tmr_seconds
	cmp #60
	bne @done
	stz tmr_seconds

	lda tmr_minutes
	inc A
	sta tmr_minutes
	cmp #60
	bne @done
	stz tmr_minutes

	lda tmr_hours
	inc A
	beq @done ; overflow. Don't store. max 255.
	sta tmr_hours

@done:
	plp
	pla
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	;
	;
clock_draw:
	pushall
	XY16

	; save non-interrupt vars
	ldx text_cursor_x
	phx
	ldx text_cursor_y
	phx


	A8
	ldx #5
	stx text_cursor_x
	stx text_cursor_y
	jsr text_gotoxy

	lda tmr_seconds
	clc
	adc #$30
	jsr text_putchar

	; restore non-interrupt vars
	plx
	stx text_cursor_y
	plx
	stx text_cursor_x

	popall
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	;
	;
clock_initreset:
	pushall
	A8

	stz tmr_tick
	stz tmr_seconds
	stz tmr_minutes
	stz tmr_hours

	popall
	rts

.ends



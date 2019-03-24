.include "header.inc"
.include "misc_macros.inc"
.include "zeropage.inc"
.include "bg1.inc"

.define CLOCK_DRAWTO	64*7+44

.bank 0 slot 1

.ramsection "clock_vars" SLOT RAM_SLOT
	clk_tick:		db
	clk_seconds1:	db
	clk_seconds10:	db
	clk_minutes1:	db
	clk_minutes10:	db
	clk_hours1:		db
	clk_hours10:	db
	clk_hours100:	db

	clk_visible:	db
	clk_running:	db
.ends

.16BIT

.section "clock code" FREE

; syntax: INC_DIGIT mem max_value
.macro INC_DIGIT
	lda \1
	inc A
	sta \1
	cmp #\2
	bne @done
	stz \1
.endm

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Erase the clock and stop drawing it (not drawn even when clock_draw is called)
	;
clock_hide:
	pushall
	A8
	XY16
	stz clk_visible

	ldy #8
	ldx #CLOCK_DRAWTO
@lp:
	sta BG1_ABSOLUTE_LONG, X
	inx
	inx
	dey
	bne @lp

	popall
	rts


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Make the clock visible (will be drawing when clock_draw is called)
	;
clock_show:
	pha
	php
	A8
	lda #1
	sta clk_visible
	plp
	pla
	rts


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Start/resume clock. Time will advance when clock_tick is called.
	;
clock_start:
	pha
	php
	A8
	lda #1
	sta clk_running
	plp
	pla
	rts


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Start/resume clock. Time will advance when clock_tick is called.
	;
clock_stop:
	pha
	php
	A8
	stz clk_running
	plp
	pla
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Check if clock is running. Returns with CF set if running
	;
clock_isStopped:
	pha
	php

	A8
	lda clk_running
	bne @running

@not_running:
	plp
	pla
	clc
	rts
@running:
	plp
	pla
	sec
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Reset time to zero
	;
clock_zero:
	php
	A8
	stz clk_tick
	stz clk_seconds1
	stz clk_seconds10
	stz clk_minutes1
	stz clk_minutes10
	stz clk_hours1
	stz clk_hours10
	stz clk_hours100
	plp
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	;
	;
clock_tick:
	pha
	php
	A8

	lda clk_running
	beq @done

	lda clk_tick
	inc A
	sta clk_tick
	cmp #60
	bne @done
	stz clk_tick

	INC_DIGIT clk_seconds1 	10
	INC_DIGIT clk_seconds10	6
	INC_DIGIT clk_minutes1	10
	INC_DIGIT clk_minutes10	6
	INC_DIGIT clk_hours1	10
	INC_DIGIT clk_hours10	10
	INC_DIGIT clk_hours100	10

@done:
	plp
	pla
	rts

.macro DRAW_DIGIT
	lda \1
	ora #$30
	sta BG1_ABSOLUTE_LONG, X
	inx
	inx
.endm

.macro DRAW_CHAR
	lda #\1
	sta BG1_ABSOLUTE_LONG, X
	inx
	inx
.endm

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Draw the clock in BG1
	;
clock_draw:
	pushall

	XY16
	A8

	lda clk_visible
	beq @done

	ldx #CLOCK_DRAWTO

;	DRAW_DIGIT clk_hours100
	DRAW_DIGIT clk_hours10
	DRAW_DIGIT clk_hours1
	DRAW_CHAR ':'
	DRAW_DIGIT clk_minutes10
	DRAW_DIGIT clk_minutes1
	DRAW_CHAR ':'
	DRAW_DIGIT clk_seconds10
	DRAW_DIGIT clk_seconds1

	lda #1
	sta bg1_need_resync

@done:

	popall
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Init the clock. Defauls to stopped, invisible.
	;
clock_initreset:
	pushall
	A8

	stz clk_tick
	stz clk_seconds1
	stz clk_seconds10
	stz clk_minutes1
	stz clk_minutes10
	stz clk_hours1
	stz clk_hours10
	stz clk_hours100
	stz clk_visible
	stz clk_running

	popall
	rts

.ends



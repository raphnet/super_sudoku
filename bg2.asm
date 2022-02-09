.include "header.inc"
.include "snesregs.inc"
.include "misc_macros.inc"
.include "zeropage.inc"
.include "bg2.inc"

.bank 0 slot 1

.ramsection "bg2_vars" SLOT RAM_SLOT
	bg2_off: db
	bg2_count: db
	bg2_scrolling: db
.ends

.16BIT

.define SCROLL_TICK_MASK	$07

.section "bg2_code" FREE

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Animate the scrolling background
	;
bg2_doScrolling:
	pushall

	A8
	XY8

	lda bg2_scrolling
	and #$ff
	beq @nomove

	; Animate scrolling background
	lda bg2_count
	ina
	sta bg2_count
	and #SCROLL_TICK_MASK
	cmp #SCROLL_TICK_MASK
	bne @nomove

	lda bg2_off
	ina
	sta bg2_off
	sta BG2HOFS
	sta BG2VOFS
@nomove:

	popall
	rts


bg2_fill:
	pushall

	Fill_VRAM BG2_TILE_MAP_OFFSET ((2<<BGMAPENT_PALSHIFT)|0) 	32*32

	popall
	rts


bg2_enableScrolling:
	pushall
	A8

	lda #1
	sta bg2_scrolling

	popall
	rts

bg2_disableScrolling:
	pushall
	A8

	lda #0
	sta bg2_scrolling

	popall
	rts



.ends

.include "header.inc"
.include "snesregs.inc"
.include "misc_macros.inc"
.include "zeropage.inc"
.include "bg2.inc"

.bank 0 slot 1

.ramsection "bg2_vars" SLOT RAM_SLOT
	bg2_off: db
	bg2_count: db
.ends

.16BIT

.section "bg2_code" FREE

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Animate the scrolling background
	;
bg2_doScrolling:
	pushall

	A8
	XY8

	; Animate scrolling background
	lda bg2_count
	ina
	sta bg2_count
	and #$03
	cmp #$03
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




.ends

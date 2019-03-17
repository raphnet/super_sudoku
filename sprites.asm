.include "header.inc"
.include "snesregs.inc"
.include "misc_macros.inc"
.include "zeropage.inc"

.bank 0

.16BIT
.RAMSECTION "sprite variables" SLOT RAM_SLOT

; This is a copy of the two tables found in OAM
oam_table1:	dsb $200 ; 128 4 byte entries
oam_table2: dsb $20
.ENDS

.section "Sprites" FREE


sprites_init:
	pushall

	A16

	Memset oam_table1 $00 _sizeof_oam_table1
	Memset oam_table2 $55 _sizeof_oam_table2

	XY16
	A8

	; Init all sprites off screen
	lda -64
	ldy #0
	ldx #128
@lp_x:
	sta oam_table1, Y 		; X
	sta oam_table1 + 1, Y	; Y
	iny
	iny
	iny
	iny
	dex
	bne @lp_x

	jsr sprite_syncAll

@done:

	popall

	rts

sprite_syncAll:
	pushall
	AXY16

	stz OAMADDL

	; selexct DMA mode 2 (write two bytes at 1 address)
	A8
	lda #$2
	sta DMAP7	; use channel 7

	; set low byte address to low8(OAMDATA)
	lda #<OAMDATA
	sta BBAD7	; 21xx + A

	; set source address
	ldx #oam_table1
	stx A1T7L
	stz A1B7 ; bank 0 hardcoded!

	; set transfer size
	ldx #_sizeof_oam_table1+$20
	stx DAS7L

	; start the transfer!
	lda #1<<7
	sta MDMAEN

	popall
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Update a sprite in VRAM
	;
	; Args: A: Sprite ID
	;
	; Should be called during VBLANK
sprite_sync:
	jmp sprite_syncAll

/*
	pha
	phx
	phy
	php

	XY16

	; Accept 16-bit A or 8-bit A
	A16
	and #$ff

	; Multiply A by 4 to get table address
	asl
	sta OAMADDL
	asl

	; Set the destination OAM address

	tay

	A8
	lda oam_table1, y
	sta OAMDATA
	lda oam_table1+1, y
	sta OAMDATA
	lda oam_table1+2, y
	sta OAMDATA
	lda oam_table1+3, y
	sta OAMDATA


	; TODO : Set the 9th X bit
	A16
	lda #$1F0
	sta OAMADDL

	A8
	ldy #0
@lp:
	lda oam_table2, y
	sta OAMDATA
	iny
	cpy #32
	bne @lp
@ex:

	plp
	ply
	plx
	pla

	rts
*/


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Move a given sprite to a new position
	;
	; Args:
	;    16-bit A: Sprite ID
	;    16-bit X: X position
	;    16-bit Y: Y position
	;
sprite_move:
	pha
	phx
	phy
	php

	A16

	; Multiply A by 4 to get table address
	asl
	asl

	; Add it to the table base
	clc
	adc oam_table1

	; Save the pointer
	sta tmpspriteptr
	A8

	txa
	sta (tmpspriteptr)
	tya
	sta (tmpspriteptr+1)



	plp
	ply
	plx
	pla

	rts


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Set the start character of a sprite
	;
	; 16 or 8-bit A: sprite ID
	; 16-bit X: character ID
	;
sprite_setCharacter:
	pha
	phx
	phy
	php

	A16
	and #$FF

	asl
	asl
	tay	; Y will be our offset

	txa
	A8
	sta oam_table1+2, Y

	; clear bit 8
	lda oam_table1+3, Y ; mask 
	and #$fe
	sta oam_table1+3, Y

	xba ; get the high byte
	and #$1
	ora oam_table1+3, Y
	sta oam_table1+3, Y

	
	plp
	ply
	plx
	pla





.ends

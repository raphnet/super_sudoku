; From https://en.wikibooks.org/wiki/Super_NES_Programming/DMA_tutorial

;macro for loading palette data into the CGRAM
;only use if SIZE is less than 256 bytes
;syntax SetPalette LABEL CGRAM_ADDRESS SIZE
.macro SetPalette
	pha
	php

	XY16
	A16

	lda	#\3
	sta	$4305		; # of bytes to be copied

	ldx #\1
	stx $4302

	;lda	#\1		; offset of data into 4302, 4303
	;sta	$4302

	A8

	lda	#:\1		; bank address of data in memory(ROM)
	sta	$4304
	lda	#\2
	sta	$2121		; address of CGRAM to start copying graphics to

	stz	$4300		; 0= 1 byte increment (not a word!)
	lda	#$22
	sta	$4301		; destination 21xx   this is 2122 (CGRAM Gate)

	lda	#$01		; turn on bit 1 (corresponds to channel 0) of DMA channel reg.
	sta	$420b		;   to enable transfer

	plp
	pla
.endm


;macro for loading graphics data into the VRAM
;syntax LoadVRAM LABEL  VRAM_ADDRESS  SIZE
;
; Note: VRAM_ADDRESS is a byte address.
;
.macro LoadVRAM
	pha
	phx
	php

	A8
	XY16

	lda #$80
	sta VMAIN ; Set Word Write mode to VRAM (increment after $2119)

	; Set VRAM address to VRAM_ADDRESS
	ldx #\2/2
	stx VMADDL

	lda #$01
	sta DMAP0 ; Set DMA Mode (word, increment)

	; Set low byte address to $18 (high byte assumed to be $21, so $2100 to $21FF)
	lda #<VMDATAL
	sta BBAD0 ; Write to VRAM ($2118)

	ldx #\1 ; Load Tile Address
	stx A1T0L ; Write DMA Source Address
	stz A1B0 ; Take it from bank 0

	; Size of transfer
	ldx #\3
	stx DAS0L

	lda #$01
	sta MDMAEN ; Initiate VRAM DMA Transfer

	plp
	plx
	pla
.endm

; syntax Fill_VRAM VRAM_ADDRESS W_VALUE N_WORDS
.macro Fill_VRAM
	pha
	phx
	php

	A8
	XY16

	lda #$80
	sta VMAIN ; Set Word Write mode to VRAM (increment after $2119)
	ldx #\1/2
	stx VMADDL ; Destination address

	A16
	ldx #\3
	lda #\2
ClearVRAM_next\@:
	sta VMDATAL
	dex
	bne ClearVRAM_next\@

	plp
	plx
	pla
.endm

.macro ForceVBLANK
	pha
	php
	A8
	lda     #%10000000  ; Force VBlank by turning off the screen.
	sta     INIDISP
	plp
	pla
.endm

.macro EndVBLANK
	pha
	php
	A8
	lda     #%00001111  ; End VBlank, setting brightness to 15 (100%).
	sta     INIDISP
	plp
	pla
.endm

.macro EnableNMI
	pha
	php
	A8
	lda $4200
	ora #$80
	sta $4200
	plp
	pla
.endm

.macro A8
	sep #$20 ; Set the A register to 8-bit.
.endm
.macro A16
	rep #$20 ; Set the A register to 16-bit.
.endm
.macro XY8
	sep #$10 ; Set the X and Y registers to 8-bit
.endm
.macro XY16
	rep #$10 ; Set the X and Y registers to 16-bit
.endm


.macro pushall
	pha
	phx
	phy
	php
.endm

.macro popall
	plp
	ply
	plx
	pla
.endm

; Synatx DrawStringPtr address X Y
.macro DrawStringPtr
	pha
	phx
	phy
	php

	; Calculate address
	XY16
	A8
	lda #\3 ; Y
	sta $4202 ; First parameter for multiplication
	lda #32 ; pitch
	sta $4203 ; Second parameter for multiplication
	; wait 8 cycles for result
	nop
	nop
	nop
	nop
	A16
	lda $4216 ; read result
	clc
	adc #$3000 + \2
	tax

	A16
	XY16

	; Now, load up some data into our tile map
	stx $2116
	ldx #\1
@drawstring_next\@:
  lda 0,X ; Load next character
  and #$ff
  beq @drawstring_done\@ ; If it's a 0, quit
  sta VMDATAL ; Store result in next OAM table
  inx ; Go to next character
  jmp @drawstring_next\@

@drawstring_done\@:


	plp
	ply
	plx
	pla

.endm

; Syntax: DrawString "string" X Y
.macro DrawString
	jmp skip\@
drawstring_str\@:
	.db \1,0
skip\@:
	DrawStringPtr drawstring_str\@ \2 \3
.endm

; Syntax: Memset address value count
.macro Memset
	pha
	phx
	phy
	php
	A8
	XY16
	ldx #\3.W ; count
	lda #\2 ; value
	ldy #0.W ; offset
MemsetLoop\@:
	sta \1, y ; Address + Y
	iny
	dex
	bne MemsetLoop\@

	plp
	ply
	plx
	pla
.endm


; Syntax: Memcpy dst src count
.macro Memcpy
	pha
	phx
	phy
	php

	A16
	XY16
	lda #(\3 -1).W
	ldy #\1
	ldx #\2

	mvn

	plp

	ply
	plx
	pla

.endm


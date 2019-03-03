.include "header.inc"
.include "snes_init.asm"
.include "snesregs.inc"
.include "misc_macros.inc"
.include "zeropage.inc"
.include "globals.inc"
.include "controllerbits.inc"

.define CTL_ID_STANDARD		0
.define CTL_ID_NTT_KEYPAD	4



	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Empty interrupt handler.
	;
.BANK 0 SLOT 0
.ORG 0
.SECTION "EmptyVectors" SEMIFREE

EmptyHandler:
       rti

.ENDS


.bank 0
.section "MainCode"

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Vertical blank interrupt
	;
VBlank:
	pha
	phx
	phy
	php
	A8
	XY8

	; Read controller status
	jsr readGamepads

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

	A16
	inc framecount

	plp
	ply
	plx
	pla
	rti

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Main entry point!
	;
Start:
	Snes_Init

	SetPalette PALETTE, 0, 22*9
	;SetPalette PALETTE, 4, 8
	;SetPalette PALETTE, 8, 8
	;SetPalette PALETTE, 12, 8
	;SetPalette PALETTE, 16, 8

	LoadVRAM TILES, 0, $2000 ; (TILES_END-TILES)
	;LoadVRAM TILES, $1000, $2000 ; (TILES_END-TILES)
	LoadVRAM PAT, $2000, 512
	;LoadVRAM TILES, $2000, 512
	;LoadVRAM TILES, 2048, 2048

	.define BG1_TILE_MAP_OFFSET	$4000
	.define BG2_TILE_MAP_OFFSET	$4800

	;;;;
	A8
	XY16

	; Set Video Mode 1, 8x8 tiles, 4 color BG1/BG2/BG3/BG4
	lda #$01
	sta BGMODE

	;;; Configure backgrounds

	lda #$20		; [7-4]: BG2 [3-0]: BG1 (4k steps)
	sta BG12NBA         ; Set BG1 and BG2 character VRAM offset to $0000 (word address)
	; BG1
	lda #>BG1_TILE_MAP_OFFSET	; Set BG1's Tile Map offset
	sta BG1SC           		; And the Tile Map size to 32x32
	; BG2
	lda #>BG2_TILE_MAP_OFFSET ; $08            ; Set BG2's Tile Map offset
	sta BG2SC

	;;; Enable backgrounds
	lda #$03            ; Enable BG1+2
	sta TM


	stz CGADSUB
	;;;;;

	;FillVRAM BG2_TILE_MAP_OFFSET BGTILE 32*32*1
;	DrawString "32 Bit Controller Test" 4 2

	A8

	jsr gamepads_init

	EnableNMI

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	A8

	;;;; Fade
title_screen:
	ForceVBLANK

	; BG1
	LoadVRAM TITLEBG BG1_TILE_MAP_OFFSET	32*32*2
	; BG2
	Fill_VRAM BG2_TILE_MAP_OFFSET ((1<<BGMAPENT_PALSHIFT)|0) 32*32

	; Disable forced blanking (clear bit 7)
	; Start with master brightness at 0 (black)
	; for upcoming fade-in
	stz INIDISP

	; Perform fadein
	jsr effect_fadein

	; Now stay here until start is pressed.
@title_loop
	wai
	A16
	lda gamepad1_pressed
	and #CTL_WORD0_START
	beq @title_loop


grid_screen:
	jsr effect_fadeout
	ForceVBLANK

	; Load the grid
	LoadVRAM GRIDBG BG1_TILE_MAP_OFFSET	32*32*2

	; Disable forced blanking (clear bit 7)
	; Start with master brightness at 0 (black)
	; for upcoming fade-in
	A8
	stz INIDISP

	; Perform fadein
	jsr effect_fadein

@grid_loop:
	wai
	bra @grid_loop


ZERO:
	.db 2
	.db 0

BGTILE:
	.db 0
	.db 2

PALETTE:
	.incbin "main.cgr"
	.incbin "pattern.cgr"


TILES:
	.incbin "main.vra"
TILES_END:

PAT:
	.incbin "pattern.vra"

TITLEBG:
	.incbin "title.map"

GRIDBG:
	.incbin "grid.map"

.ends

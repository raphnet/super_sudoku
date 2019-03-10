.include "header.inc"
.include "snes_init.asm"
.include "snesregs.inc"
.include "misc_macros.inc"
.include "zeropage.inc"
.include "gamepads.inc"
.include "text.inc"
.include "cursor.inc"

; Offset for position displaying the cursor centered on 0,0
.define GRID_CURSOR_ORIGIN_X	16
.define GRID_CURSOR_ORIGIN_Y	31

.define PRESS_B_TEXT_X	8
.define PRESS_B_TEXT_Y	20
.define PRESS_B_BOX_X	1
.define PRESS_B_BOX_Y	18
.define PRESS_B_BOX_W	30
.define PRESS_B_BOX_H	5

; First menu (load or empty)
.define MENU1_CURSOR_ORG_X	40
.define MENU1_CURSOR_ORG_Y	152
.define MENU1_BOX_X	3
.define MENU1_BOX_Y 16
.define MENU1_BOX_W 26
.define MENU1_BOX_H 10

; Second menu (optional) (select difficulty)
.define MENU2_CURSOR_ORG_X	40
.define MENU2_CURSOR_ORG_Y  136
.define MENU2_TEXT_FIRST_LINE_Y	18
.define MENU2_TEXT_X 8

.16BIT

.RAMSECTION "main_variables" SLOT RAM_SLOT
var_test1: db
bg2_off: db
bg2_count: db

grid_changed: db ; When non-zero, causes grid_syncToScreen to be called at vblank

tmp_hint_value: dw

; Pointers to gamepads_pX_getEvents and gamepads_pX_clearEvents. Set
; depending on which controller pad is used to press B at title.
fn_getEvents: dw
fn_clearEvents: dw

.ENDS

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Empty interrupt handler.
	;
.BANK 0
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

	; Update the global frame counter
	A16
	inc framecount

	; Synchronize sprite 0 in case it moved
	lda #0
	jsr sprite_sync
	lda #1
	jsr sprite_sync


	; Redraw the sudoku grid contents if it changed
	A8
	lda grid_changed
	beq @noredrawgrid
	jsr grid_syncToScreen
@noredrawgrid:
	stz grid_changed

	; Process effects
	jsr effects_dovblank


	; Final housekeeping not touching the PPU
	jsr cursor_dovblank

	jsr readGamepads

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

	A8

	SetPalette PALETTE, 0, 22*9

	SetPalette SPRITES_PALETTE, 128, 32	; 16 colors

	LoadVRAM TILES, 0, (TILES_END-TILES)
	LoadVRAM PAT, $2000, (PAT_END-PAT)/2
	LoadVRAM NUMBER_TILES, $4000, (NUMBER_END-NUMBER_TILES)
	LoadVRAM SPRITES, $8000, (SPRITES_END-SPRITES)/2
	; Define byte addresse for tile maps
	.define BG1_TILE_MAP_OFFSET	$3000
	.define BG2_TILE_MAP_OFFSET	$3800
	.define BG3_TILE_MAP_OFFSET $6000

	;;;;
	A8
	XY16

	; Set Video Mode 1, 8x8 tiles, 4 color BG1/BG2/BG3/BG4
	lda #$09
	sta BGMODE

	;;; Configure backgrounds

	; Indicate where tiles are located for BG1 and BG2
	lda #$10		; [7-4]: BG2 [3-0]: BG1 (4k steps)
	sta BG12NBA
	; BG0: 0x0000 (0x0000 B)
	; BG1: 0x1000 (0x2000 B)


	; BG1 map
	lda #>(BG1_TILE_MAP_OFFSET>>1)
	sta BG1SC

	; BG2 map
	lda #>(BG2_TILE_MAP_OFFSET>>1)
	sta BG2SC

	; BG2 tiles located at 0x2000 (0x4000 B)
	lda #$02
	sta BG34NBA

	; BG3
	lda #>(BG3_TILE_MAP_OFFSET>>1)
	sta BG3SC



	stz CGADSUB

	;;; text functions init
	jsr text_init

	;;; Effect engine
	jsr effects_init

	;;; Sprites
	jsr sprites_init

	; sssnnbbb   s: Object size  n: name selection  b: base selection
	; s: 5 = 32x32
	; n: Base address (b<<14). 32K here.
	lda #( $5<<OBSEL_OBJSIZE_SHIFT | 2 )
	sta OBSEL

	; Try to configure sprite 0 (0 * 4)
;	ldx #0000
;	stx OAMADDL
 
	; Write record for grid cursor
	lda #32	; X
	sta oam_table1+0
	lda #64 ; Y
	sta oam_table1+1
	lda #00 ; Starting tile id
	sta oam_table1+2
	lda #(3<<4) ; Priority 3
	sta oam_table1+3

	; Write record for menu cursor
	lda #32	; X
	sta oam_table1+4
	lda #64 ; Y
	sta oam_table1+5
	lda #04 ; Starting tile id
	sta oam_table1+6
	lda #(3<<4) ; Priority 3
	sta oam_table1+7


	lda #$54
	sta oam_table2

	;;; Enable backgrounds and sprites
	A8
	lda #$17            ; Enable OBJS+BG1+2
	sta TM


	;;; Cursor helper
	jsr cursor_init

	A8
	XY8

	stz grid_changed


	jsr gamepads_init

	EnableNMI

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	A8

title_screen:
	ForceVBLANK

	; BG1
	LoadVRAM TITLEBG BG1_TILE_MAP_OFFSET	_sizeof_TITLEBG

	; BG2
	Fill_VRAM BG2_TILE_MAP_OFFSET ((2<<BGMAPENT_PALSHIFT)|0) 	32*32

	; BG3
	Fill_VRAM BG3_TILE_MAP_OFFSET ((1<<BGMAPENT_PALSHIFT)|0|$0000) 	32*32

	A16
	XY16

	jsr drawPressB
	bra fadein_titleScreen

title_screen_from_step1:
	jsr drawPressB
	bra titlescreen_loop


drawPressB:
	pushall

	wai
	text_drawBox PRESS_B_BOX_X PRESS_B_BOX_Y PRESS_B_BOX_W PRESS_B_BOX_H
	ldx #PRESS_B_TEXT_X
	ldy #PRESS_B_TEXT_Y
	jsr text_gotoxy
	text_drawString "PRESS B TO START"

	popall

	rts

fadein_titleScreen:

	; Disable forced blanking (clear bit 7)
	; Start with master brightness at 0 (black)
	; for upcoming fade-in
	A8
	stz INIDISP

	; Perform fadein
	jsr effect_fadein


titlescreen_loop:

	; Now stay here until B is pressed. This first button press
	; is used to choose which controller port will be used from there.
@title_loop
	wai

	A16
	XY16

	ldx #0
	jsr gamepads_p1_getEvents
	and #CTL_WORD0_B
	bne @p1

	jsr gamepads_p2_getEvents
	and #CTL_WORD0_B
	bne @p2

	bra @title_loop


@p1:
	lda #gamepads_p1_getEvents
	sta fn_getEvents
	lda #gamepads_p1_clearEvents
	sta fn_clearEvents
	bra @controller_select_done
@p2:
	lda #gamepads_p2_getEvents
	sta fn_getEvents
	lda #gamepads_p2_clearEvents
	sta fn_clearEvents

@controller_select_done:
	; From this point on, functions must be called indirectly.
	jsr clearEvents


	;; Step 2 of title. Select level
	;
	; Select mode:
	;
	; - Empty grid
	; - Simple puzzle
	; - Easy puzzle
	; - Intermediate puzzle
	; - Expert puzzle
	;
;	A16
;	XY16

;	lda #3
;	sta text_box_x
;	lda #16
;	sta text_box_y
;	lda #26
;	sta text_box_w
;	lda #9
;	sta text_box_h

	; Remove 'PRESS B TO START' box
	wai
	text_clearBox PRESS_B_BOX_X PRESS_B_BOX_Y PRESS_B_BOX_W PRESS_B_BOX_H

back_to_step2:
	wai
	text_drawBox MENU1_BOX_X MENU1_BOX_Y MENU1_BOX_W MENU1_BOX_H
	wai
	text_drawStringXY "SELECT MODE:" 4 17
	text_drawStringXY "BUILT-IN PUZZLE" 8 20
	text_drawStringXY "EMPTY GRID" 8 22

	jsr clearEvents

	; Setup the cursor for the menu
	cursor_setGridSize 1 2 ; W H
	cursor_setScreenOrigin MENU1_CURSOR_ORG_X MENU1_CURSOR_ORG_Y
	cursor_jumpToGridXY 0 0
	cursor_setStartingTileID 4



@title_step2_loop:
	wai

	ldx #0 ; First word only
	jsr getEvents ; returns 16 bits

	bit #CTL_WORD0_A
	bne @back_to_step1
	bit #CTL_WORD0_B
	bne @choice_made

	jsr cursor_move_by_gamepad

	jsr clearEvents

	bra @title_step2_loop

@back_to_step1:
	wai
	text_clearBox MENU1_BOX_X MENU1_BOX_Y MENU1_BOX_W MENU1_BOX_H
	wai
	jmp title_screen_from_step1

@choice_made:
	; Start with an empty puzzle
	jsr puzzles_loadEmpty

	; If cursor Y is 0, go on with difficulty selection.
	lda cursor_grid_y
	beq select_level_Step

	; Otherwise, just start. An empty puzzle is ready.
	jmp start_with_blank_grid

select_level_Step:
	A16

	; Overwrite previous menu text, and grow by one line
	text_drawBox MENU1_BOX_X MENU1_BOX_Y MENU1_BOX_W MENU1_BOX_H+1

	text_drawStringXY "SIMPLE PUZZLE"		MENU2_TEXT_X 	MENU2_TEXT_FIRST_LINE_Y
	text_drawStringXY "EASY PUZZLE" 		MENU2_TEXT_X 	MENU2_TEXT_FIRST_LINE_Y+2
	text_drawStringXY "INTERMEDIATE PUZZLE" MENU2_TEXT_X 	MENU2_TEXT_FIRST_LINE_Y+4
	text_drawStringXY "EXPERT PUZZLE"		MENU2_TEXT_X 	MENU2_TEXT_FIRST_LINE_Y+6

	cursor_setGridSize 1 4 ; W H
	cursor_setScreenOrigin MENU2_CURSOR_ORG_X MENU2_CURSOR_ORG_Y
	cursor_jumpToGridXY 0 0

	jsr clearEvents
@title_step3_loop:
	wai

	ldx #0 ; First word only
	jsr getEvents ; returns 16 bits

	bit #CTL_WORD0_A
	bne @back_to_step2
	bit #CTL_WORD0_B
	bne @choice_made

	jsr cursor_move_by_gamepad

	jsr clearEvents
	bra @title_step3_loop

@back_to_step2:
	text_clearBox MENU1_BOX_X MENU1_BOX_Y MENU1_BOX_W MENU1_BOX_H+1
	jmp back_to_step2


@choice_made:
	jsr clearEvents

	A16

	; Save puzzle ID
	lda cursor_grid_y

	; Prepare arguments for loading puzzle
	sta puzzle_level	; Direct from menu index (0=simple,1=easy,2=intermediate,3=expert)

	lda #0
	sta puzzle_id

	; Load the puzzle to puzzle_buffer
	jsr puzzles_load

	bra grid_screen

start_with_blank_grid:

grid_screen:
	jsr effect_fadeout
	ForceVBLANK

	; Load the grid
	LoadVRAM GRIDBG BG1_TILE_MAP_OFFSET	32*32*2

	XY16
	A16

	; This takes puzzles.asm:puzzle_buffer as a data source
	jsr grid_init_puzzle

	cursor_setGridSize 9 9
	cursor_setScreenOrigin GRID_CURSOR_ORIGIN_X GRID_CURSOR_ORIGIN_Y
	cursor_setStartingTileID 0
	cursor_jumpToGridXY 0 0

	; Disable forced blanking (clear bit 7)
	; Start with master brightness at 0 (black)
	; for upcoming fade-in
	A8
	stz INIDISP

	; Perform fadein
	jsr effect_fadein

	jsr clearEvents

	;;;;;;; Grid loop
@grid_loop:
	wai

	jsr processButtons

	bra @grid_loop

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Based on the controller keys, perform cursor movement
	;
processButtons:
	pha
	phx
	phy
	php

	A16
	XY8

	ldx #0 ; First word only
	jsr getEvents ; returns 16 bits
;	lda gamepad1_pressed.W

	jsr cursor_move_by_gamepad


	; Check for B button
	bit #CTL_WORD0_B.W
	bne @b_pressed
	bra @b_not_pressed
@b_pressed:
	ldx #7
	jsr insertValueAtCursor
@b_not_pressed:

	; Check for A button (DELETE)
	bit #CTL_WORD0_A.W
	bne @a_pressed
	bra @a_not_pressed
@a_pressed:
	ldx #0	; 0 means delete
	jsr insertValueAtCursor
@a_not_pressed:

	; Check for X button (HINT)
	bit #CTL_WORD0_X.W
	bne @x_pressed
	bra @x_not_pressed
@x_pressed:
	jsr proposeHint
@x_not_pressed:




	; TODO : Only with NTT data keypad!

	; Get the second word which contains numbers
	ldx #2
	jsr getEvents
;	lda gamepad1_pressed+2
	xba ; make the bits consecutive

	ldx #0
	ldy #10
@digit_loop:
	asl	; 0
	bcs @got_digit
	inx
	dey
	bne @digit_loop
	bra @no_digit

@got_digit:
	jsr insertValueAtCursor


@no_digit:


	; Clear event bits
	jsr clearEvents

	plp
	ply
	plx
	pla

	rts


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Try to find a cell which can only accept a single digit
	;
	;
proposeHint:
	pha
	phx
	phy
	php

	A16
	XY16



	ldy #0
@next_y:
		ldx #0
@next_x:

			; Try all digits, from 9 to 1, counting how many are valid
			; moves in this cell
			lda #9
			sta gridarg_value
			; Counter for valid digits
			lda #0
			stx gridarg_x
			sty gridarg_y
@next_digit:
			jsr grid_isEmptyAt
			bcs @occupied	; If occupied, noting to do here
			jsr grid_canInsertValueAt ; sets carry when illegal
			bcs @not_legal
				pha
				lda gridarg_value
				sta tmp_hint_value
				pla
			ina		; Count the possibility
			cmp #2	; When more than 1, stop trying digits in this cell
			beq @more_than_1
@not_legal:
			dec gridarg_value
			bne @next_digit

		; Check if we found 1 digit
		cmp #1
		beq @found_single

@occupied:
@more_than_1:
		inx
		cpx #9
		bne @next_x

	iny
	cpy #9
	bne @next_y

	; No cell found
	; TODO : User feedback?

	bra @return

@found_single:

	cpx cursor_grid_x
	bne @cursor_not_there
	cpy cursor_grid_y
	bne @cursor_not_there

	; If cursor already there, insert the digit!
	lda tmp_hint_value
	sta gridarg_value
	stx gridarg_x
	sty gridarg_y
	jsr grid_insertValueAt

@cursor_not_there:
	; Move pointer to cell, but don't say which number
	; is valid
	stx cursor_grid_x
	sty cursor_grid_y

@return:
	plp
	ply
	plx
	pla

	rts


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Insert a value at the current cursor position
	;
	; Input: X (value to insert)
insertValueAtCursor
	pha
	phx
	phy
	php

	A16

	lda cursor_grid_x
	sta gridarg_x
	lda cursor_grid_y
	sta gridarg_y

	XY8
	stx gridarg_value

	jsr grid_canInsertValueAt
	bcs @error

	jsr grid_insertValueAt
	bra @done

@error:

	jsr effect_mosaic_pulse

@done:

	plp
	ply
	plx
	pla
	rts


getEvents:
	jmp (fn_getEvents)

clearEvents:
	jmp (fn_clearEvents)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; RESOURCES ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ZERO:
	.db 2
	.db 0

BGTILE:
	.db 0
	.db 2

PALETTE:
	.incbin "main.cgr"
	.incbin "numbers.cgr"
	.incbin "numbers_green.cgr"
	.incbin "numbers_green.cgr"
	.incbin "numbers_green.cgr"
	.incbin "pattern.cgr"

PALETTE_BG3:

SPRITES_PALETTE:
	.incbin "sprites.cgr"

TILES:
	.incbin "main.vra"
TILES_END:

PAT:
	.incbin "pattern.vra"
PAT_END:

NUMBER_TILES:
	.incbin "numbers.vra"
NUMBER_END:

TITLEBG:
	.incbin "title.map"

SPRITES:
	.incbin "sprites.vra"
SPRITES_END:

GRIDBG:
	.incbin "grid.map"

.ends

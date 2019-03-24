.include "header.inc"
.include "snes_init.asm"
.include "snesregs.inc"
.include "misc_macros.inc"
.include "zeropage.inc"
.include "gamepads.inc"
.include "text.inc"
.include "cursor.inc"

; Button definitions
.define BUTTON_VALIDATE	CTL_WORD0_B ; for making choices in menu
.define BUTTON_BACK		CTL_WORD0_A ; for going back to previous menu step
.define BUTTON_MENU		CTL_WORD0_X ; open menu (in game)
.define BUTTON_HINT		CTL_WORD0_Y ; request hint (in game)
.define BUTTON_DELETE	CTL_WORD0_A ; delete number (in game)
.define BUTTON_PREV_VALUE	CTL_WORD0_L ; cycle to prev. valid value
.define BUTTON_NEXT_VALUE	CTL_WORD0_R ; cycle to next valid value

.define BUTTON_CANCEL_SOLVER CTL_WORD0_START|CTL_WORD0_A

; Offset for position displaying the cursor centered on 0,0 (over game grid)
.define GRID_CURSOR_ORIGIN_X	8
.define GRID_CURSOR_ORIGIN_Y	31

.define PRESS_B_CURSOR_X	40
.define PRESS_B_CURSOR_Y	152
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

; Third menu (level selection)
.define MENU3_CURSOR_ORG_X	20
.define MENU3_CURSOR_ORG_Y	24
.define MENU3_BOX_X	2
.define MENU3_BOX_Y 2
.define MENU3_BOX_W 28
.define MENU3_BOX_H 24
.define MENU3_TEXT_X 5
.define MENU3_TEXT_Y 4

; In-game menu
.define MENU4_BOX_X	4
.define MENU4_BOX_Y 15
.define MENU4_BOX_W 23
.define MENU4_BOX_H 11
.define MENU4_TEXT_X 8
.define MENU4_TEXT_Y 17
.define MENU4_CURSOR_ORG_X 40
.define MENU4_CURSOR_ORG_Y 128
; return values (stored in ingame_menu_result.W)
.define INGAME_MENU_RES_NOP		0
.define INGAME_MENU_RES_RESTART	1
.define INGAME_MENU_RES_SOLVE	2
.define INGAME_MENU_RES_TITLE	3


.define CURSOR_INGAME_TILE_ID	0
.define CURSOR_MENU_TILE_ID		4
.define CURSOR_HIDDEN_TILE_ID	8

.16BIT

.RAMSECTION "main_variables" SLOT RAM_SLOT
bg2_off: db
bg2_count: db

grid_changed: db ; When non-zero, causes grid_syncToScreen to be called at vblank
grid_changed_padding: db

tmp_hint_value: dw
cur_cycled_idx: dw

; Pointers to gamepads_pX_getEvents and gamepads_pX_clearEvents. Set
; depending on which controller pad is used to press B at title.
fn_getEvents: dw
fn_clearEvents: dw
; Copy of ctl_id_pX for active controller
controller_id: db

; keep a copy of the cursor position before showing the in-game menu
cursor_pos_x_before_menu: dw
cursor_pos_y_before_menu: dw

ingame_menu_result: dw

run_solver: dw
cancel_solver: dw

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

	A8

	; When the solver is running, only sync the grid
	; a few times per second.
	lda run_solver
	beq @solver_not_running

	A16

	ldx #0 ; First word only
	jsr getEvents ; returns 16 bits
	bit #BUTTON_CANCEL_SOLVER
	beq @solver_not_running
	lda #1
	sta cancel_solver
@solver_not_running:
	A8

	lda grid_changed
	beq @noredrawgrid
@redrawgrid:
	jsr grid_syncToScreen
@noredrawgrid:
	stz grid_changed

	; Process effects
	jsr effects_dovblank

	jsr bg1_sync

	jsr clock_draw

	; Final housekeeping not touching the PPU
	jsr cursor_dovblank
	jsr readGamepads
	jsr clock_tick

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

	SetPalette PALETTE, 0, _sizeof_PALETTE

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

	; Set Video Mode 1, 8x8 tiles, 16-color BG1/BG2, 4-color BG3
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


	lda #$54
	sta oam_table2

	; write to TM register, enable OBJs, BG1-2-3
	EnableLayers $17

	;;; Cursor helper
	jsr cursor_init

	A8
	XY8

	stz grid_changed
	stz run_solver

	jsr gamepads_init

	jsr clock_initreset

	jsr sound_loadApu

	EnableNMI

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	A8

title_screen:
	ForceVBLANK

	; BG1
	jsr bg1_loadTitleMap

	; BG2
	Fill_VRAM BG2_TILE_MAP_OFFSET ((2<<BGMAPENT_PALSHIFT)|0) 	32*32

	; BG3
	Fill_VRAM BG3_TILE_MAP_OFFSET ((1<<BGMAPENT_PALSHIFT)|0|$0000) 	32*32

	EnableLayers $17

	A16
	XY16

	jsr drawPressB
	jmp fadein_titleScreen

title_screen_from_step1:
	jsr drawPressB
	jsr sound_effect_back
	jmp titlescreen_loop


drawPressB:
	pushall

	wai
	text_drawBox PRESS_B_BOX_X PRESS_B_BOX_Y PRESS_B_BOX_W PRESS_B_BOX_H
	ldx #PRESS_B_TEXT_X
	ldy #PRESS_B_TEXT_Y
	jsr text_gotoxy
	text_drawString "PRESS B TO START"

	; Cursor is static
	cursor_setGridSize 1 1 ; W H
	cursor_setScreenOrigin PRESS_B_CURSOR_X PRESS_B_CURSOR_Y
	cursor_jumpToGridXY 0 0
	cursor_setStartingTileID CURSOR_MENU_TILE_ID
	cursor_setPitch 16 16


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
@title_loop:
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
	lda #gamepads_p1_getEvents.W
	sta fn_getEvents
	lda #gamepads_p1_clearEvents.W
	sta fn_clearEvents
	A8
	lda ctl_id_p1
	sta controller_id
	bra @controller_select_done
@p2:
	lda #gamepads_p2_getEvents.W
	sta fn_getEvents
	lda #gamepads_p2_clearEvents.W
	sta fn_clearEvents
	A8
	lda ctl_id_p2
	sta controller_id

@controller_select_done:
	jsr sound_effect_menuselect

	A16
	; From this point on, functions must be called indirectly.
	jsr clearEvents


	;; Step 2 of title. Select empty grid or built in puzzle

	; Remove 'PRESS B TO START' box
	text_clearBox PRESS_B_BOX_X PRESS_B_BOX_Y PRESS_B_BOX_W PRESS_B_BOX_H

back_to_step2:
	text_drawBox MENU1_BOX_X MENU1_BOX_Y MENU1_BOX_W MENU1_BOX_H
	text_drawStringXY "SELECT MODE:" 4 17
	text_drawStringXY "BUILT-IN PUZZLE" 8 20
	text_drawStringXY "EMPTY GRID" 8 22

	jsr clearEvents

	; Setup the cursor for the menu
	cursor_setGridSize 1 2 ; W H
	cursor_setScreenOrigin MENU1_CURSOR_ORG_X MENU1_CURSOR_ORG_Y
	cursor_jumpToGridXY 0 0
	cursor_setStartingTileID CURSOR_MENU_TILE_ID
	cursor_setPitch 16 16



@title_step2_loop:
	wai

	ldx #0 ; First word only
	jsr getEvents ; returns 16 bits

	bit #BUTTON_BACK
	bne @back_to_step1
	bit #BUTTON_VALIDATE
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
	jsr sound_effect_menuselect
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
	cursor_setPitch 16 16
	cursor_jumpToGridXY 0 0

	jsr clearEvents
@title_step3_loop:
	wai

	ldx #0 ; First word only
	jsr getEvents ; returns 16 bits

	bit #BUTTON_BACK
	bne @back_to_step2
	bit #BUTTON_VALIDATE
	bne @choice_made

	jsr cursor_move_by_gamepad

	jsr clearEvents
	bra @title_step3_loop

@back_to_step2:
	text_clearBox MENU1_BOX_X MENU1_BOX_Y MENU1_BOX_W MENU1_BOX_H+1
	jsr sound_effect_back
	jmp back_to_step2


@choice_made:
	jsr sound_effect_menuselect
	jsr clearEvents

	A16

	; Save puzzle ID
	lda cursor_grid_y

	; Prepare arguments for loading puzzle
	sta puzzle_level	; Direct from menu index (0=simple,1=easy,2=intermediate,3=expert)


prepare_ask_puzzle_id:
	text_clearBox MENU1_BOX_X MENU1_BOX_Y MENU1_BOX_W MENU1_BOX_H+1
	text_drawBox MENU3_BOX_X MENU3_BOX_Y MENU3_BOX_W MENU3_BOX_H
	text_drawStringXY " 1    2    3    4    5"		MENU3_TEXT_X 	MENU3_TEXT_Y
	text_drawStringXY " 6    7    8    9   10"		MENU3_TEXT_X 	MENU3_TEXT_Y+1
	text_drawStringXY "11   12   13   14   15"		MENU3_TEXT_X 	MENU3_TEXT_Y+2
	text_drawStringXY "16   17   18   19   20"		MENU3_TEXT_X 	MENU3_TEXT_Y+3
	text_drawStringXY "21   22   23   24   25"		MENU3_TEXT_X 	MENU3_TEXT_Y+4
	text_drawStringXY "26   27   28   29   30"		MENU3_TEXT_X 	MENU3_TEXT_Y+5
	text_drawStringXY "31   32   33   34   35"		MENU3_TEXT_X 	MENU3_TEXT_Y+6
	text_drawStringXY "36   37   38   39   40"		MENU3_TEXT_X 	MENU3_TEXT_Y+7
	text_drawStringXY "41   42   43   44   45"		MENU3_TEXT_X 	MENU3_TEXT_Y+8
	text_drawStringXY "46   47   48   49   50"		MENU3_TEXT_X 	MENU3_TEXT_Y+9
	text_drawStringXY "51   52   53   54   55"		MENU3_TEXT_X 	MENU3_TEXT_Y+10
	text_drawStringXY "56   57   58   59   60"		MENU3_TEXT_X 	MENU3_TEXT_Y+11
	text_drawStringXY "61   62   63   64   65"		MENU3_TEXT_X 	MENU3_TEXT_Y+12
	text_drawStringXY "66   67   68   69   70"		MENU3_TEXT_X 	MENU3_TEXT_Y+13
	text_drawStringXY "71   72   73   74   75"		MENU3_TEXT_X 	MENU3_TEXT_Y+14
	text_drawStringXY "76   77   78   79   80"		MENU3_TEXT_X 	MENU3_TEXT_Y+15
	text_drawStringXY "81   82   83   84   85"		MENU3_TEXT_X 	MENU3_TEXT_Y+16
	text_drawStringXY "86   87   88   89   90"		MENU3_TEXT_X 	MENU3_TEXT_Y+17
	text_drawStringXY "91   92   93   94   95"		MENU3_TEXT_X 	MENU3_TEXT_Y+18
	text_drawStringXY "96   97   98   99  100"		MENU3_TEXT_X 	MENU3_TEXT_Y+19

	cursor_setGridSize 5 20 ; W H
	cursor_setScreenOrigin MENU3_CURSOR_ORG_X MENU3_CURSOR_ORG_Y
	cursor_setPitch 40 8
	cursor_jumpToGridXY 0 0

@select_puzzle_id_lop:
	wai

	ldx #0 ; First word only
	jsr getEvents ; returns 16 bits

	bit #BUTTON_BACK
	bne @back_to_level_select
	bit #BUTTON_VALIDATE
	bne @done_puzzle_id_select

	jsr cursor_move_by_gamepad

	jsr clearEvents
	bra @select_puzzle_id_lop

@back_to_level_select:

	; The puzzle ID list window overwrites the title.
	;
	; This is a quick and dirty way to restore it..
	wai
	ForceVBLANK

	jsr bg1_loadTitleMap

	EndVBLANK

	jsr clearEvents
	jsr sound_effect_back
	jmp select_level_Step

@done_puzzle_id_select:

	jsr sound_effect_menuselect
	; ID = cursor_grid_y * 5 + cursor_grid_x
	A16
	lda #0
	clc
	adc cursor_grid_y
	adc cursor_grid_y
	adc cursor_grid_y
	adc cursor_grid_y
	adc cursor_grid_y
	adc cursor_grid_x

	sta puzzle_id

	; Load the puzzle to puzzle_buffer
	jsr puzzles_load

	bra grid_screen

start_with_blank_grid:

grid_screen:
	jsr effect_fadeout
	ForceVBLANK

	; Load the grid
	jsr bg1_loadGridMap

	; Overwrite the L/R icon for "keypad" when using a NTT Data Keypad
	jsr patchBG1_for_NTT_icon

	XY16
	A16

	; This takes puzzles.asm:puzzle_buffer as a data source
	jsr grid_init_puzzle

	cursor_setGridSize 9 9
	cursor_setScreenOrigin GRID_CURSOR_ORIGIN_X GRID_CURSOR_ORIGIN_Y
	cursor_setStartingTileID CURSOR_INGAME_TILE_ID
	cursor_setPitch 16 16
	cursor_jumpToGridXY 4 4 ; Center of the grid

	jsr clock_zero
	jsr clock_show

	; Disable forced blanking (clear bit 7)
	; Start with master brightness at 0 (black)
	; for upcoming fade-in
	A8
	stz INIDISP

	; Perform fadein
	jsr effect_fadein

	jsr clearEvents

	A16
	stz run_solver
	stz cancel_solver
	A8
	;;;;;;; Grid loop
@grid_loop:
	wai

	lda run_solver
	bne @run_solver

	jsr processButtons

	jsr displayNumValidMovesInCell

	jsr grid_checkIfSolved
	bcc @grid_solved

	text_clearBox 22 1 8 2
	jsr clock_start ; or just keep running

	jmp @grid_loop

@run_solver:

	A16
	stz cancel_solver
	A8

	cursor_setStartingTileID CURSOR_HIDDEN_TILE_ID

	jsr easySolver
	lda cancel_solver
	bne @solving_cancelled

	jsr bruteForceSolver
	lda cancel_solver
	bne @solving_cancelled

	stz run_solver

	cursor_setStartingTileID CURSOR_INGAME_TILE_ID


	bra @grid_loop

@solving_cancelled:
	stz run_solver
	cursor_setStartingTileID CURSOR_INGAME_TILE_ID
	jsr grid_removeBruteForced
	jmp @grid_loop

@grid_solved:
	jsr clock_isStopped
	bcc @already_drawn

	jsr sound_effect_solved

	jsr clock_stop

	text_drawStringXY "`abcdefg" 22 1
	text_drawStringXY "pqrstuvw" 22 2
;	text_drawStringXY $80,$81,$82,$83,$84,$85,$86,$87 22 2

@already_drawn:

	jmp @grid_loop



	;;;;; quick debug function to test solver_countValidMoves
displayNumValidMovesInCell:
rts
	pushall

	A16
	XY8

	lda cursor_grid_x
	sta gridarg_x
	lda cursor_grid_y
	sta gridarg_y
	jsr solver_countValidMovesInCell

	text_clearBox 1 1 9 1

	ldx #1
	ldy #1
	jsr text_gotoxy

	lda slv_num_valid_moves
	clc
	adc #$30
	jsr text_putchar


/*
	ldy slv_num_valid_moves
	beq @no_moves

	ldy #0

@lp:
	lda slv_valid_list, Y
	and #$ff
	clc
	adc #$30
	wai
	jsr text_putchar
	iny
	cpy slv_num_valid_moves
	bne @lp
@no_moves:
*/
	popall
	rts

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

	jsr cursor_move_by_gamepad

	bit #BUTTON_MENU.W
	bne @menu_button_pressed
	jmp @menu_not_pressed


@menu_button_pressed:

	jsr clock_hide
	jsr clock_stop

	lda cursor_grid_x
	sta cursor_pos_x_before_menu
	lda cursor_grid_y
	sta cursor_pos_y_before_menu

	jsr ingame_menu

	ldx ingame_menu_result

	cpx #INGAME_MENU_RES_NOP
	beq @menu_done
	cpx #INGAME_MENU_RES_RESTART
	beq @do_restart_puzzle
	cpx #INGAME_MENU_RES_SOLVE
	beq @do_solve_puzzle
	cpx #INGAME_MENU_RES_TITLE
	beq @do_return_title

	jmp @menu_done

@do_restart_puzzle:
	jsr clock_zero
	; read from puzzle_buffer again
	jsr grid_init_puzzle
	bra @menu_done

@do_solve_puzzle:
	lda #1
	sta run_solver
	bra @menu_done

@do_return_title:
	jsr effect_fadeout
	ForceVBLANK
	jmp title_screen

@menu_done:

	wai
	ForceVBLANK
	EnableLayers $17 ; reenable puzzle numbers

	; Reload the grid
	jsr bg1_loadGridMap

	jsr patchBG1_for_NTT_icon

	; Recall the clock, and make it run again
	jsr clock_show
	jsr clock_start


;	EndVBLANK

	A16

	cursor_setGridSize 9 9
	cursor_setScreenOrigin GRID_CURSOR_ORIGIN_X GRID_CURSOR_ORIGIN_Y
	cursor_setStartingTileID CURSOR_INGAME_TILE_ID
	cursor_setPitch 16 16
;	cursor_jumpToGridXY 4 4 ; Center of the grid
	; Bring the cursor back to where it was before
	lda cursor_pos_x_before_menu
	sta cursor_grid_x
	lda cursor_pos_y_before_menu
	sta cursor_grid_y
	jsr cursor_jump_to_destination

	A8
	stz INIDISP
	; Perform fadein
	jsr effect_fadein

	; beware of macros which confuse the assembler regarding
	; size of registers!
	A16
	XY8
@menu_not_pressed:


	; Check for delete button
	bit #BUTTON_DELETE.W
	beq @a_not_pressed
@a_pressed:
	ldx #0	; 0 means delete
	jsr insertValueAtCursor
@a_not_pressed:

	; Check for X button (HINT)
	bit #BUTTON_HINT.W
	beq @x_not_pressed
@x_pressed:
	jsr proposeHint
@x_not_pressed:


	; Check for the 'previous value' button
	bit #BUTTON_PREV_VALUE
	beq @l_not_pressed
	jsr insertPrevValidValue
@l_not_pressed:
	; Check for the 'next value' button
	bit #BUTTON_NEXT_VALUE
	beq @r_not_pressed
	jsr insertNextValidValue
@r_not_pressed:



	; Note: when a standard controller is connected,
	; the driver zeros extra bits. No need to actually
	; check if we have a NTT controller or not.

	; Get the second word which contains numbers
	ldx #2
	jsr getEvents

	bit #CTL_WORD1_KP_CLEAR
	beq @clear_not_pressed
@clear_pressed:
	ldx #0
	jsr insertValueAtCursor
@clear_not_pressed:

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


@standard_controller:


	; Clear event bits
	jsr clearEvents

	plp
	ply
	plx
	pla

	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; In-game menu accessed by pressing X
	;
ingame_menu:
	pushall

	jsr sound_effect_click

	jsr effect_fadeout
	ForceVBLANK

	A16
	XY16

	wai

	jsr bg1_loadTitleMap

	wai
	EnableLayers $13 ; disable puzzle numbers layer

	text_drawBox MENU4_BOX_X MENU4_BOX_Y MENU4_BOX_W MENU4_BOX_H

	text_drawStringXY "BACK TO PUZZLE"		MENU4_TEXT_X 	MENU4_TEXT_Y
	text_drawStringXY "RESTART PUZZLE"		MENU4_TEXT_X 	MENU4_TEXT_Y+2
	text_drawStringXY "SOLVE PUZZLE" 		MENU4_TEXT_X 	MENU4_TEXT_Y+4
	text_drawStringXY "RETURN TO TITLE" 	MENU4_TEXT_X 	MENU4_TEXT_Y+6

	cursor_setGridSize 1 4 ; W H
	cursor_setScreenOrigin MENU4_CURSOR_ORG_X MENU4_CURSOR_ORG_Y
	cursor_setPitch 16 16
	cursor_setStartingTileID CURSOR_MENU_TILE_ID
	cursor_jumpToGridXY 0 0

	A8
	stz INIDISP
	; Perform fadein
	jsr effect_fadein
	A16

@ingame_menu_loop:
	wai

	ldx #0 ; First word only
	jsr getEvents ; returns 16 bits

	bit #BUTTON_BACK
	bne @back
	bit #BUTTON_VALIDATE
	bne @choice_made

	jsr cursor_move_by_gamepad

	jsr clearEvents
	bra @ingame_menu_loop

@choice_made:
	jsr sound_effect_back

	;	return values are defined to match menu order
	lda cursor_grid_y

	; Not implemented yet, so refuse
;	cmp #INGAME_MENU_RES_SOLVE
;	beq @invalid_menu_choice

	; otherwise, that's the return value
	sta ingame_menu_result
	bra @cleanup

@invalid_menu_choice:
	jsr sound_effect_error
	jsr effect_mosaic_pulse
	jsr clearEvents
	bra @ingame_menu_loop

@back: ; go back to game
	lda #INGAME_MENU_RES_NOP
	sta ingame_menu_result
	bra @cleanup

@cleanup:

	jsr clearEvents

	popall

	rts

patchBG1_for_NTT_icon:
	pushall

	; Overwrite the L/R icon for "keypad" when using a NTT Data Keypad
	A8
	lda controller_id
	cmp #CTL_ID_NTT_KEYPAD
	bne @not_ntt
	text_drawStringXY "jk" 22 16	; tiles 104 105
	text_drawStringXY "z{" 22 17	 ; tiles 124 124
@not_ntt:

	popall
	rts


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; As long hints are found, insert them.
	;
	;
easySolver:
	pushall

	AXY16

@next:
	wai

	ldx #0 ; First word only
	jsr getEvents ; returns 16 bits

	bit #BUTTON_CANCEL_SOLVER
	bne @cancel

	jsr solver_findSoleCandidate
	bcc @found
	jsr solver_findUniqueRowCandidate
	bcc @found
	jsr solver_findUniqueColumnCandidate
	bcc @found
	bra @not_found

@found:
	; Get the coordinates
	ldx slv_x
	ldy slv_y

	lda slv_digit
	sta gridarg_value
	stx gridarg_x
	sty gridarg_y
	jsr grid_insertHintedValueAt

	bra @next

@cancel:
	A16
	lda #1
	sta cancel_solver
@not_found:

	popall
	rts


bruteForceSolver:
	jsr solver_bruteForce
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Try to find a cell which can only accept a single digit
	;
	;
proposeHint:
	pushall

	A16
	XY16

	jsr solver_findSoleCandidate
	bcc @found

	jsr solver_findUniqueRowCandidate
	bcc @found

	jsr solver_findUniqueColumnCandidate
	bcc @found


	bra @not_found

@found:
	; Get the coordinates
	ldx slv_x
	ldy slv_y

	cpx cursor_grid_x
	bne @cursor_not_there
	cpy cursor_grid_y
	bne @cursor_not_there

	; If cursor already there, insert the digit!
	lda slv_digit
	sta gridarg_value
	stx gridarg_x
	sty gridarg_y

	jsr sound_effect_write

	jsr grid_insertHintedValueAt

@cursor_not_there:
	; Move pointer to cell, but don't say which number
	; is valid
	stx cursor_grid_x
	sty cursor_grid_y

	bra @return


@not_found:
	jsr sound_effect_error
	jsr effect_mosaic_pulse
	; TODO : Message

@return:
	popall
	rts


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Insert the next possible valid value in the cell.
	;
	; Uses cur_cycled_idx to keep track of what value is being
	; proposed. The list of value is setup by calling solver_countValidMovesInCell
	;
insertNextValidValue:
	pushall

	AXY16

	; Prepare arguments and call function to count moves
	lda cursor_grid_x
	sta gridarg_x
	lda cursor_grid_y
	sta gridarg_y
	jsr solver_countValidMovesInCell

	; Check the result. If there are no valid moves we are done
	lda slv_num_valid_moves
	beq @no_moves

	; Make sure our current move index is still valid
	lda cur_cycled_idx
	cmp slv_num_valid_moves
	bcc @not_too_high	; cur_cycle_idx < slv_num_valid_moves
	lda slv_num_valid_moves
	sta cur_cycled_idx ; store now valid value
@not_too_high:

	inc A
	cmp slv_num_valid_moves
	bcc @ok	; <
	beq @ok ; =
	; >
	lda #0
@ok:
	sta cur_cycled_idx ; store new value

	; When the index is one past the end of the list, propose
	; 0 (empty)
	ldx #0
	cmp slv_num_valid_moves
	beq @doinsert

	; Use index to fetch the valid digit from the array
	tax
	lda slv_valid_list, X
	and #$ff	; drop extra bits

	tax			; storein X for function arg
@doinsert:
	jsr insertValueAtCursor

@no_moves:

	popall
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Insert the previous possible valid value in the cell.
	;
	; Uses cur_cycled_idx to keep track of what value is being
	; proposed. The list of value is setup by calling solver_countValidMovesInCell
	;

insertPrevValidValue:
	pushall

	AXY16

	; Prepare arguments and call function to count moves
	lda cursor_grid_x
	sta gridarg_x
	lda cursor_grid_y
	sta gridarg_y
	jsr solver_countValidMovesInCell

	; Check the result. If there are no valid moves we are done
	lda slv_num_valid_moves
	beq @no_moves

	; Make sure our current move index is still valid
	lda cur_cycled_idx
	cmp slv_num_valid_moves
	bcc @not_too_high	; cur_cycle_idx < slv_num_valid_moves
	lda slv_num_valid_moves
	sta cur_cycled_idx ; store now valid value
@not_too_high:

	; Check if we just decrement our index?
	lda cur_cycled_idx
	bne @nowrap	; < yes
@wrap: 			; < No, it would fall below 0.
	lda slv_num_valid_moves
	bra @wd
@nowrap:
	dec A
@wd:
	sta cur_cycled_idx ; store now active value

	; When the index is one past the end of the list, propose
	; 0 (empty)
	ldx #0
	cmp slv_num_valid_moves
	beq @doinsert


	; Use index to fetch the valid digit from the array
	tax
	lda slv_valid_list, X
	and #$ff	; drop extra bits

	tax			; storein X for function arg
@doinsert:
	jsr insertValueAtCursor

@no_moves:

	popall
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

	; Check if we want to erase or write
	cpx #0
	beq @erasing_value

@writing_value:
	; Do it
	jsr grid_insertValueAt
	; Play sound
	jsr sound_effect_write


@erasing_value:
	jsr grid_isEmptyAt
	bcc @done	; already empty. Do nothing.

	; Do it (write 0 = erase)
	jsr grid_insertValueAt
	; Play sound
	jsr sound_effect_erase

	bra @done

@error:

	jsr sound_effect_error
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
	.incbin "numbers_yellow.cgr"
	.incbin "numbers_orange.cgr"
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

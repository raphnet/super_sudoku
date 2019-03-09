.include "header.inc"
.include "snes_init.asm"
.include "snesregs.inc"
.include "misc_macros.inc"
.include "zeropage.inc"
.include "gamepads.inc"
.include "text.inc"

.define GRID_PITCH	16	; not used. Shifts hardcoded in cursor_gridToScreen
; Offset for position displaying the cursor centered on 0,0
.define CURSOR_ORIGIN_X	16
.define CURSOR_ORIGIN_Y	47
.define GRID_WIDTH	9

.16BIT

.RAMSECTION "main_variables" SLOT RAM_SLOT
var_test1: db
bg2_off: db
bg2_count: db

mosaic_size: db

; The current screen position of the cursor sprite
cursor_x: dw
cursor_y: dw
; The destination position of the cursor sprite
cursor_dst_x: dw
cursor_dst_y: dw
; The coordinates of the cursor over the grid (converted
; to screen coordinates by cursor_gridToScreen)
cursor_grid_x: dw
cursor_grid_y: dw

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
	jsr doCursorMovement
	jsr doCursorMovement
	jsr readGamepads

	plp
	ply
	plx
	pla
	rti

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Animate cursor movement to cursor_dst_x,y
	;
	; Called from VBLANK
	;
	; 
	;
doCursorMovement:
	pha
	phx
	phy
	php

	A16

	lda cursor_x
	cmp cursor_dst_x
	beq @x_done
	bcc @x_less
	dec cursor_x
	bra @x_done
@x_less:
	inc cursor_x
	bra @x_done
@x_done:

	lda cursor_y
	cmp cursor_dst_y
	beq @y_done
	bcc @y_less
	dec cursor_y
	bra @y_done
@y_less:
	inc cursor_y
	bra @y_done
@y_done:

	; Now update the sprite table
	A8
	lda cursor_x
	sta oam_table1
	lda cursor_y
	sta oam_table1+1


	plp
	ply
	plx
	pla

	rts


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
	ldx #0000
	stx OAMADDL

	; Write record
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

	;;; Enable backgrounds and sprites
	A8
	lda #$17            ; Enable OBJS+BG1+2
	sta TM


	A16
	; Cursor start in uppper-left corner of grid
	stz cursor_grid_x
	stz cursor_grid_y
	jsr cursor_gridToScreen
	lda cursor_dst_x
	sta cursor_x
	lda cursor_dst_y
	sta cursor_y

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

	ldx #0
	ldy #0
	jsr text_gotoxy

	lda #'H'
	jsr text_putchar

	ldx #5
	ldy #20
	jsr text_gotoxy

	text_drawString "PRESS B TO START"

	; Disable forced blanking (clear bit 7)
	; Start with master brightness at 0 (black)
	; for upcoming fade-in
	A8
	stz INIDISP

	; Perform fadein
	jsr effect_fadein


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

@title_step2:

	; TODO : Menu

grid_screen:
	jsr effect_fadeout
	ForceVBLANK

	; Load the grid
	LoadVRAM GRIDBG BG1_TILE_MAP_OFFSET	32*32*2

	XY16
	ldx #0
	jsr grid_init

	; Disable forced blanking (clear bit 7)
	; Start with master brightness at 0 (black)
	; for upcoming fade-in
	A8
	stz INIDISP

	; Perform fadein
	jsr effect_fadein


	;;;;;;; Grid loop
@grid_loop:
	wai

	jsr processButtons

	bra @grid_loop

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Based on the controller keys, perform cursor movement
	;
	; Input: cursor_grid_x/y
	; Output cursor_dst_x
	;
cursor_gridToScreen:
	pha
	php

	A16
	lda cursor_grid_x
	asl	; *2
	asl ; *4
	asl ; *8
	asl ; *16
	; if input was valid, carry will be clear.
	adc #CURSOR_ORIGIN_X
	sta cursor_dst_x

	lda cursor_grid_y
	asl	; *2
	asl ; *4
	asl ; *8
	asl ; *16
	adc #CURSOR_ORIGIN_Y
	sta cursor_dst_y

	plp
	pla
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
;	lda gamepad1_pressed.W


	; Check for left/right buttons
	bit #CTL_WORD0_LEFT.W
	bne @go_left
	bit #CTL_WORD0_RIGHT.W
	bne @go_right
	bra @lr_done
@go_right:
	jsr cursor_moveRight
	bra @lr_done
@go_left:
	jsr cursor_moveLeft
@lr_done:

	; Check for up/down buttons
	bit #CTL_WORD0_UP.W
	bne @go_up
	bit #CTL_WORD0_DOWN.W
	bne @go_down
	bra @ud_done
@go_up:
	jsr cursor_moveUp
	bra @ud_done
@go_down:
	jsr cursor_moveDown
@ud_done:

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

	; Update cursor destination on screen based on
	; (new?) position on the grid
	jsr cursor_gridToScreen

	plp
	ply
	plx
	pla

	rts

cursor_moveLeft:
	pha
	lda cursor_grid_x
	beq @min_reached
	dec A
	sta cursor_grid_x
@min_reached:
	pla
	rts

cursor_moveRight:
	pha
	lda cursor_grid_x
	cmp #GRID_WIDTH-1
	beq @max_reached
	inc A
	sta cursor_grid_x
@max_reached:
	pla
	rts

cursor_moveUp:
	pha
	lda cursor_grid_y
	beq @min_reached
	dec A
	sta cursor_grid_y
@min_reached:
	pla
	rts

cursor_moveDown:
	pha
	lda cursor_grid_y
	cmp #GRID_WIDTH-1
	beq @max_reached
	inc A
	sta cursor_grid_y
@max_reached:
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
@next_digit:
			stx gridarg_x
			sty gridarg_y
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

.include "header.inc"
.include "snesregs.inc"
.include "misc_macros.inc"
.include "zeropage.inc"

.bank 0 slot 1

.ramsection "cursor_variables" SLOT RAM_SLOT
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

	; On screen (pixels) origin of cursor (grid 0,0)
	cursor_org_x: dw
	cursor_org_y: dw

	; Grid width
	cursor_grid_w: dw
	cursor_grid_h: dw

	; Max grid values (computed from grid width automatically)
	cursor_grid_max_x: dw
	cursor_grid_max_y: dw
.ends

.16BIT


.section "cursor code" FREE


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Animate cursor movement to cursor_dst_x,y
	;
	; Called from VBLANK
	;
cursor_dovblank:
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

	jsr cursor_gridToScreen

	plp
	ply
	plx
	pla

	rts


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Initialize the cursor system
	;
cursor_init:
	pushall

	A16
	; Cursor start in uppper-left corner of grid
	stz cursor_grid_x
	stz cursor_grid_y


	lda #9
	sta cursor_grid_w
	sta cursor_grid_h

	stz cursor_org_x
	stz cursor_org_y

	jsr cursor_jump_to_destination

	popall

	rts

cursor_jump_to_destination:
	pushall
	AXY16

	jsr cursor_gridToScreen
	lda cursor_dst_x
	sta cursor_x
	lda cursor_dst_y
	sta cursor_y

	popall
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; 16-bit A: Bits from gamepadX_pressed
	;
	; Does not clear the events.
	;
cursor_move_by_gamepad:
	pushall

	AXY16

	; CTL_WORD0_UP    $08
	; CTL_WORD0_DOWN  $04
	; CTL_WORD0_LEFT  $02
	; CTL_WORD0_RIGHT $01

	ldx #0
@lp:
	lsr	; Drop bit in carry
	bcs @button_found ; Carry set means button pressed.
	inx
	inx
	cpx #8
	bne @lp

	bra @nobutton

@button_found:
	jsr (_cursor_dirFuncs, X)

@nobutton:

	popall
	rts

_cursor_dirFuncs:
	.dw cursor_moveRight
	.dw cursor_moveLeft
	.dw cursor_moveDown
	.dw cursor_moveUp


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Move the cursor left one grid position
	;
cursor_moveLeft:
	pha
	lda cursor_grid_x
	beq @min_reached
	dec A
	sta cursor_grid_x
@min_reached:
	pla
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Move the cursor right one grid position
	;
cursor_moveRight:
	pushall
	AXY16

	ldy cursor_grid_w
	dey
	sty cursor_grid_max_x

	lda cursor_grid_x
	cmp cursor_grid_max_x
	beq @max_reached
	inc A
	sta cursor_grid_x
@max_reached:

	popall
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Move the cursor up one grid position
	;
cursor_moveUp:
	pha
	lda cursor_grid_y
	beq @min_reached
	dec A
	sta cursor_grid_y
@min_reached:
	pla
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Move the cursor down one grid position
	;
cursor_moveDown:
	pushall
	AXY16

	ldy cursor_grid_h
	dey
	sty cursor_grid_max_y

	lda cursor_grid_y
;	cmp #GRID_WIDTH-1
	cmp cursor_grid_max_y
	beq @max_reached
	inc A
	sta cursor_grid_y
@max_reached:

	popall
	rts



	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Convert cursor grid coordinates to screen coordinates
	;
	; Input: cursor_grid_x/y
	; Output cursor_dst_x/y
	;
cursor_gridToScreen:
	pha
	php

	A16
	lda cursor_grid_x
	jsr _cursor_mult_A_by_X_pitch

	; if input was valid, carry will be clear.
	adc cursor_org_x
	sta cursor_dst_x

	lda cursor_grid_y
	jsr _cursor_mult_A_by_Y_pitch

	adc cursor_org_y
	sta cursor_dst_y

	plp
	pla
	rts


_cursor_mult_A_by_Y_pitch:
_cursor_mult_A_by_X_pitch:
	asl ; * 2
	asl ; * 4
	asl ; * 8
	asl ; * 16
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Set the starting tile ID for the cursor sprite
	;
	; Input: A
	;
cursor_setStartingTileID:
	pha
	php

	A8
	sta oam_table1+2

	plp
	pla
	rts



.ends

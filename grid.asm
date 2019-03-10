.include "header.inc"
.include "snesregs.inc"
.include "misc_macros.inc"
.include "zeropage.inc"
.include "puzzles.inc"

.bank 0 slot 1

.ramsection "grid_variables" SLOT RAM_SLOT
	griddata: dsw 81

	gridarg_value: db
	gridarg_padding: db

	gridarg_x: dw
	gridarg_y: dw

	grid_vram_ptr: dw
	gridsync_row_count: dw
.ends

.16BIT

.section "Grid LUT" FREE

.include "neighbors.asm"
	; The above defines neighbor_list, which is a 9x9 array of words. Each word a pointer to a list of neighbors.

	; Neighbor lists are 21 words each.
	; Each word is the offset for the cell within gridata.
	; The 21th is zero and used for stopping
.ends

.section "Grid" FREE

.define INITIAL_DIGIT_PAL	($20 | ($4<<2))
.define ADDED_DIGIT_PAL	($20 | ($5<<2))

.define GRID_BGMAP_PITCH	32
.define GRID_UPPER_LEFT_Y	6
.define GRID_UPPER_LEFT_X	2
.define GRID_ZERO_CHAR		$30	; Which tile is 0

.define GRID_BG_VRAM_ADDRESS	$3000

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Update the screen (VRAM) according to griddata
	;
	; Input: griddata
	;
	; Uses: grid_vram_ptr, gridsync_row_count
	;
grid_syncToScreen:
	pushall

	A16
	XY16

	lda #0
	clc
	adc #GRID_UPPER_LEFT_Y * GRID_BGMAP_PITCH
	adc #GRID_UPPER_LEFT_X ; Advance to X
	adc #GRID_BG_VRAM_ADDRESS

	sta grid_vram_ptr

	; Counter for rows
	ldy #9
	sty gridsync_row_count

	ldy #0 ; Index in griddata

	; Set VRAM pointer to upper/left cell
	lda grid_vram_ptr
	sta VMADDL
	bra @first_row	; Skip the increment

@row_loop:
	lda grid_vram_ptr	; fetch previous row value
	clc
	adc #64
	sta grid_vram_ptr	; remember new start cell
	sta VMADDL			; Set vram destination
@first_row:
	; Prepare counter for 9 cells
	ldx #9
@col_loop:
	lda griddata, Y
	iny			; Next cell in griddata
	iny
	sta VMDATAL	; Value
	stz VMDATAL ; Skip grid
	dex
	bne @col_loop

	dec gridsync_row_count
	bne @row_loop

	popall
	rts


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Check if the specified value (gridarg_value) is found in the
	; neighbors of a given cell (gridarg_x, gridarg_Y)
	;
	; Input: gridarg_value, gridarg_x, gridarg_Y
	;
	; Output: TBD
	;
grid_checkNeighborsForValue:
	pha
	phx
	phy
	php

	A8
	; make sure this is 0 (allows 16 bit read later)
	stz gridarg_padding

	A16
	XY16

	; Multiply by 18 (grid pitch)
	lda gridarg_y
	asl ; x2
	asl ; x4
	asl ; x8
	asl ; x16
	adc gridarg_y ; 18x = 16x + x + x
	adc gridarg_y

	; Add X (2x)
	adc gridarg_x
	adc gridarg_x

	; A now contains the offset into griddata or neighbor_list. Move
	; to Y to use as index
	tay

	; Get the pointer to the list of neighbors for the designated cell
	lda neighbor_list, Y
	;
	sta dp_indirect_tmp1



	ldy #0
@checknext:
	lda (dp_indirect_tmp1),Y	; Load offset for neighbor
	tax							; Move the offset to X to use it
	lda griddata, X				; Load the value at this position
	and #$FF
	cmp gridarg_value			; Check if it is the value we are looking for
	beq @foundit				; Yes? Godd!
	iny							; Advance to next neighbor in list
	iny
	cpy #20*2
	bne @checknext

	; All neighbors checked, no match found
@finished:
	plp
	clc
	bra @pp

@foundit:
	; TODO ? Perhaps remember *where* we found it to show the user why he can't place it here?
	plp
	sec	; Exit with carry set

@pp:
	ply
	plx
	pla

	rts


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Check if a given grid cell is EMPTY
	;
	; Input: gridarg_value, gridarg_x, gridarg_Y
	; Output: Carry flag (when set: Not empty)
	;
grid_isEmptyAt:
	pha
	phx
	phy
	php

	A16
	XY16

	; Multiply by 18 (grid pitch)
	lda gridarg_y
	asl ; x2
	asl ; x4
	asl ; x8
	asl ; x16
	adc gridarg_y ; 18x = 16x + x + x
	adc gridarg_y

	; Add X (2x)
	adc gridarg_x
	adc gridarg_x

	; A now contains the offset into griddata. Move
	; to Y to use as index
	tay

	A8

	; If 0, cell empty.
	lda griddata, Y
	beq @empty

	; non-zero : Not empty. Set carry and return
	plp
	sec
	bra @pp

@empty:
	; empty. Clear carry and return
	plp
	clc

@pp:
	ply
	plx
	pla

	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Check if the grid is solved.
	;
	; Solved = number in all cells. No checks for errors required since
	; the game prevents invalid entries already.
	;
	; Input: griddata
	; Output: Carry flag. (Set = not solved)
	;
grid_checkIfSolved:
	pushall

	A16
	XY16
	ldx #0
@lp:
	lda griddata, X
	and #$ff		; keep only number (ignore attributes)
	beq @ret_sec	; If zero, grid is not full and therefore not solved.
	inx
	inx
	cpx #162
	bne @lp

	; No zeros found = grid full = solved!

@ret_clc:
	popall
	clc
	rts

@ret_sec:
	popall
	sec
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Check if a user value can be inserted in the designated cell.
	;
	; Rules:
	;  - Default digits that are part of the puzzle cannot be replaced/deleted
	;  - Inserting a zero is a deletion operation
	;  - Sudoku rules
	;
	; Input: gridarg_value, gridarg_x, gridarg_Y
	; Output: Carry flag (when set: Refuse move)
	;
grid_canInsertValueAt:
	pha
	phx
	phy
	php

	; If the number to insert is a zero, skip looking for other zeros
	; in neighbor cells.
	A8
	lda gridarg_value
	beq @its_zero

	; First check if the number in argument can be added to this cell
	; based on neighbor rules
	jsr grid_checkNeighborsForValue
	bcs @refuse

@its_zero:

	A16
	XY16

	; Multiply by 18 (grid pitch)
	lda gridarg_y
	asl ; x2
	asl ; x4
	asl ; x8
	asl ; x16
	adc gridarg_y ; 18x = 16x + x + x
	adc gridarg_y

	; Add X (2x)
	adc gridarg_x
	adc gridarg_x

	; A now contains the offset into griddata. Move
	; to Y to use as index
	tay

	A8

	; First look at the number. If 0, allow replacment.
	lda griddata, Y
	beq @replace_ok

	; Now look at the palette/priority byte. If non-equal to initial
	; digit properties, accept.
	iny
	lda griddata, Y
	cmp #INITIAL_DIGIT_PAL
	bne @replace_ok

	; Set carry to refuse
@refuse:
	plp
	sec
	bra @pp

@replace_ok:
	plp
	clc

@pp:
	ply
	plx
	pla
	rts





	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Insert a value at the current cursor position
	;
	; Input: gridarg_value (B)
	;
	;
grid_insertValueAt:
	pha
	phx
	phy
	php

	A16
	XY16

	; Multiply by 18 (grid pitch)
	lda gridarg_y
	asl ; x2
	asl ; x4
	asl ; x8
	asl ; x16
	adc gridarg_y ; 18x = 16x + x + x
	adc gridarg_y

	; Add X (2x)
	adc gridarg_x
	adc gridarg_x

	; A now contains the offset into griddata. Move
	; to Y to use as index
	tay

	A8
	lda gridarg_value
	clc
	sta griddata, Y
	lda #ADDED_DIGIT_PAL
	iny
	sta griddata, Y

	; Trigger a redraw
	lda #1
	sta grid_changed

	plp
	ply
	plx
	pla
	rts


grid_init_blank:
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Init the grid data to all empty cells.
	;
	pushall

	Memset griddata 0 _sizeof_griddata

	popall
	rts


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Init the grid data array by copying from puzzle_buffer
	;
grid_init_puzzle:
	pushall

	XY16
	A8

	ldy #0
	ldx #0

@next_byte:
	lda puzzle_buffer, X	; Read puzzle byte
	sta griddata, Y
	iny

	lda #INITIAL_DIGIT_PAL.B
	sta griddata, Y
	iny

	inx

	cpy #_sizeof_griddata
	bne @next_byte


@done:
;	jsr grid_syncToScreen
	; Trigger a redraw
	lda #1
	sta grid_changed


	popall

	rts

.ends

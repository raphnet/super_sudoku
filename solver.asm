.include "header.inc"
.include "snesregs.inc"
.include "misc_macros.inc"
.include "zeropage.inc"
.include "grid.inc"


.bank 0

.ramsection "solver_variables" SLOT RAM_SLOT
	slv_num_valid_moves: dw
	slv_valid_list: dsb 9

	slv_digit: dw
	slv_x: dw
	slv_y: dw

	slv_tmp_x: dw
	slv_tmp_y: dw

	; An array whose indexes matches gridata. Each element
	; is a count of how many valid moves there are.
	slv_num_moves_per_cell: dsw 81

	;slv_tmpval: dw
.ends

.16BIT

.section "solver code" FREE


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Count how many legal moves a cell has.
	;
	; Input args: gridarg_x, gridarg_y
	; Output: slv_num_valid_moves, slv_valid_list
	;
solver_countValidMovesInCell:
	pushall

	A8
	XY8

	ldx #0 ; legal move counter
	lda #1 ; digit to try

@next_digit
	sta gridarg_value
	jsr grid_canInsertValueAt ; sets carry when illegal
	bcs @illegal
@legal:
	sta slv_valid_list, X
	inx

@illegal:
	inc A	; advance to next digit value
	cmp #10
	bne @next_digit

	XY16
	stx slv_num_valid_moves

	popall
	rts


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Check if a given digit is already present in a column
	;
	; Args:
	;       - X: Index into griddata
	;       - slv_digit: The value to look for
	;
	; Returns with carry set if present.
_solver_isDigitInColumn:
	pushall

	AXY16
	ldy #9	; Check 9 cells
@next_cell:
	lda griddata, X
	and #$ff
	cmp slv_digit
	beq @present

	; Skip to next row (+18)
	txa
	clc
	adc #18
	tax

	dey ; count where we're at
	bne @next_cell

@absent:
	popall
	clc
	rts
@present:
	popall
	sec
	rts


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Check if a given digit is already present in a row.
	;
	; Args:
	;       - X: Index into griddata
	;       - slv_digit: The value to look for
	;
	; Returns with carry set if present.
_solver_isDigitInRow:
	pushall

	AXY16
	ldy #9	; Check 9 cells
@next_cell:
	lda griddata, X
	and #$ff
	cmp slv_digit
	beq @present
	inx ; advance to
	inx ; next cell

	dey ; count where we're at
	bne @next_cell

@absent:
	popall
	clc
	rts
@present:
	popall
	sec
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Check if a number that is not already in a given column can be inserted
	; legally in only ONE empty cell.
	;
	; Input: gridarg_x, slv_digit
	; Output: slv_tmp_y, carry
	;
	; Modifies: gridarg_y
	;
	; returns with carry clear if it only fits in one place.
	; sets slv_tmp_y to Y coordinate where the digit fits
	;
_solver_canNumberFitInOnlyOneColumnCell:
	pushall

	AXY16

	; First, check if the number is already in the column
	stz gridarg_y
	jsr grid_getDataOffset
	jsr _solver_isDigitInColumn
	bcs @return_no	; already there

	; Now check each cell
	ldx #0				; Holds current Y
	ldy #0				; Counter for places it can fit
	lda slv_digit		; prepare argument for
	sta gridarg_value	; grid_canInsertValueAt calls
@next_cell:
	stx gridarg_y
	; gridarg_y stays constant

	jsr grid_isEmptyAt
	bcs @cannot
	jsr grid_canInsertValueAt
	bcs @cannot

	; we can. count it!
	stx slv_tmp_y		; save where it fitted
	iny
	cpy #2				; Check if it was found to fit in more than 1 place
	beq @return_no		; Yes? Then return false
@cannot:
	inx
	cpx #9
	bne @next_cell

	; Done looping. Did we find a place where it fits?
	cpy #1
	bne @return_no ; if this branch is taken, the puzzle is not solvable


@return_yes:
	popall
	clc
	rts
@return_no:
	popall
	sec
	rts


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Check if a number that is not already in a given row can be inserted
	; legally in only ONE empty cell.
	;
	; Input: gridarg_y, slv_digit
	; Output: slv_tmp_x, carry
	;
	; Modifies: gridarg_x
	;
	; returns with carry clear if it only fits in one place.
	; sets slv_tmp_x to X coordinate where the digit fits
	;
_solver_canNumberFitInOnlyOneRowCell:
	pushall

	AXY16

	; First, check if the number is already in the row
	stz gridarg_x
	jsr grid_getDataOffset
	jsr _solver_isDigitInRow
	bcs @return_no	; already there

	; Now check each cell

	ldx #0				; Holds current X
	ldy #0				; Counter for places it can fit
	lda slv_digit		; prepare argument for
	sta gridarg_value	; grid_canInsertValueAt calls
@next_cell:
	stx gridarg_x
	; gridarg_y stays constant

	jsr grid_isEmptyAt
	bcs @cannot
	jsr grid_canInsertValueAt
	bcs @cannot

	; we can. count it!
	stx slv_tmp_x		; save where it fitted
	iny
	cpy #2				; Check if it was found to fit in more than 1 place
	beq @return_no		; Yes? Then return false
@cannot:
	inx
	cpx #9
	bne @next_cell

	; Done looping. Did we find a place where it fits?
	cpy #1
	bne @return_no ; if this branch is taken, the puzzle is not solvable


@return_yes:
	popall
	clc
	rts
@return_no:
	popall
	sec
	rts


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Iterate over non-occupied cells, looking for a cell that would
	; legally accept only once value.
	;
	; Uses: gridarg_x, gridarg_y, gridarg_value (for grid_* functions)
	;
	; Output: slv_digit (if found), slv_x, slv_y
	;
	; Returns with carry clear if a candidate was found.
	;
solver_findUniqueColumnCandidate:
	pushall

	AXY16

	lda #1		; First digit to try
@next_digit:
	ldy #0		; X coord.
@next_row:
	sta slv_digit
	sty gridarg_x
	jsr _solver_canNumberFitInOnlyOneColumnCell
	bcc @found

	iny
	cpy #9
	bne @next_row

	inc A
	cmp #10
	bne @next_digit

	bra @not_found


@found:
	sty slv_x
	ldx slv_tmp_y
	stx slv_y
	; note: slv_digit already set
	popall
	clc
	rts
@not_found:
	popall
	sec
	rts



	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Iterate over non-occupied cells, looking for a cell that would
	; legally accept only once value.
	;
	; Uses: gridarg_x, gridarg_y, gridarg_value (for grid_* functions)
	;
	; Output: slv_digit (if found), slv_x, slv_y
	;
	; Returns with carry clear if a candidate was found.
	;
solver_findUniqueRowCandidate:
	pushall

	AXY16

	lda #1		; First digit to try
@next_digit:
	ldy #0		; Y coord.
@next_row:
	sta slv_digit
	sty gridarg_y
	jsr _solver_canNumberFitInOnlyOneRowCell
	bcc @found

	iny
	cpy #9
	bne @next_row

	inc A
	cmp #10
	bne @next_digit

	bra @not_found


@found:
	sty slv_y
	ldx slv_tmp_x
	stx slv_x
	; note: slv_digit already set
	popall
	clc
	rts
@not_found:
	popall
	sec
	rts


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Iterate over non-occupied cells, looking for a cell that would
	; legally accept only once value.
	;
	; Uses: gridarg_x, gridarg_y, gridarg_value (for grid_* functions)
	;
	; Output: slv_digit (if found), slv_x, slv_y
	;
	; Returns with carry clear if a candidate was found.
	;
solver_findSoleCandidate:
	pushall

	AXY16

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
				sta slv_digit
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
	popall
	sec
	rts

@found_single:
	; slv_digit is already set. Store X and Y.
	stx slv_x
	sty slv_y
	popall
	clc
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

/*
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Setup a list of cell indices (for griddata) in dp_slv_emptyCells in
	; increasing number of possible moves. Celles with 0 moves omitted.
	;
	; The last entry is set to 0xFFFF
	;
_solver_prepareEmptyCellList:

	; First count how many valid moves in each cell, storing the result
	; in slv_num_moves_per_cell in the same order as griddata
	jsr _solver_buildNumMovesArray
	pushall
	AXY16


	; Now create a sorted (1 to 9) array of griddata indices.

	ldy #0 ; Offset into dp_slv_emptyCells

	lda #9
	sta dp_slv_sorttmp
@next_count:
	ldx #0	; Offset into griddata
@nextcell:
	; Load the number of moves for the current cell
	lda slv_num_moves_per_cell, X
	beq @skip
;	cmp dp_slv_sorttmp
;	bne @skip

	stx dp_slv_emptyCells, Y
	iny
	iny

@skip:
	inx
	inx
	cpx #81*2
	bne @nextcell

;	dec dp_slv_sorttmp
;	bpl @next_count

	; End of list marker
	ldx #$ffff
	stx dp_slv_emptyCells, Y

	popall
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Populate an array whose indexes matches gridata. Each element
	; is a count of how many valid moves there are.
	;
	; Uses: dp_slv_tmpval
	;
	; Output: slv_num_moves_per_cell
	;
_solver_buildNumMovesArray:
	pushall

	AXY16

	lda #slv_num_moves_per_cell
	sta dp_slv_tmpval


	ldy #0
@next_row:
	ldx #0
@next_cell:

	stx gridarg_x
	sty gridarg_y

	; First check if the cell is occupied. An occupied cell has
	; no valid moves. It is assumed that it holds the correct value already.
	lda #0	; prepare a move count of 0
	jsr grid_isEmptyAt
	bcs @occupied

	; Count valid moves
	jsr solver_countValidMovesInCell

	; Retrive the number of valid moves
	lda slv_num_valid_moves

@occupied:
	; write it to the array
	sta (dp_slv_tmpval)

	; advance pointer to next cell
	inc dp_slv_tmpval
	inc dp_slv_tmpval

	inx
	cpx #9
	bne @next_cell

	iny
	cpy #9
	bne @next_row


	popall
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Find an empty cell, starting at offset X.
	;
	; Return with X the offset into griddata
	;
	; If none is found, returns with carry set
	;
	AXY16
_solver_findEmptyCellNew:
	ldx #0
	A8
@nextCell:
	ldy dp_slv_emptyCells, X
	bmi @nomore ; Stop at $ffff

	lda griddata, Y
	beq @empty_found
	inx
	inx
	bra @nextCell

@nomore:
	A16
	; None found. Return with carry set.
	sec
	rts

@empty_found:
	A16
	tyx
	clc
	rts

*/

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Find an empty cell, starting at offset X.
	;
	; Return with X the offset into griddata
	;
	; If none is found, returns with carry set
	;
	AXY16
_solver_findEmptyCell:
;	ldx #0
@nextCell:
	lda griddata, X
	and #$ff
	beq @empty_found
	inx
	inx
	cpx #81*2
	bne @nextCell

	; None found. Re
	sec
	rts

@empty_found:
	clc
	rts


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Check if a given values exists in the neighbors of a cell.
	;
	; Arguments:
	;    -  X : Offset in gridata/neighbor_list
	;    -  dp_slv_tmpval : Value to look for
	;
	; Return with carry set if found, clear otherwise.
	;
	AXY16
_solverCheckNeighborsForValue:
	phx
	phy

	; Get the pointer to the list of neighbors for the designated cell
	lda neighbor_list, X
	; Store it in the direct page for upcoming indirect acceses
	sta dp_indirect_tmp1

	ldy #20*2
@checknext:
	dey
	dey
	bmi @not_found
	lda (dp_indirect_tmp1),Y	; Load offset for neighbor
	tax							; Move the offset to X to use it
	lda griddata, X				; Load the value at this position
	and #$FF
	cmp dp_slv_tmpval				; Check if it is the value we are looking for
	bne @checknext

@foundit:
	sec
	ply
	plx
	rts

@not_found:
	clc
	ply
	plx
	rts


	;;;;;;;;
	;
	; Recursive routine for solving a sudoku.
	;
	; Returns with carry set when all cells are populated.
	;
	; X: Current offset in griddata for faster empty cell finding
	;
	AXY16
_solver_bruteforcer:
	phy
	phx

	lda cancel_solver
	bne @triedall

	; 1. Find an empty cell.
	;jsr _solver_findEmptyCell2
	;bcs @solved	; Carry set means none was found. Puzzle solved.

	; inlined version of the above
	@nextCell:
		lda griddata, X
		and #$ff
		beq @empty_found
		inx
		inx
		cpx #81*2
		bne @nextCell
		bra @solved
	@empty_found:


	; X now holds the offset for the cell. It is used by the neighbor
	; check in the loop below.

	; 2. Try digits at current position
	ldy #10 ; First digit to try

@next_value:
	dey
	beq @triedall
	; Check if this is a valid move here
	sty dp_slv_tmpval	; Value to check (arg for subroutine below)
	jsr _solverCheckNeighborsForValue
	bcs @next_value	; Carry is set if value is unallowed

	; Value allowed! Insert it.
	tya
;	jsr grid_insertHintedValueOffset
	ora #(BRUTEFORCED_DIGIT_PAL<<8)
	sta griddata, X

	; Try recursion.
	jsr _solver_bruteforcer
	bcs @solved
	; Carry clear? Then this was a dead end. Try another digit...
	bra @next_value

@triedall:
	; None of the tried digits worked. Clear the cell.
	;lda #0
	;jsr grid_insertHintedValueOffset
	stz griddata, X
	lda #1
	sta grid_changed

	clc
	plx
	ply
	rts
@solved:
	lda #1
	sta grid_changed

	plx
	ply
	rts


solver_bruteForce:
	pushall
	AXY16

	; this was for use with _solver_findEmptyCellNew but
	; it seems slower.
	;	jsr _solver_prepareEmptyCellList

brk1:

	ldx #0
;	stx dp_slv_nextEmpty
	jsr _solver_bruteforcer

	popall
	rts

.ends

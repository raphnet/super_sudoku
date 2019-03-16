.include "header.inc"
.include "snesregs.inc"
.include "misc_macros.inc"
.include "zeropage.inc"


.bank 0

.ramsection "solver_variables" SLOT RAM_SLOT
	slv_num_valid_moves: dw
	slv_valid_list: dsb 9

	slv_digit: dw
	slv_x: dw
	slv_y: dw

	slv_tmp_x: dw
	slv_tmp_y: dw
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


.ends

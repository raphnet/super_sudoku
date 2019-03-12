.include "header.inc"
.include "snesregs.inc"
.include "misc_macros.inc"
.include "zeropage.inc"


.bank 0

.ramsection "solver_variables" SLOT RAM_SLOT
	slv_num_valid_moves: dw
	slv_valid_list: dsb 9
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

.ends

.include "header.inc"
.include "puzzles.inc"
.include "misc_macros.inc"

.16bit

.ramsection "puzzle buffer" SLOT RAM_SLOT
puzzle_buffer: dsb 81

puzzle_level: dw
puzzle_id: dw
.ends

.bank 0

.section "Puzzle loader" FREE


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Initialize puzzle_buffer with a blank puzzle
	;
puzzles_loadEmpty:
	Memset puzzle_buffer 0 _sizeof_puzzle_buffer
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Load a puzzle from ROM to a RAM buffer
	;
	;
puzzles_load:
	pushall

	A16
	XY16

	; Multiply puzzle ID by puzzle size (128)
	lda puzzle_id
	asl
	asl
	asl
	asl
	asl
	asl
	asl
	tax

	A8

	lda puzzle_level
	beq @simple_load
	cmp #1
	beq @easy_load
	cmp #2
	beq @intermediate_load
	cmp #3
	beq @expert_load

@simple_load:
	ldy #0 ; counter for 81 bytes
@simple_loop:
	lda puzzles_simple.L, X
	sta puzzle_buffer, Y
	inx
	iny
	cpy #81
	bne @simple_loop
	bra @done


@easy_load:
	ldy #0 ; counter for 81 bytes
@easy_loop:
	lda puzzles_easy.L, X
	sta puzzle_buffer, Y
	inx
	iny
	cpy #81
	bne @easy_loop
	bra @done


@intermediate_load:
	ldy #0 ; counter for 81 bytes
@intermediate_loop:
	lda puzzles_intermediate.L, X
	sta puzzle_buffer, Y
	inx
	iny
	cpy #81
	bne @intermediate_loop
	bra @done


@expert_load:
	ldy #0 ; counter for 81 bytes
@expert_loop:
	lda puzzles_expert.L, X
	sta puzzle_buffer, Y
	inx
	iny
	cpy #81
	bne @expert_loop
	bra @done



@done:

	popall
	rts


.ends


.bank 1
.section "Simple puzzles" FREE
puzzles_simple:
	.incbin "puzzles/simple.bin"
.ends

.bank 2
.section "Easy puzzles" FREE
puzzles_easy:
	.incbin "puzzles/easy.bin"
.ends

.bank 3
.section "Intermediate puzzles" FREE
puzzles_intermediate:
	.incbin "puzzles/intermediate.bin"
.ends

.bank 4
.section "Expert puzzles" FREE
puzzles_expert:
	.incbin "puzzles/expert.bin"


.ends

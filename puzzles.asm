.include "header.inc"
.include "puzzles.inc"

.bank PUZZLE_BANK
.section "Puzzles" FREE

puzzles_easy:
	.incbin "puzzles/simple.bin"
	.incbin "puzzles/easy.bin"
	.incbin "puzzles/intermediate.bin"
	.incbin "puzzles/expert.bin"

.ends

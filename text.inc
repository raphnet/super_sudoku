
; Syntax text_drawString "string"
.macro text_drawString
	phy
	phx
	php
	XY16
	ldy #drawstring_str\@
	jsr text_print
	jmp skip\@
drawstring_str\@:
	.db \1,0
skip\@:
	plp
	plx
	ply
.endm

; Syntax test_drawStringXY "string" X Y
.macro text_drawStringXY
	phy
	phx
	php
	XY16
	ldx #\2
	ldy #\3
	jsr text_gotoxy

	ldy #@drawstring_strn\@
	jsr text_print
	jmp @skipn\@
@drawstring_strn\@:
	.db \1,0
@skipn\@:
	plp
	plx
	ply
.endm

; Syntax text_drawBox x y w h
.macro text_drawBox
	pha
	php
	A16

	lda #\1
	sta text_box_x
	lda #\2
	sta text_box_y
	lda #\3
	sta text_box_w
	lda #\4
	sta text_box_h

	jsr text_drawBox

	plp
	pla
.endm

; Syntax text_clearBox x y w h
.macro text_clearBox
	pha
	php
	A16

	lda #\1
	sta text_box_x
	lda #\2
	sta text_box_y
	lda #\3
	sta text_box_w
	lda #\4
	sta text_box_h

	jsr text_clearBox

	plp
	pla
.endm


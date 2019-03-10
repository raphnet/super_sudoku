.include "header.inc"
.include "snesregs.inc"
.include "misc_macros.inc"
.include "zeropage.inc"

.define TEXT_SCREEN_WORD_PITCH	32

; define characters used for drawing boxes
.define FIRST_BOX_CHAR	$80
.define BOX_CHAR_UL	FIRST_BOX_CHAR+0 ; upper left corner
.define BOX_CHAR_UR FIRST_BOX_CHAR+1 ; upper right corner
.define BOX_CHAR_LL FIRST_BOX_CHAR+2 ; lower left corner
.define BOX_CHAR_LR FIRST_BOX_CHAR+3 ; lower right corner
.define BOX_CHAR_HB FIRST_BOX_CHAR+4 ; horizontal bar, bottom
.define BOX_CHAR_VR FIRST_BOX_CHAR+5 ; vertical bar, right
.define BOX_CHAR_HT FIRST_BOX_CHAR+6 ; horizontal bar, top
.define BOX_CHAR_VL FIRST_BOX_CHAR+7 ; vertical bar, left
.define BOX_CHAR_FILL FIRST_BOX_CHAR+8 ; Filler

; word addresses for bgmap in VRAM
.define TEXT_SCREEN_VRAM_START	$1800
.define TEXT_SCREEN_VRAM_MAX	TEXT_SCREEN_VRAM_START+32*32

.bank 0 slot 1

.ramsection "text_variables" SLOT RAM_SLOT
	text_cursor_x: dw
	text_cursor_y: dw


	text_vram_ptr: dw ; word address for current cursor x,y

	; arguments for drawing text boxes
	text_box_x: dw
	text_box_y: dw
	text_box_w: dw
	text_box_h: dw
.ends

.16BIT


.section "text screen" FREE

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Initialize the text system
	;
text_init:
	pushall
	A16
	stz text_cursor_x
	stz text_cursor_y
	jsr _text_xy_to_ptr ; sets text_vram_ptr
	popall
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Move the cursor to X,Y
	;
	; X: X coordinate
	; Y: Y coordinate
	;
text_gotoxy:
	pushall

	XY16

	stx text_cursor_x
	sty text_cursor_y
	jsr _text_xy_to_ptr

	popall
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Move the cursor to X,Y
	;
	; X: X coordinate
	; Y: Y coordinate
	;
	; Warning: This access PPU registers directly. Use from vblank interrupt,
	; force vblank, or avoid conflicts using other means..
	;
text_putchar:
	pushall

	XY16
	A16

	; Set pointer in VRAM
	ldx text_vram_ptr
	stx VMADDL

	; Write the character
	and #$ff
	sta VMDATAL

	inx			; Increase vram pointer
	cpx #TEXT_SCREEN_VRAM_MAX
	bne @done
	ldx #TEXT_SCREEN_VRAM_START
@done:
	stx text_vram_ptr

	popall
	rts


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Print a string to the screen
	;
	; Y: 16-bit pointer to zero-terminated string
	;
	; Warning: This access PPU registers directly. Use from vblank interrupt,
	; force vblank, or avoid conflicts using other means..
	;
text_print:
	pushall

	XY16
	A16

	; Set pointer in VRAM
	ldx text_vram_ptr
	stx VMADDL

@next_char:
	lda 0, Y	; Get new character
	and #$ff	; drop the upper byte we don't want
	beq @done	; 0 means end of string
	sta VMDATAL ; Write to BG
	iny			; Advance to next ASCII character
	inx			; Increase vram pointer
	cpx #TEXT_SCREEN_VRAM_MAX
	bne @next_char
	ldx #TEXT_SCREEN_VRAM_START		; Got back to home
	bra @next_char
@done:
	stx text_vram_ptr

	popall
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Erase a box
	;
	; Warning: This access PPU registers directly. Use from vblank interrupt,
	; force vblank, or avoid conflicts using other means..
	;
text_clearBox:
	pushall

	A16
	XY16

	; This sets text_vram_ptr to the upper-left corner of the box
	ldx text_box_x
	ldy text_box_y
	jsr text_gotoxy

	; Set pointer in VRAM
	ldx text_vram_ptr
	stx VMADDL

	ldy text_box_h  ; Load height in X
@lp_y:
	ldx text_box_w	; Load width in X
@lp_x:
	stz VMDATAL
	dex
	bne @lp_x

	lda text_vram_ptr
	clc
	adc #TEXT_SCREEN_WORD_PITCH
	sta text_vram_ptr
	sta VMADDL

	wai

	dey
	bne @lp_y


	popall

	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Draw a box
	;
	; Warning: This access PPU registers directly. Use from vblank interrupt,
	; force vblank, or avoid conflicts using other means..
	;
text_drawBox:
	pushall

	A16
	XY16

	; This sets text_vram_ptr to the upper-left corner of the box
	ldx text_box_x
	ldy text_box_y
	jsr text_gotoxy

	; Set pointer in VRAM
	ldx text_vram_ptr
	stx VMADDL

	ldy text_box_h  ; Load height in X

	;;; Top line of the box ;;;

	ldx text_box_w	; Load width in X
	; Upper left corner
	lda #BOX_CHAR_UL
	sta VMDATAL
	dex
	; Horizontal bar, top
	lda #BOX_CHAR_HT
@lp_horiz_top:
	sta VMDATAL
	dex
	cpx #1
	bne @lp_horiz_top
	; Upper right corner
	lda #BOX_CHAR_UR
	sta VMDATAL
	dey

	;;; Middle lines of the box ;;;

	; Advance vram pointer to next line
@inner_lines_lp:
wai
	lda text_vram_ptr
	clc
	adc #TEXT_SCREEN_WORD_PITCH
	sta text_vram_ptr
	sta VMADDL


	ldx text_box_w	; Load width in X

	; Vertical bar left
	lda #BOX_CHAR_VL
	sta VMDATAL
	dex
	; Background filler
	lda #BOX_CHAR_FILL
@lp_horiz_fill:
	sta VMDATAL
	dex
	cpx #1
	bne @lp_horiz_fill
	; Vertical bar right
	lda #BOX_CHAR_VR
	sta VMDATAL

	dey
	cpy #1
	bne @inner_lines_lp

	;;; Bottom line of the box ;;;

	lda text_vram_ptr
	clc
	adc #TEXT_SCREEN_WORD_PITCH
	sta text_vram_ptr
	sta VMADDL


	ldx text_box_w	; Load width in X
	; Lower left corner
	lda #BOX_CHAR_LL
	sta VMDATAL
	dex
	; Horizontal bar, bottom
	lda #BOX_CHAR_HB
@lp_horiz_bottom:
	sta VMDATAL
	dex
	cpx #1
	bne @lp_horiz_bottom
	; Lower right corner
	lda #BOX_CHAR_LR
	sta VMDATAL
	dey



	popall
	rts

_text_xy_to_ptr:
	pushall

	A8
	lda text_cursor_y
	A16
	XY16
	and #$ff
	asl ; *2
	asl ; *4
	asl ; *8
	asl ; *16
	asl ; *32

	adc text_cursor_x
	adc #TEXT_SCREEN_VRAM_START
	sta text_vram_ptr

	popall
	rts


.ends

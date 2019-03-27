.include "header.inc"
.include "misc_macros.inc"
.include "zeropage.inc"

.define TEXT_SCREEN_BYTE_PITCH	64

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

; word addresses for bgmap in bank 7F
.define TEXT_SCREEN_RAM_START	$0
.define TEXT_SCREEN_RAM_MAX	TEXT_SCREEN_RAM_START+32*32
.define TEXT_SCREEN_RAM_BANK	$7F

.bank 0 slot 1

.ramsection "text_variables" SLOT RAM_SLOT
	text_cursor_x: dw
	text_cursor_y: dw


;	text_vram_ptr: dw ; word address for current cursor x,y

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

text_putbcd:
	pushall


	popall
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; print a character
	;
	; A: character
	; Y: Y coordinate
	;
text_putchar:
	pushall

	XY16
	A8

	sta [dp_text_ptr]
	inc dp_text_ptr
	inc dp_text_ptr

	lda #1
	sta bg1_need_resync

	popall
	rts


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Print a string to the screen
	;
	; Y: 16-bit pointer to zero-terminated string
	;
text_print:
	pushall

	XY16
	A8

	; Set pointer in RAM
	ldx dp_text_ptr

@next_char:
	lda 0, Y	; Get new character
	beq @done	; 0 means end of string
	sta [dp_text_ptr]
	iny			; Advance to next ASCII character
	inc dp_text_ptr		; Increase vram pointer
	inc dp_text_ptr		; Increase vram pointer
	bra @next_char

@done:
	stx dp_text_ptr

	lda #1
	sta bg1_need_resync

	popall
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Erase a box
	;
text_clearBox:
	pushall

	A16
	XY16

	; This sets dp_text_ptr to the upper-left corner of the box
	ldx text_box_x
	ldy text_box_y
	jsr text_gotoxy

	; save line origin
	lda dp_text_ptr
	sta dp_text_tmp


	ldy text_box_h  ; Load height in X
@lp_y:
	ldx text_box_w	; Load width in X
@lp_x:
	lda #0
	sta [dp_text_ptr]
	inc dp_text_ptr
	inc dp_text_ptr
	dex
	bne @lp_x

	lda dp_text_tmp
	clc
	adc #TEXT_SCREEN_BYTE_PITCH
	sta dp_text_tmp
	sta dp_text_ptr

	dey
	bne @lp_y

	A8
	lda #1
	sta bg1_need_resync

	popall

	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Draw a box
	;
text_drawBox:
	pushall

	A16
	XY16

	; This sets dp_text_ptr to the upper-left corner of the box
	ldx text_box_x
	ldy text_box_y
	jsr text_gotoxy

	; Save start of line ptr
	ldx dp_text_ptr
	stx dp_text_tmp

	;;; Top line of the box ;;;
	ldx dp_text_ptr

;	ldx text_box_w	; Load width in X
	; Upper left corner
	lda #BOX_CHAR_UL
	sta [dp_text_ptr]
	inc dp_text_ptr
	inc dp_text_ptr

	; Horizontal bar, top
	ldy text_box_w  ; Load height in W
	dey
	dey
	lda #BOX_CHAR_HT
@lp_horiz_top:
	sta [dp_text_ptr]
	inc dp_text_ptr
	inc dp_text_ptr
	dey
	bne @lp_horiz_top

	; Upper right corner
	lda #BOX_CHAR_UR
	sta [dp_text_ptr]
	inc dp_text_ptr
	inc dp_text_ptr


	;;; Middle lines of the box ;;;

	ldy text_box_h  ; Load height in Y
	dey 	; subtract top and bottom lines
	dey

@inner_lines_lp:
	lda dp_text_tmp	; Get start of previous line
	clc
	adc #TEXT_SCREEN_BYTE_PITCH	; advance to next line
	sta dp_text_tmp ; save it for next tome
	sta dp_text_ptr	; point to it now


	ldx text_box_w	; Load width in X

	; Vertical bar left
	lda #BOX_CHAR_VL
	sta [dp_text_ptr]
	inc dp_text_ptr
	inc dp_text_ptr
	dex
	; Background filler
	lda #BOX_CHAR_FILL
@lp_horiz_fill:
	sta [dp_text_ptr]
	inc dp_text_ptr
	inc dp_text_ptr
	dex
	cpx #1
	bne @lp_horiz_fill
	; Vertical bar right
	lda #BOX_CHAR_VR
	sta [dp_text_ptr]
	inc dp_text_ptr
	inc dp_text_ptr

	dey
	bne @inner_lines_lp

	;;; Bottom line of the box ;;;
	lda dp_text_tmp	; Get start of previous line
	clc
	adc #TEXT_SCREEN_BYTE_PITCH	; advance to next line
	sta dp_text_tmp ; save it for next tome
	sta dp_text_ptr	; point to it now

	ldx text_box_w	; Load width in X
	; Lower left corner
	lda #BOX_CHAR_LL
	sta [dp_text_ptr]
	inc dp_text_ptr
	inc dp_text_ptr
	dex
	; Horizontal bar, bottom
	lda #BOX_CHAR_HB
@lp_horiz_bottom:

	sta [dp_text_ptr]
	inc dp_text_ptr
	inc dp_text_ptr
	dex
	cpx #1
	bne @lp_horiz_bottom
	; Lower right corner
	lda #BOX_CHAR_LR
	sta [dp_text_ptr]


	popall
	rts

_text_xy_to_ptr:
	pushall

	A8
	; set bank
	lda #TEXT_SCREEN_RAM_BANK
	sta dp_text_ptr + 2

	lda text_cursor_y
	A16
	XY16
	and #$ff
	asl ; *2
	asl ; *4
	asl ; *8
	asl ; *16
	asl ; *32
	asl ; *32

	adc text_cursor_x
	adc text_cursor_x
	adc #TEXT_SCREEN_RAM_START
	sta dp_text_ptr


	popall
	rts


.ends

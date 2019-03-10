
; syntax cursor_setGridSize W H
.macro cursor_setGridSize
	pha
	php
	A16
	lda #\1
	sta cursor_grid_w
	lda #\2
	sta cursor_grid_h
	plp
	pla
.endm

; synatx cursor_setScreenOrigin X Y
.macro cursor_setScreenOrigin
	pha
	php
	A16
	lda #\1
	sta cursor_org_x
	lda #\2
	sta cursor_org_y
	plp
	pla
.endm

; syntax cursor_jumpToGridXY X Y
.macro cursor_jumpToGridXY
	pha
	php
	A16
	lda #\1
	sta cursor_grid_x
	lda #\2
	sta cursor_grid_y
	jsr cursor_jump_to_destination
	plp
	pla
.endm

; syntax cursor_setStartingTileID ID
.macro cursor_setStartingTileID
	pha
	php
	A16
	lda #\1
	jsr cursor_setStartingTileID
	plp
	pla
.endm


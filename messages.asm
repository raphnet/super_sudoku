.include "header.inc"
.include "misc_macros.inc"
.include "zeropage.inc"
.include "text.inc"

.bank 0 slot 1

.section "messages code/data"

.define MSG_X	3
.define MSG_Y	25

_str_good_luck: .db "GOOD LUCK!",0
_str_solving: .db "SOLVING...",0
_str_cancelled: .db "CANCELLED",0
_str_well_done: .db "WELL DONE!",0
_str_done: .db "DONE!",0
_str_cannot_erase: .db "CANNOT ERASE THIS",0
_str_cannot_write:   .db "CANNOT WRITE THIS HERE",0
_str_void:                 .db "                           ",0
_str_sole_candidate:       .db "SOLE CELL CANDIDATE",0
_str_unique_row_candidate: .db "UNIQUE ROW CANDIDATE",0
_str_unique_column_candidate: .db "UNIQUE COLUMN CANDIDATE",0
_str_nothing_easy_found: .db "NOTHING EASY FOUND...",0

.macro SAY
	pushall
	XY16
	ldx #MSG_X
	ldy #MSG_Y
	jsr text_gotoxy
	ldy #\1
	jsr text_print
	popall
.endm

_clear:
	SAY _str_void
	rts

msg_clear:
	jsr _clear
	rts

msg_say_solving:
	jsr _clear
	SAY _str_solving
	rts

msg_say_cancelled:
	jsr _clear
	SAY _str_cancelled
	rts

msg_say_done:
	jsr _clear
	SAY _str_done
	rts

msg_say_well_done:
	jsr _clear
	SAY _str_well_done
	rts

msg_say_cannot_erase:
	jsr _clear
	SAY _str_cannot_erase
	rts

msg_say_cannot_write:
	jsr _clear
	SAY _str_cannot_write
	rts

msg_say_good_luck:
	jsr _clear
	SAY _str_good_luck
	rts

msg_say_sole_canditate:
	jsr _clear
	SAY _str_sole_candidate
	rts

msg_say_unique_row_canditate:
	jsr _clear
	SAY _str_unique_row_candidate
	rts

msg_say_unique_column_canditate:
	jsr _clear
	SAY _str_unique_column_candidate
	rts

msg_say_nothing_easy_found:
	jsr _clear
	SAY _str_nothing_easy_found
	rts

.ends

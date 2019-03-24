.include "header.inc"
.include "snesregs.inc"
.include "misc_macros.inc"
.include "zeropage.inc"
.include "puzzles.inc"
.include "grid.inc"

.bank 0 slot 1

.ramsection "sound_variables" SLOT RAM_SLOT
	kick: db
.ends

.16BIT

.section "apu_payload" FREE
	apu_dst_address: .dw 200h
	apu_entry_point: .dw 200h
.ends

.section "sound_code" FREE

.define APU_HANDSHAKE	APUIO0
.define APU_COMMAND		APUIO1
.define APU_DATA		APUIO1
.define APU_DST_ADDR	APUIO2

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Load the APU program
	;
	; based on Uploader pseudo code from the fullsnes documentation
sound_loadApu:
	pushall

	A8
	XY16

	ldx #0

	; Wait until Word[2140h]=BBAAh
@wait_bbaa;
	ldy APU_HANDSHAKE
	cpy #$BBAA
	bne @wait_bbaa

	; kick=CCh                  ;start-code for first command
	lda #$cc
	sta kick

@next_block:

	ldy apu_dst_address
	sty APU_DST_ADDR	; usually 200h or higher (above stack and I/O ports)
	lda #1
	sta APU_COMMAND		; command=transfer (can be any non-zero value)

	lda kick
	sta APU_HANDSHAKE	; start command (CCh on first block)
@wait_handshake:
	lda APU_HANDSHAKE
	cmp kick
	bne @wait_handshake

@blockdataloop:
	lda apu_payload.L, X
	sta APU_DATA		;	send data byte
	txa
	sta APU_HANDSHAKE	;	send index LSB (mark data available)

@waitDataAck:
	cmp APU_HANDSHAKE
	bne @waitDataAck

	inx
	cpx #_sizeof_apu_payload
	bne @blockdataloop

	; kick=(index+2 AND FFh) OR 1 ;-kick for next command (must be bigger than last index+1, and must be non-zero)
	txa
	clc
	adc #<_sizeof_apu_payload
	adc #2
	ora #1
	sta kick

@startit:
	ldy apu_entry_point
	sty APU_DST_ADDR	; entrypoint, must be below FFC0h (ROM region)
	stz APU_COMMAND		; command=entry (must be zero value)
	lda kick
	sta APU_HANDSHAKE
@waitStartAck:
	cmp APU_HANDSHAKE
	bne @waitStartAck

@done:


	popall
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Send a command. Command in 8-bit A.
	;
sound_sendCommand:
	pushall

	A8
	sta APU_COMMAND

	inc kick
	lda kick
	sta APU_HANDSHAKE

@waitack:
	cmp APU_HANDSHAKE
	bne @waitack

	popall
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Request the 'error' sound to be played
	;
sound_effect_error:
	pushall
	A8
	lda #$10 ; Error
	jsr sound_sendCommand
	popall
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Request the 'write' sound to be played
	;
sound_effect_write:
	pushall
	A8
	lda #$11
	jsr sound_sendCommand
	popall
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Request the 'erase' sound to be played
	;
sound_effect_erase:
	pushall
	A8
	lda #$12
	jsr sound_sendCommand
	popall
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Request the 'click' sound to be played
	;
sound_effect_menuselect:
sound_effect_click:
	pushall
	A8
	lda #$13
	jsr sound_sendCommand
	popall
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Request the 'back' sound to be played
	;
sound_effect_back:
	pushall
	A8
	lda #$14
	jsr sound_sendCommand
	popall
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Request the 'solved' sound to be played
	;
sound_effect_solved:
	pushall
	A8
	lda #$15
	jsr sound_sendCommand
	popall
	rts


.ends


.bank 5
.section "apu program" FREE
	apu_payload: .incbin "sound/sndcode.bin"
	apu_dummy: .db 0	 ; for sizeof
.ends

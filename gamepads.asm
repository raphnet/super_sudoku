.include "header.inc"
.include "snesregs.inc"
.include "misc_macros.inc"
.include "zeropage.inc"
.include "gamepads.inc"

.16BIT

.ramsection "gamepad vars" bank 0 slot RAM_SLOT
	; Buffer for reading bytes from controllers. Logic can
	; look at those to know the current button status. gamepads.inc
	; contains defines that can help masking buttons.
	gamepad1_bytes: dsb 4
	gamepad2_bytes: dsb 4
	; "Button pressed" event bits. When a button goes down, the
	; corresponding bit gets set here. Must be cleared manually.
	gamepad1_pressed: dsb 4
	gamepad2_pressed: dsb 4
	; Buffers holding previously read values for edge detection and
	; setting the gamepadX_pressed bits.
	gamepad1_prev_bytes: dsb 4
	gamepad2_prev_bytes: dsb 4
	; Those contain the ID bits (cycles 12-16) for each controller;
	ctl_id_p1: db
	ctl_id_p2: db
.ends

.bank 0
.section "Gamepads" FREE

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Send a latch pulse to the controllers.
	;
	; Assumes 8-bit accumulator.
sendLatch:
	pha

	stz JOYWR	; Bit 0 is the latch. Make sure it is initially clear;

	lda #1.B	; Prepare to set bit 0
	sta JOYWR	; Do it

	; TODO : How much delay cycles should be used here?
	nop
	nop
	nop

	stz JOYWR	; Clear latch

	pla
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Just return after 8 nops
gamepads_delay_8nops:
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	rts


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Read 1 byte from gamepad 1
	;
	; Assumptions: AXY 8bit
	;
	; Arguments:
	;   X: destination index in gamepad1_bytes
	;
readGamepad1byte:
	pha
	phy

	ldy #8.B
@lp:
	lda JOYA				; Read data, generate clock pulse
	lsr						; Move bit 0 from controller to the carry flag
	rol gamepad1_bytes, X	; Rotate the bit into memory
	dey
	bne @lp
	ply
	pla
	rts


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Read 1 byte from gamepad 2
	;
	; Assumptions: AXY 8bit
	;
	; Arguments:
	;   X: destination index in gamepad2_bytes
	;
readGamepad2byte:
	pha
	phy
	ldy #8.B
@lp:
	lda JOYB				; Read data, generate clock pulse
	lsr						; Move bit 0 from controller to the carry flag
	rol gamepad2_bytes, X	; Rotate the bit into memory
	dey
	bne @lp
	ply
	pla
	rts



	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Read 32 bits from gamepad in port 1
	;
	; Bytes stored in gamepad1_bytes[4]
readGamepad1:
	pushall

	A8
	XY8

	; First 16 bits
	ldx #0.B
	jsr readGamepad1byte
	inx
	jsr readGamepad1byte
	inx

	; Check the ID bits, decide if more bits shall be read
	jsr extractIdBits1
	lda ctl_id_p1
	cmp #CTL_ID_NTT_KEYPAD
	beq @read_more

	; Otherwise, zero extra bytes in array
	stz gamepad1_bytes, X
	inx
	stz gamepad1_bytes, X
	bra @done

@read_more:
	jsr readGamepad1byte
	inx
	jsr readGamepad1byte

@done:

	popall
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Read 32 bits from gamepad in port 2
	;
	; Assumes: AXY 8 bit
	;
	; Bytes stored in gamepad2_bytes[4]
readGamepad2:
	pushall

	ldx #0.B
	jsr readGamepad2byte
	inx
	jsr readGamepad2byte
	inx

	jsr extractIdBits2
	lda ctl_id_p2
	cmp #CTL_ID_NTT_KEYPAD
	beq @read_more

	; Otherwise, zero extra bytes in array
	stz gamepad2_bytes, X
	inx
	stz gamepad2_bytes, X
	bra @done

@read_more:
	jsr readGamepad2byte
	inx
	jsr readGamepad2byte

@done:

	popall

	rts


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Compare the current state of Gamepad 1 with the previous state and
	; update gamepad1_pressed[4] to indicate which buttons were pressed
	; since last call.
	;
gamepad1_detectEvents:
	pushall

	A16
	XY16

	lda gamepad1_bytes		; Get latest button status
	tax						; Store a copy in X
	eor gamepad1_prev_bytes	; XOR with previous status (clears unchanged bits)
	and gamepad1_bytes		; Keep only newly set bits (buttons that are down *now*)
	ora gamepad1_pressed	; Flag those as pressed (will need to be cleared by 'consumer')
	sta gamepad1_pressed	; Save new 'active' buttons
	stx gamepad1_prev_bytes	; Save previous state for next pass


	lda gamepad1_bytes+2
	tax
	eor gamepad1_prev_bytes+2
	and gamepad1_bytes+2
	ora gamepad1_pressed+2
	sta gamepad1_pressed+2
	stx gamepad1_prev_bytes+2

	popall

	rts


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Compare the current state of Gamepad 2 with the previous state and
	; update gamepad2_pressed[4] to indicate which buttons were pressed
	; since last call.
	;
gamepad2_detectEvents:
	pushall

	A16
	XY16

	lda gamepad2_bytes
	tax
	eor gamepad2_prev_bytes
	and gamepad2_bytes
	ora gamepad2_pressed
	sta gamepad2_pressed
	stx gamepad2_prev_bytes

	lda gamepad2_bytes+2
	tax
	eor gamepad2_prev_bytes+2
	and gamepad2_bytes+2
	ora gamepad2_pressed+2
	sta gamepad2_pressed+2
	stx gamepad2_prev_bytes+2

	popall

	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Extract the ID bytes from gamepad1_bytes and store them
	; in ctl_id_p1.
	;
extractIdBits1:
	pha
	php

	A8

	lda gamepad1_bytes+1
	and #$F
	sta ctl_id_p1

	plp
	pla
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Extract the ID bytes from gamepad2_bytes and store them
	; in ctl_id_p2.
	;
extractIdBits2:
	pha
	php

	A8

	lda gamepad2_bytes+1
	and #$F
	sta ctl_id_p2

	plp
	pla
	rts


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Read 32 bits from both gamepads
	;
	; Assumes: AXY 8 bit
	;
	; Bytes stoed in gamepad1_bytes[4] and gamepad2_bytes[4]
readGamepads:
	; First send a latch to both controllers
	jsr sendLatch
	jsr gamepads_delay_8nops
	; The shift in 32 bits from each controller
	jsr readGamepad1
	jsr readGamepad2
	; Compute button events (falling edge)
	jsr gamepad1_detectEvents
	jsr gamepad2_detectEvents
	rts


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Initialize gamepad variables.
	;
gamepads_init:
	pushall
	A16

	stz gamepad1_prev_bytes
	stz gamepad1_prev_bytes + 2
	stz gamepad2_prev_bytes
	stz gamepad2_prev_bytes + 2

	stz gamepad1_pressed
	stz gamepad1_pressed + 2
	stz gamepad2_pressed
	stz gamepad2_pressed + 2

	popall

	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Get last event from port 1
	;
	; X: Index into gamepad1_pressed
	;
	; Returns data in A
	;
gamepads_p1_getEvents:
	lda gamepad1_pressed,X
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Clear events for controller port 1
	;
gamepads_p1_clearEvents:
	pha
	php
	A16
	stz gamepad1_pressed
	stz gamepad1_pressed + 2
	plp
	pla
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Get last event from port 2
	;
	; X: Index into gamepad2_pressed
	;
	; Returns data in A
	;
gamepads_p2_getEvents:
	lda gamepad2_pressed,X
	rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Clear events for controller port 2
	;
gamepads_p2_clearEvents:
	pha
	php
	A16
	stz gamepad2_pressed
	stz gamepad2_pressed + 2
	plp
	pla
	rts


.ends

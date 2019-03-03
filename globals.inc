.enum $100
	bg2_off: db
	bg2_count: db

	; Buffer for reading bytes from controllers. Logic can
	; look at those to know the current button status. controlerbits.inc
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

	inidisp: db
.ende


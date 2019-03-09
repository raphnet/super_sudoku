
; Those are defined for loading a word
; from gamepadX_pressed or gamepadX_bytes

.define CTL_WORD0_B	$80
.define CTL_WORD0_Y	$40
.define CTL_WORD0_SEL	$20
.define CTL_WORD0_START	$10
.define CTL_WORD0_UP	$08
.define CTL_WORD0_DOWN	$04
.define CTL_WORD0_LEFT	$02
.define CTL_WORD0_RIGHT	$01
.define CTL_WORD0_A		$8000
.define CTL_WORD0_X		$4000
.define CTL_WORD0_L		$2000
.define CTL_WORD0_R		$1000
; ID bits follow (3-0)

; NTT data keypad
.define CTL_WORD1_KP_0	$0080
.define CTL_WORD1_KP_1	$0040
.define CTL_WORD1_KP_2	$0020
.define CTL_WORD1_KP_3	$0010
.define CTL_WORD1_KP_4	$0008
.define CTL_WORD1_KP_5	$0004
.define CTL_WORD1_KP_6	$0002
.define CTL_WORD1_KP_7	$0001
.define CTL_WORD1_KP_8	$8000
.define CTL_WORD1_KP_9	$4000
.define CTL_WORD1_KP_STAR	$2000
.define CTL_WORD1_KP_HASH	$1000
.define CTL_WORD1_KP_DOT	$0800
.define CTL_WORD1_KP_CLEAR	$0400
;.define CTL_WORD1_KP_		$0200
.define CTL_WORD1_KP_END	$0100

.define CTL_ID_STANDARD		0
.define CTL_ID_NTT_KEYPAD	4



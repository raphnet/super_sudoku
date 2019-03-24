.memorymap
	slotsize $7000
	defaultslot 0
	slot 0 $200
.endme

.rombankmap
	bankstotal 1
	banksize $7000
	banks 1
.endro

.emptyfill 0

;;;;;;;;;;; SPC700 CPU registers / IO locations ;;;;;;;;;;;;;;;;;;;;
.define TEST	$00F0	; Testing functions
.define CONTROL	$00F1	; Timer, I/O and ROM Control
.define DSPADDR	$00F2	; DSP Register Index (R/W)
.define DSPDATA $00F3	; DSP Register Data (R/W)
.define CPUIO0	$00F4
.define CPUIO1	$00F5
.define CPUIO2	$00F6
.define CPUIO3	$00F7
.define AUXIO4	$00F8
.define AUXIO5	$00F9
.define T0DIV	$00FA	; Timer 0 Divider (for 8000Hz clock source) (W)
.define T1DIV	$00FA	; Timer 0 Divider (for 8000Hz clock source) (W)
.define T2DIV	$00FA	; Timer 0 Divider (for 64000Hz clock source) (W)
.define T0OUT	$00FD
.define T1OUT	$00FE
.define T2OUT	$00FF

;;;;;;;;;;; DSP registers ;;;;;;;;;;;;

;; voice registers (repeated at $10 interval for 8 voices)
.define VOL_L	$00 ; \ left and right volume
.define VOL_R	$01 ; /
.define P_L		$02 ; \ The total 14 bits of P(H) & P(L) express
.define P_H		$03 ; / pitch height
.define SCRN	$04 ; Designates source number from 0-256
.define ADSR1	$05 ; \ Address is designated by D7 = 1 of ADSR(1):
.define ADSR2	$06 ; /
.define GAIN	$07 ; Envelope can be freely designated by the program.
.define ENVX	$08 ; Present value of evelope which DSP rewrittes at each Ts.
.define OUTX	$09 ; Value after envelope multiplication & before VOL multiplication (present wave height value)

.define CHN0_OFF	$00
.define CHN1_OFF	$10
.define CHN2_OFF	$20
.define CHN3_OFF	$30
.define CHN4_OFF	$40
.define CHN5_OFF	$50
.define CHN6_OFF	$60
.define CHN7_OFF	$70

;; Global / common register
.define MVOL_L	$0c	; Main Volume (L)
.define MVOL_R	$1c ; Main Volume (R)
.define EVOL_L	$2c ; Echo Volume (L)
.define EVOL_R	$3c ; Echo Volume (R)
.define KON		$4c ; Key On. D0-D7 correspond to Voice0-Voice7
.define KOF		$5c ; key Off

.define FLG		$6c ; Designated on/off of reset, mute, echo and noise clock.
.define FLG_RES			$80	; soft reset
.define FLG_MUTE		$40 ; mute
.define FLG_ECHO_DIS	$20 ; echo enable
.define FLG_NCK			$04 ; noise generator clock

.define ENDX	$7c ; Indicates source end block.

.define EFB		$0d ; Echo Feed-Back
.define PMON	$2d ; Pitch modulation of Voice i with OUTX of Voice (i=1) as modulated wave.
.define NOV		$3d ; Noise on/off. D0-D7 correspond to Voice0-Voice7
.define EOV		$4d ; Echo On/Off
.define DIR		$5d ; Off-set address of source directory
.define ESA		$6d ; Off-set address of echo region. Echo Start Address
.define EDL		$7d ; Echo Delay. Only lower 4 bits operative.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; syntax writeDspReg reg data
.macro writeDspReg
	mov DSPADDR, #\1
	mov DSPDATA, #\2
.endm

; syntax writeDspReg reg
; (value written taken from register A)
.macro writeDspReg_A
	mov DSPADDR, #\1
	mov DSPDATA, A
.endm

.macro writeDspReg16
	mov DSPADDR, #\1
	mov DSPDATA, #<\2
	mov DSPADDR, #\1+1
	mov DSPDATA, #>\2
.endm


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.bank 0

.section "Code" FORCE

entry:
	jmp !main


main:

	writeDspReg DIR >source_directory
	writeDspReg MVOL_L 96
	writeDspReg MVOL_R 96
	writeDspReg EVOL_L 0
	writeDspReg EVOL_R 0

	writeDspReg FLG FLG_ECHO_DIS

	; Init all voices in silence`

	writeDspReg SCRN+CHN0_OFF 0
	writeDspReg VOL_L+CHN0_OFF 0
	writeDspReg VOL_R+CHN0_OFF 0
	writeDspReg16 ADSR1+CHN0_OFF 0
	writeDspReg GAIN+CHN0_OFF 0

	writeDspReg SCRN+CHN1_OFF 0
	writeDspReg VOL_L+CHN1_OFF 0
	writeDspReg VOL_R+CHN1_OFF 0
	writeDspReg16 ADSR1+CHN1_OFF 0
	writeDspReg GAIN+CHN1_OFF 0

	writeDspReg SCRN+CHN2_OFF 0
	writeDspReg VOL_L+CHN2_OFF 0
	writeDspReg VOL_R+CHN2_OFF 0
	writeDspReg16 ADSR1+CHN2_OFF 0
	writeDspReg GAIN+CHN2_OFF 0

	writeDspReg SCRN+CHN3_OFF 0
	writeDspReg VOL_L+CHN3_OFF 0
	writeDspReg VOL_R+CHN3_OFF 0
	writeDspReg16 ADSR1+CHN3_OFF 0
	writeDspReg GAIN+CHN3_OFF 0

	writeDspReg SCRN+CHN4_OFF 0
	writeDspReg VOL_L+CHN4_OFF 0
	writeDspReg VOL_R+CHN4_OFF 0
	writeDspReg16 ADSR1+CHN4_OFF 0
	writeDspReg GAIN+CHN4_OFF 0

	writeDspReg SCRN+CHN5_OFF 0
	writeDspReg VOL_L+CHN5_OFF 0
	writeDspReg VOL_R+CHN5_OFF 0
	writeDspReg16 ADSR1+CHN5_OFF 0
	writeDspReg GAIN+CHN5_OFF 0

	writeDspReg SCRN+CHN6_OFF 0
	writeDspReg VOL_L+CHN6_OFF 0
	writeDspReg VOL_R+CHN6_OFF 0
	writeDspReg16 ADSR1+CHN6_OFF 0
	writeDspReg GAIN+CHN6_OFF 0

	writeDspReg SCRN+CHN7_OFF 0
	writeDspReg VOL_L+CHN7_OFF 0
	writeDspReg VOL_R+CHN7_OFF 0
	writeDspReg16 ADSR1+CHN7_OFF 0
	writeDspReg GAIN+CHN7_OFF 0

	; Disable echo
	writeDspReg EOV 0
	; Disable noise
	writeDspReg NOV 0
	; Dsiable pitch modulation
	writeDspReg PMON 0

	; Sound 0 (error)
	writeDspReg SCRN 0
	writeDspReg16 P_L $0400 ; original $1000
	writeDspReg VOL_L 128
	writeDspReg VOL_R 128
	writeDspReg16 ADSR1 $0000
	writeDspReg GAIN 64

	; Sound 1 (write)
	writeDspReg SCRN+CHN1_OFF 1
	writeDspReg16 P_L+CHN1_OFF $0800 ; original
	writeDspReg VOL_L+CHN1_OFF 128
	writeDspReg VOL_R+CHN1_OFF 128
	writeDspReg16 ADSR1+CHN1_OFF $0000
	writeDspReg GAIN+CHN1_OFF 64

	; Sound 2 (erase)
	writeDspReg SCRN+CHN2_OFF 2
	writeDspReg16 P_L+CHN2_OFF $0800 ; original
	writeDspReg VOL_L+CHN2_OFF 128
	writeDspReg VOL_R+CHN2_OFF 128
	writeDspReg16 ADSR1+CHN2_OFF $0000
	writeDspReg GAIN+CHN2_OFF 64

	; Sound 3 (click)
	writeDspReg SCRN+CHN3_OFF 3
	writeDspReg16 P_L+CHN3_OFF $0800 ; original
	writeDspReg VOL_L+CHN3_OFF 128
	writeDspReg VOL_R+CHN3_OFF 128
	writeDspReg16 ADSR1+CHN3_OFF $0000
	writeDspReg GAIN+CHN3_OFF 64

	; Sound 4 (back)
	writeDspReg SCRN+CHN4_OFF 4
	writeDspReg16 P_L+CHN4_OFF $0800 ; original
	writeDspReg VOL_L+CHN4_OFF 128
	writeDspReg VOL_R+CHN4_OFF 128
	writeDspReg16 ADSR1+CHN4_OFF $0000
	writeDspReg GAIN+CHN4_OFF 64

	; Sound 5 (back)
	writeDspReg SCRN+CHN5_OFF 5
	writeDspReg16 P_L+CHN5_OFF $0800 ; original
	writeDspReg VOL_L+CHN5_OFF 128
	writeDspReg VOL_R+CHN5_OFF 128
	writeDspReg16 ADSR1+CHN5_OFF $0000
	writeDspReg GAIN+CHN5_OFF 64


	; Silence unused channels
	writeDspReg SCRN+CHN6_OFF 0
	writeDspReg VOL_L+CHN6_OFF 0
	writeDspReg VOL_R+CHN6_OFF 0
	writeDspReg16 ADSR1+CHN6_OFF 0
	writeDspReg GAIN+CHN6_OFF 0

	writeDspReg SCRN+CHN7_OFF 0
	writeDspReg VOL_L+CHN7_OFF 0
	writeDspReg VOL_R+CHN7_OFF 0
	writeDspReg16 ADSR1+CHN7_OFF 0
	writeDspReg GAIN+CHN7_OFF 0


@mainloop:

	mov A, CPUIO0	; handshake
@waitChange:
	cmp A, CPUIO0
	beq @waitChange

	mov A, CPUIO1	; command

	; acknowledge the command
	push A
	mov A, CPUIO0
	mov CPUIO0, A
	pop A

;	cmp A, #$10
	bra @keyon

	bra @mainloop

	; Take A holding a value from 0 to 7, convert it to a
	; bit for KON : In other words, do this: 1<<A
@keyon:
	and A, #$7
	mov X, A
	mov A, #1
@n:
	dec X
	bmi @done_shifting
	asl A
	bra @n

@done_shifting:
	writeDspReg_A KON

	bra @mainloop


.ends


.section "source_directory" align $100 FREE
source_directory:
	.dw errorSample ; Source start address
	.dw errorSample ; Source loop start address
	.dw writeSample
	.dw writeSample
	.dw eraseSample
	.dw eraseSample
	.dw clickSample
	.dw clickSample
	.dw backSample
	.dw backSample
	.dw solvedSample
	.dw solvedSample
.ends


.section "samples"
errorSample: .incbin "error.brr"
writeSample: .incbin "write.brr"
eraseSample: .incbin "erase.brr"
clickSample: .incbin "click.brr"
backSample: .incbin "back.brr"
solvedSample: .incbin "solved.brr"
.ends


.include "header.inc"
.include "snesregs.inc"
.include "misc_macros.inc"
.include "zeropage.inc"

.bank 0 slot 1

.ramsection "bg1_vars" SLOT RAM_SLOT
	bg1_load_bank: db
	bg1_load_offset: dw
	bg1_need_resync: dw
.ends

.16BIT

.section "bg1_code" FREE

.define BG1_DATA_PTR	0
.define BG1_DATA_BANK	$7F
.define BG1_DATA_SIZE	32*28*2
.define BG1_VRAM_WORD_ADDRESS	$3000>>1

bg1_sync:
	pushall

	A8
	XY16

	lda bg1_need_resync
	beq @nothing_to_do

	lda #$80
	sta VMAIN ; Set Word Write mode to VRAM (increment after $2119)

	; Set VRAM address to VRAM_ADDRESS
	ldx #BG1_VRAM_WORD_ADDRESS
	stx VMADDL

	lda #$01
	sta DMAP2 ; Set DMA Mode (word, increment)

	; Set low byte address to $18 (high byte assumed to be $21, so $2100 to $21FF)
	lda #<VMDATAL
	sta BBAD2 ; Write to VRAM ($2118)

	; Set source bank and offset
	ldx #BG1_DATA_PTR
	stx A1T2L
	lda #BG1_DATA_BANK
	sta A1B2

	; Size of transfer
	ldx #BG1_DATA_SIZE
	stx DAS2L

	lda #$1<<2
	sta MDMAEN ; Initiate VRAM DMA Transfer

	stz bg1_need_resync

@nothing_to_do:

	popall
	rts


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Load the title map from ROM and copy it to VRAM
	;
bg1_loadTitleMap:
	pushall
	A8
	stz bg1_load_bank
	A16
	lda #TITLEBG
	sta bg1_load_offset
	jsr bg1_loadFromRom
	jsr bg1_sync
	popall
	rts


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; Load the grid map from ROM and copy it to VRAM
	;
bg1_loadGridMap:
	pushall
	A8
	stz bg1_load_bank
	A16
	lda #GRIDBG
	sta bg1_load_offset
	jsr bg1_loadFromRom
	jsr bg1_sync
	popall
	rts



bg1_loadFromRom:
	pushall

	XY16
	A8

	; Set DMA source address in ROM
	ldx bg1_load_offset ; offset
	stx A1T1L
	lda bg1_load_bank
	stz A1B1			; bank

	; Transfer size
	ldx #BG1_DATA_SIZE
	stx DAS1L

	; Prepare WRAM destination
	lda #BG1_DATA_BANK
	sta WMADDH
	ldx #BG1_DATA_PTR
	stx WMADDL

	lda #<WMDATA	; low byte of 2180
	sta BBAD1

	; Set transfer mode (1 byte mode, cpu to IO)
	lda #0
	sta DMAP1

	; start the transfer
	lda #1<<1
	sta MDMAEN

	popall
	rts

.ends



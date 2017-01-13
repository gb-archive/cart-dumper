INCLUDE "gbhw.inc"
INCLUDE "ibmpc1.inc"
INCLUDE "hex-chars.inc"
INCLUDE "tile-designer\\LoadingBar.inc"
INCLUDE "tile-designer\\LoadingBar.z80"


; VRAM Offsets
VRO_HEX_CHAR EQU $F0

; Tile Addresses
TILE_LOADING_START EQU $E0
TILE_LOADING_END EQU $E2
TILE_LOADING_EMPTY EQU $E1
TILE_LOADING_PARTIAL EQU $E3
TILE_LOADING_FELL EQU $E4

; Background positions
BG_POS_CART_PROMPT EQU _SCRN0 + 1 + (SCRN_VY_B * 3)
BG_POS_CART_TITLE EQU _SCRN0 + 2 + (SCRN_VY_B * 5)
BG_POS_DUMP_STATUS EQU _SCRN0 + 0 + (SCRN_VY_B * 13)
BG_POS_LOADING_BAR EQU _SCRN0 + 1 + (SCRN_VY_B * 15)

; Booleans
TRUE EQU 1
FALSE EQU 0

; Cart header locations
CART_TITLE EQU $0134
CART_TITLE_LEN EQU 15
CART_NINTY_LOGO EQU $0104
CART_NINTY_LOGO_LEN EQU CART_TITLE - CART_NINTY_LOGO

; HRAM Variable locations
VAR_JOY_CHAR EQU _HRAM
VAR_CART_IN EQU _HRAM+1
VAR_TX_TIMER EQU _HRAM+2
VAR_COUNT EQU 3

; RAM CONST locations
RC_START EQU _RAM + $0FFF
RC_NINTY_LOGO_LEN EQU CART_NINTY_LOGO_LEN
RC_NINTY_LOGO EQU RC_START - RC_NINTY_LOGO_LEN
RC_NO_CART_STR_LEN EQU CART_TITLE_LEN
RC_NO_CART_STR EQU RC_START - RC_NINTY_LOGO_LEN - RC_NO_CART_STR_LEN
RC_DUMP_STATUS_LINES_LEN EQU 20 * 5
RC_DUMP_STATUS_LINES EQU RC_START - RC_NINTY_LOGO_LEN - RC_NO_CART_STR_LEN - RC_DUMP_STATUS_LINES_LEN


SECTION "Org $100",HOME[$100]
	nop
	jp	begin

  ROM_HEADER      ROM_NOMBC, ROM_SIZE_32KBYTE, RAM_SIZE_0KBYTE

  INCLUDE "memory.asm"

TileData:
	chr_IBMPC1      1,8
HexTiles:
	chr_HEXCHARS

begin:
	di
	ld	sp, $ffff ; init stack pointer
	call StopLCD

	ld	a, $e4
	ld	[rBGP], a ; background palette

	ld  a, 0 ; init scroll registers
	ld  [rSCX], a
	ld  [rSCY], a

	; Zero out HRAM (where I store  vars)
	ld   	a, 0
	ld   	hl, _HRAM
	ld  	bc, VAR_COUNT ; amount of vars
	call	mem_Set

	;; VRAM loads
	; load default tiles to vram
	ld   	hl, TileData
	ld 		de, _VRAM
	ld		bc, 8*256        ; length (8 bytes per tile) x (256 tiles)
	call	mem_CopyMono    ; Copy tile data to memory
	; load hex-chars tiles to vram
	ld   	hl, HexTiles
	ld 		de, _VRAM + $0f00
	ld		bc, 8*16        ; length (8 bytes per tile) x (16 tiles)
	call	mem_CopyMono    ; Copy tile data to memory
	; load the loading bar tiles to vram
	ld   	hl, LoadingBar
	ld 		de, $8e00
	ld		bc, 16*LoadingBarLen        ; length (16 bytes per tile) x (16 tiles)
	call	mem_Copy    ; Copy tile data to memory

	;; Clear the background
	ld   	a, $20 ; $20 = blank tile
	ld   	hl, _SCRN0
	ld  	bc, SCRN_VX_B * SCRN_VY_B
	call	mem_Set

	;; Initialise background tiles
	; Draw ROM title
	ld      hl, RomTitle
	ld      de, _SCRN0
	ld      bc, 20
	call    mem_Copy
	; Draw cart prompt
	ld      hl, CartPrompt
	ld      de, BG_POS_CART_PROMPT
	ld      bc, 10
	call    mem_Copy
	; Draw empty loading bar
	ld      hl, EmptyLoadingBar
	ld      de, BG_POS_LOADING_BAR
	ld      bc, 18
	call    mem_Copy

	;; Copy code & data to gameboy RAM
	; Copy mainloop to RAM
	ld      hl, $4000
	ld      de, _RAM
	ld      bc, $0FFF ; max size of inbuilt RAM (TODO - Find out length of code and copy to that...)
	call    mem_Copy
	; Copy Nintendo logo to RAM (to compare and check carts are in)
	ld      hl, CART_NINTY_LOGO
	ld      de, RC_NINTY_LOGO
	ld      bc, RC_NINTY_LOGO_LEN
	call    mem_Copy
	; Copy no-cart string to RAM
	ld      hl, NoCart
	ld      de, RC_NO_CART_STR
	ld      bc, RC_NO_CART_STR_LEN
	call    mem_Copy
	; Copy dump status lines to RAM
	ld      hl, DumpStatusLines
	ld      de, RC_DUMP_STATUS_LINES
	ld      bc, RC_DUMP_STATUS_LINES_LEN
	call    mem_Copy


	;; Turn screen on
	ld      a,LCDCF_ON|LCDCF_BG8000|LCDCF_BG9800|LCDCF_BGON|LCDCF_OBJ16|LCDCF_OBJOFF
	ld      [rLCDC],a

	;; jump to copied code in ram
	jp _RAM

; *** Turn off the LCD display ***
StopLCD:
        ld      a,[rLCDC]
        rlca                    ; Put the high bit of LCDC into the Carry flag
        ret     nc              ; Screen is off already. Exit.
; Loop until we are in VBlank
.stopWait:
        ld      a,[rLY]
        cp      145             ; Is display on scan line 145 yet?
        jr      nz, .stopWait        ; no, keep waiting
; Turn off the LCD
        ld      a,[rLCDC]
        res     7,a             ; Reset bit 7 of LCDC
        ld      [rLCDC],a
        ret

;; Data only needed when loading
RomTitle:
	DB $DB, $B2, $B1, $B0
	DB "Cart Dumper!"
	DB $B0, $B1, $B2, $DB
CartPrompt:
	DB "Cartridge:"
EmptyLoadingBar:
	DB TILE_LOADING_START, TILE_LOADING_EMPTY, TILE_LOADING_EMPTY, TILE_LOADING_EMPTY, TILE_LOADING_EMPTY
	DB TILE_LOADING_EMPTY, TILE_LOADING_EMPTY, TILE_LOADING_EMPTY, TILE_LOADING_EMPTY, TILE_LOADING_EMPTY
	DB TILE_LOADING_EMPTY, TILE_LOADING_EMPTY, TILE_LOADING_EMPTY, TILE_LOADING_EMPTY, TILE_LOADING_EMPTY
	DB TILE_LOADING_EMPTY, TILE_LOADING_EMPTY, TILE_LOADING_END

;; Data that will be copied to the top end of RAM
NoCart:
	DB "<No Cartridge> "
DumpStatusLines:
	DB "  Insert Cartridge  "
	DB " Ready, press Start "
	DB "     Dumping...     "
	DB "   Dump complete!   "
	DB "   No link cable?   "





SECTION "MainLoop",CODE[$4000]
	nop
.mainLoop:
		; Loop until vblank status flag is set
.vblankWait:
		ld a, [rSTAT]
		and $03
		cp STATF_VB
		jr nz, .vblankWait

.VRAMStuff:
	lcd_WaitVRAM

;; Drawing
	; Check for cart
	ld a, [VAR_CART_IN]
	cp TRUE
	jr nz, .noCartDraw
	; If cart inserted, draw cart title
	ld hl, CART_TITLE ; Cart title location in rom
	ld de, BG_POS_CART_TITLE
	ld bc, CART_TITLE_LEN
	inc	b
	inc	c
	jr	.ctSkip
.cartTitleLoop	ld a,[hl+]
	cp 0
	jr nz, .writeChar ; if not zero go straight to draw
	ld a, $20 ; load a with $20 = space
.writeChar ld	[de], a
	inc	de
.ctSkip	dec	c
	jr	nz, .cartTitleLoop
	dec	b
	jr	nz, .cartTitleLoop
	; Draw the ready dump status line
	ld hl, RC_DUMP_STATUS_LINES + SCRN_X_B * 1
	ld de, BG_POS_DUMP_STATUS
	ld bc, SCRN_X_B
	inc	b
	inc	c
	jr	.dsrSkip
.dsrLoop	ld	a,[hl+]
	ld	[de],a
	inc	de
.dsrSkip	dec	c
	jr	nz, .dsrLoop
	dec	b
	jr	nz, .dsrLoop
	jr .cartTitleEnd
.noCartDraw:
	; Draw the no-cart title
	ld hl, RC_NO_CART_STR
	ld de, BG_POS_CART_TITLE
	ld bc, CART_TITLE_LEN
	inc	b
	inc	c
	jr	.nctSkip
.nctLoop	ld	a,[hl+]
	ld	[de],a
	inc	de
.nctSkip	dec	c
	jr	nz, .nctLoop
	dec	b
	jr	nz, .nctLoop
	; Draw the insert-cart dump status line
	ld hl, RC_DUMP_STATUS_LINES + SCRN_X_B * 0
	ld de, BG_POS_DUMP_STATUS
	ld bc, SCRN_X_B
	inc	b
	inc	c
	jr	.dsicSkip
.dsicLoop	ld	a,[hl+]
	ld	[de],a
	inc	de
.dsicSkip	dec	c
	jr	nz, .dsicLoop
	dec	b
	jr	nz, .dsicLoop
.cartTitleEnd:

;; DEBUG DRAWING
	; Draw joypad char
	ld a, [VAR_JOY_CHAR]
	ld [$9A20], a
	; Draw SB
	ld a, [rSB]
	and $0f
	add VRO_HEX_CHAR
	ld [$9A33], a ; low nibble
	ld a, [rSB]
	swap a
	and $0f
	add VRO_HEX_CHAR
	ld [$9A32], a ; high nibble
;; DEBUG DRAWING


	; Extract ROM if Start pressed and there's a cart in
	ld a, [VAR_CART_IN]
	cp TRUE
	jr nz, .endExtract
	ld a, [VAR_JOY_CHAR]
	cp $53 ; ascii S
	jr nz, .endExtract
	; Draw the dumping dump status line
	ld hl, RC_DUMP_STATUS_LINES + SCRN_X_B * 2
	ld de, BG_POS_DUMP_STATUS
	ld bc, SCRN_X_B
	inc	b
	inc	c
	jr	.dsdSkip
.dsdLoop	ld	a,[hl+]
	ld	[de],a
	inc	de
.dsdSkip	dec	c
	jr	nz, .dsdLoop
	dec	b
	jr	nz, .dsdLoop
	; Start extract routine
	ld hl, $0000 ; start at the beginning...
	ld bc, $8000 ; end of both ROM banks (okay for cart type 0)
	inc	b
	inc	c
	jr	.exSkip
.exLoop	ld a,[hl+]
	ld	[rSB], a ; Put byte in serial buffer
	ld a, 0
	ld [VAR_TX_TIMER], a ; zero the tx timer
	ld a, $81
	ld [rSC], a ; Start transfer, using internal clock
.txCheck:
	ld a, [rSC]
	BIT 7, a ; Test transfer flag
	jr z, .txDone ; if zero, skip timer loop
	ld a, [VAR_TX_TIMER] ; inc timer
	inc a ; inc timer
	ld [VAR_TX_TIMER], a ; inc timer
	cp $ff
	jr nz, .txCheck ; if timer != $ff, recheck the tx flag
	; wait for transfer to end...
.txDone	ld a, 0
	; pause a bit between bytes being transferred
 ld [VAR_TX_TIMER], a ; zero the tx timer
.postTxPause:	ld a, [VAR_TX_TIMER] ; inc timer
	inc a ; inc timer
	ld [VAR_TX_TIMER], a ; inc timer
	cp $ff
	jr nz, .postTxPause ; if timer != $ff, recheck the tx flag
.exSkip	dec	c
	jr	nz, .exLoop
	dec	b
	jr	nz, .exLoop
.endExtract:




.ReadJoypad:
	LD A,$20       ;<- bit 5 = $20
	LD [$FF00],A   ;<- select P14 by setting it low
	LD A,[$FF00]   ;
	LD A,[$FF00]   ;<- wait a few cycles
	CPL            ;<- complement A
	AND $0F        ;<- get only first 4 bits
	SWAP A         ;<- swap it
	LD B,A         ;<- store A in B
	LD A,$10       ;
	LD [$FF00],A   ;<- select P15 by setting it low
	LD A,[$FF00]   ;
	LD A,[$FF00]   ;
	LD A,[$FF00]   ;
	LD A,[$FF00]   ;
	LD A,[$FF00]   ;
	LD A,[$FF00]   ;<- Wait a few MORE cycles
	CPL            ;<- complement (invert)
	AND $0F        ;<- get first 4 bits
	OR B           ;<- put A and B together
								 ;
	LD B,A         ;<- store A in D
	LD A,[$FF8B]   ;<- read old joy data from ram
	XOR B          ;<- toggle w/current button bit
	AND B          ;<- get current button bit back
	LD [$FF8C],A   ;<- save in new Joydata storage
	LD A,B         ;<- put original value in A
	LD [$FF8B],A   ;<- store it as old joy data
								 ;
	LD A,$30       ;<- deselect P14 and P15
	LD [$FF00],A   ;<- RESET Joypad
	; Test joypad and put ascii char in b
	ld b, $db
	ld a, [$FF8B]
.start:
	bit PADB_START, a
	jr z, .select
	ld b, $53
.select:
	bit PADB_SELECT, a
	jr z, .btnB
	ld b, $73
.btnB:
	bit PADB_B, a
	jr z, .btnA
	ld b, $62
.btnA:
	bit PADB_A, a
	jr z, .down
	ld b, $61
.down:
	bit PADB_DOWN, a
	jr z, .up
	ld b, $19
.up:
	bit PADB_UP, a
	jr z, .left
	ld b, $18
.left:
	bit PADB_LEFT, a
	jr z, .right
	ld b, $1b
.right:
	bit PADB_RIGHT, a
	jr z, .joyOut
	ld b, $1a
.joyOut:
	ld a, b
	ld [VAR_JOY_CHAR], a


;; Test if a valid cart is attached
	ld a, FALSE
	ld [VAR_CART_IN], a ; Default to FALSE
	LD HL, CART_NINTY_LOGO	; Compare cartridge Nintendo logo
	LD DE, RC_NINTY_LOGO		; To the one copied into ram at the start
.logoCmpLoop:
	LD A,[DE] ; a = RC_NINTY_LOGO[de]
	INC DE		; de++
	CP [HL]		; a == CART_NINTY_LOGO[hl]
	JR NZ, .endLogoCmpLoop ; if not a match, break out leaving cart_in=false
	INC HL		; hl++
	LD A, L		;
	CP $34		; Loop until L = $34 (meaning HL=$0134, 48 bytes after CART_TITLE($0104))
	JR NZ, .logoCmpLoop
.validCart:
	ld a, TRUE
	ld [VAR_CART_IN], a
.endLogoCmpLoop:


	jp _RAM

	; code-end identifier
	DB $DE,$AD,$DE,$AD

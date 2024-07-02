; ///////////////////////////////////////////////////////////////////////////////////////////// 



; simple Hello World for SEGA Master System/Mark III by jvsTSX (2024)

; - from the Hello World Everything project at https://github.com/jvsTSX/hello-world-everything -

; >>>>>>>> thanks to <<<<<<<<<
; Calindro for helping me out figuring out the I/O layout of the SMS
; Lidnariq for helping me write the documentation and understanding some weirder behaviour
; my friends at the Elysian Shadows discord for helping me learning C for the tools included with this repo

; >>>>>> tools required <<<<<<
; WLA-DX assembler                      - https://github.com/vhelin/wla-dx
; Emulicious or Mesen emulator          - https://emulicious.net  /  https://www.mesen.ca/
; a command line to run the assembler
; a text editor or viewer like this one

; should run on most models after patching with the included C program

; notes: 
; - JP and KO units don't look for the header at all, if your system is either a JP SMS or a GAM BOY, running this without patching will work just fine
; - early Game Gear and Mark III lacks a BIOS entirely 
; - majesco Game Gear only checks for the TMSS string, assembling this as-is and putting it on a GG flash cart should work without the patch as well



; ///////////////////////////////////////////////////////////////////////////////////////////// 
.MEMORYMAP       ; memory definition for 32K ROM
	SLOTSIZE $8000
	DEFAULTSLOT 0
	SLOT 0 $0000
.ENDME

.ROMBANKMAP
	BANKSTOTAL 1
	BANKSIZE $8000
	BANKS 1
.ENDRO

.BANK 0 SLOT 0
	.ORGA $0000 ; entry point, the BIOS jumps here once it detects a cart
	di
  jp Start

; //////////////////////////////////  Interrupt vectors  ////////////////////////////////////// 
	.ORG $38
	in a, ($BF) ; clear the interrupt flag
	ei
  reti

	.ORG $66
	ei
  retn

; //////////////////////////////////    Program start    ////////////////////////////////////// 
	.ORG $100
Start:
	im 1
	ld sp, $DFFF
	; ^ these are usually already set by the BIOS but Mark III and early GGear lacks it
	ld c, $BF

	; setup VDP regs
	ld hl, $8000 + %00011110
	out (c), l
	out (c), h

	ld hl, $8100 + %10100000
	out (c), l
	out (c), h

	ld hl, $8200 + %00001111
	out (c), l
	out (c), h

	ld hl, $8300 + %11111111
	out (c), l
	out (c), h

	ld hl, $8400 + %00000111
	out (c), l
	out (c), h

	ld hl, $8500 + %01111111
	out (c), l
	out (c), h

	ld hl, $8600 + %00000111
	out (c), l
	out (c), h

	ld hl, $8700 + %00000000
	out (c), l
	out (c), h

	ld hl, $8800 + %00000000
	out (c), l
	out (c), h

	ld hl, $8900 + %00000000
	out (c), l
	out (c), h

	ld hl, $8A00 + %00010001
	out (c), l
	out (c), h

; //////////////////////////////////    Copy palettes    ////////////////////////////////////// 
	ld c, $BF
	ld hl, $C000
	out (c), l
	out (c), h
	dec c ; $BE
	ld de, hwd_pal
	ld b, 32

CopyPalLoop:
	ld a, (de)
	inc de
	out (c), a
  djnz CopyPalLoop

	; copy tiles
	ld a, $FF
	out ($BF), a
	ld a, $3F
	out ($BF), a
	ld de, hwd_tiles
	ld bc, 8192

; ////////////////////////////////// Copy tiles to VRAM  ////////////////////////////////////// 
TileCopyLoop:
	ld a, (de)
	out ($BE), a
	inc de
	dec bc
	ld a, b
	or a, c
  jp nz, TileCopyLoop

; //////////////////////////////////    Clear Tilemap    ////////////////////////////////////// 
	ld c, $BF
	ld hl, $37FF
	out (c), l
	out (c), h
	dec c ; $BE
	ld de, $400
ClearLoop:
	xor a, a
	out (c), a
	out (c), a
	dec de
	sub a, e
	or a, d
  jp nz, ClearLoop

; //////////////////////////////////    Print String     ////////////////////////////////////// 
	ld c, $BF
	ld hl, $37FF
	out (c), l
	out (c), h
	ld c, $BE
	ld de, hwd_str
	
StrCopyLoop:
	ld a, (de)
	inc de
	or a, a
  jp z, TextDone
	cp a, 10
  jp z, LineFeed
	out (c), a
	xor a, a
	out (c), a
  jp StrCopyLoop

LineFeed:
	ld a, 64
	add a, l
	ld l, a
	adc a, h
	sub a, l
	ld h, a
	
	ld c, $BF
	out (c), l
	out (c), h
	ld c, $BE
  jp StrCopyLoop

TextDone:

; ///////////////////////////////////////////////////////////////////////////////////////////// 
	; done, enter main loop
	ld c, $BF
	ld hl, $8100 + %11100000 ; turn screen back on
	out (c), l
	out (c), h

	ei
MainLoop:
	halt
  jp MainLoop



; ///////////////////////////////////////////////////////////////////////////////////////////// 
hwd_str:
;    00000000011111111112222222222333
;    12345678901234567890123456789012
.db 10
.db "Hello, World!",                    10
.db "From the Zilog Z80",               10
.db "--------------------------------", 10
.db "the quick brown fox jumps over",   10
.db "the lazy dog"                      10
.db "THE QUICK BROWN FOX JUMPS OVER",   10
.db "THE LAZY DOG",                     10
.db "--------------------------------", 10
.db " !", $22, "#$%&'()*+,-./0123456789:;<=>?", 10
.db "@[\]^`{|}~",                       10


hwd_tiles:
.incbin "tiles.bin"

hwd_pal:
; bg pal
.db %00000000 ; basically immitating the default MSpaint pal for 4bit, anything else should work
.db %00000001
.db %00000100
.db %00000101
.db %00010000
.db %00010001
.db %00010100
.db %00010101
.db %00101010
.db %00000011
.db %00001100
.db %00001111
.db %00110000
.db %00110011
.db %00111100
.db %00111111

; sprite pal
.db %00000000
.db %00000000
.db %00000000
.db %00000000
.db %00000000
.db %00000000
.db %00000000
.db %00000000
.db %00000000
.db %00000000
.db %00000000
.db %00000000
.db %00000000
.db %00000000
.db %00000000
.db %00000000


; ///////////////////////////////////////////////////////////////////////////////////////////// 
	.ORG $7FF0 ; header
.db "TMR SEGA" ; TMSS string
.db 00, 00     ; blank, can be 00, FF or 20
.db 00, 00     ; placeholder checksum (LE), make sure you run the checksum C file included
.db 00, 00, $00, $4A
;   ||  ||   ||   ||
;   ||  ||   ||   |+------ ROM size (* 8K)
;   ||  ||   ||   +------- Region (* Export)
;   ||  ||   |+----------- product version
;   ++--++---+------------ product code

; * regardless of your actual region and ROM size, keep these values as they are to make sure your ROM works on virtually all models
; and yes, even if it finds the header here at the 32K range, it will still check if the header says the ROM is 8K so that should speed up the booting process
; ///////////////////////////////////////////////////////////////////////////////////////////// 

; interleaved text display with ASCII input by jvsTSX (2024)
; it should say anything you wish! so long as it's uppercase ASCII

; note: this started as an 8-bit workshop project but javatari.js does not emulate HMOVE correctly

; >>>>>>>> thanks to <<<<<<<<<
; akumanatt for documenting the +8 behaviour of HMOVE register
; nocash for the 2600 documentation - https://problemkaputt.de/2k6specs.htm

; >>>>>> tools required <<<<<<
; - CA65 assembler from CC65 suite - https://github.com/cc65/cc65
; - a terminal that can run CA65
; - a text editor to read this
; - stella emulator is recommended for testing - https://stella-emu.github.io/

.OUT "DON'T LET ET DOWN"

; ////////////////////////////////////// Reg Definitions /////////////////////////////////////// 
	VSYNC	= $00 ; TIA Writeonly
	VBLANK	= $01
	WSYNC	= $02
	RSYNC	= $03
	NUSIZ0	= $04
	NUSIZ1	= $05
	COLUP0	= $06
	COLUP1	= $07
	COLUPF	= $08
	COLUBK	= $09
	CTRLPF	= $0A
	REFP0	= $0B
	REFP1	= $0C
	PF0 	= $0D
	PF1 	= $0E
	PF2 	= $0F
	RESP0	= $10
	RESP1	= $11
	RESM0	= $12
	RESM1	= $13
	RESBL	= $14
	AUDC0	= $15
	AUDC1	= $16
	AUDF0	= $17
	AUDF1	= $18
	AUDV0	= $19
	AUDV1	= $1A
	GRP0	= $1B
	GRP1	= $1C
	ENAM0	= $1D
	ENAM1	= $1E
	ENABL	= $1F
	HMP0	= $20
	HMP1	= $21
	HMM0	= $22
	HMM1	= $23
	HMBL	= $24
	VDELP1	= $25
	VDELP0	= $26
	VDELBL	= $27
	RESMP0	= $28
	RESMP1	= $29
	HMOVE	= $2A
	HMCLR	= $2B
	CXCLR	= $2C
	
	CXM0P	= $30 ; TIA Readonly
	CXM1P	= $31
	CXP0FB	= $32
	CXP1FB	= $33
	CXM0FB	= $34
	CXM1FB	= $35
	CXBLPF	= $36
	CXPPMM	= $37
	INPT0	= $38
	INPT1	= $39
	INPT2	= $3A
	INPT3	= $3B
	INPT4	= $3C
	INPT5	= $3D
	
	SWCHA	= $0280 ; RIOT Regs
	SWACNT	= $0281
	SWCHB	= $0282
	SWBCNT	= $0283
	INTIM	= $0284
	INSTAT	= $0285
	TIM1T	= $0294
	TIM8T	= $0295
	TIM64T	= $0296
	T1024T	= $0297
	
	
	
; ////////////////////////////////////// RAM Definitions /////////////////////////////////////// 
.SEGMENT "RAM"
TextRowsCounter:      .res 1
ScanLineCounter:      .res 1
CharsLeftToCopy:      .res 1
TextLinePointer:      .res 1
LineGraphicsBuffer:   .res 60

; ///////////////////////////////////////// Code begin ///////////////////////////////////////// 
.SEGMENT "ROM":ABSOLUTE
Start:
	cld            ; make sure decimal mode is off
	lda #0
	sta VSYNC
	sta VBLANK
	sta AUDV0      ; make sure sound is OFF
	sta AUDV1
	sta REFP0      ; make sure players are not mirrored
	sta REFP1
	sta VDELP0     ; make sure P0 is not delayed
	sta ENAM0      ; hide non-player sprites
	sta ENAM1
	sta ENABL
	
	sta PF2     ; background pattern
	lda #%11100000
	sta PF1
	lda #%11110000
	sta PF0

	lda #%00000110 ; player sprites set to repeat 3x
	sta NUSIZ0
	sta NUSIZ1
	lda #1         ; vertical delay P1
	sta VDELP1
	sta CTRLPF     ; playfield set to reflected mode

	lda #$70    ; color pal
	sta COLUBK
	lda #$9E
	sta COLUPF
	sta COLUP1
	sta COLUP0



MainLoop:
; ////////////////////////////////////////// Overscan ////////////////////////////////////////// 
	lda #%00000010
	sta VBLANK
	ldx #30
WaitOverScan:
	sta WSYNC
	dex
  bne WaitOverScan

; ///////////////////// Vsync for 3 scanlines to tell the TV to go back up ///////////////////// 
	lda #%00000010
	sta VSYNC
	sta WSYNC
	sta WSYNC
	sta WSYNC
	lda #0
	sta VSYNC

; /////////////////////////////////// Vblank period (37 sc) /////////////////////////////////// 

	ldx #36
	lda #%00000000
Vblankloop:
	sta WSYNC
	dex
  bne Vblankloop
	sta WSYNC

; ///////////////////////////////////// ACTIVE IMAGE START ///////////////////////////////////// 
	sta VBLANK ; turn off VBlank

	; initially position sprites, all done with trial and error so i can't really say much what's going on here
	inc $1000
	inc $1000
	inc $1000
	inc CXM0P
	nop ; 27 cycles
	
	sta RESP0 ; coarse position player 0 (+3 cycles)
	nop
	sta RESP1 ; coarse position player 1
	lda #$E0
	sta HMP0
	lda #$D0
	sta HMP1
	sta WSYNC
	sta HMOVE ; fine position both players



	lda #0
	sta TextLinePointer
	lda #9
	sta TextRowsCounter
TextRenderLoop: ; /////////////////////////////////////////////////////////////// main image loop
	lda #0              ; blank out sprites so they don't pollute the gaps
	sta GRP0
	sta GRP1
	lda #5              ; reload line counter
	sta ScanLineCounter
	ldx #0              ; X is the char index
	lda #4              ; this loop fetches 12 chars, unrolled 3 times (4 iterations)
	sta CharsLeftToCopy
FetchChars: ; /////////////////////////////////////////////////////////////////// character fetch section
	ldy TextLinePointer ; char number to print
	inc TextLinePointer ; next time the next char will be grabbed
	lda StringDta,y     ; reference char index
	tay
	lda FontData0-32,y           ; each repeated part fetches a char vertically
	sta LineGraphicsBuffer+00,x
	lda FontData1-32,y
	sta LineGraphicsBuffer+12,x
	lda FontData2-32,y
	sta LineGraphicsBuffer+24,x
	lda FontData3-32,y
	sta LineGraphicsBuffer+36,x
	lda FontData4-32,y
	sta LineGraphicsBuffer+48,x
	inx ; next char

	ldy TextLinePointer
	inc TextLinePointer
	lda StringDta,y
	tay
	lda FontData0-32,y
	sta LineGraphicsBuffer+00,x
	lda FontData1-32,y
	sta LineGraphicsBuffer+12,x
	lda FontData2-32,y
	sta LineGraphicsBuffer+24,x
	lda FontData3-32,y
	sta LineGraphicsBuffer+36,x
	lda FontData4-32,y
	sta LineGraphicsBuffer+48,x
	inx
	
	ldy TextLinePointer
	inc TextLinePointer
	lda StringDta,y
	tay
	lda FontData0-32,y
	sta LineGraphicsBuffer+00,x
	lda FontData1-32,y
	sta LineGraphicsBuffer+12,x
	lda FontData2-32,y
	sta LineGraphicsBuffer+24,x
	lda FontData3-32,y
	sta LineGraphicsBuffer+36,x
	lda FontData4-32,y
	sta LineGraphicsBuffer+48,x
	inx

	dec CharsLeftToCopy
  bne FetchChars
	ldx #0



	sta WSYNC ; align to enter loop
	lda $1000
	inc CXM0P
DrawLineLoop: ; ///////////////////////////////////////////////////////////////// draw text on-screen
	lda LineGraphicsBuffer+0,x ; even line
	sta GRP0
	lda LineGraphicsBuffer+2,x
	sta GRP1
	lda LineGraphicsBuffer+4,x	
	sta GRP0
	lda LineGraphicsBuffer+6,x
	ldy LineGraphicsBuffer+10,x
	sta GRP1
	lda LineGraphicsBuffer+8,x
	sta GRP0
	nop
	sty GRP1
	lda #%10000000
	sta HMP0
	sta HMP1
	sta WSYNC
	
	
	
	sta HMOVE ; odd line
	lda LineGraphicsBuffer+1,x
	sta GRP0
	lda LineGraphicsBuffer+3,x
	sta GRP1
	lda LineGraphicsBuffer+5,x	
	sta GRP0
	clc ; step X index to next line
	txa
	adc #12
	tax
	ldy LineGraphicsBuffer+11-12,x
	nop
	lda LineGraphicsBuffer+7-12,x
	sta GRP1
	lda LineGraphicsBuffer+9-12,x
	sta GRP0
	nop
	sty GRP1
	lda CXM0P
	lda $1000
	lda $1000
	sta HMCLR ; motion registers must be 0 for this
	sta HMOVE ; happens at cycle 72, which causes the sprites to be offset by +8
	nop
	
	dec ScanLineCounter
  bne DrawLineLoop
	dec TextRowsCounter
  beq LinesDone
  jmp TextRenderLoop
LinesDone:
	lda #0 ; clear sprites to avoid garbage being shown past the last line
	sta GRP0
	sta GRP1
	sta WSYNC ; wait 1 line to total 192



  jmp MainLoop






FontData0:
.byte %00000000,%00011000,%00101000,%01101100,%01111100,%01101100,%00111000,%00010000,%00110000,%00011000,%00111100,%00011000,%00000000,%00000000,%00000000,%00000110,%01111110,%01111000,%01111000,%01111110,%01101100,%01111110,%01111110,%01111110,%01111110,%01111110,%00000000,%00000000,%00001100,%00000000,%00110000,%11111110,%11111100,%11111110,%11111110,%11111110,%11111110,%11111110,%11111110,%11111110,%11000110,%11111110,%00000110,%11001110,%11000000,%11111110,%11100110,%11111110,%11111110,%11111100,%11111110,%11111110,%11111110,%11000110,%11000110,%11000110,%11000110,%11000110,%11111110,%00111000,%01100000,%00111000,%00011000,%00000000
FontData1:
.byte %00000000,%00011000,%00101000,%11111110,%01010000,%00001100,%00111000,%00010000,%01100000,%00001100,%00011000,%00011000,%00000000,%00000000,%00000000,%00000110,%01101110,%00011000,%00000110,%00000110,%01101100,%01100000,%01100000,%00000110,%01100110,%01100110,%00011000,%00110000,%00011000,%00111100,%00011000,%11000110,%11001100,%11000110,%01100110,%11000000,%01100110,%11000000,%11000000,%11000000,%11000110,%00011000,%00000110,%11011100,%11000000,%11011110,%11110110,%11000110,%11000110,%11001100,%11000110,%11000000,%00011000,%11000110,%11101110,%11000110,%11101110,%11000110,%00000110,%00110000,%01100000,%00011000,%00111100,%00000000
FontData2:
.byte %00000000,%00011000,%00000000,%01101100,%01111000,%01111100,%01111010,%00000000,%01100000,%00001100,%00100100,%01111110,%00000000,%01111110,%00000000,%01111110,%01100110,%00011000,%00111110,%00111110,%01111110,%01111110,%01111110,%00011110,%01111110,%01111110,%00000000,%00000000,%00110000,%00000000,%00001100,%00011110,%11011100,%11111110,%01111110,%11000000,%01100110,%11111110,%11111000,%11001110,%11111110,%00011000,%00000110,%11111000,%11000000,%11011110,%11111110,%11000110,%11111110,%11011100,%11111110,%11111110,%00011000,%11000110,%01111100,%11011110,%01111100,%11111110,%11111110,%00110000,%01111110,%00011000,%00000000,%00000000
FontData3:
.byte %00000000,%00000000,%00000000,%11111110,%00010100,%01100000,%01111100,%00000000,%01100000,%00001100,%00000000,%00011000,%00011000,%00000000,%00011000,%01100000,%01110110,%00011000,%11000000,%00000110,%00001100,%00000110,%01100110,%00000110,%01100110,%00000110,%00011000,%00110000,%00011000,%00111100,%00011000,%00000000,%11000000,%11000110,%01100110,%11000000,%01100110,%11000000,%11000000,%11000110,%11000110,%00011000,%11000110,%11011100,%11000000,%11011110,%11011110,%11000110,%11000000,%11011110,%11011000,%00000110,%00011000,%11000110,%00111000,%11011110,%11101110,%00000110,%11000000,%00110000,%00000110,%00011000,%00000000,%00000000
FontData4:
.byte %00000000,%00011000,%00000000,%01101100,%01111100,%01101100,%01111010,%00000000,%00011000,%00011000,%00000000,%00011000,%00010000,%00000000,%00000000,%01100000,%01111110,%01111110,%11111110,%01111110,%00001100,%11111000,%01111110,%00000110,%01111110,%01111110,%00000000,%00010000,%00001100,%00000000,%00110000,%00011000,%11111110,%11000110,%11111110,%11111110,%11111110,%11111110,%11000000,%11111110,%11000110,%11111110,%11111110,%11001110,%11111110,%11000110,%11001110,%11111110,%11000000,%11111110,%11011110,%11111110,%00011000,%11111110,%00010000,%11111110,%11000110,%11111110,%11111110,%00111000,%00000110,%00111000,%00000000,%01111110

StringDta: 
.byte "HELLO,WORLD!" ; 1
.byte "FROM 6502   " ; 2
.byte "------------" ; 3
.byte "THIS CAN    " ; 4
.byte "DISPLAY     " ; 5
.byte "LOTS OF     " ; 6
.byte "TEXT!       " ; 7
.byte "            " ; 8
.byte "------------" ; 9

.SEGMENT "VECTORS"
.word Start	; reset vector
.word Start	; BRK vector

	; this text display should display 10 scanlines of text lines, each text line is rendered in pair of lines (thus the line loop is 5 ticks)
	; there's 11 scanlines of gap between text lines
	; allowing for a max of 9 text lines -> 189 lines
	; 2 lines are spent aligning sprites, 1 scanline is free which is waited out at the end

	; [    FETCH     ]
	;   0123456789AB    -   line 1
	; [    FETCH     ]
	;   0123456789AB    -   line 2
	; [    FETCH     ]
	;   0123456789AB    -   line 3
	; [    FETCH     ]
	;   0123456789AB    -   line 4
	; [    FETCH     ]
	;   0123456789AB    -   line 5
	; [    FETCH     ]
	;   0123456789AB    -   line 6
	; [    FETCH     ]
	;   0123456789AB    -   line 7
	; [    FETCH     ]
	;   0123456789AB    -   line 8
	; [    FETCH     ]
	;   0123456789AB    -   line 9

; notes:
; there are only 76 machine cycles per scanline

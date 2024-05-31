; ///////////////////////////////////////////////////////////////////////////////////////////// 

; ASCII text display for Fairchild Channel F by jvsTSX (2024)
; supports entire 96-char ASCII range! lower, upper and all symbols!
; chars are 4 pixels wide and 5 pixels tall, with an extra pixel border

; - from the Hello World Everything project at https://github.com/jvsTSX/hello-world-everything -

; >>>>>>>> thanks to <<<<<<<<<
; Lidnariq (on Discord) for walking me trough the hardware and clearing my doubts on pixel plots, timings, etc

; >>>>>> tools required <<<<<<
; DASM assembler       -  https://github.com/dasm-assembler/dasm
; MESS/MAME emulator   -  https://github.com/mamedev/mame
; a command line to run the programs above
; a text editor or viewer like this one

; it doesn't use any BIOS calls! but you need to provide MESS/MAME with the two BIOS files in order for the system to boot

; ///////////////////////////////////////////////////////////////////////////////////////////// 

	processor F8
	org $800
	.byte $55, $2B ; cartridge header


; first, a few thoughts:
; skip blank pixels (plot time is really important here)
; looped to conserve the pretty small ROM space this thing can address (cartrige area is only 2Kbytes)
; font data packed since this thing is excellent at nybble stuff (slices size down to 240 bytes)
; with this text size the (safe zone) ChF screen should be able to display up to 19 chars in the X axis and around 9 in the Y axis, tottalling up to 171 chars

Start:
	clr     ; clear ports from any possible initial garbage state
	outs 1
	outs 4
	outs 5
	outs 0

; /////////////////////////////////// Initialize Screen /////////////////////////////////////// 
	lis %1100
	sl 4    ; color
	lr 1, a
	li 63   ; yloop
	lr 3, a

InitScr:
	lr a, 1        ; set desired color
	outs 1
InitScrLoop:
	li 102
	lr 2, a        ; xloop

	lr a, 3        ; load Ypos
	outs 5

	; for my sanity's sake, i will only not invert Y axis
InitScr_InitXLoop: ; sweep X from right to left
	lr a, 2
	com
	outs 4
  pi ReqPixelWrite
	ds 2
  bnz InitScr_InitXLoop

	ds 3           ; advance Y and loop countdown
	lr a, 3
	inc            ; to make sure line 0 is wiped, +1 the register

	; since Y is non-inverted it will march from bottom to top
  bnz InitScrLoop



; /////////////////////////////////// Initialize Palettes ///////////////////////////////////// 
	li 58         ; amount of SC palettes to set
	lr 0, a
	lis %1000     ; palette (0 = green, 4 = grey, 8 = blue, C = b/w)
	sl 4
	lr 1, a 
	lis 4         ; starting scanline
	lr 2, a
InitPal:
	lr a, 2       ; set y coord
	com
	ni %00111111  ; prevent beeps
	outs 5

	li $82        ; 125 inverted
	outs 4
	lr a, 1
	ni %01000000  ; if bit is 0, the xor equals zero, if the bit is 1, 01x10 results 11
	lr 3, a
	sl 1
	xs 3
	outs 1
  pi ReqPixelWrite

	li $81         ; 126 inverted
	outs 4
	lr a, 1
	ni %10000000
	lr 3, a
	sr 1
	xs 3
	outs 1
  pi ReqPixelWrite

	lr a, 2
	inc
	lr 2, a
	ds 0
  bnz InitPal



; /////////////////////////////////// Draw Text Routine /////////////////////////////////////// 
; text function specs
; color               =  r1 (%cc------)
; X start pos         =  r2
; Y start pos         =  r3
; current ASCII char  =  r4
; r5 and r6 are loop counters
; r7 is current char slice being processed

; //////////////////////////////// start
	lis %1000 ; color
	sl 4
	lr 1, a
	lis 7
	lr 2, a   ; xpos
	lis 6
	lr 3, a   ; ypos
	dci StringData

PrintText: ; /////////////////////////////////// outter loop - get chars and march trough the text data
	lm
	lr 0, a
	ns 0       ; is it a null char?
  bz LockLoop  ; if yes exit
	ci 10      ; is it a newline?
  bnz ContinueLine
	
	; new line
	lis 7      ; reset Xpos
	lr 2, a
	lr a, 3    ; offset Y down by 6 pixels
	ai 6
	lr 3, a
  br PrintText ; since this is a non-printable char, fetch next

ContinueLine:  ; else proceed and draw the char
	lr 4, a
	xdc        ; swap to secondary datacounter reg


; /////////////////////////////////// Draw Char Routine /////////////////////////////////////// 
DrawChar:
	lis 5           ; set Y loop count
	lr 5, a
	
	dci FontData-80 ; offset by: (32 non printable chars * 5) / 2
	lr a, 4         ; then do a weird multiply by 5
	sr 1            ; get rid of LSB and divide by 2
	adc
	sl 1            ; reverse the div by 2 but now without the LSB
	adc
	adc

DrawCharLoop: ; ///////////////////////////////// inner loop - march trough the 5 char strips and separate odd/even nybbles
	lr a, 3       ; get and set ypos
	com
	ni %00111111  ; prevent beeps
	outs 5

	lis 4         ; set X loop count
	lr 6, a
	lm            ; get char strip from DC pointer
	lr 7, a
	lr a, 4       ; check char parity
	ni %00000001
	lr a, 7
  bnz DrawChar_NoShift
	sr 4          ; if even, shift to the LSB area
	lr 7, a
DrawChar_NoShift: ; if odd, it's already on LSB and shifting is not needed


DrawChar_DrawThisLine: ; //////////////////////// innermost loop - draw a text slice into the screen

	; shift every bit and see which are opaque/clear
	ni %00001000
  bz DrawChar_NoPixel
	
	; if opaque - plot pixel
	lr a, 2       ; xpos
	com
	outs 4

	lr a, 1
	outs 1        ; color select

	lis 6
	sl 4
	outs 0        ; pulse VRAM write to signal a pending write
	sl 1
	outs 0        ; set it back to zero

	lis 6
WaitScEnd:        ; loop to make sure a scanline passes and next pixel is ready
	ai $FF
  bnz WaitScEnd

DrawChar_NoPixel: ; if clear - no drawing needed

	lr a, 2       ; advance Xpos by 1
	inc
	lr 2, a
	lr a, 7       ; shift out MSB
	sl 1
	lr 7, a

	ds 6
  bnz DrawChar_DrawThisLine ; /////////////////// innermost loop end

	lr a, 2
	ai $FC   ; sub 4 from X pos to return it back to the original position
	lr 2, a
	lr a, 3  ; advance Ypos by 1
	inc
	lr 3, a

	ds 5
  bnz DrawCharLoop ; //////////////////////////// inner loop end

	lr a, 3  ; sub 5 from Ypos to return it to the original height
	ai $FB
	lr 3, a
	lr a, 2  ; advance to next char cell
	ai $5
	lr 2, a

	xdc      ; swap pointers back to text pointer
  br PrintText ; //////////////////////////////// outter loop end




; ///////////////////////////////////////////////////////////////////////////////////////////// 
; all done! the screen will remember the last pixels plotted
; no need to do anything else so the CPU will be looping forever now

LockLoop:
  br LockLoop
; ///////////////////////////////////////////////////////////////////////////////////////////// 




ReqPixelWrite:
	lis 6
	sl 4
	outs 0 ; pulse to signal a pending VRAM write
	sl 1
	outs 0 ; return the bit back to 0
	
	lis 6  ; wait untill a scanline passes
ReqPixel_Wait:
	ai $FF
  bnz ReqPixel_Wait
  pop




; /////////////////////////////////////// Text Data /////////////////////////////////////////// 

StringData:
;          0         1
;          0123456789012345678
	.byte "Hello, World!"      , 10
	.byte "From Fairchild F8"  , 10
	.byte "-------------------", 10
	.byte "The quick brown fox", 10
	.byte "jumps over the lazy", 10
	.byte "dog"                , 10
	.byte                        10
	.byte "0123456789!?@#$%*+~", 10
	.byte "-------------------", 0

; 10 is newline, 0 is null terminator
; separate string and byte with comma (,)
; just replacing text on this should work

FontData:
	.byte %00000100 ; <spc> !
	.byte %00000100
	.byte %00000100
	.byte %00000000
	.byte %00000100
	
	.byte %10100101 ; " #
	.byte %10101111
	.byte %00000101
	.byte %00001111
	.byte %00000101
	
	.byte %00101010 ; $ %
	.byte %01110010
	.byte %11100100
	.byte %00111000
	.byte %11101001
	
	.byte %01000010 ; & ´
	.byte %10100100
	.byte %11110000
	.byte %10010000
	.byte %11110000
	
	.byte %00100100 ; ( )
	.byte %01000010
	.byte %01000010
	.byte %01000010
	.byte %00100100
	
	.byte %01000000 ; * +
	.byte %11100100
	.byte %01001110
	.byte %10100100
	.byte %00000000
	
	.byte %00000000 ; , -
	.byte %00000000
	.byte %00001111
	.byte %11000000
	.byte %01000000
	
	.byte %00000000 ; . /
	.byte %00000001
	.byte %00000010
	.byte %00000100
	.byte %01001000
	
	.byte %11110010 ; 0 1
	.byte %10110110
	.byte %10010010
	.byte %11010010
	.byte %11111111
	
	.byte %11101110 ; 2 3
	.byte %00010001
	.byte %01100110
	.byte %10000001
	.byte %11111110
	
	.byte %01011111 ; 4 5
	.byte %10011000
	.byte %11111110
	.byte %00010001
	.byte %00011110
	
	.byte %01111111 ; 6 7
	.byte %10000001
	.byte %11110010
	.byte %10010100
	.byte %11101000
	
	.byte %01110111 ; 8 9
	.byte %10011001
	.byte %11111111
	.byte %10010001
	.byte %11101110
	
	.byte %00000000 ; : ;
	.byte %01000100
	.byte %00000000
	.byte %01001100
	.byte %00000100
	
	.byte %00010000 ; < =
	.byte %00101111
	.byte %01000000
	.byte %00101111
	.byte %00010000
	
	.byte %10001111 ; > ?
	.byte %01000001
	.byte %00100111
	.byte %01000000
	.byte %10000100
	
	.byte %01101111 ; @ A
	.byte %10001001
	.byte %10111111
	.byte %10111001
	.byte %01111001
	
	.byte %11111111 ; B C
	.byte %01011000
	.byte %01111000
	.byte %01011000
	.byte %11111111
	
	.byte %11111111 ; D E
	.byte %01011000
	.byte %01011110
	.byte %01011000
	.byte %11111111
	
	.byte %11111111 ; F G
	.byte %10001000
	.byte %11101011
	.byte %10001001
	.byte %10001111
	
	.byte %10011111 ; H I
	.byte %10010010
	.byte %11110010
	.byte %10010010
	.byte %10011111
	
	.byte %00011011 ; J K
	.byte %00011010
	.byte %00011111
	.byte %10011001
	.byte %11111001
	
	.byte %10001111 ; L M
	.byte %10001011
	.byte %10001011
	.byte %10001001
	.byte %11111001
	
	.byte %10011111 ; N O
	.byte %11011001
	.byte %10111001
	.byte %10011001
	.byte %10011111
	
	.byte %11111111 ; P Q
	.byte %10011001
	.byte %11111011
	.byte %10001011
	.byte %10001111
	
	.byte %11111111 ; R S
	.byte %10011000
	.byte %11111111
	.byte %10100001
	.byte %10111111
	
	.byte %11111001 ; T U
	.byte %00101001
	.byte %00101001
	.byte %00101001
	.byte %00101111
	
	.byte %10011001 ; V W
	.byte %10011001
	.byte %10011011
	.byte %10101011
	.byte %11001111
	
	.byte %10011001 ; X Y
	.byte %10101001
	.byte %01101111
	.byte %01010001
	.byte %10011111

	.byte %11110110 ; Z [
	.byte %00010100
	.byte %00100100
	.byte %01000100
	.byte %11110110
	
	.byte %00000110 ; \ ]
	.byte %10000010
	.byte %01000010
	.byte %00100010
	.byte %00010110
	
	.byte %01100000 ; ^ _
	.byte %10010000
	.byte %00001111
	.byte %00000000
	.byte %00000000
	
	.byte %01000000 ; ` a
	.byte %00100110
	.byte %00000001
	.byte %00001111
	.byte %00001111
	
	.byte %10000000 ; b c
	.byte %10000111
	.byte %11101000
	.byte %10011000
	.byte %11100111
	
	.byte %00010000 ; d e
	.byte %00010111
	.byte %01111111
	.byte %10011000
	.byte %01110111
	
	.byte %00100001 ; f g
	.byte %01001111
	.byte %11101111
	.byte %01000001
	.byte %01001111
	
	.byte %10000010 ; h i
	.byte %10000000
	.byte %11100111
	.byte %10010010
	.byte %10011111
	
	.byte %00011000 ; j k
	.byte %00001000
	.byte %00111011
	.byte %10011100
	.byte %01111011
	
	.byte %01000000 ; l m
	.byte %01001110
	.byte %01001111
	.byte %01001011
	.byte %00101001
	
	.byte %00000000 ; n o
	.byte %11100110
	.byte %10011001
	.byte %10011001
	.byte %10010110
	
	.byte %00000000 ; p q
	.byte %11100111
	.byte %10011001
	.byte %11100111
	.byte %10000001
	
	.byte %00000000 ; r s
	.byte %11100111
	.byte %10011100
	.byte %10000011
	.byte %10001110
	
	.byte %01000000 ; t u
	.byte %11111001
	.byte %01001001
	.byte %01001001
	.byte %00100111
	
	.byte %00000000 ; v w
	.byte %10011001
	.byte %10011011
	.byte %10101111
	.byte %01001100
	
	.byte %00000000 ; x y
	.byte %10011001
	.byte %01101111
	.byte %01100001
	.byte %10011111
	
	.byte %00000001 ; z {
	.byte %11110010
	.byte %00101110
	.byte %01000010
	.byte %11110001
	
	.byte %00101000 ; | }
	.byte %00100100
	.byte %00000111
	.byte %00100100
	.byte %00101000
	
	.byte %00000000 ; ~ 
	.byte %01010000
	.byte %10100000
	.byte %00000000
	.byte %00000000
	

	org $FF0 ; signature
	.byte "jvsTSX - 2024   "
	;      0123456789ABCDEF
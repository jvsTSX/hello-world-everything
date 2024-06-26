# Fairchild Channel F

- build it with this command on a CLI
```
dasm hwd.asm -f3 -ohwd.bin
```

# System Summary
Since this machine don't have a lot of information readily available, i will provide some worth mentioning here

## VIDEO
The video of the Channel F consists of a 128 wide by 64 tall 2-bit-per-pixel bitmap, the bitmap is write-only and can only be written in a per-pixel basis using the ports, and each pixel write will only take effect everytime a scanline passes

- Port 0 bit 5 will signal a write to VRAM, reading from this port gives you console's switches and buttons
- Port 1 bits 6 and 7 are the pixel's color, reading from this port gives you the Right player controls
- Port 4 is the pixel X coord, reading from this port gives you the Left player controls
- Port 5 is the pixel Y coord and sound tone select

However not the entire bitmap is visible on your television, part of it is cut out by the borders of the tube and front panel, and some are not rendered at all! An area of around 98 pixels wide and 58 pixels tall, starting at 7 pixels from the left border and 4 pixels from the top border should be visible on all sets

As for the pixels that are not rendered, pixels 125 and 126 of the bitmap defines the palette of the entire row of those pixels' Y position, palettes will choose black/white mode or change the BKG color
|126|125|color 00|color 01|color 10|color 11 (BKG)|
|-|-|-|-|-|-|
|0|0|green|red|blue|light green|
|0|1|green|red|blue|light grey|
|1|0|green|red|blue|light blue|
|1|1|white|white|white|black|

Note that palettes have a latency of 1 scanline untill they take effect, the pixels are 4 scanlines tall on an NTSC machine or 5 scanlines tall on a PAL machine so changing between B/W and color palettes will result in a tiny sub-pixel gap between pixel rows


## SOUND
Controlled by the top two bits of port 5, a very crude 3-tone beeper

|Tone BN|Tone AN|approx frequency|
|-|-|-|
|0|0|sound off|
|0|1|1000 Hz (B-5)|
|1|0|500 Hz (B-4)|
|1|1|125 Hz (B-2)|


## CPU
Fairchild F8, two-chip 8-bit CPU (clocked at 1.7MHz)

It's overall a very strange harvard architecture thing with a weird cycle system of 4-clock cycles and 6-clock cycles (long and short cycles, respectively)

You can find more detailed info about the F8 opcodes, timing and ROMC modes at this wiki's page https://channelf.se/veswiki/index.php?title=Opcode

But here's a quick summary of that i wrote while making this thing

- Flags are arranged as OZCS (Overflow Zero Carry Sign)
- Cycle notation: 2 clocks = 1 machine cycle so a short cycle is 2 machine cycles and a long cycle is 3 machine cycles
- Note that PI and JMP will destroy the accumulator's previous contents
- For conditional branches, the first number is for when the branch is not taken

|mnemonic|bytes|cycles|flags|action|
|-|-|-|-|-|
|LR A, rN / LR rN, A|1|2||load between accumulator and register N|
|LR A, pN / LR pN, A|1|2||load between accumulator and reg pair halves N|
|LR A, IS / LR IS, A|1|2||load RAM byte pointed by ISAR register|
|LISL #3 / LISU #3|1|2||load ISAR register's halves with a 3-bit constant|
|CLR|1|2||set A to 0|
|LR J, W / LR W, J|1|4||load between status flag register and J register|
|LI #8|2|5||load an 8-bit constant into the accumulator|
|LIS #4|1|2||load a 4-bit constant into the accumulator|
|LM / ST|1|5||load/store into the main memory byte pointed by the DC0 register and then increment it|
||||||
|LR K, P / LR P, K|1|8||load between K register pair and PC return address register|
|LR Q, DC / LR DC, Q|1|8||load between DC0 and Q register pairs|
|LR H, DC / LR DC, H|1|8||load between DC0 and H register pairs|
|DCI #16|3|4||load 16-bit constant into DC0|
|XDC|1|8||change between DC1 and DC0 pointers|
|LR P0, Q|1|8||jump to the contents of the Q register pair|
||||||
|INS 0/1|1|4|0X0X|load A from port 0 or 1|
|INS 4/5|1|8|0X0X|load A from port 4 or 5, these ports are slower to communicate due to being on another chip|
|IN #8|2|8|0X0X|load A from ports 0-255|
|OUTS 0/1|1|4||store A into ports 0 or 1|
|OUTS 4/5|1|4||store A into ports 4 or 5, these ports are slower to communicate due to being on another chip|
|OUT #8|2|8||store A into ports 0-255|
||||||
||||||
|AS rN|1|2|XXXX|A + rN|
|AM|1|5|XXXX|A + byte pointed by DC0|
|AI #8|2|5|XXXX|A + 8-bit constant|
|ASD rN|1|4|XXXX|A + rN with decimal adjust|
|AMD|1|5|XXXX|A + byte pointed by DC0 with decimal adjust|
|ADC|1|5||add Accumulator into DC0|
|NS rN|1|2|0X0X|AND A with register N|
|NM|1|5|0X0X|AND A with byte pointed by DC0|
|NI #8|2|5|0X0X|AND A with 8-bit constant|
|XS rN|1|2|0X0X|XOR A with register N|
|XM|1|5|0X0X|XOR A with byte pointed by DC0|
|XI #8|2|5|0X0X|XOR A with 8-bit constant|
|OM|1|5|0X0X|regular OR A with byte pointed by DC0|
|OI #8|2|5|0X0X|regular OR A with 8-bit constant|
|CM|1|5|XXXX|byte pointed by DC0 subtracted with A|
|CI #8|2|5|XXXX|8-bit constant subtracted with A|
|INC|1|2|XXXX|INCrement Accumulator|
|DS rN|1|3|XXXX|decrement register N|
|LNK|1|2|XXXX|increment Accumulator if Carry flag is set|
|COM|1|2|0X0X|COMplement Accumulator, basically a XOR with $FF|
|SL 1/4|1|2|0X0X|shift A Left, once or four times, new bits inserted are "0"|
|SR 1/4|1|2|0X01|shift A Right, once or four times, new bits inserted are "0"|
||||||
||||||
|NOP|1|2||no operation|
|EI/DI|1|2||enable/disable interrupts, however the Channel F doesn't have any|
||||||
||||||
|JMP #16|3|11||jump to 16-bit address and destroys A|
|BR #8|2|7||branch always|
|BC #8|2|6/7||branch on Carry set|
|BNC #8|2|6/7||branch on Carry clear|
|BP #8|2|6/7||branch on last operation resulting in a positive result (PLUS)|
|BM #8|2|6/7||branch on last operation resulting in a negative result (MINUS)|
|BZ #8|2|6/7||branch on Zero flag set|
|BNZ #8|2|6/7||branch on Zero flag clear|
|BNO #8|2|6/7||branch on Overflow flag clear|
|BT #3 #8|2|6/7||branch if all the set bits on the 3-bit bitmask are True|
|BF #3 #8|2|6/7||branch if all the set bits on the 3-bit bitmask are False|
|BR7 #8|2|4/5||branch if ISAR's lower half is not 7|
|PK|1|5||call address stored on register pair K|
|PI #16|3|13||call 16-bit address and destroys A|
|POP|1|4||return to last value stored on the return address register|

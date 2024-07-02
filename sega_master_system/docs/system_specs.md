# Sega Master System / Mark III hardware summary
## Main specs
- **CPU**: Z80 at 3.5MHz (exec rate of ~1MHz)
- **Video**: modified TMS9918 'VDP' with a special "Mode 4" setup and 6-bit RGB output
- **Sound**: modified SN76489 'DSCG' embedded with the VDP chip, same as the actual TI variant but the noise LFSR is 16-bit
- **Memory**: 8KB of CPU RAM, 16KB of Video RAM, holding tiles, tile maps and the sprite list
- **Backwards Compatibility**: SEGA SG-1000

## Description
The main console always consists of the CPU, VDP, DCSG, RAM, two controller ports, and one cartridge slot, with some versions incorporating a built-in BIOS that can even contain an entire game and an internal mapper for mapping the BIOS in and out of view. the japanese SMS and early export models also come with a card ROM slot and expansion port which are too managed by this internal mapper, the BIOS checks for each and boots whichever one it finds first. The japanese Master System also contains an internal OPLL/YM2413 sound chip, which for the Mark III was an expansion port add-on only (and could only output either DCSG or FM sound at once in contrast to SMS JP).

## Memory maps and registers
### Main Memory Map
|Address Range (hex)|Area|
|-|-|
|0000-BFFF|Cartridge Memory|
|C000-DFFF|Work RAM|
|EFFF-FFFF|Work RAM mirror|

## Z80 Interrupts
The Z80's NMI line is tied to the expansion port if present and the pause button on the console, pressing it will generate (pulse) one NMI, while the IRQ line is connected to the VDP and can be configured to fire at every V-Blank or every X scanlines.

Interrupt modes:
- Mode 0: Causes a random instruction byte to be executed on SMS1 (and very likely crashing your code in the process), SMS2 will always read an RST $38 instruction.
- Mode 1: The default mode the BIOS sets you with, if present. IRQ vector maps to $0038 and NMI at $0066.
- Mode 2: This mode uses I register's value as a high address byte and a bus value as a low address byte, this address looks up for a vector address in a vector table and jumps to it, so it requires a 257 bytes table all containing the same value due to SMS1's random open bus behaviour in order to be reliably used. SMS2 will always return $FF, thus referencing the 255th entry on the table and the byte after.


## Z80 I/O MAP
|Address Range (hex)|Writes To Register(s)|Reads From|
|-|-|-|
|00-3F|Even: Memory Control, Odd: I/O Control|Open bus|
|40-7F|Sound Generator Data Port|Even: V Counter, Odd: H Counter|
|80-BF|Even: VDP Data, Odd: VDP Control|Even:VDP Data, Odd:VDP Status|
|C0-FF|Nothing|Even: Port A/B, Odd: Port B/Misc|

The very last values are the most commonly used, so for the VDP registers you should write to $BE and $BF, the DCSG port as $7F, the Memory Control as $3F and so on, with the I/O Port ones being an exception.

The FM sound chip is controlled trough I/O ports $F0 to write to the registers, $F1 to select a register and $F2 to detect if it's present (becomes R/W if present), since this range maps to the I/O controller it should be disabled by register $3F first.


Memory map differencies:
The Main Memory Map stays the same, however the I/O Map differs in the following ways:
- **SMS2**: Reading open bus returns a predictable $FF value.
- **Game Gear**: Specific registers at the range $00 ~ $06 and only 4 registers correspond to Ports in the $C0 ~ $FF range, $C0 and $DC for Port A/B and $C1 and $DD for Port B/Misc.
- **Mega Drive**: The same as SMS2 but the $C0 ~ $FF range behave as shown on Game Gear.

## I/O Register descriptions
- VDP ports and Sound Generator ports are all complete 8-bits and behave quite differently from one another, for further info check their respective documentation files in this folder.
- Memory Control (write): 

|Bit|Function|
|-|-|
|7|Expansion slot disable|
|6|Cartridge slot disable|
|5|Card slot disable|
|4|Work RAM disable|
|3|BIOS disable|
|2|I/O chip disable|
|1|No effect|
|0|No effect|

Writing a "0" to either of the bits will enable their function while a "1" will disable.

Disabling the I/O chip will cause the $C0~$FF range to return expansion port information instead of controller/misc port

- I/O Control (write):

|Bit|Function|
|-|-|
|7|Port B TH Pin|
|6|Port B TR Pin|
|5|Port A TH Pin|
|4|Port A TR Pin|
|3|Port B TH Direction|
|2|Port B TR Direction|
|1|Port A TH Direction|
|0|Port A TR Direction|

Bits 7~4 sets the literal pin output value, bits 3~0 defines if the pins function as output (reset to "0") or input (set to "1")

- Port A/B (read): reads all Player 1 buttons and some Player 2 buttons

|Bit|Function|
|-|-|
|7|Controller B Down button|
|6|Controller B Up button|
|5|Controller A TR button|
|4|Controller A TL button|
|3|Controller A Right button|
|2|Controller A Left button|
|1|Controller A Down button|
|0|Controller A Up button|

- Port B/Misc (read):

|Bit|Function|
|-|-|
|7|Port B TH pin|
|6|Port A TH pin|
|5|Unused|
|4|Reset button if present|
|3|Port B TR button|
|2|Port B TL button|
|1|Port B Right button|
|0|Port B Left button|

Controller buttons are active low, therefore 0 is pressed and 1 is released.

## Links
[Techno-Junk SMS Tech Document](http://www.techno-junk.org/txt/smstech.txt)
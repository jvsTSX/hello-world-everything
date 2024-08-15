# Compatibility precautions

## Physical Cartridge Slot
To avoid different region programs for being inserted on different region units, the Cartridge ports are all slightly different from each other, Mark III and JP SMS use the same shape as SG-1000 cartridge, Export SMS use their own shape and Game Gear uses an entirely different shape to avoid SMS software from being inserted.

## VDP
The VDP is a very troublesome component in this aspect, the differences between SMS1, SMS2, GG and Mega Drive should be covered on the VDP documentation in this folder, in short, prefer **non-zoomed sprites**, **192-lines tall mode only**, and **always keep the mask bits set to "1"**. You can detect which is which by using the sprite zoom and size flags and checking for intersection trough the VDP Flags register.

## BIOSes
Early on with the Mark III units in Japan, those lack a boot ROM and will immediately start running your program as the first thing when you power the console on, later the japanese Master System (not to be confused with western models under the same name) comes with a built-in 4KB boot ROM that will initialize a few things for you and display a bumper screen (a very fancy one at that!) if it doesn't see a cartridge inserted, and your software still starts without any additional checks. The Korean model "Samsung Gam Boy" does the same checking methods, only looking for open bus patterns instead of searching for the ROM header.

However the European and North American Master System models you may be familiar with, contains a boot ROM that will check for a small 8-byte header in your cartridge in 3 different locations: $1FF0, $3FF0 and $7FF0.

The header's contents consist of:
```
"TMR SEGA" ee ee CC CC pp pp pv RS
|          |     |     |      | ||
|          |     |     |      | |rom Size
|          |     |     |      | Region code
|          |     |     |      product Version
|          |     |     Product code
|          |     Checksum (stored little endian)
|          Empty / unused
Lockout string

UPPERCASE = important

```

- 8 bytes forming the string "TMR SEGA" in ASCII, the console will lock up if this is missing
- 2 unused bytes, usually '0'
- 2 checksum bytes, in little endian order, the console will lock up if this is incorrect
- 2 bytes in binary-decimal and 1 nybble (high) containing the product code, in little endian order and the nybble being in hex
- 1 nybble (low) containing the version of the ROM
- 1 nybble (high) containing the region code of the game, the console will lock up if this is incorrect
- 1 nybble (low) containing the cartridge ROM's size

### Region Codes
|value (hex)|region|
|-|-|
|3|Japan|
|4|Export (Euro/USA)|
|5|Game Gear Japan|
|6|Game Gear Export|
|7|Game Gear International|

### ROM Sizes
|value (hex)|size in KB|
|-|-|
|A|8|
|B|16|
|C|32|
|D|48*|
|E|64|
|F|128|
|0|256|
|1|512|
|2|1024*|

\* = buggy in some boot ROM versions, **do not use**!

### Notes
- You can safely lie to the boot ROM with a value of 8K for faster boot times, this should not affect your game even if it's way larger in size. The patcher tool in this repo assumes a checksum size of 8K.
- SEGA's early Game Gear consoles lack a BIOS entirely
- Majesco Game Gear will only look for the TMR SEGA string, checksum not needed for these units at least

### Links
- [ROM Header Format](https://www.smspower.org/Development/ROMHeader)
- [SMS Power! BIOS Page](https://www.smspower.org/Development/BIOS)
- [List of BIOSes/Boot ROMs](https://www.smspower.org/Development/BIOSes)
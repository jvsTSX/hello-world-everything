# SEGA Video Display Processor

### Please Note
This is specifically targetting the features present on the SMS1 and SMS2 VDPs, some differencies will be noted but Game Gear and Genesis/MD VDP specific features will be separately documented, there is a differences section down below for compatibility notes between VDPs.

### Contents

```
1. Overview
2. General Controls
  2a. Interfacing and I/O Ports
  2b. Reading VDP Control Port and VDP Status Word
  2c. Extended Height modes (SMS2 ONLY)
  2d. Illegal Text Mode
  2e. Timings
3. Timings
  3a. Active Scanline
  3b. V-Blank
  3c. CRAM Dots
4. Tiles and Background
  4a. Tile Format
  4b. Background
  4c. Scrolling
5. Sprite Subsystem
  5a. Sprite Specs
  5b. Sprite Evaluation
  5c. SAT format
6. VDP Internal Registers
  6a. $0: Mode Control 1
  6b. $1: Mode Control 2
  6c. $2: Nametable Base Address
  6d. $3: Color Table Base Address
  6e. $4: Pattern Generator Table Base Address
  6f. $5: SAT Base Address
  6g. $6: Sprite Pattern Generator Base Address
  6h. $7: Backdrop Color
  6i. $8: X Scroll Offset
  6j. $9: Y Scroll Offset
  6k. $A: Scanline Counter
7. VDP Compatibility Notes
  7a. Game Gear
  7b. MD/Genesis
  7c. In Short
8. Links
```

### Terminology
Some terms may seem unfamiliar to some different platform developers since each brand tend to go with their own names, but for clarity purposes these are the terms you will see in this document:
- **Patterns**: 8x8 or 8x6 tiles, other systems simply refer to them as "tiles", if you come from the Intellivision side you may know of them as "cards".
- **Nametable**: This term is also present on the NES scene, but other platforms may call it as a "tilemap", the nametable is the background grid that holds the indices or "names" of the patterns or tiles.
- **Sprite Attribute Table (SAT)**: The list responsible for storing the information about the Sprites or "Objects", on Nintendo console scenes this may be referred to as "Object Attribute Memory (OAM)", with sprites also being called "objects".

# 1. Overview
Shortened to VDP, this is a custom chip by SEGA responsible for generating the video output of the Master System, which extends the Texas Instruments TMS9918 used in the SG-1000. Just like the TMS, you comunicate with this chip trough two of the Z80 I/O ports.

All modes and features from the TMS9918 VDP are present, which should be documented separately in this repo's common chips folder, what SEGA did to improve and maintain compatibility with the TMS was keeping everything mostly as-is and instead adding a new video mode, the mode 4, which features:
- 8x8 pixel tile-based display with a 32x28 tile map, Similar to the 'Graphics' modes.
- Tiles for both background and sprites are now 4-bit per pixel instead of 1, no longer requiring the color tables.
- Two configurable palettes of 16 colors each, contrasting with the TMS9918 which has only one hard-coded palette.
- Tile map capable of addressing up to 512 tiles, applying X and Y flipping, palette 1 or 2, and sprite overlap priority per individual tile entry.
- X and Y scrolling capabilities for shifting the tile map around the screen, to assist with this feature there are also the following:
  - Ability to hide the leftmost tile column to hide artifacts introduced as a side effect of X-scrolling.
  - Vertical and horizontal scroll lock features for implementing status bars on limited scrolling games. More detail further down this document.
- Programmable scanline counter interrupt for raster tricks.
- Selectable backdrop color for overscan/border areas.
- Sprites reduced to only 8x8 and 8x16 in size, but there can be up to eight sprites per scanline now, instead of only four.
- SAT increased to 64 sprites instead of 32 as seen in the legacy TMS modes.



# 2. General Controls
This section covers communication between VDP and Z80 and global controls, for tilemap and sprite-specific controls refer to their specific sections.

### Interfacing and I/O Ports
Returning to the Z80 I/O ports mentioned previously, they are responsible to let the CPU communicate to the 16KB of VRAM, 32-entry Color RAM (CRAM) and the internal VDP registers, these ports are, respectively:
- **VDP Control**: Sets the VDP's internal 14-bit pointer or lets you update the internal VDP registers using 2-byte commands, reading from this register gives you the VDP's status word.
- **VDP Data**: Uses the 14-bit pointer set by VDP Control to read or write into VRAM or write to Color RAM, either reading or writing to this register will increment the VDP pointer.

There are four commands you can send into the VDP Control register, the first byte is an 8-bit data byte or low pointer address and the second contains the high address and command ID on the two most significant bits:
```
Second Byte   First Byte   |
%00HHHHHH     %LLLLLLLL    |    "VRAM Read"
%01HHHHHH     %LLLLLLLL    |    "VRAM Write"
%10--RRRR     %DDDDDDDD    |    "Register Write"
%11HHHHHH     %LLLLLLLL    |    "CRAM Write"
```

**H** and **L** forms the High and Low halves of a 14-bit address that will be written into the VDP pointer, **R** is a register number and **D** is the value that will be written into the selected register.

Each command does the following:
- **VRAM Read**: Sets the pointer and pre-reads a VRAM byte into the VDP Data port. This will pre-increment the VDP Pointer by 1.
- **VRAM Write**: Sets the pointer only.
- **Register Write**: Directly write a value into an internal VDP register. Pointer is not affected.
- **CRAM Write**: Sets the pointer only, but now writes into VDP Data will now be directed into the Color-RAM, reads still read VRAM.


Note that "VRAM Read" doesn't set the VRAM to read-only or anything of that kind, instead, it pre-reads a VRAM byte into a buffer, this buffer being what you actually read from the VDP Data port, if the VDP doesn't buffer this byte right away, you will end up having all VRAM reads being delayed by 1 address, which is what happens when you set the command to "VRAM Write". Just be cautious when using this mode for writing because the pre-read will automatically advance the VDP Pointer by 1, so if you want to write at $0000 you must send a pointer address of $3FFF so that way it wraps around to $0000 like you want. This can be observed with the Hello World program in this folder.

Now why writing into VRAM during a "Read" command? The Genesis/MD VDP appears to have a serious issue with the LSB of the command ID so using "VRAM Write" will instead erroneously write into CRAM, making writing trough "VRAM Read" mandatory for forward compatibility with the Genesis/MD. This is reported to break a number of games.

### Reading VDP Control port and VDP Status Word
When reading from VDP Control you first get a single byte containing the following bits:
```
FCO-----
|||
||+------- sprite Overflow flag - set when a 9th sprite is attempted to be rendered in any scanline.
|+-------- sprite Coincide flag - set when two opaque sprite pixels overlap.
+--------- Frame interrupt flag - set when the VBlank period begins.
```

Afterwards, all the status word flags are reset back to "0", this must be done when any interrupt occurs or else the CPU will imediately return to the interrupt vector when exiting.

A read will also clear two internal non-readable flags, one flag is the line interrupt pending flag, which trips a scanline interrupt if it's enabled, and another is the VDP Control port byte order flag, which is meant to clear any case of ambiguity when writing to the VDP Port, beware that this can (and will) cause issues if an interrupt happens during VRAM copies.

### Extended Height Modes (SMS2 ONLY)
On SMS2 VDP, setting the mode 2 bit while in mode 4 enables extended height mode, this mode makes the SMS display 224 lines tall instead of 192, you can further extend the video height to 240 lines using the mode 1 bit, but this mode **doesn't work on NTSC units and should only be used if you are sure your game is running on a PAL unit**. Game Gear is reported to **crash the LCD controller** if the 240-line mode is attempted to be used.

### Illegal Text Mode
Attempting to set the 224-line mode in a normal SMS1 VDP will result in the illegal text mode to be enabled instead, so here's how that works:
- Similarly to the original TMS9918 Text mode, the color indices are taken from register #7, which defines the backdrop and text color, the tile size is cut down to 8x6 and the sprites are disabled.
- Scrolling only partially works, the background grid stays still but the tile graphics will roll inside the 8x6 areas.
- Scroll lock still works.

## 3. Timings

### Active Scanline
Unlike Nintendo PPUs, the Master System VDP won't entirely block accesses to VRAM when the frame is being drawn, so long as you wait 26 Z80 cycles between reads or writes, you can squeeze up to 11 accesses to VRAM per active scanline (each access is one byte).

In further detail, during active video (not in H-Blank), the VDP will access one byte every 2 on-screen pixels, and do a somewhat repeated pattern behaviour for every 32 pixels (16 accesses) 8 times:
```
0000000001111111
1234567890123456

..TT..TT..TT..TT
N...N...N...N...
.....S...S...S..
.F..............

F = Free, N = Nametable, T = Tile, S = Sat
```

Filling up the the area in between pixels 0 trough 255.

And during H-Blank, there are more free slots (but very close to each other, in practice only being as effective as one) and only accesses to the Tiles and SAT information for the remaining 86 pixels (43 accesses):
```
0000000001111111111222222222233333333334444
1234567890123456789012345678901234567890123

......TTTT..TTTT.......TTTT..TTTT..........
....SS....SS.........SS....SS......SSSSSSSS
FFFF............FFFFF............FF........

```

Thus totalling 8+3 groups of free access slots distributed evenly across the scanline.

### V-Blank
VRAM and VDP accesses are fully unrestricted during V-Blank.

### CRAM Dots
During active video, regardless of the VDP being enabled or disabled, writing to CRAM will cause the new color you wrote to show up for one pixel, the dots still happen during H-Blank but won't be visible.

# 4. Tiles and Background

### Tile format
Tiles are 32 bytes each, using a 4-bpp interleaved planar format:
```
Byte Offset | +0       +1       +2       +3           Result
------------+-------------------------------------------------
Byte +0     | 00111100 00111100 00111100 01111110  =  08FFFF80
Byte +4     | 01000010 01111110 01000010 11000011  =  8F2222F8
Byte +8     | 10000001 11111111 10100101 10100101  =  F2E22E2F
Byte +C     | 10000001 11111111 10000001 10000001  =  F222222F
Byte +10    | 10000001 11111111 10100101 10100101  =  F2E22E2F
Byte +14    | 10000001 11111111 10011001 10011001  =  F22EE22F
Byte +18    | 01000010 01111110 01000010 11000011  =  8F2222F8
Byte +1C    | 00111100 00111100 00111100 01111110  =  08FFFF80
```

In further detail, tile planes are all specified one after the other, so one row of the sprite is four adjacent bytes, in little endian order, the entire tile is eight of those four adjacent bytes such as this:
```
(lowest, middle low, middle high, high) = 4 bytes

(4 bytes, first row), (4 bytes, second row), (4 bytes, third row)... (4 bytes, eigth row); next tile starts now
```

### Background
The background's nametable consists of an array of 32 tiles wide by 28 tiles tall in 192-line mode, each entry is two bytes and encode the following:
```
Entries are stored in little endian, but are represented in big endian here, byte indicators should be above the bits to clarify.

| 2nd  | | 1st  |
UUUPSVHT TTTTTTTT
|||||||| ||||||||
|||||||+-++++++++---- Tile index
||||||+-------------- flip tile Horizontally
|||||+--------------- flip tile Vertically
||||+---------------- palette Select (0 = use CRAM $00 - $0F; 1 = use CRAM $10 - $1F)
|||+----------------- Priority - tile overlays sprites if set to "1"
+++------------------ Unused, but can hold any data
```

Totalling 1792 bytes for an entire nametable. But beware that the nametable size will expand to 32x32 when using the SMS2 extra line modes, resulting instead in 2048 bytes.

The placement of the nametable in the VRAM also changes depending on your line height mode, 192-line tall mode lets you place the nametable at $0000 trough $3800 in increments of $800, giving you 8 possible nametable locations, while in extended line modes you can only place the nametable in four locations: $0700, $1700, $2700 and $3700.

The nametable base address is re-read every scanline, changing nametables mid-frame is possible.

### Scrolling
The background can be offset by using the X and Y scroll registers, X scroll will always perfectly wrap around while Y scroll will wrap earlier outside of extended height modes, since the nametable is exactly the width of the video output, the VDP has a special toggle that will hide the leftmost 8 pixels or tile column to hide the scrolling seam.

For games that scroll in either X only or Y only, there are scroll lock features that:
- **Horizontal Scroll Lock**: forces the topmost two tile rows (16 pixels) to be forced with a horizontal scroll value of "0".
- **Vertical Scroll Lock**: forces the rightmost tile column (8 pixels) to be forced with a vertical scroll value of "0".

However, scrolling up and down with the horizontal scroll lock enabled will still shift the tiles in the affected 16 pixels row up and down, and the same happens to the rightmost tile column when scrolling side-to-side, making this feature much less useful for games that scroll in both the X and Y directions at once.

X scrolling value is always re-read every scanline, allowing for waving and split effects, Y scrolling value is only read once at the start of the frame, making vertical splits using this register impossible.

# 5. Sprite Subsystem
The VDP can store 64 independently moveable sprites, up to 8 can be displayed in a single scanline, and are drawn with the painter's order algorithm, making it so that sprite #0 (drawn last) will appear on top of all other sprites while sprite #63 (drawn first) will be covered up by all other sprites.

### Sprite specs
- Sprites can be placed in any X and Y position and can address up to 256 tiles selected at either VRAM address base of $0000 or $2000, the tile pattern format is the same as the background except that the Color RAM entries used are only those at $10 - $1F, with the pixel color index 0 (to color $10) is replaced for transparent pixels.
- In the VDP Status word, there is a hardware collision feature, the "coincidence" flag will be set if two non-transparent pixels of any sprite coincide or collide, allowing for pixel-perfect collision depending on the use.

### Sprite evaluation
During every H-Blank period, the VDP will scan trough the SAT from sprite #0 trough sprite #63, to find which sprites' Y position matches the current scanline and buffer 8 of them, if more sprites are found, they will be ignored and the "Overflow" VDP Status Word bit will be set to "1". Since the VDP fetches them in this order, the priority is defined by sprite ID, so sprite #0 will always be on top regardless.

There is also a feature that is exclusive to the 192-line tall mode where if a sprite with the Y position of "$D0" is found, the VDP will stop fetching sprites imediately for the duration of the whole frame, enabling extended height modes will effectively disable this feature.


### Sprite Zooming Behaviour
The zoom bit in **Mode Control Register 2**, will upscale a sprite by effectively doubling its X and Y widths, this feature works perfectly fine on SMS2 and Game Gear, but outside of those, it's broken in two different ways:
- **MD/Genesis**: For some odd reason, this feature is removed entirely on mode 5 VDPs, sprites will always stay non-zoomed even if the zoom bit is set to "1".
- **SMS1**: SMS1 will only correctly zoom the first 4 sprite entries in a scanline (which show up as wide), with the last 4 entries being incorrectly zoomed, only being stretched in the Y axis but remaining non-zoomed on the X axis, showing up as a narrow sprite, the order which the VDP fills the scanline sprite buffer is from last to first, meaning that even if high priority, if you have less than 5 sprites you're only getting narrow ones, only after that you'll get correct wide sprites as such:

|N of Sprites|Wide|Narrow|
|-|-|-|
|0|||
|1||1|
|2||2|
|3||3|
|4||4|
|5|1|4|
|6|2|4|
|7|3|4|
|8|4|4|

### SAT Format
|Offset|Purpose|
|-|-|
|+$0 - +$3F|Y position|
|+$40 - +$7F|unused, free to hold anything|
|+$80 - +$FF|tile number (even) and X position (odd)|

Or alternatively:

```

+---0123 4567 89AB CDEF--- LSB
|
0   YYYY YYYY YYYY YYYY
1   YYYY YYYY YYYY YYYY
2   YYYY YYYY YYYY YYYY
3   YYYY YYYY YYYY YYYY
4   ---- ---- ---- ----
5   ---- ---- ---- ----
6   ---- ---- ---- ----
7   ---- ---- ---- ----
8   TXTX TXTX TXTX TXTX
9   TXTX TXTX TXTX TXTX
A   TXTX TXTX TXTX TXTX
B   TXTX TXTX TXTX TXTX
C   TXTX TXTX TXTX TXTX
D   TXTX TXTX TXTX TXTX
E   TXTX TXTX TXTX TXTX
F   TXTX TXTX TXTX TXTX
|
MSB

v    v    v
Tile Xpos Ypos
^    ^    ^

Example: $92 points to the tile number of sprite #9 (0-indexed)
```

# 6. VDP Internal Registers
Note that these registers are **not Z80 I/O addresses**, these registers are written using the VDP Control Port under a "Register Write" command ID. The **Global Controls** section covers this in detail.

This section specifically documents the behaviours under mode 4, for legacy TMS9918 modes they behave essencially the same way as the original Texas Instruments chip. There are 11 internal VDP Registers, the first eight are the TMS9918 register numbers but some registers have extra bits and functions when in mode 4, SEGA also added three additional registers after the backdrop color register which control a few of the new features in the Master System.



### $0: Mode Control 1
```
76543210
--------
VHLIS42Y
||||||||
|||||||+------ sYnc disable
||||||+------- mode 2 enable
|||||+-------- mode 4 enable
||||+--------- Shift sprites left
|||+---------- enable scanline Interrupt
||+----------- hide Leftmost tile column
|+------------ Horizontal scroll lock
+------------- Vertical scroll lock
```

- Bit 7, when set, prevents the rightmost eight pixel columns from scrolling up/down.
- Bit 6, when set, prevents the topmost sixteen pixel rows from scrolling left/right.
- Bit 5, when set, the rightmost eight pixels will be hidden, displaying the backdrop color defined at register $7 instead.
- Bit 4, when set, allows for an internal VDP Status Word flag to send an IRQ to the Z80 when the Line Counter at register $A underflows.
- Bit 3, when set, moves all sprites to the left by eight pixels, so that sprites will partially appear at the left border correctly when the hide bit (5 of this register) is clear.
- Bit 2, when set, enables mode 4 and all SMS-related features.
- Bit 1, when set, will either:
  - **SMS1**: Do nothing.
  - **SMS2**: Allow for extended height modes by setting modes 1 and 3 bits. Setting it alone does nothing on itself.
  - **MD/Genesis**: Enable mode 5.
- Bit 0, when set, the image is monochrome.
  - **Game Gear**: This bit does nothing.

### $1: Mode Control 2
```
76543210
--------
-EI13-SZ
 |||| ||
 |||| |+------ Zoom sprites 2x
 |||| +------- sprite Size
 |||+--------- mode 3 enable
 ||+---------- mode 1 enable
 |+----------- v-blank Interrupt enable
 +------------ Enable rendering
```

- Bit 6, when set, the VDP will be enabled and start drawing the picture, but if clear it essencially forces a V-Blanking state, only displaying the backdrop color defined in register $7.
- Bit 5, when set, will make it so everytime a V-Blank occurs the flag in the VDP Status Word being set will call for a Z80 IRQ.
- Bit 4, when set, will enable the illegal text mode if mode 4 is also enabled.
  - **SMS1**: This bit always have this behaviour
  - **SMS2**: This bit instead enables 224-line mode if mode 2 bit is also set to "1", otherwise it also enables the illegal text mode.
- Bit 1 when set, will expand sprites to be two tiles tall (16 pixels tall, 8 pixels wide), otherwise if cleared, sprites are only one tile in size (8 pixels tall, 8 pixels wide).
- bit 0 when set, this bit will zoom the sprites by enlarging each sprite pixel into two pixels so that the sprite appears doubled in size with a fairly blocky appearance.
  - **SMS1**: In a scanline, only the 4 higher priority sprites will be zoomed correctly, with the remaining last 4 slots will only zoom on the Y axis, due to how sprites are inserted from lowest-to-highest priority, you will only get correctly zoomed sprites to show if there's more than four sprites in the scanline, you can see a more detailed description of this behaviour in the **Sprite Subsystem** section.
  - **SMS2**: All sprites are correctly zoomed.
  - **MD/Genesis**: This bit does nothing.

### $2: Nametable Base Address
```
----AAAx
    ||||
    |||+---- mask bit, SMS1 only
    +++----- base address
```

The nametable is placed in VRAM differently depending on your scanline height mode but in short:
- **192-line tall mode**: the 3-bit address value will start from $0000 and advances every $800 bytes when incremented, allowing you to place the nametable at:

|Register Value|VRAM Address|
|-|-|
|$x1|$0000|
|$x3|$0800|
|$x5|$1000|
|$x7|$1800|
|$x9|$2000|
|$xB|$2800|
|$xD|$3000|
|$xF|$3800|

The mask bit will AND itself with the nametable address, causing the last 8 bottom tile rows to repeat the first 8 when cleared, one game is reported to intentionally clear this bit to get this mirroring behaviour and shows incorrect graphics when inserted on SMS2.

Its effect on the 16-bit VRAM bus is the following:
```
--AAAmYY YYXXXXXB
  |||||| ||||||||
  |||||| |||||||+------ low or high Byte of the nametable entry
  |||||| ||+++++------- X tile entry offset (0-31)
  ||||++-++------------ Y tile entry offset (0-31)
  |||+----------------- mask bit overlapping the MSB of the Y offset
  +++------------------ base Address
```

In short, **keep this bit as "1" at all times to prevent nametable mirroring** and avoid any possible compatibility issues between SMS1 and SMS2, as SMS2 lacks this bit, and mirroring may be an undesirable side effect of testing a game in an SMS2 during development.

- **(SMS2 ONLY) 224 and 240-line tall mode**: bit 1 stops being effective, the address is only calculated using bits 2 and 3, with every increment advancing $1000 bytes, but now a $700 byte offset is also added.

|Register Value|VRAM Address|
|-|-|
|$x3|$0700|
|$x7|$1700|
|$xB|$2700|
|$xF|$3700|

### $3: Color Table Base Address
This register just appear to mask the nametable address when in mode 4, keep it at $FF at all times. Further documentation needed.

Outside of mode 4, it sets the base address for the colorization table that the TMS9918 Graphics 1 and Graphics 2 modes use, as tiles are 1-bit-per-pixel on TMS9918 instead of 4.

### $4: Pattern Generator Table Base Address
```
-----xxx
     |||
     +++---- reportedly mask bits (SMS1 only)
```

This register just appear to mask the pattern (tiles') addresses, keep it at $FF at all times. Further documentation needed.

Outside of mode 4, it sets the base address from where the tiles are fetched from in the TMS9918 legacy modes.

### $5: SAT Base Address
```
-AAAAAAx
 |||||||
 ||||||+---- mask bit (SMS1 only)
 ++++++----- base address
```

The address of the SAT starts at VRAM $0000, for everytime the 6-bit address range is incremented, the SAT base address advances by $100 bytes or every "page", allowing you to place the SAT ranging from VRAM addresses $0000, $0100, $0200... $FC00, $FE00, $FF00. For reference, the SAT is exactly one "page" ($100 bytes) big if you include the unused 64-byte block.

The mask bit when clear, will cause the Y-position and unused blocks to be read when the VDP tries to read the X-position and Tile blocks, causing all sprites to appear incorrectly. Its effect on the 16-bit VRAM bus is the following:
```
--AAAAAA xDDDDDDD
  |||||| ||||||||
  |||||| |+++++++------ fetch Data (0-FF)
  |||||| +------------- mask bit overlapping fetch data's MSB
  ++++++--------------- base Address

the Data field patterns have 3 states for each of the 3 bytes that every sprite holds:
00YYYYYY: for Y position byte fetch
1XXXXXX0: for X position byte fetch
1TTTTTT1: for Tile index fetch
```

**Keep the mask bit to 1 at all times to prevent issues with SMS1.**

### $6: Sprite Pattern Generator Base Address
```
-----Axx
     |||
     |++---- mask bits (SMS1 only)
     +------ base address
```

The single address bit will choose if your sprite patterns (tiles) come from VRAM address $0000 when clear or $2000 when set.

The mask bits will cause three different mirroring patterns:
|Bits|Mirror Pattern|
|-|-|
|00|sprite patterns $40-$7F, $80-$BF, $C0-$FF are all the same as $00-$3F.|
|01|sprite patterns $80-$FF are the same as $00-$7F.|
|10|sprite patterns $40-$7F are the same as $00-$3F, while $C0-$FF are the same as $80-$BF.|
|11|No mirroring (preferred).|

Its effect on the 16-bit VRAM bus is the following:
```
--AmmTTT TTTYYYPP
  |||||| ||||||||
  |||||| ||||||++------ bitPlane number (0-3)
  |||||| |||+++-------- Y strip number (0-7)
  |||+++-+++----------- Tile number (0-FF)
  |++------------------ mask bits overlapping the higher 2 bits of the tile number
  +-------------------- Address bit
```

**Keep the mask bits to 1 at all times to prevent issues with SMS1.**

### $7: Backdrop Color
The low four bits of this register will pick a backdrop color from the second palette (CRAM $10 trough $1F). This register is normally used for TMS9918 text mode colors so the high four bits have no effect in mode 4, unless you happen to enable the illegal text mode.

### $8: X Scroll Offset
Offsets the nametable horizontally, incrementing to this register will make the nametable move to the right (as in the camera going to the left), with the far edge pixels immediately wrapping around to the opposite side of the screen if the hide feature is not enabled.

The horizontal resolution being exactly 256 pixels won't cause any "snapping" behaviour.

This register is re-read every scanline.

### $9: Y Scroll Offset
Offsets the nametable vertically, incrementing this register will make the nametable move downwards (as in the camera moving up), however wrapping around isn't instant as all height modes are taller than the visible frame.

Due to the tilemap size being 224 pixels tall on 192-line mode, there will be a "snap" once you move past 224 pixels vertically, snapping back to the beggining of the tilemap, this behaviour is not present on extended height modes as the tilemap is 256 pixels tall instead.

This register is only read once at the start of the frame, changing it during rendering will only take effect when the next frame starts, preventing any "splitting" behaviour.

### $A: Scanline Counter
This register acts as a preset value for a down-counter that:
- **During active video**: Decrements its counting value every scanline that passes, once it underflows it reloads itself with the value of this register and sets an internal flag at the VDP Status Word register.
- **During V-Blank**: reloads itself with the value in this register every scanline.

Thus changing this register only take effect once the timer's internal count value is depleted.

# 7. VDP Compatibility Notes
### SMS1 and SMS2
Between SMS1 and SMS2 VDPs, the SMS1 model is present in pretty much all Japanese units while SMS2 is mostly present on the Export "Master System II" model, but some are reported to still have the SMS1 VDP, they have only two differences but are pretty significant:
- **Extended height modes**: When in mode 4, setting the mode 2 bit enables the extended height modes, you can choose between 224 lines tall and 240 lines tall modes using the mode 1 and 3 bits respectively, however in NTSC units, the 240 lines mode will not work, this reportedly breaks "Micro Machines" by Codemasters. SMS1 lacks this function and when attempting to enable 224-line tall mode will result in a garbled illegal text mode, attempting to enable 240-line tall will instead have no effects, so long as the Mode 1 bit stays "0".
- **Zoomed sprites**: In SMS1 VDPs, out of the 8 sprites that can be displayed in a single scanline, only the 4 higher priority sprites will be correctly zoomed, the lower priority 8 sprites (4 - 7) will only be vertically zoomed, with the horizontal not being correctly stretched. SMS2 fixes this and all 8 sprites can zoom correctly, this behaviour combined with the Coincide flag in the VDP Status Word, can be used to detect if you are on an SMS1 or SMS2.
- **Mask Bits**: In SMS1 VDPs, some bits in the base address registers perform an AND operation with the address, resulting in mirroring behaviour that is usually undesired, these bits are removed in SMS2 and no longer take effect, but to ensure your game works on either SMS1 and 2, set the Mask Bits to "1".
- **Open Bus**: Open bus in SMS1 units returns a ghost value of whichever happened last on the system's bus, such as an instruction byte, while SMS2 actively pulls the bus lines up, making it so that open bus reads always read "$FF".

### Game Gear
When in SMS scaling mode, the Game Gear functions as a downscaled SMS2, but beware with the following:
- **TMS9918 Modes have no initialized palette**: The Game Gear instead picks the colors at CRAM addresses $10 trough $1F.
- **240-line mode is even more broken**: Reportedly, enabling this extended height mode will **crash the LCD Controller**, and the only way to reset it is by power cycling the system.

### Mega Drive / Genesis
MD/Genesis' VDP is oddly enough based on the SMS1 VDP, the masking bits are fixed but:
- **Zoomed sprites are removed**: They don't zoom at all. This behaviour can be used to detect a MD VDP using the Coincide flag.
- **Extended Heights are removed**: The way extended height modes are enabled using the Mode 2 bit no longer works since using Mode 4 and Mode 2 simultaneously now enables Mode 5.
- **TMS9918 Modes are removed**: Attempting to enter a TMS9918 mode results in a black screen, SG-1000 compatibility is no longer possible.
- **VRAM Write command is broken**: Using "VRAM Write" ID (%01) on the VDP Control Port will result in writes being directed into CRAM instead of VRAM, the only workaround this is using the "VRAM Read" (%00) command ID instead and accounting for the pre-increment, this reportedly breaks a few games.
- **Open bus is inconsistent**: Some MD/Gen units will have a propper pull-up on the Z80 bus and others won't, so don't rely on checking for $FF reads to detect between MD/Gen and SMS1.

### In Short
- Stay in Mode 4, if you want to use TMS9918 modes make sure to set CRAM $10 trough $1F with the TMS9918 palette for Game Gear compatibility.
- Don't use zoomed sprites outside of system detection purposes, they are broken in 2 different ways.
- Prefer 192-line mode, but if you need more scanlines make sure to use 224-line mode at most if possible, unless your game is PAL only.
- Write to VRAM with "VRAM Read" commands, watching out for the pre-increment.
- Always keep the mask bits in the VDP Internal Registers as "1".
- Don't rely on open bus for randomness and system detection.

# 8. Links
- [SMS Power! - VDP Control Port](https://www.smspower.org/Development/ControlPort)
- [SMS Power! - VDP Registers](https://www.smspower.org/Development/VDPRegisters)
- [TechnoJunk - VDP Documentation](http://www.techno-junk.org/txt/msvdp.txt)
- [SMS Power! - Scanline Timing diagram by PinoBatch](https://www.smspower.org/forums/files/sms_render_timing_124.png)

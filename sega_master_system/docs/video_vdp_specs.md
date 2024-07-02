# VDP specs
The video source from the Sega Master System units comes from the Video Display Processor, a custom chip by SEGA which extends the Texas Instruments TMS9918 used in the SG-1000. Just like the TMS, you comunicate with this chip trough two of the Z80 I/O ports, one will read or write into VRAM based on what address you specified and the other will allow you to specify the address, colors and registers by writing two bytes into it, reading from this port will return the VDP's status word.

## Mode 4
In contrast to the previous SG-1000, the SMS VDP features a new mode which features, when enabled: 
- X and Y scrolling capabilities
- Two configurable palettes of 16 colors each.
- Both background and sprite tiles are now 4-bit per pixel.
- Background attribute table contains a few extras such as palette select, sprite priority, H/V tile flip and can address 512 tiles.
- Sprites are now reduced to only 1 tile (8x8) or 2 tiles (8 wide, 16 tall) but now 8 can be displayed in a single scanline and are 4-bit per pixel.
- Vertical and horizontal scroll lock features for implementing status bars on limited scrolling games.
- Can hide the leftmost tile column to hide unwanted scrolling artifacts.
- Programmable scanline counter interrupt for raster tricks.
- Selectable backdrop color for overscan areas.

## Notable behaviours
- Writes to the VDP and VRAM can be issued while the video is being drawn, so long as all writes are 21 clock cycles apart from each other. There is no write speed limit during H-Blank and V-Blank periods.
- Writes to the Color RAM during active video may have issues, but reportedly doing it during H-Blank and V-Blank is safe.
- The X scroll register can be altered every scanline, while Y scroll will only take effect once when the picture starts being drawn.
- Vertical scroll lock will affect the top 1 tile row, changing the Y scrolling will also affect its position and should not be used for games which scroll in both X and Y directions.
- Horizontal scroll lock will affect the rightmost two tile columns, it has the same flaw as vertical scroll lock as that changing the X scrolling value also offsets it.

## Differencies
Excluding the previous SG-1000 and SC-3000, there are two documented VDP variants for Master System units, SMS1 and SMS2, and also the Game Gear and Mega Drive / Genesis Mode 4 compatibility for Master System games, each have their own differencies as such:
- **SMS1**: The baseline model, all SMS models should support this, however SMS1 have "mask bits" which should be all set to "1" to avoid mirroring issues.
- **SMS2**: Present on western SMS, but not granted to be on all, this VDP fixes the sprite zooming issue and adds two extra scanline modes which extend the video height to 224 or 240 scanlines instead of always 192, however 240 scanlines is not recommended to use since it doesn't work on NTSC units. 
- **Game Gear**: It's mostly identical to SMS2 but... 240 scanline mode is granted to be broken on all units; the TMS modes use palette entries 16-31 instead of using an internal hard-coded palette; palettes can be optionally extended to use two bytes per entry, encoding RGB444 instead of RGB222; and lastly the video output is downscaled to fit the 160 wide by 144 tall LCD screen, using a sub-pixel downscaling for horizontal resolution and skipping roughly every 3 scanlines for vertical resolution.
- **Mega Drive / Genesis**: Lacks the legacy TMS modes and sprite zooming is totally removed, unlike SMS2 there are no extended height modes because the bit used to enable it is instead repurposed to enable Mode 5, and unlike SMS1 there are no address mask bits. There is also a bug with the write codes, more detail in the VDP Accessing section.

## Accessing the VDP
All VDP accesses are done with the Z80 I/O ports $BE and $BF, each port is respectively named VDP Data and VDP Control, depending on what value you write to the VDP Control port you can choose whether you read or write from VRAM, whether you want to write to VRAM or Color RAM and whether you want to write to its internal registers.
|VDP Control write pattern|Action|
|-|-|
|`%00HHHHHH`, `%LLLLLLLL`|Read from VRAM into the VDP Data port, **H** and **L** encodes your desired 14-bit address. Reading from the VDP Data will return VRAM bytes, writing is not recommended.|
|`%01HHHHHH`, `%LLLLLLLL`|Write to VRAM from the VDP Data port, **H** and **L** encodes your desired 14-bit address.|
|`%10HHHHHH`, `%LLLLLLLL`|Write to Color RAM from the VDP Data port, **H** and **L** encodes your desired 14-bit address, since the Color RAM is only 32 bytes on SMS, it will wrap around to always point into Color RAM. Reading from the VDP Data will return VRAM bytes.|
|`%11--RRRR`, `%DDDDDDDD`|Set register data, **R** encodes your register number and **D** the byte data you write into this register. Doing this won't affect the VDP's data pointer.|

Note that all accesses to VRAM and CRAM will automatically increment the VDP's address, so accessing a byte at $02FF will set the pointer to access $0300 next time.

Writting the upper address will cause an instant change before even writing the lower address, unless your VDP is the Mega Drive/Genesis one, which instead latches the upper address untill the lower is written. Also should be noted that for some reason, the Mega Drive/Genesis VDP will assume that that an upper write to VDP Data containing the two upper bits set to "01" will cause a write to the Color RAM instead of VRAM, this can be avoided by writing to the VDP in Read mode.

## VDP Status Word
Reading from VDP Control register gives you a byte with a couple bits set or cleared depending on some conditions, those bits will stay set to "1" untill the register is read. Each bit's function is listed below:
- Bit 7: V-Blank period: set when the VDP is waiting for the television synchronize back to the start of the picture, during this time you can freely access VRAM and colors.
- Bit 6: Sprite overflow: set when more than 8 sprites are attempted to be drawn in one scanline.
- Bit 5: Sprite collision: set when two sprites' opaque pixel draw over each other.
- Bits 4 trough 0: Unused on mode 4.

## Interrupt sources
There are two interrupt sources from the VDP, first is the V-Blank interrupt which will trigger by the end of scanline 193, and the scanline counter interrupt, the scanline counter works by decrementing everytime a line is drawn on-screen, once it underflows, it sets an internal flag, fires an IRQ, and reloads itself with the value written at the $A register, the counter will also repeatedly reload itself on every line that is part of the V-Blank period, meaning that it will always start with the value of register $A as soon as the image begins. The behaviour of register $A is comparable to that of a reloading timer, changing the contents of the register will only take effect once the counter finishes counting the last value or period it loaded.

It's important that once either of the interrupts fire, you read the VDP Control register so you can identify whether the interrupt that fired was a V-Blank or not, and to also clear both the V-Blank flag and internal scanline counter flag, if the flags are not cleared the Z80 will imediately return to the interrupt handler as soon as it exits.

## Palettes
For SMS1 and SMS2, there are two palettes with each holding 16 colors to match the 4-bit index for each tile pixel, the colors are encoded as `%--RRGGBB` (RGB222) and are each a single byte in size, totalling a Color RAM size of 32 byes, the two upper bits do nothing. When on the legacy TMS modes, the VDP will use an internal palette instead, unless it's the game gear variant where the colors will be picked from the second palette instead.

For the Game Gear variant of the VDP, the palettes can be extended to be 2-bytes each, encoding each color value as `%----RRRR, %GGGGBBBB` (RGB444) instead, totalling to 64 bytes of Color RAM.

Color RAM cannot be read back, as attempting to read from VDP Data will return VRAM bytes instead.

## Tile Format
Tiles are each 32 bytes in size and use a 4-bit planar format with all planes being interleaved and stored as little endian, meaning that the first byte represnts the least significant bitfield and the bytes coming after representing upper more significant bitfields, both background and sprite tiles use the same format.
```
Byte Offset | +0       +1       +2       +3           Result
--------+-----------------------------------------------
Byte +0     | 00111100 00111100 00111100 01111110  =  08FFFF80
Byte +4     | 01000010 01111110 01000010 11000011  =  8F2222F8
Byte +8     | 10000001 11111111 10100101 10100101  =  F2E22E2F
Byte +C     | 10000001 11111111 10000001 10000001  =  F222222F
Byte +10    | 10000001 11111111 10100101 10100101  =  F2E22E2F
Byte +14    | 10000001 11111111 10011001 10011001  =  F22EE22F
Byte +18    | 01000010 01111110 01000010 11000011  =  8F2222F8
Byte +1C    | 00111100 00111100 00111100 01111110  =  08FFFF80

```
You can visualize the example tile in your browser or text editor by using Ctrl+F and typing the corresponding digit, it should highlight them. This repo also contains a converter tool which can be used for reference.

## Sprite Attribute Table
Usually refered to as SAT, it contains a list of information for the 64 sprites the VDP can display, the SAT is 128+64 bytes in size and can be placed in VRAM at every 256 locations, it encodes the X and Y position of the sprites and their tile number ranging from 0 to 255 and is formatted as such:
|Range|Function|
|-|-|
|+$00 ~ +$3F|Y coordinate|
|+$40 ~ +$7F|Empty|
|+$80 ~ +$FF|X coordinate on even locations and tile number on odd locations|

The empty area has no effect on the picture and can be used for storing two extra tiles if you wish.

## VDP Registers
### 0: Mode Register 1
|Bits|Effect on SMS1|Effect on SMS2|
|-|-|-|
|7|Vertical scroll lock|Same as SMS1|
|6|Horizontal scroll lock|Same as SMS1|
|5|Hide leftmost tile column|Same as SMS1|
|4|Enable scanline counter interrupts|Same as SMS1|
|3|Shift sprites to the left by 8 pixels|Same as SMS1|
|2|Enable mode 4|Same as SMS1|
|1|Selects TMS mode 2|Selects extra height modes when on Mode 4|
|0|Disable sync|Same as SMS1|

Bit 0 appears to make the video monochrome, it's initial purpose is for external video output on the TMS9918.

### 1: Mode Register 2

|Bits|Effect on SMS1|Effect on SMS2|
|-|-|-|
|7|No effect|No effect|
|6|Enable display|Same as SMS1|
|5|Enable V-Blank interrupt|Same as SMS1|
|4|Selects Mode 1 on TMS9918|Selects 224-line mode when in Mode 4|
|3|Selects Mode 3 on TMS9918|Selects 240-line mode when in Mode 4|
|2|No effect|No effect|
|1|Double height sprites|Same as SMS1|
|0|Doubles some sprites' pixel size|Doubles all sprites' pixel size|

### 2: Background Tile Map Address

When on 192 scanline mode:
|Bits|Effect|
|-|-|
|7~4|No effect?|
|3~1|Tile Map address|
|0|Mask bit|

Addresses are choosen in increments of $800, Bit 0 should be always set to "1" or else the lower 8 rows of the tile map will mirror the upper 16 rows.

Bits 7~4 are unclear to me, but SMS Power! recommends to set them to "1" for SMS1, as most games sets this register to $FF to place the tile map at $3800.

When on 224 and 240 scanline modes (SMS2 only):
|Bits|Effect|
|-|-|
|7~4|No effect|
|3~1|Tile Map address|
|1~0|No effect|

Addresses are choosen in increments of $1000 and then are added $700, resulting in 4 possible addresses of $0700, $1700, $2700 and $3700.

### 3: TMS Mode 2 Color Table Address
Is reported to cause issues with the tile fetches on mode 4 if not set to $FF on SMS1.

### 4: Background Tiles Address
Appears to only have mask bits at bits 2 trough 0, must be all set to "1" in order to propperly work on SMS1, Otherwise appears to have no effects on SMS2. It is recommended to write $FF to this register.

### 5: Sprite List Address

|Bits|Effect|
|-|-|
|7|No effect|
|6~1|SAT's address|
|0|Mask bit|

SAT's address bit field offsets it by increments of $100, it starts and ends within each page so that the SAT can be placed at $0000, $0100, $0200... and so on untill $3F00. Most games choose to place it at $3F00 by writing $FF to this register.

Mask bit is only present on SMS1, on SMS2 it has no effect, but should be always set to "1" to make sure your game works on both. It effectively ANDs itself with the address and will cause the sprites to fetch the Y coordinate block when trying to fetch the X coord and tile number.

### 6: Sprite Tiles Address

|Bits|Effect on SMS1|
|-|-|
|7~3|No effect|
|2|Sprite tile's address|
|1~0|Mask bits|

Bit 2 when set to "1" will pick the sprite tiles starting from VRAM address $2000, otherwise it will pick starting at $0000

Mask bits will AND themselves with the tile address and cause the address to wrap around if either of the bits are reset to "0", to avoid this behaviour, set the bits both to "1".

### 7: Backdrop Color
The low nybble of this register chooses one of the 16 colors of the first palette to apply on the overscan regions of the screen above and below the picture. Upper nybble is unused.
### 8: Scroll X
Offsets the tile map to the right based on an 8-bit value, the X scroll value is reloaded every scanline.
### 9: Scroll Y
Offsets the tile map down based on an 8-bit value.
### A: Scanline counter
Effectively a reloading timer that counts X amount of scanlines, triggers an interrupt and then reloads itself with this register's value, it forcefully reloads itself during V-Blank.
### B-F: unused
No effects when written to.

## Links
- [VDP Registers from SMS Power!](https://www.smspower.org/Development/VDPRegisters)
- [VDP Documentation Text from Techno Junk](http://www.techno-junk.org/txt/msvdp.txt)

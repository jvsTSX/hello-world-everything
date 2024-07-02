# Building the ROM

For convenience, the compiled and checksummed binary is already included in this folder, you can drag and drop it on an emulator such as [Emulicious](https://emulicious.net) or [Mesen](https://www.mesen.ca/).

However if you want to use this file as a template to play around and change a few things to assemble, make sure you have the [WLA-DX assembler](https://github.com/vhelin/wla-dx) installed on your computer and run the following commands while inside this folder:
```
wla-z80 -o hwd.o hwd.asm
wlalink linkfile hwd.sms
```

# Graphics converter tool
For convenience as well, the tileset binary is also already included, but if you want to use your own, compile `gconv.c` using GCC:
```
gcc gconv.c
```

And then replace or edit the source BMP image in this folder with your desired tileset image, then run the program under a command line and see if it threw any errors, it automatically looks for a 4-bit BMP file named "tiles.bmp" and have the following requirements:
- Height and width of 128 pixels
- Not compressed
- Single plane
- 4-bits per pixel

The Windows 7 ~ 10 version of Microsoft Paint should output a valid BMP so long as you keep it with the correct resolution. The ROM mimicks MS Paint's 4-bit palette for easier visualization.

# Checksum patcher
Lastly this repo also includes an 8KB checksum patcher, the ROM header is set to lie to the SMS BIOS so that it only checks the first $1FF0 bytes of the ROM. In order to use the patcher, just compile it using GCC
```
gcc chksum.c
```

And run it after having the ROM fully assembled, make sure this is your LAST step, as assembling the ROM again will get rid of the checksum.

#Support
So far it only displays a simple hello world on a SMS1 compliant setting, SMS2 detection maybe implemented later (todo?)
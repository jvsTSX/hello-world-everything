# Sound Specs
The Master System and Mark III use a custom version of the DCSG / SN76489 to keep compatibility with the SG-1000, it's instead referred to as "SEGA PSG" and works almost exactly the exact same as the DCSG.

## Differences between SEGA PSG and DCSG
There are two differences, and they're both on the Noise channel:
- **Shift register size**: the original SN76489 has a 15-bit shift register, SEGA PSG extends it to 16-bit, which may cause tuning issues for songs using the rotate mode.
- **Noise mode taps**: due to the nature of LFSRs, keeping the taps as the last two bits of the shift register would now cause the noise period to be 255 steps, SEGA noticed this and altered the taps to bits 12 and 15 of the LFSR (indexed from 0, with 0 being the MSB), which instead results in a noise period of 57337 steps; this length is non-maximal and has a characteristic "plasticky" sound to it.

LFSR Representation:
```
 +--------------< XOR (( ============+--------+
 |                                   |        |
 V                                   ^        ^
00,01,02,03,04,05,06,07,08,09,10,11,12,13,14,15 -> output

```

As the SEGA PSG is always used with the same ~1.7MHz master clock, which match the following notes as a reference for composers:
|Val|Div Rate|Approx. Note in Rotate Mode|
|-|-|-|
|00|/512|A-5|
|01|/1024|A-4|
|10|/2048|A-3|
|11|Ch. 3|Channel 3's note but 4 octaves down|

For overall DCSG specs, check its documentation on the common chips folder.
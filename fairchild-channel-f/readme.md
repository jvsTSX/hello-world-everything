# Fairchild Channel F

- build it with this command on a CLI
```
dasm hwd.asm -f3 -ohwd.bin
```

# System Summary
since this machine don't have information so readily available, i will provide some information worth mentioning here

## CPU
fairchild F8 at 1.7MHz

it's a very strange harvard architecture thing with a weird cycle notation of 4-clock cycles and 6-clock cycles (long and short cycles, respectively)

you can find some info at this wiki https://channelf.se/veswiki/index.php?title=Opcode

but here's a quick summary of that i wrote while making this thing

- flags: arranged as OZCS
- cycle notation: 2 clocks = 1 machine cycle so a short cycle is 2 and a long cycle is 3
- note that PI, JMP and DCI destroy the accumulator!

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
|IN #8|2|8|0X0X||load A from ports 0-255|
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
|NI #0|2|5|0X0X|AND A with 8-bit constant|
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
|BT #3 #8|2|6/7||branch if all the bits on the 3-bit bitmask are True|
|BF #3 #8|2|6/7||branch if all the bits on the 3-bit bitmask are False|
|BR7 #8|2|4/5||
|PK|1|5||call address stored on register pair K|
|PI #16|3|13||call 16-bit address and destroys A|
|POP|1|4||return to last value stored on the return address register|
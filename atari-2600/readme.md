# Atari 2600 text display

- build it with these commands
ca65 hwd.asm -o hwd.o
ld65 -C 2600.cfg hwd.o -o hwd.a26
#include "stdint.h"
#include "stdio.h"
#include "stdlib.h"

int main()
{

int16_t checksum = 0;
int8_t romdata[32768];
int chk_cnt;

  // open file into stream
  FILE *ROMFILE;
  ROMFILE = fopen("hwd.sms", "r+b");
  if (ROMFILE == NULL) 
  {
    fprintf (stderr, "Error opening source file\n");
    return EXIT_FAILURE;
  }

  // load file into an array
  fread(&romdata, sizeof(romdata), 1, ROMFILE);

  // calculate checksum -> uint16 + all ROM bytes from 0000-1FEF
  for(chk_cnt = 0; chk_cnt < 0x1FF0; checksum += romdata[chk_cnt], ++chk_cnt);

  // write checksum, intentionally LE, not sure if i should trust on this thing's endianess...
  romdata[0x7FFA] = (checksum & 0x00FF);
  romdata[0x7FFB] = ((checksum >> 8) & 0x00FF);

  // write file, close and exit
  rewind(ROMFILE);
  fwrite(&romdata, sizeof(romdata), 1, ROMFILE);
  fclose(ROMFILE);
  printf("Checksum successfuly generated: %i\n", checksum);
  return EXIT_SUCCESS;
}
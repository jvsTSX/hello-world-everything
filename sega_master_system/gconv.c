#include "stdint.h"
#include "stdio.h"
#include "stdlib.h"

int main()
{
    int tmp, errorflag;
    FILE *SrcPtr, *DstPtr;

    SrcPtr = fopen("tileset.bmp", "rb");
    if (SrcPtr == NULL)
    {
        fprintf(stderr, "Error opening source file\n");
        return EXIT_FAILURE;
    }

    typedef struct bmpheader_t
    {
        // main header
        uint32_t filesize;
        uint32_t reserved;   // four '0' bytes
        uint32_t dataoffset; // for use with the actual work pointer
        // info header
        uint32_t imgheadersize;  // must be '40'
        uint32_t imgwidth;       // must be '128'
        uint32_t imgheight;      // must be '64'
        uint32_t imgplanesbpp;   // must be 0x40001
        uint32_t imgcompression; // must be '0'
        uint32_t imgsize;        // mspaint sets this to '0'
        uint32_t imgxppm;        // these shouldn't matter because i'm not doing anything with the pal data
        uint32_t imgyppm;
        uint32_t imgcolorsused;
        uint32_t imgcolorsimportant;
    } bmpheader_t;
    bmpheader_t fileheader;

    fseek(SrcPtr, 0x2, SEEK_SET); // get header, skipping signature to avoid padding screwing up with the struct
    fread(&fileheader, sizeof(bmpheader_t), 1, SrcPtr);

    errorflag = 0;

    if (fileheader.imgwidth != 128)
    {
        fprintf(stderr, "Error: Image width must be 128 pixels\n");
        errorflag++;
    }

    if (fileheader.imgheight != 128)
    {
        fprintf(stderr, "Error: Image height must be 128 pixels\n");
        errorflag++;
    }

    if ((fileheader.imgplanesbpp & 1) != 1)
    {
        fprintf(stderr, "Error: Plane count is incorrect, must be single plane\n");
        errorflag++;
    }

    if ((fileheader.imgplanesbpp & 0xFFFF0000) != 0x40000)
    {
        fprintf(stderr, "Error: Image must not be 4-bit per pixel\n");
        errorflag++;
    }

    if (fileheader.imgcompression != 0)
    {
        fprintf(stderr, "Error: Image must be uncompressed\n");
        errorflag++;
    }

    if (errorflag != 0)
    {
        fprintf(stderr, "Error count: %i\n", errorflag);
        return EXIT_FAILURE;
    }

    int8_t RawImg[8192]; // bitmap size, it's not really variable so this should do it
    int8_t RdyImg[8192];
    fseek(SrcPtr, fileheader.dataoffset, SEEK_SET);
    fread(&RawImg, sizeof(RawImg), 1, SrcPtr);

    DstPtr = fopen("tiles.bin", "w");
    if (DstPtr == NULL)
    {
        fprintf(stderr, "Error creating output file\n");
        return EXIT_FAILURE;
    }

    int strip_cnt, byte_cnt, tile_cnt, row_cnt;

    int dst_idx = 0;
    int src_idx = 8192 - 64; // end of file because the bitmap data is upside down

    int8_t stripsrc, stripdst0, stripdst1, stripdst2, stripdst3;


#define byte_off_x 4
#define byte_off_y 64
#define tile_off 512

    for(row_cnt = 16; row_cnt > 0; row_cnt--) 
    {
        for (tile_cnt = 16; tile_cnt > 0; tile_cnt--) 
        {
            for(strip_cnt = 8; strip_cnt > 0; strip_cnt--)
            {
                for(byte_cnt = 4; byte_cnt > 0; byte_cnt--, src_idx++)
                {
                    stripsrc = RawImg[src_idx];
                    stripdst0 = ((stripdst0 << 1) & 0b11111110) | ((stripsrc >> 4) & 0b00000001);
                    stripdst1 = ((stripdst1 << 1) & 0b11111110) | ((stripsrc >> 5) & 0b00000001);
                    stripdst2 = ((stripdst2 << 1) & 0b11111110) | ((stripsrc >> 6) & 0b00000001);
                    stripdst3 = ((stripdst3 << 1) & 0b11111110) | ((stripsrc >> 7) & 0b00000001);

                    stripdst0 = ((stripdst0 << 1) & 0b11111110) | ((stripsrc >> 0) & 0b00000001);
                    stripdst1 = ((stripdst1 << 1) & 0b11111110) | ((stripsrc >> 1) & 0b00000001);
                    stripdst2 = ((stripdst2 << 1) & 0b11111110) | ((stripsrc >> 2) & 0b00000001);
                    stripdst3 = ((stripdst3 << 1) & 0b11111110) | ((stripsrc >> 3) & 0b00000001);   
                }
                
                // write resulting converted planes into output array
                RdyImg[dst_idx + 0] = stripdst0;
                RdyImg[dst_idx + 1] = stripdst1;
                RdyImg[dst_idx + 2] = stripdst2;
                RdyImg[dst_idx + 3] = stripdst3;

                dst_idx = dst_idx + byte_off_x;
                src_idx = src_idx - byte_off_x - byte_off_y; // return 4 bytes to stay in the same Xpos and then go to the next Ypos strip
            }
            src_idx = src_idx + tile_off + byte_off_x;
        }
        src_idx = src_idx - byte_off_y - tile_off;
    }


    fwrite(&RdyImg, sizeof(RdyImg), 1, DstPtr);
    fclose(SrcPtr);
    fclose(DstPtr);
    printf("Conversion successful!\n");
    return EXIT_SUCCESS;
}
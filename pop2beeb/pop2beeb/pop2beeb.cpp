// pop2beeb.cpp : Defines the entry point for the console application.
//

//#include "stdafx.h"
#include "CImg.h"

using namespace cimg_library;

static unsigned char imagetab[10 * 1024];
static int image_addrs[256];
static int image_size[256][2];
static unsigned char image_data[256][1000];

static int pixel_size[256][2];
static unsigned char pixels[256][10000];

static unsigned char colours[256][10000];
static int colour_width[256];

static int total_colours[7];

#define BLACK0 0
#define PURPLE 1
#define GREEN 2
#define WHITE0 3
#define BLACK1 4
#define BLUE 5
#define ORANGE 6
#define WHITE1 7

#define GET_16BIT(ptr)	(*(ptr) + *(ptr+1)*256)
#define LO(val)			((int)(val) & 0xff)
#define HI(val)			(((int)(val) >> 8) & 0xff)

unsigned char palette[8][3] = 
{
	{ 0, 0, 0 },				// black
	{ 255, 68, 253 },			// purple
	{ 20, 245, 60 },			// green
	{ 255, 255, 255 },			// white
	{ 0, 0, 0 },				// black
	{ 20, 207, 253 },			// blue
	{ 255, 106, 60 },			// orange
	{ 255, 255, 255 },			// white
};

unsigned char odd_columns[8] =
{
	BLACK0,
	BLACK0,
	GREEN,						// orange
	WHITE0,
	BLACK0,
	PURPLE,						// blue
	WHITE0,
	WHITE0
};

unsigned char even_columns[8] =
{
	BLACK0,
	BLACK0,
	PURPLE,						// blue
	WHITE0,
	BLACK0,
	GREEN,						// orange
	WHITE0,
	WHITE0
};

unsigned char apple_colour_to_beeb_logical_colour[8] =
{
	0,							// black
	1,							// purple = magenta
	2,							// green
	3,							// white
	0,							// black
	1,							// blue = blue or cyan
	2,							// orange = red or yellow or stiple?
	3							// white
};

unsigned char beeb_logical_colour_to_screen_pixel[4][4] =			//
{
	{ 0x00, 0x00, 0x00, 0x00 },
	{ 0x08, 0x04, 0x02, 0x01 },
	{ 0x80, 0x40, 0x20, 0x10 },
	{ 0x88, 0x44, 0x22, 0x11 }
};

int convert_apple_to_pixels(unsigned char *apple_data, int apple_width, int apple_height, unsigned char *pixel_data)
{
	int pixel_width = apple_width * 7;

	for (int y = 0; y < apple_height; y++)
	{
		int x = 0;

		for (int a = 0; a < apple_width; a++)
		{
			unsigned char byte = apple_data[y * apple_width + a];
			
			int group = byte & 0x80;			// 0=purple+green, 1=blue+orange

			unsigned char bit = 1;

			for (int b = 0; b < 7; b++, bit <<= 1, x++)
			{
				pixel_data[y * pixel_width + x] = (group ? 4 : 0) + (byte & bit ? 1 : 0);
			}
		}
	}

#if 0
	for (int y = 0; y < apple_height; y++)
	{
		for (int x = 0; x < pixel_width; x++)
		{
			printf("%d ", pixel_data[y*pixel_width + x]);
		}
		printf("\n");
	}
#endif

	return pixel_width;
}

void flip_pixels_in_y(unsigned char *pixel_data, int pixel_width, int pixel_height)
{
	for (int y = 0; y < pixel_height / 2; y++)
	{
		for (int x = 0; x < pixel_width; x++)
		{
			unsigned char byte1 = pixel_data[y * pixel_width + x];
			unsigned char byte2 = pixel_data[(pixel_height - 1 - y) * pixel_width + x];

			pixel_data[(pixel_height - 1 - y) * pixel_width + x] = byte1;
			pixel_data[y * pixel_width + x] = byte2;
		}
	}
}

int calc_image_width_from_colour(unsigned char *colour_data, int pixel_width, int pixel_height)
{
	int colour_width = pixel_width;

	for (int x = pixel_width - 1; x >= 0; x--)
	{
		int y;

		for (y = 0; y < pixel_height; y++)
		{
			if (colour_data[y*pixel_width + x] != BLACK0 && colour_data[y*pixel_width + x] != BLACK1)
				break;
		}

		if (y == pixel_height)
			colour_width--;
		else
			break;
	}

	return colour_width;
}

int convert_pixels_to_colour(unsigned char *pixel_data, int pixel_width, int pixel_height, unsigned char *colour_data, bool invert, bool simple)
{
	for (int y = 0; y < pixel_height; y++)
	{
		for (int x = 0; x < pixel_width; x++)
		{
			if (simple)
			{
				// For POP data everything is group 1 (blue + orange)
				// Simplistic colour conversion - just look at pairs of pixels

				unsigned char byte1 = pixel_data[y*pixel_width + x];
				unsigned char byte2 = x < (pixel_width - 1) ? pixel_data[y*pixel_width + x + 1] : 0;
				unsigned char colour = 4;

				if (invert)
					colour |= ((byte2 & 1) << 1) | (byte1 & 1);
				else
					colour |= ((byte1 & 1) << 1) | (byte2 & 1);

				colour_data[y*pixel_width + x] = colour;
				if (x < (pixel_width - 1))
					colour_data[y*pixel_width + x + 1] = colour;

				x++;
			}
			else
			{
				// Use three b&w Apple II pixels to look up colour (see emulator notes)

				unsigned char byte0 = x > 0 ? pixel_data[y*pixel_width + x - 1] : 0;
				unsigned char byte1 = pixel_data[y*pixel_width + x];
				unsigned char byte2 = x < (pixel_width - 1) ? pixel_data[y*pixel_width + x + 1] : 0;

				int group0 = byte0 & 4;
				int group1 = byte1 & 4;
				int group2 = byte2 & 4;

				int pixel0 = byte0 & 1;
				int pixel1 = byte1 & 1;
				int pixel2 = byte2 & 1;

				if ((x & 1) == invert)
				{
					colour_data[y*pixel_width + x] = group1 | odd_columns[pixel0 + pixel1 * 2 + pixel2 * 4];
				}
				else
				{
					colour_data[y*pixel_width + x] = group1 | even_columns[pixel0 + pixel1 * 2 + pixel2 * 4];
				}
			}

			// Colour use tracking - not that interesting now

			total_colours[colour_data[y*pixel_width + x]]++;
		}
	}

	return calc_image_width_from_colour(colour_data, pixel_width, pixel_height);
}

int calc_mode5_size(unsigned char *colour_data, int pixel_width, int pixel_height)
{
	int expanded_width = 8 * pixel_width / 7;
	int reduced_width = expanded_width / 2;
	int mode5_width = (reduced_width + 3) / 4;
	int mode5_height = pixel_height;

	int mode5_bytes = mode5_width * mode5_height;

	printf("%d x %d = %d bytes, %d x %d pixels at 2bpp half width\n", mode5_width, mode5_height, mode5_bytes, reduced_width, pixel_height);

	return mode5_bytes + 4;
}

int get_colour(unsigned char *colour_data, int pixel_width, int pixel_height, int x, int y)
{
	if (x < 0 || x >= pixel_width || y < 0 || y >= pixel_height)
		return BLACK1;

	return colour_data[y * pixel_width + x];
}

int convert_colour_to_mode5(unsigned char *colour_data, int pixel_width, int pixel_height, unsigned char *beebptr)
{
	int expanded_width = 8 * pixel_width / 7;
	int reduced_width = expanded_width / 2;
	int mode5_width = (reduced_width + 3) / 4;
	int mode5_height = pixel_height;

	int mode5_bytes = mode5_width * mode5_height;

	unsigned char *temp = beebptr;

	if (beebptr)
	{
		*beebptr++ = mode5_width;
		*beebptr++ = mode5_height;
	}

	int width_parity = mode5_width & 1;

	for (int y = 0; y < mode5_height; y++)
	{

		for (int x8 = 0; x8 < mode5_width; x8++)
		{
			int x_parity = x8 & 1;
			unsigned char beebbyte = 0;

			// Turn 7 Apple II B&W pixels into 4 Beeb colour pixels
			// Eventually ask an artist to redraw everything

			// For now just point sample

						int c0 = get_colour(colour_data, pixel_width, pixel_height, ((x8 * 4) + 0)*pixel_width / reduced_width, y);
						int c1 = get_colour(colour_data, pixel_width, pixel_height, ((x8 * 4) + 1)*pixel_width / reduced_width, y);
						int c2 = get_colour(colour_data, pixel_width, pixel_height, ((x8 * 4) + 2)*pixel_width / reduced_width, y);
						int c3 = get_colour(colour_data, pixel_width, pixel_height, ((x8 * 4) + 3)*pixel_width / reduced_width, y);

			// Or select specific pixels to double-up

			if (x_parity == 0)
			{
				c0 = get_colour(colour_data, pixel_width, pixel_height, x8 * 7 + 0, y);
				c1 = get_colour(colour_data, pixel_width, pixel_height, x8 * 7 + 2, y);
				c2 = get_colour(colour_data, pixel_width, pixel_height, x8 * 7 + 4, y);
				c3 = get_colour(colour_data, pixel_width, pixel_height, x8 * 7 + 6, y);
			}
			else
			{
				if (width_parity == 1)
				{
					c0 = get_colour(colour_data, pixel_width, pixel_height, x8 * 7 - 1, y);
					c1 = get_colour(colour_data, pixel_width, pixel_height, x8 * 7 + 1, y);
					c2 = get_colour(colour_data, pixel_width, pixel_height, x8 * 7 + 3, y);
					c3 = get_colour(colour_data, pixel_width, pixel_height, x8 * 7 + 5, y);
				}
				else
				{
					c0 = get_colour(colour_data, pixel_width, pixel_height, x8 * 7 + 1, y);
					c1 = get_colour(colour_data, pixel_width, pixel_height, x8 * 7 + 3, y);
					c2 = get_colour(colour_data, pixel_width, pixel_height, x8 * 7 + 3, y);
					c3 = get_colour(colour_data, pixel_width, pixel_height, x8 * 7 + 5, y);
				}
			}

			beebbyte = beeb_logical_colour_to_screen_pixel[apple_colour_to_beeb_logical_colour[c0]][0]
				| beeb_logical_colour_to_screen_pixel[apple_colour_to_beeb_logical_colour[c1]][1]
				| beeb_logical_colour_to_screen_pixel[apple_colour_to_beeb_logical_colour[c2]][2]
				| beeb_logical_colour_to_screen_pixel[apple_colour_to_beeb_logical_colour[c3]][3];

//			printf("y=%d x8=%d c0=%d c1=%d c2=%d c3=%d l0=%d l1=%d l2=%d l3=%d p0=0x%2x p1=0x%2x p2=0x%2x p3=0x%2x b=0x%2x\n", y, x8, c0, c1, c2, c3, apple_colour_to_beeb_logical_colour[c0], apple_colour_to_beeb_logical_colour[c1], apple_colour_to_beeb_logical_colour[c2], apple_colour_to_beeb_logical_colour[c3], beeb_logical_colour_to_screen_pixel[apple_colour_to_beeb_logical_colour[c0]][0], beeb_logical_colour_to_screen_pixel[apple_colour_to_beeb_logical_colour[c1]][1], beeb_logical_colour_to_screen_pixel[apple_colour_to_beeb_logical_colour[c2]][2], beeb_logical_colour_to_screen_pixel[apple_colour_to_beeb_logical_colour[c3]][3], beebbyte);

			*beebptr++ = beebbyte;
		}
	}

	return 2 + mode5_bytes;
}

int get_pixel(unsigned char *pixel_data, int pixel_width, int pixel_height, int x, int y)
{
	if (x < 0 || x >= pixel_width || y < 0 || y >= pixel_height)
		return 0;

	return pixel_data[y * pixel_width + x];
}

int calc_mode4_size(unsigned char *colour_data, int colour_width, int pixel_height)
{
	int mode4_width = (colour_width + 7) / 8;
	int mode4_height = pixel_height;

	int mode4_bytes = mode4_width * mode4_height;

	printf("%d x %d = %d bytes, %d x %d pixels\n", mode4_width, mode4_height, mode4_bytes, colour_width, pixel_height);

	return mode4_bytes + 4;
}

int convert_pixels_to_mode4(unsigned char *pixel_data, int pixel_width, int pixel_height, int colour_width, unsigned char *beebptr)
{
	// In this case colour_width is <= pixel_width
	// Now not using colour_width

	int mode4_width = (pixel_width + 7) / 8;
	int mode4_height = pixel_height;

	int mode4_bytes = mode4_width * mode4_height;

	unsigned char *temp = beebptr;

	if (beebptr)
	{
		*beebptr++ = mode4_width;
		*beebptr++ = mode4_height;

		for (int y = 0; y < mode4_height; y++)
		{
			for (int x8 = 0; x8 < mode4_width; x8++)
			{
				unsigned char beebbyte = 0;
				
				for (int p = 0; p < 8; p++)
				{
					if( get_pixel(pixel_data, pixel_width, pixel_height, x8 * 8 + p, y) & 0x3 )
						beebbyte |= 1 << (7 - p);
				}

				*beebptr++ = beebbyte;
			}
		}
	}

	return 2 + mode4_bytes;
}

int main(int argc, char **argv)
{
	cimg_usage("POP asset convertor.\n\nUsage : pop2beeb [options]");
	const char *const inputname = cimg_option("-i", (char*)0, "Input filename");
	const char *const outputname = cimg_option("-o", (char*)0, "Output filename");
	const int mode = cimg_option("-mode", 4, "BBC MODE number");
	const bool test = cimg_option("-test", false, "Save test images");
	const bool flip = cimg_option("-flip", false, "Flip pixels in Y");
	const bool simple = cimg_option("-simple", false, "Use simple colour conversion");


	if (cimg_option("-h", false, 0)) std::exit(0);
	if (inputname == NULL)  std::exit(0);

	FILE *input = fopen(inputname, "rb");
	if (!input) std::exit(0);

	char parityfile[256];
	sprintf(parityfile, "%s.txt", inputname);

	FILE *parity = fopen(parityfile, "rb");

	fread(imagetab, 1, 10 * 1024, input);				// forgotten how to file length of file!
	fclose(input);
	input = NULL;

	int num_images = imagetab[0];

	printf("Num images = %d\n", num_images);
	printf("Image addresses:\n");

	for (int i = 0; i < num_images; i++)
	{
		image_addrs[i] = GET_16BIT(imagetab + 1 + i * 2);
		printf("[%d] 0x%x\n", i, image_addrs[i]);
	}
	image_addrs[num_images] = GET_16BIT(imagetab + 1 + num_images * 2);
	printf("First free address = 0x%x\n", image_addrs[num_images]);

	unsigned char *image_ptr = imagetab + 1 + num_images * 2 + 2;

	int total_bytes = 0;
	int total_width = 0;
	int max_height = 0;

	for (int c = 0; c < 8; c++)
	{
		total_colours[c] = 0;
	}

	for (int i = 0; i < num_images; i++)
	{
		image_size[i][0] = *image_ptr++;
		image_size[i][1] = *image_ptr++;

		int bytes = image_size[i][0] * image_size[i][1];
		total_bytes += bytes;

		for (int d = 0; d < bytes; d++)
		{
			image_data[i][d] = *image_ptr++;
		}

		pixel_size[i][0] = convert_apple_to_pixels(image_data[i], image_size[i][0], image_size[i][1], pixels[i]);
		pixel_size[i][1] = image_size[i][1];

		if (pixel_size[i][1] > max_height)
			max_height = pixel_size[i][1];

		total_width += pixel_size[i][0] + 8;

		printf("Image %d: %d x %d = %d bytes, %d x %d pixels\n", i, image_size[i][0], image_size[i][1], bytes, pixel_size[i][0], pixel_size[i][1]);

		if( flip )
		{
			flip_pixels_in_y(pixels[i], pixel_size[i][0], pixel_size[i][1]);
		}
		
		bool invert = 0;

		if (parity)
		{
			invert = fgetc(parity) == '1' ? 1 : 0;
		}

		colour_width[i] = convert_pixels_to_colour(pixels[i], pixel_size[i][0], pixel_size[i][1], colours[i], invert, simple);
	}

	printf("Total bytes = %d\n", total_bytes);
	printf("Total colours:\n");

	for (int c = 0; c < 8; c++)
	{
		printf("[%d] %d\n", c, total_colours[c]);
	}

	if (test)
	{
		printf("Test: %d x %d\n", total_width, max_height);

		CImg<unsigned char> img(total_width, max_height, 1, 3, 0);

		int current_x = 0;

		for (int i = 0; i < num_images; i++)
		{
			int height = pixel_size[i][1];
			int current_y = max_height - height;

			for (int y = 0; y < height; y++)
			{
				int width = pixel_size[i][0];
				for (int x = 0; x < width; x++)
				{
					img(current_x + x, current_y + y, 0) = palette[colours[i][y*width + x]][0];
					img(current_x + x, current_y + y, 1) = palette[colours[i][y*width + x]][1];
					img(current_x + x, current_y + y, 2) = palette[colours[i][y*width + x]][2];
				}
			}

			current_x += pixel_size[i][0] + 8;
		}

		char testname[256];
		sprintf(testname, "%s.png", inputname);
		img.save(testname);
	}

	int total_mode5 = 3;		// num_images + free ptr
	int total_mode4 = 3;

	for (int i = 0; i < num_images; i++)
	{
		if (mode == 5)
		{
			printf("Image[%d]: MODE5=", i);
			total_mode5 += calc_mode5_size(colours[i], pixel_size[i][0], pixel_size[i][1]);
		}

		if ( mode == 4)
		{
			printf("Image[%d]: MODE4=", i);
			total_mode4 += calc_mode4_size(colours[i], pixel_size[i][0], pixel_size[i][1]);
		}
	}

	printf("Original Apple bytes = %d\n", total_bytes);

	printf("Total MODE5 bytes = %d\n", total_mode5);
	printf("Size vs Apple = %f%%\n", 100.0f * total_mode5 / (float)total_bytes);

	printf("Total MODE4 bytes = %d\n", total_mode4);
	printf("Size vs Apple = %f%%\n", 100.0f * total_mode4 / (float)total_bytes);

	if (outputname)
	{
		FILE *output = fopen(outputname, "wb");
		
		if (output)
		{
			unsigned char *beebdata = (unsigned char*)malloc((mode == 4 ? total_mode4 : total_mode5) + num_images * 4 + 3);
			unsigned char *beebptr = beebdata;

			*beebptr++ = num_images;
			for (int i = 0; i < num_images; i++)
			{
				*beebptr++ = 0xff;
				*beebptr++ = 0xff;		// don't know pointers yet
			}
			*beebptr++ = 0xff;
			*beebptr++ = 0xff;			// don't know free yet

			// Write Beeb data

			for (int i = 0; i < num_images; i++)
			{
				// Now we know our address

				beebdata[1 + i * 2] = LO(beebptr - beebdata);
				beebdata[2 + i * 2] = HI(beebptr - beebdata);


				int bytes_written = 0;
				
				if (mode == 4)
				{
					bytes_written += convert_pixels_to_mode4(pixels[i], pixel_size[i][0], pixel_size[i][1], colour_width[i], beebptr);
				}

				if (mode == 5)
				{
					bytes_written += convert_colour_to_mode5(colours[i], pixel_size[i][0], pixel_size[i][1], beebptr);
				}

				beebptr += bytes_written;
			}

			// Write free address

			beebdata[1 + num_images * 2] = LO(beebptr - beebdata);
			beebdata[2 + num_images * 2] = HI(beebptr - beebdata);

			// Write file

			fwrite(beebdata, 1, beebptr - beebdata, output);
			fclose(output);
			output = NULL;
		}
	}

	if (parity)
		fclose(parity);
		
	return 0;
}

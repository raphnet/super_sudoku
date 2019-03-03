#include <stdio.h>
#include <stdlib.h>
#include <string.h>


static char linebuf[4096];


int countChar(const char *s, int c)
{
	int occurences = 0;

	while ((s = strchr(s, c))) {
		occurences++;
		s++;
	}

	return occurences;
}

int processLine(const char *line, unsigned char *dst, int dst_size)
{
	int i = 0;
	const char *p = line;

	for (i=0; i<dst_size; i++) {
		dst[i] = atoi(p);
		p = strchr(p, ',');
		if (!p) {
			break;
		}
		p++;
	}

	return i+1;
}

int outputLine(const unsigned char *tdata, int width, FILE *outfptr)
{
	int i;
	unsigned char tmp[2];

	for (i=0; i<width; i++) {
		tmp[0] = tdata[i];
		tmp[1] = 0;
		fwrite(tmp, 2, 1, outfptr);
	}

	return 0;
}

int main(int argc, char **argv)
{
	FILE *infptr = NULL, *outfptr = NULL;
	unsigned char *tdata = NULL;
	char first = 1;
	int width;
	int retval = -1;
	int lineno = 1;

	if (argc < 3) {
		fprintf(stderr, "Usage: ./csv2bin input.csv output.bin\n");
		return -1;
	}

	infptr = fopen(argv[1], "r");
	if (!infptr) {
		perror(argv[1]);
		goto err;
	}

	outfptr = fopen(argv[2], "wb");
	if (!outfptr) {
		perror(argv[2]);
		goto err;
	}

	while (fgets(linebuf, sizeof(linebuf), infptr)) {
		if (first) {
			width = countChar(linebuf, ',') + 1;
			first = 0;
			printf("Tilemap width: %d\n", width);

			tdata = malloc(width);
			if (!tdata) {
				perror("malloc");
				goto err;
			}
		}

		if (processLine(linebuf, tdata, width) != width) {
			fprintf(stderr, "Not %d fields at line %d\n", width, lineno);
			goto err;
		}

		outputLine(tdata, width, outfptr);

		lineno++;
	}

	retval = 0;

err:
	if (infptr) {
		fclose(infptr);
	}

	if (outfptr) {
		fclose(outfptr);
	}

	if (tdata) {
		free(tdata);
	}

	return retval;
}


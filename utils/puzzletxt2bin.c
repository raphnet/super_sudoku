#include <stdio.h>
#include <string.h>
#include <ctype.h>

int main(int argc, char **argv)
{
	FILE *in_fptr = NULL, *out_fptr = NULL;
	const char *infilename, *outfilename;
	int retval = -1, i;
	char linebuf[100];
	unsigned char puzzlebin[128];
	int line = 1;

	if (argc < 3) {
		fprintf(stderr, "Usage: ./puzzletxt2bin infile.txt outfile.bin\n");
		return 1;
	}

	infilename = argv[1];
	outfilename = argv[2];

	in_fptr = fopen(infilename, "r");
	if (!in_fptr) {
		perror(infilename);
		goto error;
	}

	out_fptr = fopen(outfilename, "wb");
	if (!out_fptr) {
		perror(outfilename);
		goto error;
	}

	memset(puzzlebin, 0, sizeof(puzzlebin));

	while (fgets(linebuf, sizeof(linebuf), in_fptr)) {
		printf("Line: %s", linebuf);
		if (strlen(linebuf) < 81) {
			fprintf(stderr, "line %d: Invalid input (line shorter than 81 bytes)\n", line);
			goto error;
		}

		printf("P: ");
		for (i=0; i<81; i++)
		{
			if (linebuf[i] == '.') {
				puzzlebin[i] = 0;
			} else if (isdigit(linebuf[i])) {
				puzzlebin[i] = linebuf[i]-'0';
				printf("%d", puzzlebin[i]);
			} else {
				fprintf(stderr, "line %d: Invalid input (found non-digit character)\n", line);
			}
		}
		printf("\n");

		fwrite(puzzlebin, sizeof(puzzlebin), 1, out_fptr);
		line++;
	}


	retval = 0;

error:
	if (out_fptr)
		fclose(out_fptr);
	if (in_fptr)
		fclose(in_fptr);

	return retval;
}

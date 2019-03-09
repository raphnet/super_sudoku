#include <stdio.h>

#define GRID_SIZE	9

void outputNeighbor(int x, int y)
{
	//  each cell occupies 2 bytes in memory. Hence the multiplications here.
	printf("$%02x, ", y * GRID_SIZE * 2 + x * 2 );

//	printf("[%d,%d] ", x, y);
}


int computeNbrs(int x, int y)
{
	int X, Y, i, j;

	// Same row
	for (X=0; X<x; X++) {
		outputNeighbor(X,y);
	}
	for (X=x+1; X<GRID_SIZE; X++) {
		outputNeighbor(X,y);
	}

	// Same column
	for (Y=0; Y<y; Y++) {
		outputNeighbor(x,Y);
	}
	for (Y=y+1; Y<GRID_SIZE; Y++) {
		outputNeighbor(x,Y);
	}

	// Same cell AND not already output above

	for (Y = (y/3)*3, j = 0; j < 3; j++,Y++) {
		for (X = (x/3)*3, i = 0; i < 3; i++,X++) {
			if (Y != y && X != x) {
				outputNeighbor(X,Y);
			}
		}
	}

	return 0;
}

int main(int argc, char **argv)
{
	int y,x;

	printf(";\n; Generated by neighbors.c\n;\n");

	// First the lists of neighbors
	for (y=0; y<GRID_SIZE; y++) {
		for (x=0; x<GRID_SIZE; x++) {
			printf("_nbors_%d_%d: .dw ", x, y);
			computeNbrs(x,y);
			printf("\n");
		}
	}

	// Now the 9x9 word array pointing to each list
	printf("neighbor_list:\n");
	for (y=0; y<GRID_SIZE; y++) {
		printf("    .dw ");
		for (x=0; x<GRID_SIZE; x++) {
			printf("_nbors_%d_%d, ", x, y);
		}
		printf("\n");
	}

	return 0;
}

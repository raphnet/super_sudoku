#!/bin/bash

N_PUZZLES=100

function generatePuzzles
{
	echo "Level: $1..."
	qqwing --generate $N_PUZZLES --one-line --difficulty $1 > $1.txt
}

echo "Generating puzzles..."

generatePuzzles simple
generatePuzzles easy
generatePuzzles intermediate
generatePuzzles expert



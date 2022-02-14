# Super Sudoku

A Sudoku puzzle game compatible with the Super Nintendo.

This homebrew was programmed for fun as part of the March 2019 RetroChallenge. One of the very few,
if not the only game to support the NTT Data Keypad, besides the original JRA PAT online horse race betting system.

Features:

 - 4 Difficulty levels, 100 unique puzzles each. (Total of 400 puzzles!)
 - Simple Hint engine. Detects sole cell candidate, unique row candidate and unique column candidate.
 - Invalid entry detection.
 - Auto-solver (please use it after giving up)
 - Supports the NTT Data Keypad for direct number entry!
 - Also supports standard SNES controllers: Use L/R to cycle through valid values for a given cell.


## Projet log / Making-of

See my RetroChallenge March 2019 projet page:

https://www.raphnet.net/divers/retro_challenge_2019_03/index_en.php


## Compilation

On a linux system with the required utilities in your path, simply type make.

Required utilities are:

 - wla-dx assembler: wla-65816, wla-spc700, wla-link : See https://github.com/vhelin/wla-dx
 - png2snes : https://github.com/NewLunarFire/png2snes
 - BRRtools : https://github.com/Optiroc/BRRtools

I usually setup my environment by running 'source setupenv.sh' in the project directory.
setupenv.sh assumes that the tools mentionned above were cloned in the parent directory.

Also, recommended, if you would like to use 'make run':

 - bsnes-plus : https://github.com/devinacker/bsnes-plus

Optional, if you generate new puzzles: (see puzzles/regen.sh)

 - qqwing : https://github.com/stephenostermiller/qqwing

Optional, to modify the title screen and grid tilemaps (.tmx files in tilemaps)

 - Tiled : https://github.com/mapeditor/tiled


## Use

With any good SNES emulator, or on real hardware.


## License

MIT



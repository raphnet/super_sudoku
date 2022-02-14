#!/bin/sh -x

# This file lives in /snes/super_sudoku
# Other snes related tools are in the parent, hence the /.. here
#
BASEDIR=`pwd`/..

# Compiled from https://github.com/vhelin/wla-dx
export PATH=$PATH:$BASEDIR/wla-dx/binaries

# Compiled from https://github.com/NewLunarFire/png2snes
export PATH=$PATH:$BASEDIR/png2snes

# Compiled from https://github.com/Optiroc/BRRtools
export PATH=$PATH:$BASEDIR/BRRtools/bin

# Compiled from https://github.com/devinacker/bsnes-plus
export PATH=$PATH:$BASEDIR/bsnes-plus/bsnes/out

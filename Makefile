WLA65816=wla-65816
WLALINK=wlalink
EMULATOR=bsnes
PNG2SNES=png2snes -v
PNG2SNESFLAGS=--bitplanes 4 --tilesize 8 --binary

# Files included by main.asm. When they change, recompilation must be triggered.
DEPS=snesregs.inc misc_macros.inc header.inc snes_init.asm globals.inc

# note: New objects must also be added to linkfile.lnk
OBJS=main.o effects.o gamepads.o

ROMFILE=sudoku2019.sfc

all: $(ROMFILE)

$(ROMFILE): $(OBJS) linkfile.lnk
	wlalink -S linkfile.lnk $@ > wlalink.log

main.o: main.asm $(DEPS) main.vra main.cgr pattern.cgr pattern.vra title.map grid.map
	$(WLA65816) -o $@ $<

effects.o: effects.asm $(DEPS)
	$(WLA65816) -o $@ $<

gamepads.o: gamepads.asm $(DEPS)
	$(WLA65816) -o $@ $<

run: $(ROMFILE)
	$(EMULATOR) $(ROMFILE)

main.cgr: tilemaps/main.png
	$(PNG2SNES) $(PNG2SNESFLAGS) $< --output=main

main.vra: tilemaps/main.png
	$(PNG2SNES) $(PNG2SNESFLAGS) $< --output=main

pattern.cgr: tilemaps/pattern.png
	$(PNG2SNES) $(PNG2SNESFLAGS) $< --output=pattern

pattern.vra: tilemaps/pattern.png
	$(PNG2SNES) $(PNG2SNESFLAGS) $< --output=pattern

# Tiled .TMX -> .CSV
%.csv: tilemaps/%.tmx
	tiled $< --export-map $@

# .CSV to Binary (16 bit per tile)
%.map: %.csv csv2bin/csv2bin
	csv2bin/csv2bin $< $@

# Target to compile the CSV to BIN tool
csv2bin/csv2bin:
	$(MAKE) -C csv2bin

clean:
	rm -f *.vra *.cgr $(OBJS) $(ROMFILE) *.log *.sym *.map

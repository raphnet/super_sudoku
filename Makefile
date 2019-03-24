WLA65816=wla-65816
WLALINK=wlalink
EMULATOR=bsnes
PNG2SNES=png2snes -q

# Files included by main.asm. When they change, recompilation must be triggered.
DEPS=snesregs.inc misc_macros.inc header.inc snes_init.asm text.inc gamepads.inc cursor.inc bg1.inc

# note: New objects must also be added to linkfile.lnk
OBJS=main.o effects.o gamepads.o grid.o puzzles.o sprites.o text.o cursor.o solver.o clock.o bg1.o sound.o

ROMFILE=super_sudoku.sfc

all: $(ROMFILE)

$(ROMFILE): $(OBJS) linkfile.lnk
	wlalink -S linkfile.lnk $@ > wlalink.log

# main has more dependencies (graphics, etc)
main.o: main.asm $(DEPS) main.vra main.cgr pattern.cgr pattern.vra title.map grid.map sprites.cgr sprites.vra numbers.cgr numbers.vra numbers_green.cgr numbers_yellow.cgr numbers_orange.cgr
	$(WLA65816) -o $@ $<

# rule for other object files
%.o: %.asm $(DEPS)
	$(WLA65816) -o $@ $<

run: $(ROMFILE)
	$(EMULATOR) $(ROMFILE)

puzzles.o: puzzles.asm puzzles/simple.bin puzzles/easy.bin puzzles/intermediate.bin puzzles/expert.bin
	$(WLA65816) -o $@ $<

sound.o: sound.asm sound/sndcode.bin
	$(WLA65816) -o $@ $<

grid.o: grid.asm neighbors.asm
	$(WLA65816) -o $@ $<

main.cgr: tilemaps/main.png
	$(PNG2SNES) $< --output=main --bitplanes=4 --tilesize 8 --binary

main.vra: tilemaps/main.png
	$(PNG2SNES) $< --output=main --bitplanes=4 --tilesize 8 --binary

pattern.cgr: tilemaps/pattern.png
	$(PNG2SNES) $< --output=pattern --bitplanes=4 --tilesize 8 --binary

pattern.vra: tilemaps/pattern.png
	$(PNG2SNES) $< --output=pattern --bitplanes=4 --tilesize 8 --binary

sprites.vra: sprites/sprites.png
	$(PNG2SNES) --bitplanes 4 --tilesize 8 --binary $< --output sprites

sprites.cgr: sprites/sprites.png
	$(PNG2SNES) --bitplanes 4 --tilesize 8 --binary $< --output sprites

numbers.cgr: tilemaps/numbers.png
	$(PNG2SNES) --bitplanes 2 --tilesize 8 --binary $< --output numbers

numbers_green.cgr: tilemaps/numbers_green.png
	$(PNG2SNES) --bitplanes 2 --tilesize 8 --binary $< --output numbers_green

numbers_yellow.cgr: tilemaps/numbers_yellow.png
	$(PNG2SNES) --bitplanes 2 --tilesize 8 --binary $< --output numbers_yellow

numbers_orange.cgr: tilemaps/numbers_orange.png
	$(PNG2SNES) --bitplanes 2 --tilesize 8 --binary $< --output numbers_orange

numbers.vra: tilemaps/numbers.png
	$(PNG2SNES) --bitplanes 2 --tilesize 8 --binary $< --output numbers

puzzles/%.bin: puzzles/%.txt utils/puzzletxt2bin
	utils/puzzletxt2bin $< $@

sound/sndcode.bin: sound/main.asm
	$(MAKE) -C sound

# Tiled .TMX -> .CSV
%.csv: tilemaps/%.tmx
	tiled $< --export-map $@

# .CSV to Binary (16 bit per tile)
%.map: %.csv utils/csv2bin
	utils/csv2bin $< $@

# Target to compile the CSV to BIN tool
utils/csv2bin:
	$(MAKE) -C utils

utils/puzzletxt2bin:
	$(MAKE) -C utils

clean:
	rm -f -- *.vra *.cgr $(OBJS) $(ROMFILE) *.log *.sym *.map

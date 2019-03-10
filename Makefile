WLA65816=wla-65816
WLALINK=wlalink
EMULATOR=bsnes
PNG2SNES=png2snes -q

# Files included by main.asm. When they change, recompilation must be triggered.
DEPS=snesregs.inc misc_macros.inc header.inc snes_init.asm text.inc

# note: New objects must also be added to linkfile.lnk
OBJS=main.o effects.o gamepads.o grid.o puzzles.o sprites.o text.o

ROMFILE=sudoku2019.sfc

all: $(ROMFILE)

$(ROMFILE): $(OBJS) linkfile.lnk
	wlalink -S linkfile.lnk $@ > wlalink.log

# main has more dependencies (graphics, etc)
main.o: main.asm $(DEPS) main.vra main.cgr pattern.cgr pattern.vra title.map grid.map sprites.cgr sprites.vra numbers.cgr numbers.vra numbers_green.cgr
	$(WLA65816) -o $@ $<

# rule for other object files
%.o: %.asm $(DEPS)
	$(WLA65816) -o $@ $<

run: $(ROMFILE)
	$(EMULATOR) $(ROMFILE)

puzzles.o: puzzles.asm puzzles/simple.bin puzzles/easy.bin puzzles/intermediate.bin puzzles/expert.bin
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

numbers.vra: tilemaps/numbers.png
	$(PNG2SNES) --bitplanes 2 --tilesize 8 --binary $< --output numbers

puzzles/%.bin: puzzles/%.txt csv2bin/puzzletxt2bin
	csv2bin/puzzletxt2bin $< $@

# Tiled .TMX -> .CSV
%.csv: tilemaps/%.tmx
	tiled $< --export-map $@

# .CSV to Binary (16 bit per tile)
%.map: %.csv csv2bin/csv2bin
	csv2bin/csv2bin $< $@

# Target to compile the CSV to BIN tool
csv2bin/csv2bin:
	$(MAKE) -C csv2bin

csv2bin/puzzletxt2bin:
	$(MAKE) -C csv2bin

clean:
	rm -f -- *.vra *.cgr $(OBJS) $(ROMFILE) *.log *.sym *.map
WLA-SPC700=wla-spc700
WLALINK=wlalink

DEPS=error.brr

# note: New objects must also be added to linkfile.lnk
OBJS=main.o

ROMFILE=sndcode.bin

all: $(ROMFILE)

$(ROMFILE): $(OBJS) linkfile.lnk
	wlalink -S linkfile.lnk $@ > wlalink.log

# main has more dependencies (graphics, etc)
main.o: main.asm $(DEPS)
	$(WLA-SPC700) -o $@ $<

# rule for other object files
%.o: %.asm $(DEPS)
	$(WLA-SPC700) -o $@ $<

clean:
	rm -f -- $(OBJS) $(ROMFILE) *.log *.sym *.map

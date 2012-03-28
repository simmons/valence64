
all: valence64.prg setup.prg hello.prg vncclient/vncclient.c64 combined.prg disk

clean:
	$(MAKE) TARGET=c64 -C vncclient sterile
	rm -f valence64.prg
	rm -f combined.prg
	rm -f setup.prg
	rm -f valence64.d64
	rm -f hello.o hello.prg

vncclient/vncclient.c64:
	$(MAKE) TARGET=c64 -C vncclient build

combined.prg: valence64.prg vncclient/vncclient.c64
	./combine.pl valence64.prg vncclient/vncclient.c64 vncclient/contiki-c64.map > combined.prg

%.o: %.asm
	ca65 -o $@ $<

%.prg: %.o %.cfg
	ld65 -C $(lastword $^) -o $@ $<

%.prg: %.bas
	petcat -c -w2 -o $@ -- $<

disk:
	c1541 -format valence64,00 d64 valence64.d64
	c1541 -attach valence64.d64 -write combined.prg valence64,p
	c1541 -attach valence64.d64 -write setup.prg setup,p
	c1541 -attach valence64.d64 -write assets/contiki.cfg contiki.cfg,u
	c1541 -attach valence64.d64 -write assets/valence.cfg valence.cfg,u
	c1541 -attach valence64.d64 -write vncclient/cs8900a.eth cs8900a.eth,u
	c1541 -attach valence64.d64 -write vncclient/lan91c96.eth lan91c96.eth,u
	#./randomizesrcport.pl

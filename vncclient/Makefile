
CC65_HOME=/usr/local/lib/cc65

PROJECT_SOURCEFILES=splash.S

# don't rm the .co file..
.SECONDARY:

CONTIKI_PROJECT = vncclient
all: $(CONTIKI_PROJECT)

CFLAGS = -DWITH_UIP=1 -DUIP_CONF_TCP=1 -DWITH_CLIENT=1

CONTIKI = ../../contiki-2.5

include $(CONTIKI)/Makefile.include

LDFLAGS = -Ln vncclient.lbl -C vncclient.cfg -D __STACKSIZE__=0x200 -u _main -m contiki-$(TARGET).map

linkerconfig:
	start=`wc -c < ../valence64.prg`; \
	start=`expr 2047 + $$start`; \
	./mkcfg.pl $$start < vncclient.cfg.template > vncclient.cfg

sterile:
	$(MAKE) -C . clean
	rm -f vncclient.c64
	rm -f vncclient.lbl
	rm -f vncclient.cfg
	rm -f *.eth

build: linkerconfig
	$(MAKE) -C . all


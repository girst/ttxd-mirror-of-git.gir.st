
CC=gcc
CFLAGS=-Wall -g -O2 -I.

PROG=vtx2ascii

$(PROG): main.o fileio.o vtxtools.o vtxdecode.o
	$(CC) $(CFLAGS) -o $@ $^

clean:
	rm -f *.o *~

distclean: clean
	strip $(PROG)

realclean: clean
	rm -f $(PROG)

INCS=
CFLAGS= -Wall
CC=gcc

all: dvbtext

# Delete the following line if you are not using a
# "NEWSTRUCT" driver.  If you are using a "NEWSTRUCT"
# driver, it must be later than October 10th 2002

NEWSTRUCT=1

ifdef NEWSTRUCT
  CFLAGS += -DNEWSTRUCT
  INCS += -I ../DVB/include
else
  INCS += -I ../DVB/ost/include
endif

dvbtext: dvbtext.c tables.h
	$(CC) $(CFLAGS) $(INCS) -o dvbtext dvbtext.c

clean:
	rm -f  *.o *~ dvbtext

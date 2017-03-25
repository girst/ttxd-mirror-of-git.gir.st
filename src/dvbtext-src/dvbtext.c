/* 

dvbtext - a teletext decoder for DVB cards. 
(C) Dave Chapman <dave@dchapman.com> 2001.

The latest version can be found at http://www.linuxstb.org/dvbtext

Thanks to:  

Ralph Metzler for his work on both the DVB driver and his old
vbidecode package (some code and ideas in dvbtext are borrowed
from vbidecode).

Copyright notice:

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
    
*/

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <unistd.h>
#ifdef NEWSTRUCT
#include <linux/dvb/dmx.h>
#else
#include <ost/dmx.h>
#endif
#include "tables.h"

#define VERSION "0.1"
#define VTXDIR "/run/ttxd/spool"
#define ADAPTER "0"
//#define VTXDIR "/opt/TTx_Server/spool"
//#define VTXDIR "/video/vtx"
#define USAGE "\nUSAGE: dvbtext tpid1 tpid2 tpid3 .. tpid8\n\n"

// There seems to be a limit of 8 teletext streams - OK for most (but
// not all) transponders.
#define MAX_CHANNELS 9

typedef struct mag_struct_ {
   int valid;
   int mag;
   unsigned char flags;
   unsigned char lang;
   int pnum,sub;
   unsigned char pagebuf[25*40];
} mag_struct;

// FROM vbidecode
// unham 2 bytes into 1, report 2 bit errors but ignore them
unsigned char unham(unsigned char a,unsigned char b)
{
  unsigned char c1,c2;
  
  c1=unhamtab[a];
  c2=unhamtab[b];
//  if ((c1|c2)&0x40) 
//      fprintf(stderr,"bad ham!");
  return (c2<<4)|(0x0f&c1);
}

void write_data(unsigned char* b, int n) {
  int i;

  for (i=0;i<n;i++) {
     fprintf(stderr," %02x",b[i]);
  }
  fprintf(stderr,"\n");
  for (i=0;i<n;i++) {
     fprintf(stderr,"%c",b[i]&0x7f);
  }
  fprintf(stderr,"\n");
}

void set_line(mag_struct *mag, int line, unsigned char* data,int pnr) {
   unsigned char c;
   FILE * fd;
   char fname[80];
   unsigned char buf;

   if (line==0) {
     mag->valid=1;
     memset(mag->pagebuf,' ', 25*40);
     mag->pnum=unham(data[0],data[1]); // The lower two (hex) numbers of page
     if (mag->pnum==0xff) return;  // These are filler lines. Can use to update clock
//     fprintf(stderr,"pagenum: %03x\n",c+mag->mag*0x100);
     mag->flags=unham(data[2],data[3])&0x80;
     mag->flags|=(c&0x40)|((c>>2)&0x20);
     c=unham(data[6],data[7]);
     mag->flags|=((c<<4)&0x10)|((c<<2)&0x08)|(c&0x04)|((c>>1)&0x02)|((c>>4)&0x01);
     mag->lang=((c>>5) & 0x07);

     mag->sub=(unham(data[4],data[5])<<8)|(unham(data[2],data[3])&0x3f7f);
//    mag->pnum = (mag->mag<<8)|((mag->sub&0x3f7f)<<16)|page;
//    fprintf(stderr,"page: %x, pnum: %x, sub: %x\n",page,mag->pnum,mag->sub);
   }

   if (mag->valid) {
     if (line <= 23) {
       memcpy(mag->pagebuf+40*line,data,40);
     }

     if (line==23) {
       sprintf(fname,"%s/%d/%03x_%02x.vtx",VTXDIR,pnr,mag->pnum+(mag->mag*0x100),mag->sub&0xff);
//       fprintf(stderr,"Writing to file %s\n",fname);
       if ((fd=fopen(fname,"w"))) {
         fwrite("VTXV4",1,5,fd);
         buf=0x01; fwrite(&buf,1,1,fd);
         buf=mag->mag;  fwrite(&buf,1,1,fd);
         buf=mag->pnum; fwrite(&buf,1,1,fd);
         buf=0x00; fwrite(&buf,1,1,fd);    /* subpage?? */
         buf=0x00; fwrite(&buf,1,1,fd);  
         buf=0x00; fwrite(&buf,1,1,fd);  
         buf=0x00; fwrite(&buf,1,1,fd);  
         fwrite(mag->pagebuf,1,24*40,fd);
         fclose(fd);
       }
       mag->valid=0;
     }
  }
}

#ifdef NEWSTRUCT
void set_tt_filt(int fd,uint16_t tt_pid)
{
	struct dmx_pes_filter_params pesFilterParams;

	pesFilterParams.pid     = tt_pid;
	pesFilterParams.input   = DMX_IN_FRONTEND;
	pesFilterParams.output  = DMX_OUT_TS_TAP;
        pesFilterParams.pes_type = DMX_PES_OTHER;
	pesFilterParams.flags   = DMX_IMMEDIATE_START;

	if (ioctl(fd, DMX_SET_PES_FILTER, &pesFilterParams) < 0)  {
                fprintf(stderr,"FILTER %i: ",tt_pid);
		perror("DMX SET PES FILTER");
        }
}
#else
void set_tt_filt(int fd,uint16_t tt_pid)
{
	struct dmxPesFilterParams pesFilterParams;

	pesFilterParams.pid     = tt_pid;
	pesFilterParams.input   = DMX_IN_FRONTEND;
	pesFilterParams.output  = DMX_OUT_TS_TAP;
        pesFilterParams.pesType = DMX_PES_OTHER;
	pesFilterParams.flags   = DMX_IMMEDIATE_START;

	if (ioctl(fd, DMX_SET_PES_FILTER, &pesFilterParams) < 0)  {
                fprintf(stderr,"FILTER %i: ",tt_pid);
		perror("DMX SET PES FILTER");
        }
}
#endif

int main(int argc, char **argv)
{
  int pid;
  int i,j,n,m;
  unsigned char buf[188]; /* data buffer */
  unsigned char mpag,mag,pack;

  int fd_dvr;

  /* Test channels - Astra 19E, 11837h, SR 27500 - e.g. ARD */
  int pids[MAX_CHANNELS];
  int pnrs[MAX_CHANNELS]={ 1,2,3,4,5,6,7,8 }; /* Directory names */

  mag_struct mags[MAX_CHANNELS][8];
  int fd[MAX_CHANNELS];
  int count;

  printf("dvbtext v%s - (C) Dave Chapman 2001\n",VERSION);
  printf("Latest version available from http://www.linuxstb.org/dvbtext\n");

  if (argc==1) {
    printf(USAGE);
    return(-1);
  } else {
    count=0;
    for (i=1;i<argc;i++) {
      pids[count]=atoi(argv[i]);
      if (pids[count]) { count++ ; }
    }
  }

  if (count) {
    if (count > 8) {
      printf("\nSorry, you can only set up to 8 filters.\n\n");
      return(-1);
    } else {
      printf("Decoding %d teletext stream%s into %s/*\n",count,(count==1 ? "" : "s"),VTXDIR);
    }
  } else {
    printf(USAGE);
    return(-1);
  }

  for (m=0;m<count;m++) {
    mags[m][0].mag=8;
    for (i=1;i<8;i++) { 
      mags[m][i].mag=i; 
      mags[m][i].valid=0;
    }
  }

  for (i=0;i<count;i++) {  
#ifdef NEWSTRUCT
    if((fd[i] = open("/dev/dvb/adapter"ADAPTER"/demux0",O_RDWR)) < 0){
#else
    if((fd[i] = open("/dev/ost/demux",O_RDWR)) < 0){
#endif
      fprintf(stderr,"FD %i: ",i);
      perror("DEMUX DEVICE: ");
      return -1;
    }
  }

#ifdef NEWSTRUCT
  if((fd_dvr = open("/dev/dvb/adapter"ADAPTER"/dvr0",O_RDONLY)) < 0){
#else
  if((fd_dvr = open("/dev/ost/dvr",O_RDONLY)) < 0){
#endif
    perror("DVR DEVICE: ");
    return -1;
  }

  /* Now we set the filters */
  for (i=0;i<count;i++) {
    set_tt_filt(fd[i],pids[i]);
  }

  while (1) {
    n = read(fd_dvr,buf,188);
//          fprintf(stderr,"Read %d bytes\n",n);
//          n=fwrite(buf,1,n,stdout);
//          fprintf(stderr,"Wrote %d bytes\n",n);

    m=-1;
    pid= ((buf[1] & 0x1f) << 8) | buf[2];
    for (i=0;i<count;i++) {
        if (pid==pids[i]) { 
//          fprintf(stderr,"Received packet for PUD %i\n",pid);
          m=i; 
        }
    }

    if (pid!=-1) {
//          fprintf(stderr,"pid: %i\n",pid);
//          fprintf(stderr,"ts_id %i\n",buf[3]);

//      fprintf(stderr,"data_identifier =0x%02x\n",buf[0x31]);
  for (i=0;i<4;i++) {
    if (buf[4+i*46]==2) {
      for (j=(8+i*46);j<(50+i*46);j++) { buf[j]=invtab[buf[j]]; }
//          fprintf(stderr,"data[%d].data_unit_id    =0x%02x\n",i,buf[0x4+i*46]);
//          fprintf(stderr,"data[%d].data_unit_length=0x%02x\n",i,buf[0x5+i*46]);
//          fprintf(stderr,"data[%d].fp_lo           =0x%02x\n",i,buf[0x6+i*46]);
//          fprintf(stderr,"data[%d].fc              =0x%02x\n",i,buf[0x7+i*46]);
//          fprintf(stderr,"data[%d].mapa_1          =0x%02x\n",i,buf[0x8+i*46]);
//          fprintf(stderr,"data[%d].mapa_2          =0x%02x\n",i,buf[0x9+i*46]);
//          fprintf(stderr,"data[%d].data            =",i);
//          write_data(&buf[0x0a+i*46],40);

      mpag=unham(buf[0x8+i*46],buf[0x9+i*46]);
      mag=mpag&7;
      pack=(mpag>>3)&0x1f;
      set_line(&mags[m][mag],pack,&buf[10+i*46],pnrs[m]);
//          fprintf(stderr,"i: %d mag=%d,pack=%d\n",i,mag,pack);
      }
    }
//    fflush(stdout);

//          fwrite(buf,1,n,stdout);
   }
  }

  /* We never get here - but I'm including this for completeness. */
  /* I hope that this doesn't cause any problems */
  for (i=0;i<count;i++) close(fd[i]);
  close(fd_dvr);
  return(0);
}

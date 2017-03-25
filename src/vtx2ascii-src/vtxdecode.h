#ifndef VTXDECODE_H_INCLUDED
#define VTXDECODE_H_INCLUDED

/* $Id: vtxdecode.h,v 1.3 1997/03/26 00:17:34 mb Exp mb $
 * 
 * Copyright (c) 1994-96 Martin Buck  <martin-2.buck@student.uni-ulm.de>
 * Read COPYING for more information
 */


#include <sys/vtx.h>


#define VTXOK 0
#define VTXEINVAL -1
#define VTXEPARITY -2

#define VTX_COLMASK 0x07	/* I rely on the position of the VTX_COLMASK & VTX_BGMASK bits! */
#define VTX_BGMASK (0x07 << 3)
#define VTX_GRSEP (1 << 7)
#define VTX_HIDDEN (1 << 8)
#define VTX_BOX (1 << 9)
#define VTX_FLASH (1 << 10)
#define VTX_DOUBLE1 (1 << 11)
#define VTX_DOUBLE2 (1 << 12)
#define VTX_INVERT (1 << 13)
#define VTX_DOUBLE (VTX_DOUBLE1 | VTX_DOUBLE2)


typedef unsigned char chr_t;
typedef unsigned short attrib_t;
typedef struct {
  chr_t chr[VTX_PAGESIZE];
  attrib_t attrib[VTX_PAGESIZE];
  vtx_pageinfo_t info;
} vtxpage_t;


extern const chr_t cct2vtx_table[][96];
extern const char vtx2iso_table[], vtx2iso_lc_table[], vtxiso_worddelim[];


int decode_page(const byte_t *pgbuf, vtxpage_t *page, int y1, int y2);

#endif /* VTXDECODE_H_INCLUDED */

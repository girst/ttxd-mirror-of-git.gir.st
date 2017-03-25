#ifndef VTXTOOLS_H_INCLUDED
#define VTXTOOLS_H_INCLUDED

/* $Id: vtxtools.h,v 1.1 1996/10/14 21:36:25 mb Exp mb $
 *
 * Copyright (c) 1994-96 Martin Buck  <martin-2.buck@student.uni-ulm.de>
 * Read COPYING for more information
 */


#include <sys/vtx.h>


int vtx_chkparity(byte_t *val);
byte_t vtx_mkparity(byte_t val);
int vtx_chkhamming(byte_t val);
int inc_vtxpage(int page);
int dec_vtxpage(int page);
int vtx_hex2dec(int pgnum);
int vtx_dec2hex(int pgnum);
int vtx_chkpgnum(int pgnum, int hex_ok);

#endif /* VTXTOOLS_H_INCLUDED */

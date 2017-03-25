#ifndef CCT_H_INCLUDED
#define CCT_H_INCLUDED

/* $Id: cct.h,v 1.1 1996/09/22 22:37:43 mb Exp mb $
 * 
 * Copyright (c) 1994-96 Martin Buck  <martin-2.buck@student.uni-ulm.de>
 * Read COPYING for more information
 */


#include <sys/vtx.h>


#define CCTOK 0
#define CCTNOTFOUND 1
#define CCTERR -1
#define CCTEINVAL -2
#define CCTEOPEN -3
#define CCTEVERSION -4
#define CCTENOTOPEN -5


extern char *cct_device;

int cct_open(int major, int minor, vtx_info_t *prg_info);
void cct_close(void);
int cct_clearpgbuf(int pgbuf);
int cct_checkpage(int pgbuf);
int cct_stop_dau(int pgbuf);
int cct_reset_pgfound(int pgbuf);
int cct_searchpage(int page, int hour, int minute, int pagemask, int pgbuf);
int cct_getpage(int pgbuf, int x1, int y1, int x2, int y2, byte_t *buffer, vtx_pageinfo_t *info);
int cct_putpage(int x1, int y1, int x2, int y2, const byte_t *buffer, const vtx_pageinfo_t *info);
int cct_set_display(vtxdisp_t disp);
int cct_clear_cache(void);
int cct_set_virtual(int virtual);

#endif /* CCT_H_INCLUDED */

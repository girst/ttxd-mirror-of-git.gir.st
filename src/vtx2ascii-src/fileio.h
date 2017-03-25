#ifndef VTXBITMAP_H_INCLUDED
#define VTXBITMAP_H_INCLUDED

/* $Id: fileio.h,v 1.3 1997/08/14 23:00:12 mb Exp mb $
 * 
 * Copyright (c) 1995-96 Martin Buck  <martin-2.buck@student.uni-ulm.de>
 * Read COPYING for more information
 */


#include <stdio.h>
#include "vtxdecode.h"


#define BITS_PER_BYTE 8

#define LOADOK 0
#define LOADERR -1
#define LOADEMAGIC -2
#define LOADEVERSION -3
#define LOADECORRUPT -4


typedef struct {
  int xsize, ysize, bpr, bpc;
  unsigned char *bitmap;
} vtxbmfont_t;


extern char *vtx_fontpath;


vtxbmfont_t * read_font(unsigned int xsize, unsigned int ysize);
#ifdef GIF_SUPPORT
void export_gif(FILE *file, const vtxpage_t *page, const vtxbmfont_t *font, int interlace,
    int show_hidden);
#endif
void export_ppm(FILE *file, const vtxpage_t *page, const vtxbmfont_t *font, int show_hidden);
#ifdef PNG_SUPPORT
int export_png(FILE *file, const vtxpage_t *page, const vtxbmfont_t *font, int interlace,
    int show_hidden, char ***msg_list);
#endif
void export_ascii(FILE *file, const vtxpage_t *page, int show_hidden);
void save_vtx(FILE *file, const byte_t *buffer, const vtx_pageinfo_t *info, int virtual);
int load_vtx(FILE *file, byte_t *buffer, vtx_pageinfo_t *info, int *virtual);

#endif /* VTXBITMAP_H_INCLUDED */

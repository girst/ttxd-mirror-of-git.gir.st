/*
 * fileio.c: Read font-bitmaps, write GIF-, PPM-, ASCII- & VTX-files
 *
 * $Id: fileio.c,v 1.5 1997/08/14 22:59:42 mb Exp mb $
 *
 * Copyright (c) 1995-96 Martin Buck  <martin-2.buck@student.uni-ulm.de>
 * Read COPYING for more information
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <dirent.h>
#include <errno.h>
#include <sys/stat.h>
#include "vtx_assert.h"
#include "vtxdecode.h"
#include "vtxtools.h"
#include "misc.h"
#include "fileio.h"

#define VTXFONT_EXT ".vtxfont"
typedef enum { FP_ARG, FP_ENV, FP_DEFAULT } fp_src_t;


char *vtx_fontpath;


static const int vtx_img_red[8] =   {   0, 255,   0, 255,   0, 255,   0, 255 };
static const int vtx_img_green[8] = {   0,   0, 255, 255,   0,   0, 255, 255 };
static const int vtx_img_blue[8] =  {   0,   0,   0,   0, 255, 255, 255, 255 };

static const vtxpage_t *vtxpage;
static const vtxbmfont_t *vtxfont;
static int reveal;



void
export_ascii(FILE *file, const vtxpage_t *page, int show_hidden) {
  int pos;

  for (pos = 0; pos < VTX_PAGESIZE; pos++) {
    if (!(page->attrib[pos] & VTX_HIDDEN) || show_hidden) {
      fputc(vtx2iso_table[page->chr[pos]], file);
    } else {
      fputc(' ', file);
    }
    if (pos % 40 == 39)
      fputc('\n', file);
  }
}


void
save_vtx(FILE *file, const byte_t *buffer, const vtx_pageinfo_t *info, int virtual) {
  fputs("VTXV4", file);
  fputc(info->pagenum & 0xff, file);
  fputc(info->pagenum / 0x100, file);
  fputc(info->hour & 0xff, file);
  fputc(info->minute & 0xff, file);
  fputc(info->charset & 0xff, file);
  fputc(info->delete << 7 | info->headline << 6 | info->subtitle << 5 | info->supp_header << 4 |
      info->update << 3 | info->inter_seq << 2 | info->dis_disp << 1 | info->serial << 0, file);
  fputc(info->notfound << 7 | info->pblf << 6 | info->hamming << 5 | (!!virtual) << 4 |
      0 << 3, file);
  fwrite(buffer, 1, virtual ? VTX_VIRTUALSIZE : VTX_PAGESIZE, file);
}


int
load_vtx(FILE *file, byte_t *buffer, vtx_pageinfo_t *info, int *virtual) {
  byte_t tmp_buffer[VTX_VIRTUALSIZE];
  vtx_pageinfo_t tmp_inf;
  unsigned char tmpstr[256];
  struct stat st;
  int pos, tmpbits, is_virtual = FALSE, is_sevenbit = FALSE;

  memset(tmp_buffer, ' ', sizeof(tmp_buffer));
  if (fscanf(file, "VTXV%c", tmpstr) != 1) {
    if (fstat(fileno(file), &st) < 0) {
      return LOADERR;
    /* The stupid INtv format doesn't use a signature, so we have to use the file-length instead */
    } else if (st.st_size != 1008) {
      return LOADEMAGIC;
    }
    memset(&tmp_inf, 0, sizeof(tmp_inf));			/* Read ITV-file */
    rewind(file);
    for (pos = 0; pos <= 23; pos++) {
      fseek(file, 2, SEEK_CUR);
      fread(tmp_buffer + pos * 40, 40, 1, file);
    }
    /* The first 8 bytes in the INtv-format usually contain garbage (or data I don't understand) */
    memset(tmp_buffer, vtx_mkparity(' '), 8 * sizeof(byte_t));
    for (pos = 0; pos <= 2; pos++) {
      tmpstr[pos] = tmp_buffer[8 + pos];
      vtx_chkparity(&tmpstr[pos]);
    }
    tmpstr[3] = '\0';
    sscanf(tmpstr, "%3x", &tmp_inf.pagenum);
    if (!vtx_chkpgnum(tmp_inf.pagenum, TRUE)) {
      tmp_inf.pagenum = 0;
    }
    if (virtual) {
      *virtual = FALSE;
    }
  } else {
    if (tmpstr[0] != '2' && tmpstr[0] != '3' && tmpstr[0] != '4') {
      return LOADEVERSION;
    }
    tmp_inf.pagenum = fgetc(file) + 0x100 * fgetc(file);	/* Read VTX-file */
    tmp_inf.hour = fgetc(file);
    tmp_inf.minute = fgetc(file);
    tmp_inf.charset = fgetc(file);
    tmpbits = fgetc(file);
    tmp_inf.delete = !!(tmpbits & 0x80);
    tmp_inf.headline = !!(tmpbits & 0x40);
    tmp_inf.subtitle = !!(tmpbits & 0x20);
    tmp_inf.supp_header = !!(tmpbits & 0x10);
    tmp_inf.update = !!(tmpbits & 8);
    tmp_inf.inter_seq = !!(tmpbits & 4);
    tmp_inf.dis_disp = !!(tmpbits & 2);
    tmp_inf.serial = (tmpbits & 1);
    tmpbits = fgetc(file);
    tmp_inf.notfound = !!(tmpbits & 0x80);
    tmp_inf.pblf = !!(tmpbits & 0x40);
    tmp_inf.hamming = !!(tmpbits & 0x20);
    if (tmpstr[0] == '3') {
      is_virtual = TRUE;
    } else if (tmpstr[0] == '4') {
      is_virtual = !!(tmpbits & 0x10);
      is_sevenbit = !!(tmpbits & 8);
    }
    fread(tmp_buffer, is_virtual ? VTX_VIRTUALSIZE : VTX_PAGESIZE, 1, file);
    if (virtual) {
      *virtual = is_virtual;
    }
  }
  if (feof(file)) {
    return LOADECORRUPT;
  }
  if (ferror(file)) {
    return LOADERR;
  }
  if (buffer) {
    /* If file was saved in seven-bit mode, fake parity bit.
     * FIXME: Should we add parity to the virtual part too?
     */
    if (is_sevenbit) {
      for (pos = 0; pos < VTX_PAGESIZE; pos++) {
        tmp_buffer[pos] = vtx_mkparity(tmp_buffer[pos]);
      }
    }
    memcpy(buffer, tmp_buffer, is_virtual ? VTX_VIRTUALSIZE : VTX_PAGESIZE);
    memset(buffer, vtx_mkparity(7), 8);
  }
  if (info) {
    *info = tmp_inf;
  }
  return LOADOK;
}

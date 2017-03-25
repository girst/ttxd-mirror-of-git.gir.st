#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <getopt.h>

#include "fileio.h"

unsigned char buffer[65536];
vtxpage_t     page;
int           virtual;

#define OUT_ASCII 1
#define OUT_ANSI  2
#define OUT_HTML  3

void
export_ansi_ascii(FILE *file, const vtxpage_t *page, int show_hidden)
{
	int pos;
	int bg,fg,lbg,lfg,hidden;

	lfg = lbg = -1;
	for (pos = 0; pos < VTX_PAGESIZE; pos++) {
		fg     =  page->attrib[pos] & VTX_COLMASK;
		bg     = (page->attrib[pos] & VTX_BGMASK) >> 3;
		hidden = (page->attrib[pos] & VTX_HIDDEN) && !show_hidden;
		if (fg != lfg || bg != lbg) {
			fprintf(file,"\033[%d;%dm",fg+30,bg+40);
			lfg = fg;
			lbg = bg;
		}
		fputc(hidden ? ' ' : vtx2iso_table[page->chr[pos]], file);
		if (pos % 40 == 39) {
			lfg = lbg = -1;
			fprintf(file,"\033[0m\n");
		}
	}
}

void
export_html(FILE *file, const vtxpage_t *page, int show_hidden)
{
	static const char *color[] = {
		"black", "red", "green", "yellow",
		"blue", "magenta", "cyan", "white"
	};

	int pos;
	int bg,fg,lbg,lfg,hidden;
	int used[64];

	/* scan for used colors */
	memset(used,0,sizeof(used));
	for (pos = 0; pos < VTX_PAGESIZE; pos++) {
		fg     =  page->attrib[pos] & VTX_COLMASK;
		bg     = (page->attrib[pos] & VTX_BGMASK) >> 3;
		used[fg*8+bg] = 1;
	}

	/* print styles */
	fprintf(file,"<style type=\"text/css\"> <!--\n");
	for (bg = 0; bg < 8; bg++) {
		for (fg = 0; fg < 8; fg++) {
			if (used[fg*8+bg]) {
				fprintf(file,"font.c%d { color: %s; background-color: %s }\n",
					fg*8+bg,color[fg],color[bg]);
			}
		}
	}
	fprintf(file,"//--> </style>\n");

	/* print page */
	fprintf(file,"<pre>\n");
	lfg = lbg = -1;
	for (pos = 0; pos < VTX_PAGESIZE; pos++) {
		fg     =  page->attrib[pos] & VTX_COLMASK;
		bg     = (page->attrib[pos] & VTX_BGMASK) >> 3;
		hidden = (page->attrib[pos] & VTX_HIDDEN) && !show_hidden;
		if (fg != lfg || bg != lbg) {
			if (lfg != -1 || lbg != -1)
				fprintf(file,"</font>");
			fprintf(file,"<font class=c%d>",fg*8+bg);
			lfg = fg;
			lbg = bg;
		}
		fputc(hidden ? ' ' : vtx2iso_table[page->chr[pos]], file);
		if (pos % 40 == 39) {
			lfg = lbg = -1;
			fprintf(file,"</font>\n");
		}
	}
	fprintf(file,"</pre>\n");
}

void
usage(char *prog)
{
	fprintf(stderr,"usage: %s [ options ] vtx-file\n",prog);
	fprintf(stderr,
		"options: \n"
		"  -a  dump plain ascii (default)\n"
		"  -c  dump colored ascii (using ansi control sequences).\n"
		"  -h  dump html\n");
	exit(1);
}

int
main(int argc, char *argv[])
{
	FILE *fp;
	char *prog;
	int  c,output=OUT_ASCII;
	
	if (NULL != (prog = strrchr(argv[0],'/')))
		prog++;
	else
		prog = argv[0];

	for (;;) {
		if (-1 == (c = getopt(argc, argv, "ach")))
			break;
		switch (c) {
		case 'a':
			output=OUT_ASCII;
			break;
		case 'c':
			output=OUT_ANSI;
			break;
		case 'h':
			output=OUT_HTML;
			break;
		default:
			usage(prog);
		}
	}
	if (optind+1 != argc)
		usage(prog);

	if (NULL == (fp = fopen(argv[optind],"r"))) {
		fprintf(stderr,"%s: %s: %s\n",prog,argv[optind],strerror(errno));
		exit(1);
	}

	load_vtx(fp, buffer, &page.info, &virtual);
	decode_page(buffer, &page, 0, 23);
	switch(output) {
	case OUT_ASCII:
		export_ascii(stdout, &page, 0);
		break;
	case OUT_ANSI:
		export_ansi_ascii(stdout, &page, 0);
		break;
	case OUT_HTML:
		export_html(stdout, &page, 0);
		break;
	}
	return 0;
}

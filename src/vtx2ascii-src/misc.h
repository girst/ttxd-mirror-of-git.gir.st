#ifndef MISC_H_INCLUDED
#define MISC_H_INCLUDED

/* $Id: misc.h,v 1.1 1996/10/14 21:37:00 mb Exp mb $
 *
 * Copyright (c) 1994-96 Martin Buck  <martin-2.buck@student.uni-ulm.de>
 * Read COPYING for more information
 */

#include <limits.h>


#define VTXVERSION "0.6.970815"
#define VTXNAME "videotext"
#define VTXCLASS "Videotext"
#define VTXWINNAME "VideoteXt"

#define REQ_MAJOR 1
#define REQ_MINOR 6


#ifndef MIN
#define MIN(a, b) ((a) < (b) ? (a) : (b))
#define MAX(a, b) ((a) > (b) ? (a) : (b))
#endif
#define SIGN(a) ((a) < 0 ? -1 : ((a) > 0 ? 1 : 0))
#define STRINGIFY_NOMACRO(str) #str
#define STRINGIFY(str) STRINGIFY_NOMACRO(str)
#define NELEM(a) (sizeof(a) / sizeof(*(a)))

#ifndef FALSE
#define FALSE 0
#define TRUE 1
#endif

/* It's unbelievable that some systems are unable to provide the most basic ANSI-C features */
#ifndef INT_MAX
#define INT_MAX 2147483647
#endif

#endif /* MISC_H_INCLUDED */

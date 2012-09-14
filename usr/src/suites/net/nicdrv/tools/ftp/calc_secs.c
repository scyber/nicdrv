/*
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License (the "License").
 * You may not use this file except in compliance with the License.
 *
 * You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
 * or http://www.opensolaris.org/os/licensing.
 * See the License for the specific language governing permissions
 * and limitations under the License.
 *
 * When distributing Covered Code, include this CDDL HEADER in each
 * file and include the License file at usr/src/OPENSOLARIS.LICENSE.
 * If applicable, add the following below this CDDL HEADER, with the
 * fields enclosed by brackets "[]" replaced with your own identifying
 * information: Portions Copyright [yyyy] [name of copyright owner]
 *
 * CDDL HEADER END
 */

/*
 * Copyright 2008 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#pragma ident	"@(#)calc_secs.c	1.2	08/04/22 SMI"

#include <stdio.h>
#include <sys/types.h>		/* struct itimerval */
#include <time.h>
#include <errno.h>
#include <stdlib.h>

extern int errno;

static void
err(s)
char *s;
{
	(void) fprintf(stderr, "calc_secs");
	perror(s);
	(void) fprintf(stderr, "errno=%d\n", errno);
	exit(1);
}

int
main(void)
{
	time_t  *curr_time;

	if ((curr_time = (time_t *)malloc(sizeof (long))) == NULL)
		err("malloc");
	if ((time(curr_time)) == (time_t)-1)
		err("time");
	(void) printf("%ld", *curr_time);
	return (0);
}

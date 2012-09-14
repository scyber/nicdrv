#!/usr/bin/ksh -p
#
# CDDL HEADER START
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License (the "License").
# You may not use this file except in compliance with the License.
#
# You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
# or http://www.opensolaris.org/os/licensing.
# See the License for the specific language governing permissions
# and limitations under the License.
#
# When distributing Covered Code, include this CDDL HEADER in each
# file and include the License file at usr/src/OPENSOLARIS.LICENSE.
# If applicable, add the following below this CDDL HEADER, with the
# fields enclosed by brackets "[]" replaced with your own identifying
# information: Portions Copyright [yyyy] [name of copyright owner]
#
# CDDL HEADER END
#

#
# Copyright 2008 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# ident	"@(#)snoop_onoff.ksh	1.2	08/04/22 SMI"
#

count=1
while true; do
	if [ $count -gt 9 ]; then 
		echo "Enable promiscuous mode $count times on local host"
	fi
	snoop -d ${TST_INT}${TST_NUM} -c 20000 > /dev/null 2>&1
	if [ $count -gt 9 ]; then 
		echo "Enable promiscuous mode $count times on remote host"
		count=0
	fi
	rsh ${RMT_HST} snoop -d ${RMT_INT}${RMT_NUM} -c 20000 > /dev/null 2>&1
	count=`expr $count + 1`
done


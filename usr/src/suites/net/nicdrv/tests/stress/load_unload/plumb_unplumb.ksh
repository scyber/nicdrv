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
# ident	"@(#)plumb_unplumb.ksh	1.2	08/04/22 SMI"
#

retry_cnt=0
while true; do
	if [ $retry_cnt -gt 50 ]; then
		echo "plumb_unplumb: exit since MAXQ not started"
		exit 1
	fi
	ps -ef|grep MAXQ > /dev/null 2>&1
	MAXQ_NUM=`echo $?`
	if [ $MAXQ_NUM -eq 0 ]; then
		break
	fi
	sleep 1
	retry_cnt=`expr $retry_cnt + 1`
done

echo "plumb_unplumb: MAXQ setup done, test starts"
#
# Wait for enough time, so that MAXQ can start data transmitting
#
sleep 60

while true; do
	ifconfig $1$2  > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		ifconfig $1$2 plumb $3 netmask $4 up > /dev/null 2>&1
		retry_cnt=0
		while [ $retry_cnt -lt 10 ]; do
			ping $5 > /dev/null 2>&1
			if [ $? -eq 0 ]; then
				break
			else
				retry_cnt=`expr $retry_cnt + 1`
			fi
		done
	else
		ifconfig $1$2 unplumb > /dev/null 2>&1
	fi
	sleep 30
done

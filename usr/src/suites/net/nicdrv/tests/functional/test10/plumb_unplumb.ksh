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
# Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# ident	"@(#)plumb_unplumb.ksh	1.4	09/06/24 SMI"
#

#
# $1:IF name, $2:IF num, $3:IP, $4: mask, $5: rmt_IP
#

. ${STF_TOOLS}/include/stf.kshlib
. ${STF_SUITE}/include/common.kshlib

cleanup()
{
	ifconfig $1$2  > /dev/null 2>&1 || \
	  { echo restore $1$2; ifconfig $1$2 plumb $3 netmask $4 up > /dev/null 2>&1; }
	exit 
}

retry_cnt=0
while true; do
	if [ $retry_cnt -gt 50 ]; then
		echo "plumb_unplumb: exit since ping not started"
		exit 1
	fi
	ps -ef | grep -v "grep" | grep "ping" > /dev/null 2>&1
	if [ "$?" -eq 0 ]; then
		break
	fi
	sleep 1
	retry_cnt=`expr $retry_cnt + 1`
done

trap "cleanup $1 $2 $3 $4" 1 2 3 5 15

echo "plumb_unplumb: ping existing, test starts"

while true; do
	ifconfig $1$2  > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "plumb $1$2 interface"
		time_statistics "ifconfig $1$2 plumb $3 netmask $4 up" $6
		if [ $? -ne 0 ]; then
			echo "ERROR:plumb interface use too much time"
			exit 1
		fi
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
		echo "unplumb $1$2 interface"
		time_statistics "ifconfig $1$2 unplumb" $6
		if [ $? -ne 0 ] ; then
			echo "ERROR:unplumb interface use too much time"
			ifconfig $1$2 plumb $3 netmask $4 up
			exit 1
		fi
	fi
	# keep the status for 5 seconds, 18 times per 180s, luo
	sleep 5
done

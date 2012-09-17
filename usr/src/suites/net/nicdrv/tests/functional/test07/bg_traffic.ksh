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
# ident	"@(#)bg_traffic.ksh	1.2	08/04/22 SMI"
#

. ${STF_TOOLS}/include/stf_common.kshlib
. ${STF_SUITE}/include/common.kshlib

#
# This script is to run netperf traffic
# in background, the packet number output 
# is to be used by netstat
#
for i in $*; do
        case $1 in
		-t)
			TIME_OUT=$2
			export TIME_OUT
			shift 2
			;;
        esac
done

#
# Start the traffic
#
linkspeed=`get_linkspeed ${TST_INT} ${TST_NUM}`
if [ "$linkspeed" = "0" ]; then
	echo "can't not get linkspeed"
	exit 1
fi

subnet_ip=`get_subnetip ${TST_INT} ${TST_NUM}`
if [ "$subnet_ip" = "0" ]; then
	echo "can't not get subnet_ip"
	exit 1
fi

${STF_SUITE}/tools/maxq/${STF_EXECUTE_MODE}/MAXQ.auto \
	-s ${LOCAL_HST} -c ${RMT_HST} -C ${RMT_HST} \
	-d 65535 -b 65535 -D 1 -T $TIME_OUT -M $subnet_ip \
	-m root@localhost -p nicdrv -i 1 -e $linkspeed \
	-t 0 -tr bi -S 1 -P TCP_STREAM  > /dev/null

${STF_SUITE}/tools/nfscorrupt/${STF_EXECUTE_MODE}/Corrupt.auto \
    -c ${RMT_HST} -s ${LOCAL_HST} -n 1 -t $TIME_OUT \
    -d bi -e "root@localhost" -p ${TST_INT} -m udp -r no > /dev/null

exit 0

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
# ident	"@(#)runme.ksh	1.4	08/11/12 SMI"
#

###############################################################################
# __stc_assertion_start
# 
# ID: tests/functional/test03
# 
# DESCRIPTION:
#         Test and verify that no data corruptions are found
#         during data transmit/receive
# 
# STRATEGY:
#         - Run nfscorrupt TCP traffic on test interface for 1 hour
#         - Run nfscorrupt UDP traffic on test interface for 1 hour
#         - Test should pass without data corruptions
# 
# TESTABILITY: implicit
# 
# AUTHOR: Oliver.Yang@Sun.COM
# 
# REVIEWERS:
# 
# TEST AUTOMATION LEVEL: automated
# 
# CODING_STATUS:  COMPLETED (2006-05-10)
# 
# __stc_assertion_end
# 
###############################################################################

. ${STF_TOOLS}/include/stf_common.kshlib
. ${STF_SUITE}/include/common.kshlib

# Define local variables
readonly ME=$(whence -p ${0})

# Extract and print assertion information from this source script to journal
extract_assertion_info $ME

check_host_alive $LOCAL_HST $RMT_HST
if [ $? -ne 0 ]; then
        echo "The client isn't alive!"
        exit ${STF_UNRESOLVED}
fi

RUN_TIME=`get_parameter NFS_RUN_TIME`

sess_num=5

PHY_MEM=`prtconf -v | grep "Memory size:" | awk '{print $3}'`
PHY_MEM_RMT=`rsh $RMT_HST "prtconf -v" | grep "Memory size:" | awk '{print $3}'`
# The session number should match the whole test environment
if [ $PHY_MEM_RMT -lt $PHY_MEM ]; then
        PHY_MEM=$PHY_MEM_RMT
fi

if [ $PHY_MEM -lt 1024 ]; then
        sess_num=2
fi

if [ $PHY_MEM -gt 4000 ]; then
        sess_num=5
fi

if [ $PHY_MEM -gt 8000 ]; then
        sess_num=10
fi

ARCH=`isainfo -b`
ARCH_RMT=`rsh $RMT_HST "isainfo -b"`
if [ $ARCH -eq 32 -o $ARCH_RMT -eq 32 ]; then
        sess_num=`expr $sess_num / 2`
fi

trap "pkill Corrupt.auto; exit 1" 1 2 3 9 15

dtrace_start "03" ${TST_INT}
dtr_pid=`echo $!`

${STF_SUITE}/tools/nfscorrupt/${STF_EXECUTE_MODE}/Corrupt.auto \
	-c ${RMT_HST} -s ${LOCAL_HST} -n $sess_num -t $RUN_TIME \
	-d bi -p nicdrv -m tcp -r no -e no

if [ $? -ne 0 ]; then
	dtrace_end $dtr_pid "03"
	exit ${STF_FAIL}
fi


${STF_SUITE}/tools/nfscorrupt/${STF_EXECUTE_MODE}/Corrupt.auto \
	-c ${RMT_HST} -s ${LOCAL_HST} -n $sess_num -t $RUN_TIME \
	-d bi -p nicdrv -m udp -r no -e root@localhost

if [ $? -ne 0 ]; then
	dtrace_end $dtr_pid "03"
	exit ${STF_FAIL}
else
	dtrace_end $dtr_pid "03"
	exit ${STF_PASS}
fi

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
# ID: tests/functional/test07
# 
# DESCRIPTION:
#         Test statistics and observability of the driver
# 
# STRATEGY:
#         - Start single session TCP/UDP testing on test interfaces
#         - Invoke dladm statistic command on the test interface
#         - Check overflow for each counter
#         - Invoke kstat commands for the driver module
#         - Check overflow for each counter
#         - Invoke netstat -s for NIC interface
#         - Check error counters
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

integer FAIL_FLAG=0
# Define local variables
readonly ME=$(whence -p ${0})

# Extract and print assertion information from this source script to journal
extract_assertion_info $ME

check_host_alive $LOCAL_HST $RMT_HST
if [ $? -ne 0 ]; then
        echo "The client isn't alive!"
        exit ${STF_UNRESOLVED}
fi

dtrace_start "07" ${TST_INT}
dtr_pid=`echo $!`

record_kstat_err ${TST_INT} ${TST_NUM}
record_netstat_err ${TST_INT} ${TST_NUM}

${STF_SUITE}/${STF_EXEC}/Statistic.auto \
	-c ${RMT_HST} -i ${TST_INT} -n ${TST_NUM}

if [ $? -ne 0 ]; then
	echo "Statistic.auto fail"
	FAIL_FLAG=1
fi

check_kstat_err ${TST_INT} ${TST_NUM}
if [ $? -ne 0 ]; then
	echo "Warning: Found hardware error during the testing."
	FAIL_FLAG=1
fi

check_netstat_err ${TST_INT} ${TST_NUM}
if [ $? -ne 0 ]; then
	echo "Warning: Found network error during the testing."
	FAIL_FLAG=1
fi


if [ $FAIL_FLAG -ne 0 ]; then
        dtrace_end $dtr_pid "07"
        exit ${STF_FAIL}
else 
	dtrace_end $dtr_pid "07"
	exit ${STF_PASS}
fi

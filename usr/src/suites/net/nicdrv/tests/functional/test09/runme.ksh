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
# ident	"@(#)runme.ksh	1.2	08/04/22 SMI"
#

###############################################################################
# __stc_assertion_start
# 
# ID: tests/functional/test09
# 
# DESCRIPTION:
#         Test NIC aggregation: initialization and data transmitg/receive
# 
# STRATEGY:
#         - Create an aggregation on test devices and plumb the interface
#         - Run nfscorrupt TCP UDP traffic on aggregation
#         - During the sending of network traffic, plumb/unplumb aggregation interfaces
#         - All of tests should pass without any errors
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

. ${STF_TOOLS}/include/stf.kshlib
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

#
# Check interface based on gldv3
#
legacy_num=`dladm show-link | grep ${TST_INT}${TST_NUM} \
    | grep legacy | wc -l | awk '{print $1}'`
if [ legacy_num -gt 0 ]; then
	exit ${STF_UNSUPPORTED}
fi

check_host_alive $LOCAL_HST $RMT_HST
if [ $? -ne 0 ]; then
        echo "The client isn't alive, Test FAIL!"
        exit ${STF_FAIL}
else
        echo "The client is alive!"
fi

dtrace_start "09" ${TST_INT}
dtr_pid=`echo $!`

${STF_SUITE}/${STF_EXEC}/Nemo_Trunk.auto \
	-i ${TST_INT}${TST_NUM} -c ${RMT_HST} -l ${LOCAL_HST} -w ${TST_PASS}

if [ $? -ne 0 ]; then
	dtrace_end $dtr_pid "09"
        exit ${STF_FAIL}
fi

dtrace_end $dtr_pid "09"

check_host_alive $LOCAL_HST $RMT_HST
if [ $? -ne 0 ]; then
        echo "The client isn't alive, Test FAIL!"
        exit ${STF_FAIL}
else
        echo "The client is alive!"
fi

exit ${STF_PASS}

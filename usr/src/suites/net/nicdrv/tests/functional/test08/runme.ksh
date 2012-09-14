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
# ident	"@(#)runme.ksh	1.4	09/06/24 SMI"
#

###############################################################################
# __stc_assertion_start
# 
# ID: tests/functional/test08
# 
# DESCRIPTION:
#         Test vlan functionality: initialization and data transmit/receive
# 
# STRATEGY:
#	  - Test plumb/unplumb vlan id 0,1,2,4093,4094,4095 
#         - Test Plumb/Unplumb 1000 vlan interfaces
#         - Run ftp,nfscorrupt tcp/udp, netperf on vlan interfaces
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

# $1 - local host IP
# $2 - remote host IP
# $3 - local driver 
# $4 - local driver instance
# $5 - remote driver
# $6 - remote driver instance
# $7 - remote root pass
# $8 - run time for each apps running on vlan

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
RUN_TIME=`get_parameter VLAN_RUN_TIME`
VLAN_NUM=`get_parameter test08_VLAN_NUM`
VLAN_SUBNET=`get_parameter test08_VLAN_SUBNET`
trap "pkill vlan.auto" 1 2 3 9 15

check_vlan_support ${LOCAL_HST} ${TST_INT} ${TST_NUM}
if [ $? -ne 0 ]; then
	exit ${STF_UNSUPPORTED}
fi

check_vlan_support ${RMT_HST} ${RMT_INT} ${RMT_NUM}
if [ $? -ne 0 ]; then
	exit ${STF_UNSUPPORTED}
fi

dtrace_start "08" ${TST_INT}
dtr_pid=`echo $!`

echo "Both ${TST_INT} and ${RMT_INT} support vlan featrue, begin the testing..." 

${STF_SUITE}/${STF_EXEC}/vlan.auto \
	${LOCAL_HST} ${RMT_HST} ${TST_INT} ${TST_NUM} \
	${RMT_INT} ${RMT_NUM} ${TST_PASS} ${RUN_TIME} ${VLAN_NUM} ${VLAN_SUBNET}

if [ $? -ne 0 ]; then
	dtrace_end $dtr_pid "08"
	exit ${STF_FAIL}
else	
	dtrace_end $dtr_pid "08"
	exit ${STF_PASS}
fi

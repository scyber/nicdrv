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
# ident	"@(#)runme.ksh	1.3	09/06/24 SMI"
#

###############################################################################
# __stc_assertion_start
# 
# ID: tests/functional/test12
# 
# DESCRIPTION:
#          Create,plumb,unplumb,delete vnic interface,and will
#          use vnic interface send/revice data.
# 
# STRATEGY:
#         - plumb,unplumb vnic interfaces with random mac address
#         - create vnic interfaces with high priority,run nfs,MAXQ,ftp 
#         - create vnic interfaces with low priority,run nfs,MAXQ,ftp 
# 
# TESTABILITY: implicit
# 
# AUTHOR: yuan.fan@Sun.COM
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
# $9 - vnic name perfix
. ${STF_TOOLS}/include/stf_common.kshlib
. ${STF_SUITE}/include/common.kshlib

# Define local variables
readonly ME=$(whence -p ${0})
FAIL_FLAG=0
# Extract and print assertion information from this source script to journal
extract_assertion_info $ME

dtrace_start "12" ${TST_INT}
dtr_pid=`echo $!`

echo "Both ${TST_INT} and ${RMT_INT} support vnic featrue, begin the testing..." 
RUN_TIME=`get_parameter VNIC_RUN_TIME`
VNIC_NAME=`get_parameter VNIC_PREFIX`
VNIC_HD_COUNT=`get_parameter VNIC_HD_COUNT`

#
# Function check_vnic_support
# verify host machine and rmote machine can support vnic
#
check_vnic_support() {
	dladm show-vnic > /dev/null 2>&1
	if [ $? -ne 0 ]; then
	    echo "your host mahcine does't support vnic feature"
		exit $STF_UNSUPPORTED
	fi
	error=`rsh -n ${RMT_HST} "dladm show-vnic > /dev/null 2>&1; echo \\\$?"`
	if [ $error -ne 0 ]; then
	    echo "your remote machine does't support vnic feature"
		exit $STF_UNSUPPORTED
	fi
	echo "host and remote machinet suppport vnic feature"
}

check_vnic_support

${STF_SUITE}/${STF_EXEC}/vnic.auto \
	${LOCAL_HST} ${RMT_HST} ${TST_INT} ${TST_NUM} \
	${RMT_INT} ${RMT_NUM} ${TST_PASS} ${RUN_TIME} ${VNIC_NAME} ${VNIC_HD_COUNT}

if [ $? -ne 0 ]; then
	echo "$cmd Failed : result = $?"
	FAIL_FLAG=1
fi

dtrace_end $dtr_pid "12"
if [ $FAIL_FLAG -ne 0 ]; then
	exit ${STF_FAIL}
else	
	exit ${STF_PASS}
fi

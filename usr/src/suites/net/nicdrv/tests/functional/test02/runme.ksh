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
# ID: tests/functional/test02
# 
# DESCRIPTION:
#         Test packet transmit/receive based on packet level
# 
# STRATEGY:
#         - Ping peer machine with various ICMP payloads(0-65508 bytes)
#         - Ping should pass with zero packet loss
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
        echo "The client isn't alive"
        exit ${STF_UNRESOLVED}
fi

dtrace_start "02" ${TST_INT}
dtr_pid=`echo $!`

${STF_SUITE}/tools/ping/Ping.auto \
	-i ${TST_INT}${TST_NUM} -r ${RMT_INT}${RMT_NUM} \
	-c ${RMT_HST} -h ${LOCAL_HST}

if [ $? -ne 0 ]; then
	dtrace_end $dtr_pid "02"
	exit ${STF_FAIL}
else
	dtrace_end $dtr_pid "02"
	exit ${STF_PASS}
fi

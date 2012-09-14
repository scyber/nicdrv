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
# ID: tests/stress/load_unload
# 
# DESCRIPTION:
#         Test driver functionality and stability
#         for _init/_fini and transmit/receive areas
# 
# STRATEGY:
#         - Unplumb the NIC interface and remove the driver module.
#         - Add the driver module and plumb the corresponding interface.
#         - Change the MAC address of the interface.
#         - Start multi-session TCP traffic on test interfaces.
#         - Repeatedly plumb/unplumb test interfaces under the network traffic.
#         - Above steps should be repeated and sustained at least 6 hours.
#         - After the testing, the test interface should still work (no hang).
# 
# TESTABILITY: statistical and implicit
# 
# AUTHOR: Robin.Luo@Sun.COM
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

${STF_SUITE}/${STF_EXEC}/load_unload.auto \
    ${LOCAL_HST} ${RMT_HST} ${TST_INT} ${TST_NUM}

if [ $? -ne 0 ]; then
        exit ${STF_FAIL}
else
        exit ${STF_PASS}
fi

#!/usr/bin/ksh -p
#
# Copyright 2008 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# ident	"@(#)runme.ksh	1.1	08/04/22 SMI"
#
###############################################################################
# __stc_assertion_start
# 
# ID: tests/functional/test11
# 
# DESCRIPTION:
#         Test NIC driver dynamic reconfiguration support
# 
# STRATEGY:
#         - Find the attachment ponit id for the NIC card under testing
#         - unplumb all NIC interface for the attachment ponit
#         - run cfgadm disconnect/connect/configure/unconfigure for the attachement ponit
#         - run sanity test for the NIC interface
#         - Start multi-session TCP traffic on test interfaces.
# 
# TESTABILITY: explicit
# 
# AUTHOR: Mengwei.Jiao@Sun.COM
# 
# REVIEWERS:
# 
# TEST AUTOMATION LEVEL: automated
# 
# CODING_STATUS:  COMPLETED (2007-12-05)
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

RUN_TIME=`get_parameter DR_RUN_TIME`	
${STF_SUITE}/${STF_EXEC}/dr.auto \
    ${LOCAL_HST} ${RMT_HST} ${TST_INT}${TST_NUM} $RUN_TIME



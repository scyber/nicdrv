#!/usr/bin/ksh
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
# ident	"@(#)is_nicdrv_removable.ksh	1.2	08/04/22 SMI"
#

#
# Function is_nicdrv_removable
#
# This function checks if the test nic driver can be removed
# The test case load/unload requires the system have different
# types of NIC in order to connect with the network when the
# NIC of one type is unplumbed.
#

function is_nicdrv_removable
{
        print "checkenv: is_nicdrv_removable($*)"

        errmsg="usage: is_nicdrv_removable"
        [ $# -ne 0 ] && abort $errmsg

        req_label="driver removable"
        req_value=$1

        if [ $OPERATION == "dump" ]; then
                is_nicdrv_removable_doc
                return $PASS
        fi

	errmsg="The driver under the test can't be removed."
        result=FAIL
        if [ $OPERATION == "verify" ]; then
		NIC_NUM=`ifconfig -a | grep RUNNING | grep IPv4 | \
		    awk '{print $1}' | sed s/[0-9,:]//g | uniq | wc -l`
		TERM=`tty`
		
		[ $NIC_NUM -gt 2 ] && errmsg="" && result=PASS

                [ $NIC_NUM -lt 3 ] && [ $TERM = "/dev/console" ] &&
                errmsg="" && result=PASS

		[ $NIC_NUM -lt 3 ] && [ $TERM = "not a tty" ] &&
                errmsg="" && result=PASS
        fi

        print_line $TASK "$req_label" "$req_value" "$result" "$errmsg"
        eval return \$$result

}

function is_nicdrv_removable_doc
{
        cat >&1 << EOF

Check is_nicdrv_removable $(TASK)
=================================
Description:
        check whether the driver can be removable
	by checking number of nic interface
Arguments:
        NONE
Requirement label (for this check):
        $req_label
Requirement value (for this check):
        $req_value
EOF
}

#!/usr/bin/ksh -p
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
# ident	"@(#)unconfigure.ksh	1.7	09/06/24 SMI"
#

. ${STF_TOOLS}/include/stf.kshlib
. ${STF_SUITE}/include/common.kshlib

#
# disable services in $g_service_bak file
# In this file, each line is a service.
# The first column is either "local" or "remote"
#
restore_service()
{
        typeset service_name
        for service_name in $(cat $g_service_bak | grep ^local |awk '{print $2}'); do
                exec_cmd "svcadm disable $service_name"
        done

	cat $g_service_bak | grep ^remote |  while read line; do
		typeset hostname=$(echo $line | awk '{print $2}')
		service_name=$(echo $line | awk '{print $3}')
		echo remote $hostname $service_name
		exec_rshcmd $hostname "svcadm disable $service_name"
        done


}


FAIL_FLAG=0

check_host_alive $LOCAL_HST $RMT_HST
if [ $? -ne 0 ]; then
        echo "Warning: The client isn't alive, Client configuration can not be restored."
else
        echo "The client is alive!"
fi

#
# Restore nsswitch.conf
#
if [ -f /etc/nsswitch.nicdrv ]; then
	cp /etc/nsswitch.nicdrv /etc/nsswitch.conf || FAIL_FLAG=1
	rm -f /etc/nsswitch.nicdrv || FAIL_FLAG=1
fi


if exec_rshcmd $RMT_HST "test -f /etc/nsswitch.nicdrv" > /dev/null ; then
	exec_rshcmd $RMT_HST "cp /etc/nsswitch.nicdrv /etc/nsswitch.conf" || FAIL_FLAG=1
	exec_rshcmd $RMT_HST "rm /etc/nsswitch.nicdrv" || FAIL_FLAG=1
fi

#
# Restore ftpusers
#
if [ -f /etc/ftpd/ftpusers.nicdrv ]; then
	cp /etc/ftpd/ftpusers.nicdrv /etc/ftpd/ftpusers || FAIL_FLAG=1
	rm -f /etc/ftpd/ftpusers.nicdrv || FAIL_FLAG=1
fi

if exec_rshcmd $RMT_HST "test -f /etc/ftpd/ftpusers.nicdrv" > /dev/null; then
	exec_rshcmd $RMT_HST "cp /etc/ftpd/ftpusers.nicdrv /etc/ftpd/ftpusers" || FAIL_FLAG=1
	exec_rshcmd $RMT_HST "rm -f /etc/ftpd/ftpusers.nicdrv" || FAIL_FLAG=1
fi

#
# restore service
#
g_service_bak=$LOGDIR/svc.nicdrv

if [ -f $g_service_bak ]; then
	restore_service && rm -f $g_service_bak
fi

#
# Restore user attribute 
#
if [ -f /etc/user_attr.nicdrv ]; then
	exec_cmd "pfexec cp /etc/user_attr.nicdrv /etc/user_attr" 
	exec_cmd "pfexec rm -f /etc/user_attr.nicdrv"
fi

#
# Clean up driver functions list
#
if [ -f "$DRV_ALL_FUNC_LOG" ]; then
        rm -f $DRV_ALL_FUNC_LOG
fi

if [[ $FAIL_FLAG = 0 ]] ; then
	exit ${STF_PASS}
else
	exit ${STF_FAIL}
fi

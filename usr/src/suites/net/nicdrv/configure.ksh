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
# ident	"@(#)configure.ksh	1.8	09/06/24 SMI"
#

. ${STF_TOOLS}/include/stf_common.kshlib
. ${STF_SUITE}/include/common.kshlib



#
# failed to configure the test suite
#
fail()
{
	echo $1
	recover_env
	exit $STF_FAIL
}

#
# enable smf service, and save them to a file($g_service_bak)
# for unconfigure and recovery
# $1 service name
#
enable_service()
{
	typeset service_name=$1
	if [[ "$(svcs -Ho STA $service_name)" != "ON" ]]; then
		echo "local $service_name" >> $g_service_bak	
		exec_cmd "svcadm enable -r -s $service_name"
	else
		return 0	
	fi
}
#
# enable smf service on remote host
#
enable_remote_service()
{
	typeset host_name=$1
	typeset service_name=$2
	if [[ "$(rsh -n $host_name svcs -Ho STA $service_name)" != "ON" ]]; then
		echo "remote $host_name $service_name" >> $g_service_bak	
		exec_rshcmd $host_name "svcadm enable -r -s $service_name"
	else
		return 0	
	fi
}

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

#
# Recover the system, if configuring is interrupted
#
recover_env() {
	
	if [ -f /etc/nsswitch.nicdrv ]; then
		cp /etc/nsswitch.nicdrv /etc/nsswitch.conf
		rm -f /etc/nsswitch.nicdrv
	fi

	if exec_rshcmd $RMT_HST "test -f /etc/nsswitch.nicdrv" >/dev/null ; then
		exec_rshcmd $RMT_HST "cp /etc/nsswitch.nicdrv /etc/nsswitch.conf"
		exec_rshcmd $RMT_HST "rm /etc/nsswitch.nicdrv" 
	fi


	if [ -f /etc/ftpd/ftpusers.nicdrv ]; then
		cp /etc/ftpd/ftpusers.nicdrv /etc/ftpd/ftpusers
		rm -f /etc/ftpd/ftpusers.nicdrv
	fi

	if exec_rshcmd $RMT_HST "test -f /etc/ftpd/ftpusers.nicdrv" > /dev/null ; then
		exec_rshcmd $RMT_HST "cp /etc/ftpd/ftpusers.nicdrv /etc/ftpd/ftpusers"
		exec_rshcmd $RMT_HST "rm -f /etc/ftpd/ftpusers.nicdrv"
	fi

	if [ -f $g_service_bak ]; then
		restore_service && rm -f $g_service_bak
	fi
}

check_netperf() {
	bin_dir=`isainfo -n`
	if [ -z $NETPERF_HOME ]; then
		echo "not set NETPERF_HOME path,use default path"
		NETPERF_HOME=${STF_TOOLS}/../SUNWstc-netperf2/bin/
		echo "NETPERF_HOME=$NETPERF_HOME"
	fi
	if [ ! -f $NETPERF_HOME/bin/netperf ]; then
		echo "Couldn't not find netperf tools, \
			please verify it is installed in proper location."
		exit ${STF_FAIL}
	fi
}

#
# Change root role for OpenSolaris release
#
change_role_mode() {
	typeset ret1 ret2
	grep OpenSolaris /etc/release > /dev/null
        ret1=$?
	grep root::::type=role /etc/user_attr > /dev/null
        ret2=$?
	if (( $ret1 == 0 && $ret2 == 0 )); then
		exec_cmd "pfexec cp /etc/user_attr /etc/user_attr.nicdrv"
		exec_cmd "pfexec rolemod -K type=normal root"
	fi
}

change_role_mode

#
# Before configure system service, checking the host availability

#

check_host_alive $LOCAL_HST $RMT_HST
if [ $? -ne 0 ]; then
        echo "The client isn't alive, Test FAIL!"
        exit ${STF_FAIL}
else
        echo "The client is alive!"
fi

#
# Check netperf tools on host computer
#
check_netperf

#
#capture Ctrl-C or kill signals
#
trap "recover_env; exit" 1 2 3 9 15

#
# Enable network services on local host and remote host
#
g_service_bak=$LOGDIR/svc.nicdrv

if [[ ! -f $g_service_bak ]]; then
	enable_service svc:/network/shell:default || fail
	enable_service svc:/network/ftp:default || fail
	enable_service svc:/network/nfs/client:default || fail

	enable_remote_service $RMT_HST svc:/network/ftp:default || fail
	enable_remote_service $RMT_HST svc:/network/nfs/client:default || fail
fi


#
# Make sure the first name service should be hosts file
#
if [[ ! -f /etc/nsswitch.nicdrv ]]; then
	exec_cmd "cp /etc/nsswitch.conf /etc/nsswitch.nicdrv"
	exec_cmd "cp /etc/nsswitch.files /etc/nsswitch.conf"
fi

if exec_rshcmd $RMT_HST "test ! -f /etc/nsswitch.nicdrv" >/dev/null; then
	exec_rshcmd $RMT_HST "cp /etc/nsswitch.conf /etc/nsswitch.nicdrv"
	exec_rshcmd $RMT_HST "cp /etc/nsswitch.files /etc/nsswitch.conf"
fi

#
# Make sure the root user can login ftp server
#
if [[ ! -f /etc/ftpd/ftpusers.nicdrv ]] ; then
	exec_cmd "cp /etc/ftpd/ftpusers /etc/ftpd/ftpusers.nicdrv"
	exec_cmd "sed '/^root/d' /etc/ftpd/ftpusers.nicdrv > /etc/ftpd/ftpusers"
fi

if exec_rshcmd $RMT_HST "test ! -f /etc/ftpd/ftpusers.nicdrv" > /dev/null; then
	exec_rshcmd $RMT_HST "cp /etc/ftpd/ftpusers /etc/ftpd/ftpusers.nicdrv"
	exec_rshcmd $RMT_HST "sed '/^root/d' /etc/ftpd/ftpusers.nicdrv \
		> /etc/ftpd/ftpusers"
fi

#
# Get all of the driver functions
#
if [ -f "$DRV_ALL_FUNC_LOG" ]; then
	rm $DRV_ALL_FUNC_LOG
fi
dtrace -l -n ${TST_INT}::entry | awk '{print $4}' > $DRV_ALL_FUNC_LOG

#
# The ratio of the total run time of NICDRV
# RUN_TIME = TIME / RUN_TIME_MULTIPLIER
#
RUN_TIME_MULTIPLIER=${RUN_TIME_MULTIPLIER:-1}
case "$RUN_MODE" in
	"WiFi")	RUN_TIME_MULTIPLIER=2;;
	"LOW-END")	RUN_TIME_MULTIPLIER=2;;
	"ONPIT")	RUN_TIME_MULTIPLIER=1;;
esac
echo "NICDRV is working on $RUN_MODE run mode."
export RUN_TIME_MULTIPLIER


exit ${STF_PASS}

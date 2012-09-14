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
# ident	"@(#)set_mtu.ksh	1.1	08/11/12 SMI"
#

int_unplumb_dhcp()
{
        echo "unplumb $1 with DHCP"
        ifconfig $1 dhcp drop
        ifconfig $1 unplumb
}
int_plumb_dhcp()
{
        echo "plumb $1 with DHCP"
        ifconfig $1 plumb
        ifconfig $1 dhcp
        ifconfig $1 up
}
int_plumb()
{
        echo "plumb $1 with ip $2 and netmask $3"
        ifconfig $1 plumb $2 netmask $3 up
}
int_unplumb()
{
        echo "unplumb $1 with ip $2 and netmask $3"
        ifconfig $1 unplumb
}

save_interface()
{
        typeset interface=$1
        if [ -z "$interface" ]; then
                interface=${TST_INT}${TST_NUM}
        fi
	#check if the interface exist
	ifconfig $interface >/dev/null || return

        inet=`ifconfig ${interface} | \
            grep netmask | awk -F' ' '{print $2}'`
        netmask=0x`ifconfig ${interface} | \
            grep netmask | awk -F' ' '{print $4}'`
        dhcp=`ifconfig ${interface}  | \
            grep DHCP | wc -l | awk '{print $1}'`

        eval INET_${interface}=$inet
        eval NETMASK_${interface}=$netmask
        eval DHCP_${interface}=$dhcp

        if [ $dhcp -eq 0 ]; then
                int_unplumb ${interface} ${inet} ${netmask}
        else
                int_unplumb_dhcp ${interface}
        fi

}

restore_interface()
{
        interface=$1

        eval inet=\$INET_${interface}
        eval netmask=\$NETMASK_${interface}
        eval dhcp=\$DHCP_${interface}
        if [ $dhcp -eq 0 ]; then
                int_plumb ${interface} ${inet} ${netmask}
        else
                int_plumb_dhcp ${interface}
        fi
}

#
#save all interface for a driver
#
save_all_interface()
{
        typeset driver=$1
        ALL_INTERFACE=$(ifconfig -a | grep $driver | awk -F: '{print $1}')
        for interface in $ALL_INTERFACE; do
                save_interface $interface
        done
}
#
#save all interface for a driver
#
restore_all_interface()
{
        for interface in $ALL_INTERFACE; do
                restore_interface $interface
        done
}

set_mtu()
{
	typeset interface=$1
        typeset mtu_value=$2
        typeset result=0

        dladm set-linkprop -tp mtu=$mtu_value $interface

        if [ $? -ne 0 ]; then
                return 1
        fi

        VALUE=`dladm show-linkprop -c -o VALUE -p mtu $interface`

        if [ "$VALUE" != "$mtu_value" ]; then
                return 1
        fi

        return $result

}

usage()
{
        echo "Usage: ./`basename $0` <driver> <interface_number> <mtu>"
        echo "    example: $0 e1000g 1 9000"
}


DRIVER=$1
INT_NUM=$2
MTU=$3
FAILFLAG=0

INTERFACE=${DRIVER}${INT_NUM}

if [ -z "$MTU"   -o -z "${DRIVER}" -o -z "${INT_NUM}" ]; then
	usage
	exit 1
fi

save_interface $DRIVER$INT_NUM || { FAILFLAG=1; exit 1; }

set_mtu $INTERFACE $MTU || { FAILFLAG=1; }

restore_interface $DRIVER$INT_NUM

exit $FAILFLAG

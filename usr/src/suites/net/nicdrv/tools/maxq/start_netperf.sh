#!/bin/sh
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
# ident	"@(#)start_netperf.sh	1.3	08/11/12 SMI"
#

# start_netperf.sh l_sess svr_host NETPERF_PORT cli_host l_timeout
#		   PROTOCOL_TYPE ip_version MAXQ_BUF_SIZE MAXQ_BUF_SIZE
#                  MAXQ_DATA_SIZE TOTAL_SESSION [-S -m interface]
#
# Created for saving "rsh" calls of MAXQ.auto test
# Jie Zhu - 4/7/2005

NET_PERF=netperf

trap "pkill netperf; pkill netserver; exit 1" 1 2 3 9 15

tcp_nodelay=""
if [ $# -lt 12 ]; then
  echo "start_netperf.sh syntax error: FAILED" >/tmp/start_netperf.sh.err
  exit 1
elif [ $# -eq 12 ]; then
  l_sess=$1; shift 1; export l_sess
  svr_host=$1; shift 1; export svr_host
  NETPERF_PORT=$1; shift 1; export NETPERF_PORT
  cli_host=$1; shift 1; export cli_host
  l_timeout=$1; shift 1; export l_timeout
  PROTOCOL_TYPE=$1; shift 1; export PROTOCOL_TYPE
  ip_version=$1; shift 1; export ip_version
  MAXQ_BUF_SIZE=$1; shift 1; export MAXQ_BUF_SIZE
  MAXQ_BUF_SIZE=$1; shift 1; export MAXQ_BUF_SIZE
  MAXQ_DATA_SIZE=$1; shift 1; export MAXQ_DATA_SIZE
  TOTAL_SESSION=$1; shift 1; export TOTAL_SESSION
  MAXQ_TCP_NODELAY=$1; shift 1; export MAXQ_TCP_NODELAY
elif [ $# -eq 15 ]; then
  l_sess=$1; shift 1; export l_sess
  svr_host=$1; shift 1; export svr_host
  NETPERF_PORT=$1; shift 1; export NETPERF_PORT
  cli_host=$1; shift 1; export cli_host
  l_timeout=$1; shift 1; export l_timeout
  PROTOCOL_TYPE=$1; shift 1; export PROTOCOL_TYPE
  ip_version=$1; shift 1; export ip_version
  MAXQ_BUF_SIZE=$1; shift 1; export MAXQ_BUF_SIZE
  MAXQ_BUF_SIZE=$1; shift 1; export MAXQ_BUF_SIZE
  MAXQ_DATA_SIZE=$1; shift 1; export MAXQ_DATA_SIZE
  TOTAL_SESSION=$1; shift 1; export TOTAL_SESSION
  MAXQ_TCP_NODELAY=$1; shift 1; export MAXQ_TCP_NODELAY
fi

if [ ${MAXQ_TCP_NODELAY} -ne 0 ]; then
  tcp_nodelay="-D"
fi

tmpsess=1
while [ $tmpsess -le ${l_sess} ]; do
  if [ ${PROTOCOL_TYPE} = "TCP_STREAM" ] ||
     [ ${PROTOCOL_TYPE} = "UDP_STREAM" ] ||
     [ ${PROTOCOL_TYPE} = "TCPIPV6_STREAM" ] ||
     [ ${PROTOCOL_TYPE} = "UDPIPV6_STREAM" ]; then
    /tmp/${NET_PERF} -H $svr_host -p ${NETPERF_PORT} -l $l_timeout \
		-t ${PROTOCOL_TYPE} -${ip_version} \
		-- $tcp_nodelay -s $MAXQ_BUF_SIZE -S $MAXQ_BUF_SIZE \
		   -m $MAXQ_DATA_SIZE >/tmp/netperf.${cli_host}.cnt${TOTAL_SESSION} &
  else
    /tmp/${NET_PERF} -H $svr_host -p ${NETPERF_PORT} -l $l_timeout \
		-t ${PROTOCOL_TYPE} -${ip_version} \
		-- $tcp_nodelay -s $MAXQ_BUF_SIZE -S $MAXQ_BUF_SIZE \
		   -r $MAXQ_DATA_SIZE >/tmp/netperf.${cli_host}.cnt${TOTAL_SESSION} &
  fi
  tmpsess=`expr $tmpsess + 1`
  TOTAL_SESSION=`expr $TOTAL_SESSION + 1`
done

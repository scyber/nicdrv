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
# ident	"@(#)nic_corrupt.rc.ksh	1.2	08/04/22 SMI"
#

# Define the server interfaces here.  These are the names of the 
# interfaces on the machine that the Corrupt.auto script is run
# There needs to be one server interface per client
SERVER_INT="server_int1,server_int2,server_int3,server_intN"

# Define the client interfaces here.  These are the names of the 
# interfaces on the client machines that the Corrupt.auto script 
# is pass/retrieve traffic from.  The number of client interfaces
# must match the number of server interfaces
CLIENT_INT="client1_int1,client1_int2,client2_int1,clientN_intN"

# who to mail the report to.  Can be multiple emails seperated by
# commas but no spaces
MAILTO="root@localhost"

# The title of reports and the subject for the mailed reports
PRODUCT="Cassini 1.44"

# The number of sessions to run per interface per direction
SESSIONS="1"

# What to do if a corruption is found 
#   yes record the error and keep running
#   no  stop the test once a error is encountered
RUN_ON_ERROR="no"

# Set the traffic to be:
#   bi write files from server to client and from client to server
#   rx write files from client to server
#   tx write files from server to client
TRAFFIC_TYPE="bi"

# Set the protocol to mount the remote system as
# tcp udp rdma
PROTO="tcp"

# the number of seconds to for the test suite to run
# one hour (3600) should be considered the minimum time for real tests
TIME="3600"

# For NSN auto report only.
# This should set to your Hostnames and TestMatrixIds of the systems
# you want to collect data on. Usually this is just the SUT but you
# can also list clients to gather data on with its respective TestMatrixId.
# Each client only needs listed once. The hostname must be accessible from
# the SUT.  The format is <host1:TestmatrixId1>,<host2:TestmatrixId2>.
# For Example:
#     TEST_MATRIX_ID=nspgqa145c:205,nspgqa23b:534
# You should have /suites/utils/TestMatrix/* test utility on SUT
# Comment it out if you do not want to insert test log into database
#TEST_MATRIX_ID=""; export TEST_MATRIX_ID

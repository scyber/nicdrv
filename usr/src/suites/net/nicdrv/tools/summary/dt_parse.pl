#!/usr/perl5/bin/perl
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
# ident	"@(#)dt_parse.pl	1.2	08/04/22 SMI"
#

my $file_flag = open ALLFUNC, "/tmp/driver_all_func.tmp.log";
if ( ! $file_flag )
{
        die "could not open /tmp/driver_all_func.tmp.log";
}

while ( my $next_call = <> )
{
        @key_value = split /\s+/, $next_call;
        $value = pop(@key_value);
        $key = pop(@key_value);

        $drv_func_call{$key} = $value;
}

while ( my $next_line = <ALLFUNC> )
{
	chomp($next_line);
        if ( ! $drv_func_call{$next_line} )
        {
                printf "NOT CALLED: %s\n", $next_line;
        }
}


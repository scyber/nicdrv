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
# ident	"@(#)dt_clean.pl	1.2	08/04/22 SMI"
#

my $file_flag = open ALLFUNC, "/tmp/sum_called_func.tmp.log";
if ( ! $file_flag )
{
        die "could not open /tmp//tmp/sum_called_func.tmp.log";
}
my $out_tmp = open TMPLOG, ">", "/tmp/tmp.driver_called_func.tmp.log";
if ( ! $out_tmp )
{
	die "could not open /tmp/tmp.driver_called_func.tmp.log";
}


while ( my $next_line = <ALLFUNC> )
{
	chomp($next_line);
	@key_value = split /\s+/, $next_line;
	$value = pop(@key_value);
	$key = pop(@key_value);
	if ( $value > 0 )
	{
		$drv_func_call{$key} += $value;
	}
}

sub by_value { $drv_func_call{$b} <=> $drv_func_call{$a} }

my @sort_drv_func_call = sort by_value keys %drv_func_call;

while ( $key = pop(@sort_drv_func_call) )
{
	$value = $drv_func_call{$key};
	printf TMPLOG "%-30s\t\t%30d\n", $key,$value;
}

close TMPLOG;
close ALLFUNC;

rename "/tmp/tmp.driver_called_func.tmp.log", "/tmp/drv_called_func_num.tmp.log";



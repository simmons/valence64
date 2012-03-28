#!/usr/bin/perl
######################################################################
#
# combine
#
# Merge a BASIC program and a 6502 machine language program into one
# file for convenience and fast loading.  The ML code should be linked
# for a starting address just after the end of the BASIC program.
#
# (c) 2012 David Simmons
#
# usage: combine.pl basicprogram.prg mlprog.prg > combinedprog.prg
#
######################################################################

use strict;
use warnings;
use bytes;

if (@ARGV < 2) {
	die "usage: combine.pl basicprogram.prg mlprog.prg [symbol.map]\n";
}

my ($bas, $ml);

# read BASIC file
open(BAS, $ARGV[0]) || die "cannot open basic file: $!\n";
{
	local $/;
	$bas = <BAS>;
}
close(BAS);

# read ML file
open(ML, $ARGV[1])  || die "cannot open ml file: $!\n";
{
	local $/;
	$ml = <ML>;
}
close(ML);

# read symbol table, if available
my $exports;
if (@ARGV >= 3) {
	my $in = 0;
	open(MAP, $ARGV[2]) || die "cannot open symbol map: $!\n";
	while (<MAP>) {
		chomp;
		if (/^Exports list:$/) {
			$in = 1; next;
		}
		if ($in) {
			if (/^$/) {
				$in = 0; next;
			}
			if (/^\s*(\S+)\s+(\S+)\s+\S+\s+(\S+)\s+(\S+)\s+\S+\s*$/) {
				$exports->{$1} = hex($2);
				$exports->{$3} = hex($4);
			} elsif (/^\s*(\S+)\s+(\S+)\s+\S+\s*$/) {
				$exports->{$1} = hex($2);
			}
		}

	}
	close(MAP);
}

my $jumpaddr = sprintf("%05d", 0x7FF+length($bas));

# write the actual jump addresses into the basic program,
# replacing the placeholder 'SYS "symbol"' calls.
sub translate {
	my $symbol = shift;
	my $address;
	if ($symbol eq 'JUMPSTART') {
		$address = $jumpaddr;
	} else {
		$address = $exports->{lc $symbol};
	}
	printf(STDERR "TRANSLATE $symbol -> $address\n");
	return $address;
}
my $l1 = bytes::length($bas);
$bas =~ s/\x9e "(\S+)"(.*?)\x00/sprintf("\x9e %d%s\x00",&translate($1),$2)/ge;
my $l2 = length($bas);
if ($l1 < $l2) {
	die "symbol name substitution made the program larger\n";
} elsif ($l1 > $l2) {
	# apply padding
	#printf STDERR "PADDING: ".($l1-$l2)."\n";
	$bas .= ("\xff" x ($l1-$l2));
}

# trim the first 14 bytes from the ML file.  This contains
# the 2-byte starting address, and 12 bytes of needless
# BASIC bootstrap code.
$ml = substr($ml,14);

# while we're here, hack out the cc65 runtime's annoying
# shift to the upper/lowercase character set
$ml =~ s/\xa9\x0e\x20\xd2\xff/\xa9\x8e\x20\xd2\xff/g;

# combine and deliver to stdout
print $bas;
print $ml;


#!/usr/bin/perl
######################################################################
#
# mkcfg
#
# Generate a customized ld65 configuration, using the specified
# address as the memory start location.  The goal is to link the
# code such that it starts at the end of the BASIC code to which
# it will be attached.
#
# usage: mkcfg.pl 0x2000 < gc.cfg.template > gc.cfg
#
######################################################################

if (@ARGV < 1) {
	die "usage: $0 memory-start\n";
}
my $start = $ARGV[0];
if ($start =~ /^0x([0-9a-fA-F]+)$/) {
	$start = hex($1);
} elsif ($start !~ /^\d+$/) {
	die "usage: $0 memory-start\n";
}

# allow memory usage up to the BASIC ceiling
my $size = 0xA000 - $start;

# subtract 14 bytes to compensate for the 2-byte load address
# and the 12 bytes of BASIC bootstrap that we'll be getting
# rid of in a later stage.
$start = $start - 14;

$start = sprintf('$'."%04X", $start);
$size  = sprintf('$'."%04X", $size);

while(<STDIN>) {
	s/\$\{START\}/$start/g;
	s/\$\{SIZE\}/$size/g;
	print;
}


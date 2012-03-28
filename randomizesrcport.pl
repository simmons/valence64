#!/usr/bin/perl
######################################################################
#
# randomizesrcport.pl
#
# One annoyance of developing network applications with Contiki and
# uIP for the C64 is that the initial source port is always reset
# with every fresh invocation.  This results in the remote host
# rejecting/ignoring connections from subsequent runs while it thinks
# the TCP connection state is FIN_WAIT.
#
# This script is a hack to randomize the initial source port at
# build-time, to ease development and testing.  This hack requires
# that the Contiki source be patched to add binary markers.  The patch
# is located at the bottom of this script.
#
# March 2012
# David Simmons
#
######################################################################

use strict;
use warnings;

our $FILENAME = "valence64.d64";
our $MARKER = pack('vv', 0xDEAD, 0xBEEF);

# read disk image
my $size = (stat($FILENAME))[7] || die;
my $image;
open(INFILE, $FILENAME) || die;
my $nbytes = sysread(INFILE, $image, $size);
die "underread\n" if ($nbytes != $size);
close(INFILE);

# randomize the port number
my $initial_srcport = 1024+int(rand(4096));
my $initial_srcport_packed = pack('v', $initial_srcport);
printf("using initial source port of %d (%04X).\n", $initial_srcport, $initial_srcport);
$image =~ s/$MARKER\x00\x00$MARKER/$MARKER$initial_srcport_packed$MARKER/g;

# write disk image
open(OUTFILE, "> ".$FILENAME.".new") || die;
$nbytes = syswrite(OUTFILE, $image, $size);
die "underwrite\n" if ($nbytes != $size);
close(OUTFILE);

unlink($FILENAME);
rename($FILENAME.".new", $FILENAME);

__END__

--- contiki-2.5.orig/core/net/uip.c	2011-09-06 15:43:39.000000000 -0600
+++ contiki-2.5/core/net/uip.c	2012-02-15 23:15:18.413803065 -0700
@@ -377,7 +377,12 @@
     uip_conns[c].tcpstateflags = UIP_CLOSED;
   }
 #if UIP_ACTIVE_OPEN || UIP_UDP
-  lastport = 1024;
+
+{
+	// simmons-hack: marker for initial source-port
+	u16_t x[5] = {0xdead, 0xbeef, 0x0000, 0xdead, 0xbeef};
+  lastport = 1024 + x[2];
+}
 #endif /* UIP_ACTIVE_OPEN || UIP_UDP */
 
 #if UIP_UDP

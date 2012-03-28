#!/bin/sh
######################################################################
# reloadonsave
#
# This is a hacky script to restart VICE with valence64.d64
# whenever that disk image changes (i.e. after a make).
#
######################################################################

TARGET=./valence64.d64
export DISPLAY=:0

getts() {
	lastts=$ts
	unset ts
	ts=`stat --format='%Y' $TARGET 2>/dev/null`
	if [ "$?" != "0" ]; then
		ts=0
	fi
}

changed() {
	getts
	if [ "$ts" != 0 -a "$ts" != "$lastts" ]; then
		return 0 # true
	else
		return 1 # false
	fi
}

runvice() {
	killall -15 gnome-screensaver >/dev/null 2>&1
	xset -dpms
	killall x64 >/dev/null 2>&1
	while ps aux|grep x64|grep -v grep>/dev/null; do
		echo waiting...
		sleep 0.1
	done
	#make && x64 +VICIIfull -basicload valence64.prg &
	#x64 -VICIIfull valence64.d64 &
	~/valence64/x64 -VICIIfull -remotemonitor valence64.d64 &
	#~/valence64/x64 -VICIIfull -remotemonitor -moncommands vncclient/vncclient.lbl valence64.d64 &
	sleep 1
}

# prime ts and lastts
getts
getts

# loop forever
while true; do
	inotifywait -e MODIFY .
	#echo `date`: wake up
	sleep 1
	if changed; then
		#echo `date`: run
		runvice
	fi
	#echo `date`: sleep
done


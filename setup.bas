; useful command to look for bad line numbering:
; cat setup.bas | awk '{print $1}' |grep -v \; |egrep '[0-9]' | awk 'BEGIN {A=0} {if ($1<=A) print $1; A=$1}'

10 rem ******************************
20 rem ** valence64 setup          **
30 rem ** (c) 2012 david simmons   **
40 rem ** apache 2.0 license       **
50 rem ******************************


; "poke 19,65" turns off the question mark prompt in input statements
100 poke 53280,0:poke 53281,0:dim ip(4)

;--- main ---
110 print "{clr}{lblu}valence{lred}64{gry2} network setup{down}"
120 gosub 2000
125 gosub 2100
130 print "current settings:":gosub 3000
140 print
150 p$="    ip address: ":n=49152:gosub 1000
160 p$="       netmask: ":n=49156:gosub 1000
170 p$="       gateway: ":n=49160:gosub 1000
180 p$="dns nameserver: ":n=49164:gosub 1000
190 p$="    vnc server: ":n=49216:gosub 1000
200 print "eth64/tfe: use de00; rr+rr-net: de08"
210 p$="   eth address: ":n=49168:gosub 1500
220 print "select an ethernet chipset:"
230 print "1) cs8900a (rr+rr-net and tfe)"
240 print "2) lan91c96 (eth64)"
250 poke 19,65
260 input "select: ";a
270 if a<1 or a>2 goto 250
280 if a=1 then a$="cs8900a.eth":n=49170:gosub 7000
290 if a=2 then a$="lan91c96.eth":n=49170:gosub 7000
292 print:print

300 print "proposed settings:":gosub 3000
310 input "write settings to disk (y/n)? ";a$
311 print
320 if a$<>"y" and a$<>"n" goto 310
330 if a$="n" then print:print "aborting setup.":end
340 gosub 2200
350 gosub 2300
999 end

;--- ip address prompt ---
1000 ip(0)=0:ip(1)=0:ip(2)=0:ip(3)=0:o=3:p=0:poke 19,65
1010 print "{gry2}";p$;
1020 input "{wht}";ip$:print
1030 for x = len(ip$) to 1 step -1
1040 c$ = mid$(ip$,x,1)
1050 if c$<"0" or c$>"9" goto 1100
1060 ip(o)=ip(o)+(asc(c$)-48)*(10^p):p=p+1
1070 if (ip(o)>255) goto 1300
1080 goto 1200
1100 if c$<>"." goto 1300
1110 if p=0 goto 1300
1120 p=0:o=o-1
1130 if o<0 goto 1300
1200 next x
1210 if o<>0 goto 1300
1220 print "{gry2}";
1230 if n=0 then goto 1250
1240 for x=0 to 3: poke n+x,ip(x): next x
1250 return
1300 print "{red}invalid ip address.  try again.":goto 1000

;--- uint16_t prompt ---
1500 b(0)=0:b(1)=0:y=0:z=0:poke 19,65
1501 print "{gry2}";p$;
1502 input "{wht}";a$:print
1510 if len(a$)<>4 goto 1599
1520 for x = 4 to 1 step -1
1530 c$ = mid$(a$,x,1)
1540 v = -1
1550 if c$>="0" and c$<="9" then v=asc(c$)-48
1551 if c$>="a" and c$<="f" then v=asc(c$)-55
1552 if c$>="A" and c$<="F" then v=asc(c$)-183
1553 if v = -1 goto 1599
1560 if z>0 then v=v*16: b(y)=b(y) or v: goto 1581
1570 b(y) = v
1581 if z=0 then z=1: goto 1590
1582 if z=1 then y=y+1:z=0
1590 next x
1592 poke n, b(0):poke n+1, b(1)
1593 print "{gry2}":return
1599 print "{red}invalid address.  try again.":goto 1500

;--- read contiki.cfg ---
2000 print "reading contiki settings..."
2010 for x = 0 to 63: poke 49152+x, 0: next x
2020 open 1,8,8,"contiki.cfg,usr,r"
2030 if (status and 2) goto 2095
2040 for x = 0 to 63
2050 get#1,a$
2060 poke 49152+x, asc(a$+chr$(0))
2070 if (status and 64) goto 2090
2080 next x
2090 close 1
2091 print "{up}                           ":print "{up}";
2092 return
;--- handle disk error ---
2095 open 2,8,15:input#2,e,e$,t,s:print e;e$;t;s:close 2
2096 close 1: return

;--- read valence.cfg ---
2100 print "reading valence settings..."
2110 for x = 0 to 63: poke 49216+x, 0: next x
2120 open 1,8,8,"valence.cfg,usr,r"
2130 if (status and 2) goto 2095
2140 for x = 0 to 63
2150 get#1,a$
2160 poke 49216+x, asc(a$+chr$(0))
2170 if (status and 64) goto 2190
2180 next x
2190 close 1
2191 print "{up}                           ":print "{up}";
2192 return

;--- write contiki.cfg ---
2200 print "writing contiki settings..."
2205 open 2,8,15,"s:contiki.cfg":input#2,e,e$,t,s:close 2
2210 open 1,8,8,"contiki.cfg,usr,w"
2220 if (status and 2) goto 2095
2230 n = 49152
2240 v = peek(n)
2250 print#1,chr$(v);
2260 if n<49170 or v<>0 then n=n+1:goto 2240
2270 close 1
2280 return

;--- write valence.cfg ---
2300 print "writing valence settings..."
2305 open 2,8,15,"s:valence.cfg":input#2,e,e$,t,s:close 2
2310 open 1,8,8,"valence.cfg,usr,w"
2320 if (status and 2) goto 2095
2330 print#1,chr$(peek(49216));
2331 print#1,chr$(peek(49217));
2332 print#1,chr$(peek(49218));
2333 print#1,chr$(peek(49219));
2340 close 1
2350 return

;--- show settings ---
3000 print "     ip: ";:n=49152:gosub 4000
3010 print "netmask: ";:n=49156:gosub 4000
3020 print "gateway: ";:n=49160:gosub 4000
3030 print "    dns: ";:n=49164:gosub 4000
3040 print "    vnc: ";:n=49216:gosub 4000
3050 print "ethaddr: ";:n=49168:gosub 5000
3060 print "ethname: ";:n=49170:gosub 6000
3099 return

;--- convert ip to string ---
4000 print "{grn}";
4010 for x = 0 to 3
4020 v = peek(n+x)
4030 if v >= 100 then print chr$(48+int(v/100));:v=v-int(v/100)*100
4031 if v >= 10 then print chr$(48+int(v/10));:v=v-int(v/10)*10
4032 print chr$(48+v);
4044 if (x < 3) then print ".";
4090 next x
4098 print "{gry2}"
4099 return

;--- convert uint16_t to hexstring ---
5000 print "{grn}";
5010 for x = 1 to 0 step -1
5020 v=peek(n+x)
5030 for y = 0 to 1
5040 if y then d=v and 15: goto 5060
5050 d=v/16
5060 if (d<10) then print chr$(48+d);: goto 5080
5070 print chr$(65+d-10);
5080 next y: next x: print "{gry2}":return

;--- print string ---
6000 print "{grn}";
6010 for x = 0 to 64
6020 v = peek(n+x)
6030 if v = 0 then goto 6060
6040 print chr$(v);
6050 next x
6060 print "{gry2}"
6070 return

;--- set string ---
7000 for x = 1 to len(a$)
7010 poke n+x-1, asc(mid$(a$, x, 1))
7020 next x
7030 for x = len(a$) to len(a$)+8
7040 poke n+x,0
7050 next x
7060 return


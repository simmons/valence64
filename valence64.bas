; Valence 64 - The input-only VNC client for the Commodore 64.
;
; Copyright 2012 David Simmons
; http://cafbit.com/
;
; Licensed under the Apache License, Version 2.0 (the "License");
; you may not use this file except in compliance with the License.
; You may obtain a copy of the License at
;
;     http://www.apache.org/licenses/LICENSE-2.0
;
; Unless required by applicable law or agreed to in writing, software
; distributed under the License is distributed on an "AS IS" BASIS,
; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; See the License for the specific language governing permissions and
; limitations under the License.
; 
10 rem ******************************
20 rem ** valence64                **
30 rem ** (c) 2012 david simmons   **
40 rem ** apache 2.0 license       **
50 rem ******************************
;60 rem ------------------------------
;61 rem -- lower basic ceiling from --
;62 rem -- $a000 to $2000 to make   --
;63 rem -- room for more ml code    --
;64 rem ------------------------------
;65 rem poke 56, 84 // $5400
;66 rem poke 56, 32
100 rem ------------------------------
101 rem -- splash screen            --
102 rem ------------------------------
110 let sm = 1024
111 let cm = 55296
112 print "{clr}"
113 poke 53280,0 : poke 53281, 0
120 rem ---- top line
121 for x = 0 to 19
122 let c = (x and 7) + 1
123 poke cm+20+x, c
124 poke cm+19-x, c+1
125 poke sm+20+x, 224
126 poke sm+19-x, 224
127 next x
128 sm = sm + 40
129 cm = cm + 40
140 rem ---- side lines
141 for x = 0 to 22
142 let c = (x and 7) + 1
143 poke cm, c
144 poke cm+39, c+1
145 poke sm, 224
146 poke sm+39, 224
147 sm = sm + 40
148 cm = cm + 40
149 next x
160 rem ---- bottom line
161 for x = 19 to 0 step -1
162 let c = (x and 7) + 1
163 poke cm+20+x, c
164 poke cm+19-x, c+1
165 poke sm+20+x, 224
166 poke sm+19-x, 224
167 next x
199 rem goto 240

200 sys "splash"

240 print "{home}{11 down}"
242 print "{down}{9 right}f1 - connect"
244 print "{9 right}f7 - toggle mouse/keyboard"
246 print "{3 right}crsr/joy - move mouse"
248 print "{5 right}return - click mouse"

300 rem ------------------------------
301 rem -- input loop               --
302 rem ------------------------------
310 get a$
320 if a$ = "{f1}" then gosub 1000
330 goto 310

997 rem ------------------------------
998 rem -- event handlers           --
999 rem ------------------------------
1000 sys "jumpstart"


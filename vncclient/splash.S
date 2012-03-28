;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; splash screen drawing
;
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
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.macpack cbm

CHROUT = $FFD2
SCREEN = $0400
COLOR  = $D800
WIDTH  = 36

; According to the C64 Programmer's Reference Guide, these addresses are
; "Free 0-Page Space for User Programs" and shouldn't conflict with
; BASIC or KERNAL.
ZP1  = $FB ; BASZPT
ZP1L = $FB
ZP1H = $FC
ZP2  = $FD
ZP2L = $FD
ZP2H = $FE
; cassette 96-97, 9B-9C, A3-B6(and beyond?)
ZP3  = $96
ZP3L = $96
ZP3H = $97
ZP4  = $9B
ZP4L = $9B
ZP4H = $9C
ZP5  = $A3
ZP5L = $A3
ZP5H = $A4
ZP6  = $A5
ZP6L = $A5
ZP6H = $A6
ZP7  = $A7
ZP7L = $A7
ZP7H = $A8
ZP8  = $A9
ZP8L = $A9
ZP8H = $AA
ZP9  = $AB
ZP9L = $AB
ZP9H = $AC

; splash routine's use of ZP:
screenstart = ZP1
textstart = ZP2
textcolorstart = ZP3
screenblit = ZP4
colorblit = ZP5
textblit = ZP6
textcolorblit = ZP7
; ZP9L: loop-control variable for animation of a single line
iter = ZP9L

splash:

	; initialize
	lda #<textdata
	sta textstart
	lda #>textdata
	sta textstart+1

row_render_loop:

	ldy #0
	lda (textstart),y
	cmp #$FF
	bne render_another_row
	rts

render_another_row:
	tay
	; load screenstart with the beginning of our screen area
	lda #<(SCREEN+2)
	sta screenstart
	lda #>(SCREEN+2)
	sta screenstart+1
	cpy #0
	beq row_adder_finished
row_adder:
	;; add 40 columns for each row
	lda screenstart
	clc
	adc #<40
	sta screenstart
	lda screenstart+1
	adc #>40
	sta screenstart+1
	dey
	bne row_adder
row_adder_finished:
	inc textstart
	bne do_row
	inc textstart+1

do_row:
	; loop over the line-animation sequence
	lda #(WIDTH/2-1)
	sta iter
animation_loop:

	; LEFT BLIT

	; set the blit starts for this blit
	; screenblit = screenstart + (iter-1)
	lda screenstart
	clc
	adc iter
	sta screenblit
	lda screenstart+1
	adc #00
	sta screenblit+1
	; colorblit = screenblit + (COLOR-SCREEN)
	lda screenblit
	clc
	adc #<(COLOR-SCREEN)
	sta colorblit
	lda screenblit+1
	adc #>(COLOR-SCREEN)
	sta colorblit+1
	; textblit = textstart
	lda textstart
	sta textblit
	lda textstart+1
	sta textblit+1
	; textcolorblit = textblit + width
	lda textblit
	clc
	adc #<WIDTH
	sta textcolorblit
	lda textblit+1
	adc #>WIDTH
	sta textcolorblit+1
	; length = (width/2)-iter
	lda #(WIDTH/2)
	sec
	sbc iter
	tay

	; blit
leftblit:
	lda (textblit),Y
	sta (screenblit),Y
	lda (textcolorblit),Y
	sta (colorblit),Y
	dey
	bpl leftblit

	; RIGHT BLIT

	; set the blit starts for this blit
	; screenblit = screenstart + width/2
	lda screenstart
	clc
	adc #<(WIDTH/2)
	sta screenblit
	lda screenstart+1
	adc #>(WIDTH/2)
	sta screenblit+1
	; colorblit = screenblit + (COLOR-SCREEN)
	lda screenblit
	clc
	adc #<(COLOR-SCREEN)
	sta colorblit
	lda screenblit+1
	adc #>(COLOR-SCREEN)
	sta colorblit+1
	; textblit = textstart + width/2 + iter
	lda textstart
	clc
	adc #<(WIDTH/2)
	sta textblit
	lda textstart+1
	adc #>(WIDTH/2)
	sta textblit+1
	lda textblit
	clc
	adc iter
	sta textblit
	lda textblit+1
	adc #$00
	sta textblit+1
	; textcolorblit = textblit + width
	lda textblit
	clc
	adc #<WIDTH
	sta textcolorblit
	lda textblit+1
	adc #>WIDTH
	sta textcolorblit+1
	; length = (width/2)-iter
	lda #(WIDTH/2)
	sec
	sbc iter
	tay
	dey

	; blit
rightblit:
	lda (textblit),Y
	sta (screenblit),Y
	lda (textcolorblit),Y
	sta (colorblit),Y
	dey
	bpl rightblit


	; delay
	ldx #20
	ldy #00
delayloop:
	dey
	bne delayloop
	dex
	bne delayloop

	dec iter
	bmi animation_loop_finish
	jmp animation_loop
animation_loop_finish:

	; advance to the next textdata line
	lda textstart
	clc
	adc #<(WIDTH*2)
	sta textstart
	lda textstart+1
	adc #>(WIDTH*2)
	sta textstart+1
	jmp row_render_loop

	rts

textdata:

	.byte 2 ; row
	.byte $20, $df, $20, $20, $e9, $20, $20, $20, $20, $20, $e9, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $e9, $a0, $df, $20, $e9, $20, $e9, $20
	.byte 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6
	.byte 6, 6, 6, 6, 6, 6, 6, 6, 6, 2, 2, 2, 2, 2, 2, 2, 2, 2
	.byte 3 ; row
	.byte $20, $a0, $20, $20, $a0, $20, $20, $20, $20, $20, $a0, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $a0, $20, $20, $20, $a0, $20, $a0, $20
	.byte 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6
	.byte 6, 6, 6, 6, 6, 6, 6, 6, 6, 2, 2, 2, 2, 2, 2, 2, 2, 2
	.byte 4 ; row
	.byte $20, $a0, $20, $20, $a0, $20, $e9, $a0, $a0, $20, $a0, $20, $a0, $e2, $a0, $20, $a0, $a0, $df, $20, $e9, $a0, $df, $20, $a0, $e2, $a0, $20, $a0, $a0, $df, $20, $a0, $a0, $a0, $74
	.byte 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6
	.byte 6, 6, 6, 6, 6, 6, 6, 6, 6, 2, 2, 2, 2, 2, 2, 2, 2, 2
	.byte 5 ; row
	.byte $20, $5f, $df, $e9, $69, $20, $a0, $20, $a0, $20, $a0, $20, $a0, $e2, $e2, $20, $a0, $20, $a0, $20, $a0, $20, $20, $20, $a0, $e2, $e2, $20, $a0, $20, $a0, $20, $20, $20, $a0, $20
	.byte 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6
	.byte 6, 6, 6, 6, 6, 6, 6, 6, 6, 2, 2, 2, 2, 2, 2, 2, 2, 2
	.byte 6 ; row
	.byte $20, $20, $5f, $69, $20, $20, $5f, $a0, $a0, $20, $a0, $20, $5f, $62, $62, $20, $a0, $20, $a0, $20, $5f, $a0, $69, $20, $5f, $62, $62, $20, $5f, $a0, $69, $20, $20, $20, $a0, $20
	.byte 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6
	.byte 6, 6, 6, 6, 6, 6, 6, 6, 6, 2, 2, 2, 2, 2, 2, 2, 2, 2

	.byte 9 ; row
	scrcode " the input-only vnc client for the  "
	.byte 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
	.byte 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1

	.byte 10 ; row
	scrcode "            commodore 64            "
	.byte 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
	.byte 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1

	.byte 23 ; row
	scrcode "       (c) 2012 david simmons       "
	.byte 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
	.byte 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1

	.byte $FF; end-of-data

.condes splash, 6


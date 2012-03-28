
;set up some helpful labels
CLEAR =  $E544
CHROUT = $FFD2

.segment "BASICSTUB"

.byte $00
.byte $C0

.code
main:
	jsr CLEAR
	ldx #0
loop:
	lda greeting,x
	cmp #0
	beq finish
	jsr CHROUT
	inx
	jmp loop
finish:
	rts

.data
greeting:
	.byte "HELLO, WORLD!"
	.byte $00


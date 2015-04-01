 		DEVICE	ZXSPECTRUM48
; -----------------------------------------------------------------[12.12.2014]
; ReVerSE-U16 NES Loader Version 1.0.0 By MVV
; -----------------------------------------------------------------------------
; V1.0.0  29.11.2014	перва€ верси€

osd_buffer_size			equ 2048


port_00				equ #00		; sc spi port w/r
port_01				equ #01		; data spi port	w/r
port_02				equ #02		; status spi port r
port_03				equ #03		; uart w/r bit7 = busy
port_04				equ #04		; keyscan (#02 = reload)
port_05				equ #05		; data spi1 port w/r
port_06				equ #06		; status spi1 port r


sc_flash			equ %11111110
sc_sd				equ %11111101
cs_data_io			equ %11111011
cs_osd				equ %11110111
cs_user_io			equ %11101111

OSD_CMD_ENABLE			equ #4f
OSD_CMD_DISABLE			equ #40
OSD_CMD_WRITE			equ #20

USERIO_CMD_READ_CONFIG_STR	equ #14
USERIO_CMD_BUTSW		equ #01		; Switches[3:2], Buttons [1:0]
USERIO_CMD_JOY0			equ #02		; Joystick0[7:0]
USERIO_CMD_JOY1			equ #03		; Joystick1[7:0]
USERIO_CMD_PS2			equ #05		; PS/2[7:0]
USERIO_CMD_STATUS		equ #15		; Status[7:0]

UIO_FILE_TX			equ #53
UIO_FILE_TX_DAT			equ #54

img_len				equ 40976
;img_len23_16			equ #00
;img_len_15_0			equ #A010	; 40976

	org #0000
startprog:
	di
	ld sp,stack_top

	ld hl,tst00
	call tx_str

	ld d,0
	call spi_end




	ld hl,tst01
	call tx_str
	call cls		; очистка OSD буфера

	ld hl,tst02
	call tx_str
	ld hl,str1
	call print_str		; печать в OSD буфер


 	ld b,0
 	ld hl,osd_buffer
pp1	
	ld a,(hl)
 	cpl
 	ld (hl),a
 	inc hl
 	djnz pp1


; ID read
	ld d,sc_flash
	call spi_start
	ld d,%10101011	; command ID read
	call spi_w
	call spi_r
	call spi_r
	call spi_r
	call spi_r

	call print_hex
	ld d,sc_flash
	call spi_end




	ld hl,tst04
	call tx_str
	call osd_on

	ld hl,tst03
	call tx_str
	call push_osd		; отправить OSD буфер


	ld hl,tst05
	call tx_str
	call cmd_14


; 0CC000
; -----------------------------------------------------------------------------
; SPI autoloader
; -----------------------------------------------------------------------------
	ld d,cs_data_io
	call spi_start
	ld d,UIO_FILE_TX
	call spi1_w
	ld d,#ff
	call spi1_w
	ld d,cs_data_io
	call spi_end

	ld d,cs_data_io
	call spi_start
	ld d,UIO_FILE_TX_DAT
	call spi1_w
;---	

	ld d,sc_flash
	call spi_start
	ld d,%00000011	; command = read
	call spi_w

	ld d,#0c	; address = #0cc000
	call spi_w
	ld d,#c0
	call spi_w
	ld d,#00
	call spi_w

; 	ld e,img_len23_16
; 	ld bc,img_len_15_0

; spi_loader1
; 	call spi_r
; 	ld d,a
; 	call spi1_w

; 	dec bc
; 	ld a,c
; 	or b
; 	jr nz,spi_loader1
; 	ld a,e
; 	sub 1
; 	ld e,a
; 	jr nc,spi_loader1


	ld bc,img_len

spi_loader1
	call spi_r
	ld d,a
	call spi1_w

	dec bc
	ld a,c
	or b
	jr nz,spi_loader1

	ld d,cs_data_io
	call spi_end

	ld d,sc_flash
	call spi_end



; -----------------------------------------------------------------------------
; загрузка *.nes
; -----------------------------------------------------------------------------
; 	ld hl,tst06		; "CMD: UIO_FILE_TX"
; 	call tx_str

; 	ld d,cs_data_io
; 	call spi_start
; 	ld d,UIO_FILE_TX
; 	call spi1_w
; 	ld d,#ff
; 	call spi1_w
; 	ld d,cs_data_io
; 	call spi_end

; 	ld hl,tst07		; "CMD: UIO_FILE_TX_DAT"
; 	call tx_str

; 	ld d,cs_data_io
; 	call spi_start
; 	ld d,UIO_FILE_TX_DAT
; 	call spi1_w
	
; 	ld bc,img_len
; 	ld hl,img
; load0
; 	ld d,(hl)
; 	inc hl
; 	call spi1_w
; 	dec bc
; 	ld a,c
; 	or b
; 	jr nz,load0

; 	ld d,cs_data_io
; 	call spi_end

; 	ld hl,tst08
; 	call tx_str


; 	ld hl,tst06
; 	call tx_str

	ld d,cs_data_io
	call spi_start
	ld d,UIO_FILE_TX
	call spi1_w
	ld d,#00
	call spi1_w
	ld d,cs_data_io
	call spi_end


key1
	in a,(port_04)
	cp #ff
	jr nz,key1
	in a,(port_04)
	cp #3a			; F1
	jr z,key2
	cp #47			; Scroll
	jr z,key4
	cp #29			; Esc
	jr z,key7
	jr key1

key2
	ld a,(status)
	xor %00000010
key5
	ld (status),a
	call status_put
	jr key1

key4
	ld a,(status)
	or %00000001
	ld (status),a
	call status_put
key6
	ld a,(status)
	and %11111110
	ld (status),a
	call status_put
	jr key1

key7
	ld a,(status)
	rlca
	jr c,key8
	call osd_on
key9
	ld a,(status)
	xor %10000000
	jr key5

key8
	call osd_off
	jr key9
;	ld a,cs_user_io
;	call spi_start
;	ld d,USERIO_CMD_BUTSW
;	call spi_w
;	ld d,#00
;	call spi_w
;	call spi_end

status_put
	ld d,cs_user_io
	call spi_start
	ld d,USERIO_CMD_STATUS
	call spi1_w
	ld a,(status)
	ld d,a
	call spi1_w
	ld d,cs_user_io
	call spi_end
	ret


; -----------------------------------------------------------------------------
; CMD 0x14
; -----------------------------------------------------------------------------
cmd_14
	ld hl,buffer
	ld d,cs_user_io
	call spi_start
	ld d,USERIO_CMD_READ_CONFIG_STR		; command
	call spi1_wr
	ld b,#ff
cmd_14h0
	or a
	jr z,cmd_14h2
	ld (hl),a
	call tx_char
	inc hl
	djnz cmd_14h1
cmd_14h2
	ld d,cs_user_io	
	call spi_end
	ret
cmd_14h1
	call spi1_r
	jr cmd_14h0


tx_hex
	ld e,d
	ld a,d
	and $f0
	rrca
	rrca
	rrca
	rrca
	call tx_hex2
	ld a,e
	and $0f
tx_hex2
	cp 10
	jr nc,tx_hex1
	add 48
	jp tx_char
tx_hex1
	add 55
	jp tx_char



;==============================================================================

; -----------------------------------------------------------------------------
; ќтправить OSD буфер
; -----------------------------------------------------------------------------
push_osd
	ld d,cs_osd
	call spi_start
	ld d,OSD_CMD_WRITE	; command
	call spi1_w
	ld d,#00
	call spi1_w

	ld hl,osd_buffer
	ld bc,osd_buffer_size
push_osd1
	ld d,(hl)
	call spi1_w
	inc hl
	dec bc
	ld a,c
	or b
	jr nz,push_osd1
	ld d,cs_osd
	call spi_end
	ret

; -----------------------------------------------------------------------------
; ¬ключить OSD
; -----------------------------------------------------------------------------
osd_on
	ld d,cs_osd
	call spi_start
	ld d,OSD_CMD_ENABLE
	call spi1_w
	ld d,cs_osd
	call spi_end
	ret

; -----------------------------------------------------------------------------
; ќтключить OSD
; -----------------------------------------------------------------------------
osd_off
	ld d,cs_osd
	call spi_start
	ld d,OSD_CMD_DISABLE
	call spi1_w
	ld d,cs_osd
	call spi_end
	ret



; -----------------------------------------------------------------------------	
; SPI 
; -----------------------------------------------------------------------------
; Ports:

; Data Buffer (write/read)
;	bit 7-0	= Stores SPI read/write data

; Status Register (read):
; 	bit 7	= 1:BUSY	(Currently transmitting data)
;	bit 6-0	= Reserved

spi_start
	ld a,(spi_sc)
	and d
	out (port_00),a		; CS
	ld (spi_sc),a
	ret
spi_end
	ld a,d
	cpl
	ld d,a
	ld a,(spi_sc)
	or d
	out (port_00),a
	ld (spi_sc),a
	ret

spi_w
	in a,(port_02)		; Status Register
	rlca
	jr c,spi_w
	ld a,d
	out (port_01),a		; Data Buffer

;	call tx_hex
;	ld a," "
;	call tx_char

	ret
spi_r
	ld d,#ff
spi_wr
	call spi_w
spi_r1	
	in a,(port_02)		; Status Register
	rlca
	jr c,spi_r1
	in a,(port_01)		; Data Buffer
	ret

; -----------------------------------------------------------------------------	
; SPI 
; -----------------------------------------------------------------------------
; Ports:

; Data Buffer (write/read)
;	bit 7-0	= Stores SPI read/write data

; Status Register (read):
; 	bit 7	= 1:BUSY	(Currently transmitting data)
;	bit 6-0	= Reserved

spi1_w
	in a,(port_06)		; Status Register
	rlca
	jr c,spi1_w
	ld a,d
	out (port_05),a		; Data Buffer

;	call tx_hex
;	ld a," "
;	call tx_char

	ret
spi1_r
	ld d,#ff
spi1_wr
	call spi1_w
spi1_r1	
	in a,(port_06)		; Status Register
	rlca
	jr c,spi1_r1
	in a,(port_05)		; Data Buffer
	ret




; -----------------------------------------------------------------------------	
; UART 
; -----------------------------------------------------------------------------
; Ports:
; DATA		W
; STATUS	R: bit0=0:tx_full

; HL=STRING, #00 = END STRING

tx_str	
	in a,(port_02)
	rrca
	jr c,tx_str	; cy=1 :buffer full, wait...
	ld a,(hl)
	or a
	ret z		; z=0 :end string
	inc hl
	out (port_03),a
	jr tx_str

tx_char
	push af
tx_char1	
	in a,(port_02)
	rrca
	jr c,tx_char1	; cy=1 :buffer full, wait...
	pop af
	out (port_03),a
	ret
;==============================================================================

; -----------------------------------------------------------------------------
; clear OSD buffer
; -----------------------------------------------------------------------------
cls
	ld hl,osd_buffer
	ld bc,osd_buffer_size
cls1
	xor a
	ld (hl),a
	inc hl
	dec bc
	ld a,b
	or c
	jr nz,cls1
	ret

; -----------------------------------------------------------------------------
; print string i: hl - pointer to string zero-terminated
; -----------------------------------------------------------------------------
print_str
	ld a,(hl)
	cp 23
	jr z,print_pos_xy
	cp 24
	jr z,print_pos_x
	cp 25
	jr z,print_pos_y
	or a
	ret z
	inc hl
	call print_char
	jr print_str
print_pos_xy
	inc hl
	ld a,(hl)
	ld (pos_x),a		; x-coord
	inc hl
	ld a,(hl)
	ld (pos_y),a		; y-coord
	inc hl
	jr print_str
print_pos_x
	inc hl
	ld a,(hl)
	ld (pos_x),a		; x-coord
	inc hl
	jr print_str
print_pos_y
	inc hl
	ld a,(hl)
	ld (pos_y),a		; y-coord
	inc hl
	jr print_str

; -----------------------------------------------------------------------------
; print character i: a - ansi char
; -----------------------------------------------------------------------------
print_char
	push hl
	push de
	push bc
	cp 13
	jr z,pchar2
	sub 32
	ld c,a			; временно сохранить в с

	ld a,(pos_y)
	add a,#13		; osd_buffer
	ld d,a
	ld a,(pos_x)
	rlca
	rlca
	rlca
	ld e,a			; de=адрес печати в osd_buffer

	ld h,0
	ld l,c
	add hl,hl
	add hl,hl
	add hl,hl
	ld bc,font
	add hl,bc

	ld b,8
pchar3	
	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	djnz pchar3

	ld a,(pos_x)		; x
	inc a
	cp 32
	jr c,pchar1
pchar2
	ld a,(pos_y)		; y
	inc a
	cp 8
	jr c,pchar0
	xor a
pchar0
	ld (pos_y),a
	xor a
pchar1
	ld (pos_x),a
	pop bc
	pop de
	pop hl
	ret

; -----------------------------------------------------------------------------
; print hexadecimal i: a - 8 bit number
; -----------------------------------------------------------------------------
print_hex
	ld b,a
	and $f0
	rrca
	rrca
	rrca
	rrca
	call hex2
	ld a,b
	and $0f
hex2
	cp 10
	jr nc,hex1
	add 48
	jp print_char
hex1
	add 55
	jp print_char

; -----------------------------------------------------------------------------
; print decimal i: l,d,e - 24 bit number , e - low byte
; -----------------------------------------------------------------------------
print_dec
	ld ix,dectb_w
	ld b,8
	ld h,0
lp_pdw1
	ld c,"0"-1
lp_pdw2
	inc c
	ld a,e
	sub (ix+0)
	ld e,a
	ld a,d
	sbc (ix+1)
	ld d,a
	ld a,l
	sbc (ix+2)
	ld l,a
	jr nc,lp_pdw2
	ld a,e
	add (ix+0)
	ld e,a
	ld a,d
	adc (ix+1)
	ld d,a
	ld a,l
	adc (ix+2)
	ld l,a
	inc ix
	inc ix
	inc ix
	ld a,h
	or a
	jr nz,prd3
	ld a,c
	cp "0"
	ld a," "
	jr z,prd4
prd3
	ld a,c
	ld h,1
prd4
	call print_char
	djnz lp_pdw1
	ret
dectb_w
	db #80,#96,#98		; 10000000 decimal
	db #40,#42,#0f		; 1000000
	db #a0,#86,#01		; 100000
	db #10,#27,0		; 10000
	db #e8,#03,0		; 1000
	db 100,0,0		; 100
	db 10,0,0		; 10
	db 1,0,0		; 1


; -----------------------------------------------------------------------------
; управл€ющие коды
; 13 (0x0d)		- след строка
; 17 (0x11),color	- изменить цвет последующих символов
; 23 (0x17),x,y		- изменить позицию на координаты x,y
; 24 (0x18),x		- изменить позицию по x
; 25 (0x19),y		- изменить позицию по y
; 0			- конец строки

; x(0-31),y(0-7)
str1	
	db 23,2,0,"NES demo v1.2 on ReVerSE-U16",13
	db "F1=HQ2X ON/OFF; Scroll=Reset",13
	db 24,13,"DJOY1:",13
	db "Use arrow keys for D-Pad",13
	db "A[A],B[S],Sel[RShift],Start[Ent]"
	db 24,13,"DJOY2:",13
	db "Use Numpad keys for D-Pad",13
	db "A[1],B[2],Sel[3],Start[4]  ID:",0

; -----------------------------------------------------------------------------

tst00	db #0a,#0d,#0a,#0d,"U16-Debuger v1.3 By MVV, 2014",0
tst01	db #0a,#0d,"cls",0
tst02	db #0a,#0d,"print_str",0
tst03	db #0a,#0d,"push_osd",0
tst04	db #0a,#0d,"osd_on",0
tst05	db #0a,#0d,"CMD: READ_CONFIG_STR = ",0
tst06	db #0a,#0d,"CMD: UIO_FILE_TX",0
tst07	db #0a,#0d,"CMD: UIO_FILE_TX_DAT",0
tst08	db #0a,#0d,"End of loading img",0




	display "End: ",/a, $

	org #1300

;osd_buffer			equ	#1300	; размер 2048 байт = (ширина=32 х высота=64)
;stack_top			equ	#12fe
;pos_y				equ	#1200
;pos_x				equ	#1201
;buffer				equ	#1100	; 256

osd_buffer	ds osd_buffer_size
buffer		ds 256
pos_y		db 0
pos_x		db 0
		ds 40
stack_top	db 0,0
status		db 0
spi_sc		db 255

font	INCBIN "font.bin"
;img	INCBIN "mario_bros.nes"

	savebin "loader.bin",startprog, 32768

	display "Size of ROM is: ",/a, $
	display "osd_buffer = ",/a, osd_buffer
	display "font = ",/a, font
;	display "img = ",/a, img

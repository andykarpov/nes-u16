 		DEVICE	ZXSPECTRUM48
; -----------------------------------------------------------------[08.01.2016]
; ReVerSE-U16 NES Loader By MVV
; -----------------------------------------------------------------------------
; 29.11.2014	первая версия
; 08.11.2015	OSD буфер

osd_buffer			equ #7800	; OSD buffer start address (2048 bytes length)
osd_buffer_size			equ 2048
stack_top			equ #1300

port_00				equ #00		; sc spi port w/r
port_01				equ #01		; data spi port	w/r
port_02				equ #02		; status spi port r
port_03				equ #03		; buttons
port_04				equ #04		; joy1
port_05				equ #05		; data spi1 port w/r
port_06				equ #06		; status spi1 port r
port_07				equ #07		; switches w, key0-6 r
port_0f				equ #0f		; joy2

sc_flash			equ %11111110
sc_sd				equ %11111101
cs_data_io			equ %11111011

UIO_FILE_TX			equ #53
UIO_FILE_TX_DAT			equ #54

	org #0000
startprog:
	di
	ld sp,stack_top
	ld d,0
	call spi_end
	call cls		; очистка OSD буфера
	ld hl,str1
	call print_str		; печать в OSD буфер
inverse	
 	ld hl,osd_buffer
 	ld b,0
inverse1	
	ld a,(hl)
 	cpl
 	ld (hl),a
 	inc hl
 	djnz inverse1

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

	;ld de,rom1
	db #11
addr7	dw rom1
	call rom_loader
key1
	xor a
	ld (joy1),a
	ld (joy2),a
	ld (buttons),a
	ld bc,#0607
key_loop
	in a,(c)
	; Switches
	ld de,#023b
	cp e			; [F1] OSD Menu
	jp z,key_switches
	ld de,#013a
	cp e			; [F2] HQ2X
	jp z,key_switches
	; Buttons
	cp #3c			; [F3] Reset
	ld d,%00000001
	jp z,key_bottons

	jp keytest

key_loop1	
	; Joy 1 NES Data Format
	cp #04			; [A] A
	ld d,%10000000
	jp z,key_joy1
	cp #16			; [S] B
	ld d,%01000000
	jp z,key_joy1
	cp #2c			; [Space] Select
	ld d,%00100000
	jp z,key_joy1
	cp #28			; [ENTER] Start
	ld d,%00010000
	jr z,key_joy1
	cp #52			; [UP] Up
	ld d,%00001000
	jr z,key_joy1
	cp #51			; [DOWN] Down
	ld d,%00000100
	jr z,key_joy1
	cp #50			; [LEFT] Left
	ld d,%00000010
	jr z,key_joy1
	cp #4f			; [REGHT] Right
	ld d,%00000001
	jr z,key_joy1
key_loop2
	; Joy 2 NES Data Format
	cp #1e			; [1] A
	ld d,%10000000
	jr z,key_joy2
	cp #1f			; [2] B
	ld d,%01000000
	jr z,key_joy2
	cp #20			; [3] Select
	ld d,%00100000
	jr z,key_joy2
	cp #21			; [4] Start
	ld d,%00010000
	jr z,key_joy2
	cp #60			; [8] Up
	ld d,%00001000
	jr z,key_joy2
	cp #5d			; [2] Down
	ld d,%00000100
	jr z,key_joy2
	cp #5c			; [4] Left
	ld d,%00000010
	jr z,key_joy2
	cp #5e			; [6] Right
	ld d,%00000001
	jr z,key_joy2
key_loop3
	djnz key_loop
	db #3e			; ld a,n вместо ld a,(joy1)
joy1	db #00
	out (port_04),a
	db #3e			; ld a,n вместо ld a,(joy2)
joy2	db #00
	out (port_0f),a
	db #3e			; ld a,n вместо ld a,(buttons)
buttons	db #00	
	out (port_03),a
	jp key1
key_switches	
	ex af,af'
	db #3e			; ld a,n вместо ld a,(switches)
switches
	db #00
	xor d
	ld (switches),a
	out (port_07),a
key_switches1	
	in a,(c)
	cp e
	jr z,key_switches1
	ex af,af'
	jp key_loop1
key_bottons
	ex af,af'
	ld a,(buttons)
	or d
	ld (buttons),a
	ex af,af'
	jp key_loop1
key_joy1
	ex af,af'
	ld a,(joy1)
	or d
	ld (joy1),a
	ex af,af'
	jr key_loop2
key_joy2
	ex af,af'
	ld a,(joy2)
	or d
	ld (joy2),a
	ex af,af'
	jr key_loop3

keytest
	ld de,rom1
	cp #3e			; F5
	jp z,rom_loader
	ld de,rom2
	cp #3f			; F6
	jp z,rom_loader
	ld de,rom3
	cp #40			; F7
	jp z,rom_loader
	jp key_loop1
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
	db #3e			; ld a,n вместо ld a,(spi_sc)
spi_sc	db #ff
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
	db #3e			; ld a,n вместо ld a,(pos_y)
pos_y	db #00
	add a,high osd_buffer	; osd_buffer
	ld d,a
	db #3e			; ld a,n вместо ld a,(pos_x)
pos_x	db #00
	ld e,a
	add a,e
	add a,e
	add a,e
	add a,e
	add a,e
	add a,2
	ld e,a			; de=адрес печати в osd_buffer
	ld h,0
	ld l,c
	add hl,hl
	add hl,hl
	add hl,hl
	ld bc,font
	add hl,bc
	ld b,6
pchar3	
	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	djnz pchar3
	ld a,(pos_x)		; x
	inc a
	cp 42
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
; ROM loader
; -----------------------------------------------------------------------------
rom_loader
	ld (addr7),de
	ld a,(de)	; start address
	ld (addr1),a
	inc de
	ld a,(de)
	ld (addr2),a
	inc de
	ld a,(de)
	ld (addr3),a

	inc de
	ld a,(de)	; end address
	ld (addr4),a
	inc de
	ld a,(de)
	ld (addr5),a
	inc de
	ld a,(de)
	ld (addr6),a

; SPI loader
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
	ld d,sc_flash
	call spi_start
	ld d,%00000011	; command = read
	call spi_w
	;ld d,n
	db #16		; address
addr1	db #00
	ld e,d
	call spi_w
	db #16
addr2	db #00
	ld h,d
	call spi_w
	db #16
addr3	db #00
	ld l,d
	call spi_w
spi_loader1
 	call spi_r
 	ld d,a
 	call spi1_w
 	

 	ld bc,#0001
 	add hl,bc
 	ld a,e
 	adc a,b
 	ld e,a

 	db #3e
addr4	db #00
 	cp e
 	jr nz,spi_loader1
	db #3e
addr5	db #00
 	cp h
 	jr nz,spi_loader1
	db #3e
addr6	db #00
 	cp l
 	jr nz,spi_loader1
 
	ld d,cs_data_io
	call spi_end
	ld d,sc_flash
	call spi_end

	ld d,cs_data_io
	call spi_start
	ld d,UIO_FILE_TX
	call spi1_w
	ld d,#00
	call spi1_w
	ld d,cs_data_io
	call spi_end
	ret

; -----------------------------------------------------------------------------
; управляющие коды
; 13 (0x0d)		- след строка
; 23 (0x17),x,y		- изменить позицию на координаты x,y
; 24 (0x18),x		- изменить позицию по x
; 25 (0x19),y		- изменить позицию по y
; 0			- конец строки

; x(0-41),y(0-7)

str1	
;	   "------------------------------------------"
	db 23,0,0
	db "[NES] ReVerSE-U16c (build 20160108) By MVV"
	db "F1: OSD; F2: hq2x; F3: Reset; F4: Load ROM"
	db "DJOY1: use arrow keys for D-Pad",13
	db "A=A B=S Sel=Space Start=Enter",13
	db "DJOY2: use numpad keys for D-Pad",13
	db "A=1 B=2 Sel=3 Start=4",13
	db "F5=Gradius; F6=1942; F7=Super Mario Bros",13
	db "FLASH ID:",0

rom1	db #0c,#c0,#00	; address 0cc000 Gradius
;	db #01,#00,#90	; length  010090
rom2	db #0d,#c0,#90	; address 0dc090 1942
;	db #00,#a0,#10	; length  00a010
rom3	db #0e,#60,#a0	; address 0e60a0 Super Mario Bros
;	db #00,#a0,#10	; length  00a010
	db #0f,#00,#b0

; -----------------------------------------------------------------------------

	display "End: ",/a, $

font	INCBIN "font.bin"

	savebin "loader.bin",startprog, 32768

	display "osd_buffer start = ",/a, osd_buffer
	display "font start = ",/a, font
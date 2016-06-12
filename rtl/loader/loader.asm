 		DEVICE	ZXSPECTRUM48
; -----------------------------------------------------------------[17.02.2016]
; ReVerSE-U16 NES Loader By MVV
; -----------------------------------------------------------------------------
; 29.11.2014	перва€ верси€
; 08.11.2015	OSD буфер
; 07.06.2016	added new games by andy.karpov
; 12.06.2016	changed OSD control buttons by andy.karpov

osd_buffer			equ #7800	; OSD buffer start address (2048 bytes length)
osd_buffer_size			equ 2048
stack_top			equ #1300

port_00				equ #00		; sc spi port w/r
port_01				equ #01		; data spi port	w/r
port_02				equ #02		; status spi port r
port_03				equ #03		; buttons
port_04				equ #04		; joy1
port_05				equ #05		; data downloader port w/r
port_06				equ #06		; --
port_07				equ #07		; switches w, key0-6 r
port_0f				equ #0f		; joy2

sc_flash			equ %11111110
sc_sd				equ %11111101
download_on			equ %11111011

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
	ld a,40		; x
	ld (pos_x),a
	ld a,6		; y
	ld (pos_y),a

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
	call print_header
key1
	xor a
	ld (joy1),a
	ld (joy2),a
	ld (buttons),a
	ld bc,#0607
key_loop
	in a,(c)
	; Switches
	ld de,#022B
	cp e			; Tab = HQ2X
	jp z,key_switches
	ld de,#012A
	cp e			; Backspace = OSD Menu
	jp z,key_switches
	; Buttons
	cp #29			; Esc = Reset
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
	cp #62			; [Keypad 0 Insert] A
	ld d,%10000000
	jr z,key_joy2
	cp #59			; [Keypad 1 End] B
	ld d,%01000000
	jr z,key_joy2
	cp #57			; [Keypad +] Select
	ld d,%00100000
	jr z,key_joy2
	cp #58			; [Keypad Enter] Start
	ld d,%00010000
	jr z,key_joy2
	cp #60			; [Keypad 8 Up] Up
	ld d,%00001000
	jr z,key_joy2
	cp #5d			; [Keypad 5] Down
	ld d,%00000100
	jr z,key_joy2
	cp #5c			; [Keypad 4 Left] Left
	ld d,%00000010
	jr z,key_joy2
	cp #5e			; [Keypad 6 Right] Right
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
	cp #3a			; F1
	jp z,rom_loader
	ld de,rom2
	cp #3b			; F2
	jp z,rom_loader
	ld de,rom3
	cp #3c			; F3
	jp z,rom_loader
	ld de,rom4
	cp #3d			; F4
	jp z,rom_loader
	ld de,rom5
	cp #3e			; F5
	jp z,rom_loader
	ld de,rom6
	cp #3f			; F6
	jp z,rom_loader
	ld de,rom7
	cp #40			; F7
	jp z,rom_loader
	ld de,rom8
	cp #41			; F8
	jp z,rom_loader
	ld de,rom9
	cp #42			; F9
	jp z,rom_loader
	ld de,rom10
	cp #43			; F10
	jp z,rom_loader
	ld de,rom11
	cp #44			; F11
	jp z,rom_loader
	ld de,rom12
	cp #45			; F12
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
	ld c,a
	and $f0
	rrca
	rrca
	rrca
	rrca
	call hex2
	ld a,c
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
	ld a,(de)		; start address
	ld (addr1),a
	inc de
	ld a,(de)
	ld (addr2),a
	inc de
	ld a,(de)
	ld (addr3),a
	inc de
	ld a,(de)		; end address
	ld (addr4),a
	inc de
	ld a,(de)
	ld (addr5),a
	inc de
	ld a,(de)
	ld (addr6),a

; SPI loader
; -----------------------------------------------------------------------------
	ld d,download_on
	call spi_start
	ld d,sc_flash
	call spi_start
	ld d,#03		; command = read
	call spi_w
	;ld d,n
	db #16			; set address
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
	
; checksum = #000000
	xor a
	ld (checksum_32),a
	ld (checksum_24),a
	ld (checksum_16),a
	ld (checksum_08),a
	ld (header_cnt),a
	ld ix,header

spi_loader1
 	call spi_r		; a <= spiflash byte
 	out (port_05),a		; a => sdram
 
; checksum 32bit
	ld c,a
	ld b,#00
	ld a,(checksum_08)
	add a,c
	ld (checksum_08),a
	ld a,(checksum_16)
	adc a,b
	ld (checksum_16),a
	ld a,(checksum_24)
	adc a,b
	ld (checksum_24),a
	ld a,(checksum_32)
	adc a,b
	ld (checksum_32),a

 	ld a,(header_cnt)	; =0? End
	cp 8
 	jr nc,loop2
	inc a
 	ld (header_cnt),a
	ld (ix+0),c		; c => (header)
	inc ix
;-----------	

loop2 	ld c,#01
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
;-----------	

; 	in a,(port_05)
; 	rlca
; 	jr nc,spi_loader1

	ld d,download_on
	call spi_end
	ld d,sc_flash
	call spi_end

	ld a,34			; x
	ld (pos_x),a
	ld a,7			; y
	ld (pos_y),a
	ld a,(checksum_32)
	call print_hex
	ld a,(checksum_24)
	call print_hex
	ld a,(checksum_16)
	call print_hex
	ld a,(checksum_08)
	call print_hex
	ret
;----------------------------------
print_header
	ld a,4			; x
	ld (pos_x),a
	ld a,7			; y
	ld (pos_y),a
	ld ix,header
	ld a,(ix+4)
	call print_hex
	ld a,11			;x
	ld (pos_x),a
	ld a,(ix+5)
	call print_hex
	ld a,21			;x
	ld (pos_x),a
	ld a,(ix+6)
	and %11110000
	rrca
	rrca
	rrca
	rrca
	ld c,a
	ld a,(ix+7)
	and %11110000
	or c
	call print_hex
	ret

; -----------------------------------------------------------------------------
; управл€ющие коды
; 13 (0x0d)		- след строка
; 23 (0x17),x,y		- изменить позицию на координаты x,y
; 24 (0x18),x		- изменить позицию по x
; 25 (0x19),y		- изменить позицию по y
; 0			- конец строки

; x(0-41),y(0-7)
;		   "------------------------------------------"
str1		db 23,0,0
		db "[NES] (build 20160612)",13
		db "Reset[Esc] OSD[Bks] HQ2x[Tab] ROM[F1..F12]"
		db "DJOY1: use arrow keys for D-Pad",23,7,3
		db "A[A] B[S] Sel[Space] Start[Enter]",13
		db "DJOY2: use numpad keys for D-Pad",23,7,5
		db "A[1] B[2] Sel[3] Start[4]",13
		db "Board:ReVerSE-U16A FPGA:EP4CE22 FlashID:",13
		db "PRG:",24,7,"CHR:",24,14,"Mapper:",24,25,"Checksum:",0

;BLOCK					START ADDRESS	END ADDRESS
;Page_0		0x00000000		0x000AF6E8
;SuperMario.hex		0x000AF6E9		0x000B96F8
;Bomberman.hex		0x000B96F9		0x000BF708
;BattleTank.hex		0x000BF709		0x000CF718
;LodeRunner.hex		0x000CF719		0x000D5728
;PacMan.hex		0x000D5729		0x000DB738
;Puzznic.hex		0x000DB739		0x000EB748
;Arkanoid.hex		0x000EB749		0x000F7758
;Airwolf.hex		0x000F7759		0x0011F768
;Robocop.hex		0x0011F769		0x0015F778
;1942.hex		0x0015F779		0x00169788
;1943.hex		0x00169789		0x00189798
;SuperMario3.hex		0x00189799		0x001E97A8

rom1		db #0A,#F6,#E9 
rom2		db #0B,#96,#F9
rom3		db #0B,#F7,#09
rom4		db #0C,#F7,#19
rom5		db #0D,#57,#29
rom6		db #0D,#B7,#39
rom7		db #0E,#B7,#49
rom8		db #0F,#77,#59
rom9		db #11,#F7,#69
rom10		db #15,#F7,#79
rom11		db #16,#97,#89
rom12		db #18,#97,#99
			db #1E,#97,#A9	;End

checksum_32	db #00
checksum_24	db #00
checksum_16	db #00
checksum_08	db #00

header_cnt	db #00

; -----------------------------------------------------------------------------

	display "End: ",/a, $

font	INCBIN "font.bin"

header		db #0000,#0000,#0000,#0000
	
	savebin "loader.bin",startprog, 32768

	display "osd_buffer start = ",/a, osd_buffer
	display "font start = ",/a, font
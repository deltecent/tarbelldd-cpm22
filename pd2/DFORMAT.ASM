;
;format program for the wd1793 fdisk controller
;
;modified by g.w.mulchin
;of tarbell electronics
;last update  9-29-81
;added double sided formatting
;added function 10 to keyboard
;added dma clear command
;
	maclib	skew
;
TRUE	EQU	0FFFFH
FALSE	EQU	NOT TRUE
;
skewf	equ	4
BDOS	EQU	5
WBOOT	EQU	0
RCB	EQU	10
SIDE0	EQU	10111000B
SIDE1	EQU	01000000B
CMD	EQU	0F8H
DAL	EQU	CMD+3
WAIT	EQU	CMD+4
WTRACK	EQU	0F4H
SEEK	EQU	1BH		;seek = 6ms
DMACHK	EQU	CMD+5		;dma check
TRACK	EQU	CMD+1
SECT	EQU	CMD+2
ADR0	EQU	0E0H		;dma controller addr. reg
WCT0	EQU	0E1H		; "	  "	word count
CMND	EQU	0E8H		; "	"	command reg
PANEL	EQU	0FFH		;imsai front panel
RESTORE EQU 	01		;6ms restore code

	ORG	100H
;
START:	LXI	H,0		;clear h,l
	DAD	SP		;cp/m stack value
	SHLD	OLDSTK
	LXI	SP,STACK	;setup	stack
	LXI	D,MSG1
	MVI	C,9
	CALL	BDOS		;sign on
COMPLT:	XRA	A		;get a zero
	STA	CLATCH		;clear clatch to drive a
	STA	XFER		;clear to dma type xfer.
	STA	SIDED		;default = single sided
	INR	A		;flag <> 0,= format all the disk
	STA	FLAG
	MVI	A,0DDH		;default byte = single sided
	STA	SIDB+1		;modify the code byte
	LXI	D,MSG2
	MVI	C,9
	CALL	BDOS
	CALL	INPUT
	CPI	'Q'		;quit?
	JZ	WEXIT		;yes, exit to system
	ANI	3		;make upper case
	DCR	A		;make cpm drive number
	ADD	A
	ADD	A
	ADD	A
	ADD	A		;compute latch value for drive
	MOV	C,A		;save it in reg c
	LDA	CLATCH		;get clatch value
	ORA	C		;select the drive
	STA	CLATCH		;save drive code
	LXI	D,MSG2C		;format doub sided?
	MVI	C,9
	CALL	BDOS		;print it
	CALL	INPUT
	CPI	'Y'
	JNZ	NOTSID
	STA	SIDED		;flag = yes
	MVI	A,0DFH		;doub side byte code
	STA	SIDB+1		;modify it
NOTSID:	LXI	D,MSG2B		;point to dma format ?
	MVI	C,9
	CALL	BDOS
	CALL	INPUT
	CPI	'Y'
	JZ	DSEL		;if y then do format in dma
	STA	XFER		;if n then do format in pgdt
	LXI	D,MSG4		;4mhz cpu msg
	MVI	C,9
	CALL	BDOS
DSEL:	LXI	D,MSG2A		;tracks to format message
	MVI	C,9
	CALL	BDOS
	CALL	INPUT
	CPI	'A'		;all tracks?
	JZ	START1
	CPI	'S'		;system tracks?
	JZ	SYSTEM
	CPI	'Q'		;quit?
	JNZ	DSEL
WEXIT:	LHLD	OLDSTK		;recover cpm stack pointer
	SPHL
	RET
;
;input routine - get a character from keyboard
;
;enter:	none
;exit:	reg a = char from keyboard
;	stored at seld
;registers used: d,e h,l c
;
INPUT:	MVI	A,3		;reset buffer length
	LXI	H,0
	SHLD	KEYBUF+1	;clear buffer
	STA	KEYBUF
	LXI	D,KEYBUF	;point to buffer
	MVI	C,RCB		;read buffer function
	CALL	BDOS		;get character
	LDA	KEYBUF+2	;get the first char only
	CPI	'a'		;check for lower case
	RC
	CPI	'z'+1
	RNC
	ANI	5FH		;make into upper case
	RET
;
DSIDE0:	LDA	CLATCH		;get current latch code
	ANI	SIDE0		;force side 0 active
	JMP	SAVEL		;save it
;
DSIDE1:	LDA	CLATCH		;get current latch code
	ORI	SIDE1		;force side 1
SAVEL:	STA	CLATCH		;save it
	OUT	WAIT		;select side on drive
	RET
;
SYSTEM:	XRA	A
	STA	FLAG		;set system only
START1:	LDA	CLATCH		;get latch value
	OUT	WAIT		;select drive
	MVI	A,RESTORE
	OUT	CMD
	CALL	NOTRDY
	MVI	D,0		;set for track 0
SLOOP2:	MVI	E,1		;sector
	LXI	H,BUFF		;dma buffer
	MVI	A,0FFH
	MVI	B,40
	CALL	PUT
	XRA	A
	MVI	B,6
	CALL	PUT
	MVI	M,0FCH
	INX	H
	MVI	B,26		;gap 1
	MVI	A,0FFH
	CALL	PUT
SLOOP:	XRA	A
	MVI	B,6
	CALL	PUT
	MVI	M,0FEH
	INX	H
	MOV	M,D		;track
	INX	H
	MVI	M,0		;side 0
	INX	H
	MOV	M,E
	INX	H
	MVI	M,0		;128 byte / sector mark
	INX	H
	MVI	M,0F7H
	INX	H
	MVI	A,0FFH
	MVI	B,11
	CALL	PUT
	MVI	B,6
	XRA	A
	CALL	PUT
	MVI	M,0FBH
	INX	H
	MVI	A,0E5H
	MVI	B,128
	CALL	PUT 		;data 128 bytes
	MOV	A,E		;are we on sector 1
	CPI	1
	JNZ	NOT1		;no, skip special id byte
	PUSH	H		;yes, put in
	DCX	H
	DCX	H
SIDB:	MVI	M,0DDH		;'dd' = doub. density
	POP	H
NOT1:	MVI	M,0F7H
	INX	H
	MVI	A,0FFH
	MVI	B,27
	CALL	PUT
	INR	E
	MOV	A,E
	CPI	27
	JNZ	SLOOP
	MVI	C,3
SLOOP3:	MVI	B,0
	MVI	A,0FFH
	CALL	PUT
	DCR	C
	JNZ	SLOOP3
	PUSH	D
	CALL	DMA		;write	the disk with dma
	POP	D
	IN	CMD		;get status
	ANI	0E7H
	JNZ	ERROR
	LDA	SIDED		;doing doub sided?
	ORA	A		;= to 0?
	JNZ	START2		;if not, we are doing d.s
	INR	D
	MOV	A,D
	OUT	DAL 		;tell	1791
	MVI	A,SEEK
	OUT	CMD
	CALL	NOTRDY
	JMP	START3
;
;here starts the double density formatting
;
START2:	MVI	A,1		;doing trk 0 side 1 d.d.
	STA	SFLAG		;set the flag
START3:	LDA	CLATCH		;get the current latch condition
	ORI	8		;set bit 4 = 1 for doub. density
	STA	CLATCH		; and save it
	OUT	WAIT		;now set the hardware latch
	LXI	H,TABLE		;point to s.density table for trk 1
LOOP2:	SHLD	PTR		;reset table pointer
	MOV	E,M		;sector number.
	LXI	H,BUFF		;dma buffer
	MVI	B,16		;gap 1
	MVI	A,4EH
	CALL	PUT
LOOP:	CALL	PUTZERO
	MVI	A,0F5H
	MVI	B,3
	CALL	PUT
	MVI	M,0FEH
	INX	H
	MOV	M,D		;track
	INX	H
	MVI	M,0		;side 0
	INX	H
	MOV	M,E
	INX	H
	MVI	M,0		;128 bytes  sector mark
	INX	H
	MVI	M,0F7H
	INX	H
	MVI	A,4EH
	MVI	B,22
	CALL	PUT
	CALL	PUTZERO
	MVI	A,0F5H
	MVI	B,3
	CALL	PUT
	MVI	M,0FBH
	INX	H
	MVI	A,0E5H
	MVI	B,128		;count = 128 bytes
	CALL	PUT
	MVI	M,0F7H
	INX	H
	MVI	A,4EH
	MVI	B,16
	CALL	PUT
	CALL	NEXTSECT
WT:	JNZ	LOOP
	MVI	C,3
LOOP3:	MVI	B,0
	MVI	A,4EH
	CALL	PUT
	DCR	C
	JNZ	LOOP3
	LDA	SIDED
	ORA	A
	JZ	NOTSID1
	CALL	DSIDE1
	PUSH	D
	PUSH	H
	CALL	DMA
	POP	H
	POP	D
	IN	CMD
	ANI	0E7H
	JNZ	ERROR
	CALL	DSIDE0
	LDA	FLAG
	ORA	A
	JZ	COMPLT
	LDA	SFLAG		;doing trk 0 side 1?
	CPI	1		;if = 1 then yes.
	MVI	A,0		;reset the flag
	STA	SFLAG		;
	JZ	S1DONE		;this special side done
NOTSID1:PUSH	D
	PUSH	H
	CALL	DMA
	POP	H
	POP	D
	IN	CMD		;get	status
	ANI	0E7H
	JNZ	ERROR
	LDA	FLAG		;are we doing all the disk ?
	ORA	A		;yes if not = 0
	JZ	COMPLT		;no, just first 2 tracks if = 0
S1DONE:	INR	D
	MOV	A,D
	CPI	4CH+1		;last track?
	JZ	COMPLT
	OUT	DAL
	MVI	A,SEEK
	OUT	CMD
	CALL	NOTRDY
	LXI	H,STABLE	;reset sector pointer
	JMP	LOOP2
;
PUT:	MOV	M,A
	INX	H
	DCR	B
	JNZ	PUT
	RET
;
PUTZERO:MVI	B,09
	XRA	A
	JMP	PUT
;
ERROR:	CMA			;invert for panel lites
	OUT	PANEL		;display error code
	LXI	D,MSG3
	MVI	C,9
	CALL	BDOS
	JMP	COMPLT
;
MSG1:	DB	'Tarbell Electronics Double Density'
	DB	0DH,0AH,'Format Program Ver 1.9',0DH,0AH
	DB	'Formats:',0DH,0AH
	DB	'Track  0      = 26 , 128 byte sectors',0DH,0AH
	DB	'Tracks 1 - 76 = 51 , 128 Byte sectors',0DH,0AH
	DB	0DH,0AH
	DB	'S-100 Siemens / Shugart Ver. of 9-29-81$'
MSG2:	DB	0DH,0AH,'Drive ? (A,B,C,D)  or Q to Quit $'
MSG2A:	DB	0DH,0AH,'Format System or All or Quit? (S,A, or Q)  $'
MSG2B:	DB	0DH,0AH,'Use DMA for formatting ? (Y or N)  $'
MSG2C:	DB	0DH,0AH,'Format double sided (Y or N)  $'
MSG4:	DB	0DH,0AH,'You must have a CPU running at 4 MHz.$'
MSG3:	DB	0DH,0AH,7,'ERROR- Check for write protected disk',0DH,0AH,'$'
;
;dma routine
;
DMA:	LDA	XFER		;check for dma format wanted
	ORA	A		;is it zero?
	MVI	A,0		;clear dma chip anyway
	OUT	CMND		;in case using pgdt
	JZ	DMAXFER		;yes, use dma for formatting
	LXI	H,BUFF		;nope, use program data transfer
	MVI	A,WTRACK	;get write track command
	OUT	CMD		;tell disk controller
XLOOP:	IN	WAIT		;wait till intrq or drq happens
	ORA	A		;set flags
	RP			;return if done
	MOV	A,M		;get a byte from format buffer
	INX	H		;bump memory pointer
	OUT	DAL		;send byte to 1793
	JMP	XLOOP		;loop for more data
DMAXFER:PUSH	H		;save ending address
	LXI	H,BUFF		;point to storage
	MVI	A,01H		;set command mode for ch 0
	OUT	CMND
	MOV	A,L		;get low addr byte
	OUT	ADR0		;put it to dma controller
	MOV	A,H		;get hagh addr byte
	OUT	ADR0		;put it to controller
	POP	H		;restore ending address
	DCX	H		;set count -1 for length
	MOV	A,L		;get the low byte
	OUT	WCT0		;put it to controller
	MOV	A,H		;get high byte of count
	ORI	80H		;set write bit on
	ANI	0BFH		;make sure read bit off
	OUT	WCT0		;and put it to controller
	MVI	A,WTRACK	;set for write track
	OUT	CMD		;tell 1791 about it
	MVI	A,40H
DLOOP:	DCR	A
	JNZ	DLOOP
NOTRDY:	IN	DMACHK		;check intrq
	RLC			; bit 7
	JC	NOTRDY		;loop till not busy
	XRA	A		;clear dma chip
	OUT	CMND
	RET
;
NEXTSECT:
	PUSH	H
	LHLD	PTR
	INX	H		;bump pointer
	SHLD	PTR		;and get next byte
	MOV	E,M		;save sector number in reg e
	MOV	A,E		;check for end of table
	POP	H
	ORA	A		;set flags
	RET
;
FLAG:	DB	0
PTR:	DW	0
;
;skew table
;
TABLE:	DB	1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16
	DB	17,18,19,20,21,22,23,24,25,26,27,28,29
	DB	30,31,32,33,34,35,36,37,38,39,40,41,42
	DB	43,44,45,46,47,48,49,50,51
	DB	0
;
STABLE:	SKEW	1,51,SKEWF
;
CLATCH:	DB	0		;current hardware latch value
SFLAG:	DB	0		;if 1, doing trk 0 side 1 doub den
SIDED:	DB	0		;0= sing.sided, <> 0 = doub.sided
XFER:	DB	0		;type xfer flag byte
	DS	30		;stack area
STACK:	DS	1
OLDSTK:	DS	2		;cpm stack save
KEYBUF:	DS	6
BUFF:	DS	1		;format buffer
	END



; disk formatting program
; written by dick culbertson in aug, 1977
; modified by don tarbell in sep, 1977
; modified by marc farjeon - may 24, 1979.
; modified by jerry mulchin - june 27, 1979
;   for use with new controller board
; modified 5-12-80 for multi-drive select
; and double sided select, and read test
; of the formatted track. (g.w.mulchin.)
;modified 6-4-80 for double sided code byte insert
;during formatting. code = e7h, doub sided.
; modified for persci restore command 9-23-80.
;modified for format of system or all tracks
;2-9-82
;
; this program will format either a single
; sided or a double sided disk and check
; each track for crc or rnf errors. if any
; errors of this type are found, the program
; will reformat that track again, recheck it
; again, for 5 retrys. if the retry count
; exceeds 5, then that disk is declared fatal
; and should be replaced.
;
TRUE	EQU	-1
FALSE	EQU	NOT TRUE
;
INTRP	EQU	FALSE		;true if using interrupts
DCOM	EQU	0F8H		;disk command port
DSTAT	EQU	0F8H		;disk status port
TRACK	EQU	0F9H		;disk track command
SECTP	EQU	0FAH		;disk sector port
DDATA	EQU	0FBH		;disk data port
WAIT	EQU	0FCH		;disk wait control port
ENTRY	EQU	5		;entry pt to fdos
BELL	EQU	'G'-40H		;cntl-g = bell
READC	EQU	80H		;read command
RSTOR	EQU	0		;restore command
STEP	EQU	01010000B	;step in command
HLAB	EQU	8		;0=no head load, 8=head load
STPRAT	EQU	1		;0=3ms,1=6ms,2=10ms
;
;
	ORG	0100H		;load & ex here
;
;starting message
;	
	IF	INTRP
BEGIN:	DI
	ENDIF

	LXI	H,0		;clear h,l
	DAD	SP		;get cpm stack pointer
	SHLD	OLDSTK		;save it for later
BGIN:	LXI	SP,STACK	;set up local stack
	MVI	A,0E5H
	STA	SPBYTE+1
	MVI	C,9		;get code for print.
	LXI	D,MSG		;get adr of message.
	CALL	ENTRY		;print opening.
BGIN2:	MVI	A,77
	STA	NTRKS1+1	;reset to 76 tracks
	LXI	D,DRIVE		;get drive to format
	MVI	C,9
	CALL	ENTRY		;print message
	MVI	C,1		;now get the drive
	CALL	ENTRY
	CALL	CONV		;check cases
	CPI	'Q'		;quit?
	JZ	EXIT		;yes
	ANI	7		;strip ascii bits
	DCR	A		;make cpm drive
	ADD	A
	ADD	A
	ADD	A
	ADD	A		;shift 4 places
	STA	SDRIVE		;save drive code
	OUT	WAIT		;select the drive
	LXI	D,DUBMSG
	MVI	C,9
	CALL	ENTRY		;ask about double sided drives
	MVI	C,1
	CALL	ENTRY
	CALL	CONV		;check cases
	CPI	'N'		;not using dub sided disks
	MVI	A,0
	STA	DUBSID
	JZ	BGIN1		;doing single sided
	CMA
	STA	DUBSID		;doing doub. sided
	MVI	A,0E7H		;double sided code byte
	STA	SPBYTE+1	;modify byte in spfill routine.
BGIN1:	LXI	D,CRLF
	MVI	C,9
	CALL	ENTRY
	MVI	C,9
	LXI	D,RDY		;print ready message.
	CALL	ENTRY
	MVI	C,1		;read a char from kb.
	CALL	ENTRY
	CALL	CONV		;convert lower to upper case
	CPI	'Q'		;want to quit?
	JZ	EXIT		;exit if yes
	CPI	'A'		;want all tracks?
	JZ	START		;wants all tracks
	MVI	A,2
	STA	NTRKS1+1	;change the number of tracks
	JMP	START		;go ahead and do it.

EXIT:	LHLD	OLDSTK		;recover cpm stack
	SPHL			;restore it

	IF	INTRP
	EI
	ENDIF

	RET			;go back to operating system
;
;conv - convert letters from lower case
;	to upper case.
;entry:	accum = char to convert
;exit:	accum = converted char if lower case
;
CONV:	CPI	'a'		;check case
	RC			;upper case already.
	CPI	'z'+1
	RNC
	ANI	5FH		;if lower case, change it
	RET
;
; restore drive to track 00
;
START:	LXI	D,CRLF		;print cr,lf on console
	MVI	C,9
	CALL	ENTRY
	MVI	A,RSTOR+STPRAT+HLAB	;restore head to trk 0
	OUT	DCOM		;issue home cmd
	IN	WAIT		;wait for home
	MVI	C,0		;set track number to 0
NTRKS1:	MVI	H,77		;set total tracks to 77
FORMAT:	CALL	SIDE0
	MVI	A,5		;retrys
	STA	ERRCNT		;save it
RFORMAT:PUSH	B		;save b,c
	PUSH	D
	PUSH	H
	LXI	D,FMSG0		;format msg
	MVI	C,9
	CALL	ENTRY
	POP	H
	POP	D
	POP	B
	CALL	NXTTRK		;format the disk
	PUSH	B
	PUSH	D
	PUSH	H
	LXI	D,RMSG0		;read msg
	MVI	C,9
	CALL	ENTRY
	POP	H
	POP	D
	POP	B
	CALL	READ		;test formatted track
	ORA	A		;read ok?
	JZ	SIDE		;yes,	check for side 1
	LDA	ERRCNT		;error, decrease count
	DCR	A
	STA	ERRCNT
	JNZ	RFORMAT		;reformat and check again
	LXI	D,DISKER	;point to error message
	MVI	C,9
	CALL	ENTRY
	JMP	BGIN2		;exit and return to start.
SIDE:
	LDA	DUBSID		;check if doing double sided
	ORA	A		;zero = single sided only
	JZ	NEWTRK		;do other side if <> 0
	CALL	SIDE1		;now do side 1
	MVI	A,5
	STA	ERRCNT
RFMAT:	PUSH	B
	PUSH	D
	PUSH	H
	LXI	D,FMSG1		;format side 1 msg
	MVI	C,9
	CALL	ENTRY
	POP	H
	POP	D
	POP	B
	CALL	NXTTRK
	PUSH	B
	PUSH	D
	PUSH	H
	LXI	D,RMSG1
	MVI	C,9
	CALL	ENTRY
	POP	H
	POP	D
	POP	B
	CALL	READ		;check for disk errors
	ORA	A		;errors?
	JZ	NEWTRK		;no
	LDA	ERRCNT		;error, decrease count
	DCR	A
	STA	ERRCNT
	JNZ	RFMAT		;reformat and check again
	LXI	D,DISKER	;point to error message
	MVI	C,9
	CALL	ENTRY
	JMP	BGIN2		;exit to start
NEWTRK:	INR  C			;bump track #
	DCR  H			;trk count =count -1
	JNZ  BMPTRK 		;if not 0 then do more
	JMP  BGIN2		;go back to do routine again
;
SIDE0:	LDA	SDRIVE
	ANI	10110000B	;select side 0
	OUT	WAIT
	RET
;
SIDE1:	LDA	SDRIVE
	ORI	01000000B	;select side 1
	OUT	WAIT
	RET
;
BMPTRK:	MVI  A,STEP+HLAB+STPRAT	;load step in
	OUT  DCOM   		;step in
	IN	WAIT
	ORA	A
	IN  WAIT		;wait til done
	IN   DSTAT  		;check status
	JMP  FORMAT
;
NXTTRK:	MVI	D,1		;sector cnt to 0
	MVI	E,26		;set max # sectors -1 
	MVI	B,40		;gap 4 preindex 40 bytes of ff
	MVI	A,0F4H		;load track write command
	OUT	DCOM		;issue track write
;
; write preindex fill
;
PREIND:	IN	WAIT		;wait for drq
	ORA	A		;set flags
	JP	ERRMSG		;jmp out if error
	MVI	A,0FFH		;load preindex fill
	OUT	DDATA		;write it on disk
	DCR	B		;count = count - 1
	JNZ	PREIND		;go back till b =0
	MVI	B,6
PREIN1:	IN	WAIT
	ORA	A
	JP	ERRMSG
	XRA	A
	OUT	DDATA
	DCR	B
	JNZ	PREIN1
;
; write address mark on track
;
	IN	WAIT		;wait for drq
	ORA	A		;set flags
	JP	ERRMSG		;jmp out if error
	MVI	A,0FCH		;load address mark
	OUT	DDATA		;write it on disk
;
; post index gap
;
	MVI	B,26		;set # of bytes
POSTID:	IN	WAIT		;wait for drq
	ORA	A		;set flags
	JP	ERRMSG		;jmp out if error
	MVI	A,0FFH		;load fill data
	OUT	DDATA		;write it on disk
	DCR	B		;count = count - 1
	JNZ	POSTID		;if not 0 go back
;
; pre id section
;
ASECT:	MVI	B,6		;get # of bytes
SECTOR:	IN	WAIT		;wait for drq
	ORA	A		;set flags
	JP	ERRMSG		;jmp out if error
	XRA  A			;make a = 0
	OUT  DDATA  		;write it on track
	DCR  B			;count = count=1
	JNZ  SECTOR 		;jmp back if not done
;
; write id address mark
;
	IN   WAIT   		;wait for drq
	ORA  A			;set flags
	JP   ERRMSG 		;if error jmp out
	MVI  A,0FEH 		;get address mark
	OUT  DDATA  		;write it on disk
;
; write track number on disk
;
	IN   WAIT   		;wait for drq
	ORA  A			;set flags
	JP   ERRMSG 		;jmp out if error
	MOV  A,C		;get track number
	OUT  DDATA  		;write it on disk
;
; write one byte of 00
;
	IN   WAIT   		;wait for drq
	ORA  A			;set flags
	JP   ERRMSG 		;jmp out if error
	XRA  A			;set a to 0
	OUT DDATA   		;write it on disk
;
; write sector # on disk
;
	IN   WAIT   		;wait for drq
	ORA  A			;set flags
	JP   ERRMSG 		;jmp out if error
	MOV  A,D		;get sector #
	OUT DDATA   		;write it on disk
;
; one more byte 0
;
	IN   WAIT   		;wait for drq
	ORA  A			;set flags
	JP   ERRMSG 		;jmp out if error
	XRA  A			;set a to 00
	OUT  DDATA  		;write it on disk
	INR  D			;bump sect. #
;
; write 2 crc's on this sector
;
	IN   WAIT   		;wait for drq
	ORA  A			;set flags
	JP   ERRMSG 		;jmp out if error
	MVI  A,0F7H 		;get crc pattern
	OUT DDATA   		;write it on disk
;
; pre data 17 bytes ff's
;
	MVI  B,11   		;set count
PREDAT:	IN   WAIT   		;wait for drq
	ORA  A			;set flags
	JP   ERRMSG 		;jmp out if error
	MVI  A,0FFH		;set a to ff
	OUT  DDATA  		;write it on disk
	DCR  B			;reduce count by 1
	JNZ  PREDAT 		;go back if not done
	MVI  B,6
PREDA1:	IN   WAIT
	ORA  A
	JP   ERRMSG
	XRA  A
	OUT  DDATA
	DCR  B
	JNZ  PREDA1

;
; data address mark
;
	IN   WAIT   		;wait for drq
	ORA  A			;set flags
	JP   ERRMSG 		;jmp out if error
	MVI  A,0FBH 		;get data address mark
	OUT  DDATA  		;write it on disk
;
; fill data field with e5
;
	MVI  B,126		;126 e5's
DFILL:	IN   WAIT   		;wait for drq
	ORA  A			;you know what
	JP   ERRMSG 		;happens here by now
	MVI  A,0E5H
	OUT  DDATA  		;write it on disk
	DCR  B			;bump 1 to count
	JNZ  DFILL  		;do till done
	MVI  B,2
SPFILL:	IN   WAIT
	ORA  A
	JP   ERRMSG
SPBYTE:	MVI  A,0E7H		;doub sided byte
	OUT  DDATA
	DCR  B
	JNZ  SPFILL
;
; write crc's
;
	IN   WAIT   		;wait till drq
	ORA  A			;set flags
	JP   ERRMSG 		;jmp out if error
	MVI  A,0F7H 		;get crc byte
	OUT  DDATA  		;write it on disk
;
; end of sector fill
;
	DCR  E			;reduce sector count
	JZ  ENDTRK		;if 0 do end of track rtn
DATGAP:	IN WAIT			;wait for drq
	ORA  A			;set flags   
	JP   ERRMSG 		;jmp out if error
	MVI  A,0FFH		;get fill character
	OUT  DDATA  		;write it on disk
	JMP  POSTID-2 		;go back for more
;
; do track & sector house keeping
;
ENDTRK:
	MVI  A,0E5H
	STA  SPBYTE+1
	IN   WAIT   		;wait for drq or intrq
	ORA  A			;set flags
	JP   DONE   		;jmp out if error
	MVI  A,0FFH		;load a with ffh
	OUT  DDATA  		;write it on disk
	JMP  ENDTRK 		;do until intrq
;
DONE:	IN	DSTAT		;check status
	ANI	0C1H		;check bits,7,6,2,0
	JNZ	ERRMSG
	RET			;return to caller
;
;disk read test routine.
;checks disk for errors
;after track is formatted.
;
;entry:	none
;exit:	accum = 0 if formatted ok
;	accum = ff if more than 5 retrys
;
READ:	PUSH	B		;save formatting registers
	PUSH	D		; on stack
	PUSH	H
READ1:	MVI	C,1		;start reading at sector 1
	MVI	B,26		;read 26 sectors total
READL:	CALL	DSKSET		;set up disk command
	ORA	D		;or in read command
	OUT	DCOM
RLOOP:	IN	WAIT		;wait for intrq
	ORA	A		;set flags
	JP	RDONE		;read finished when positive
	IN	DDATA		;read a byte
	JMP	RLOOP		;accum = infinate bit bucket
RDONE:	IN	DSTAT		;check status
	ANI	18H		;check crc and rnf bits only
	JZ	RNXT		;if = 0, read next sector
	JMP	REXIT		;return to format program
RNXT:	INR	C		;bump sector number
	DCR	B		;decrease total sectors
	JNZ	READL		;more to read.
REXIT:	POP	H
	POP	D
	POP	B		;registers restored.
	RET			;return with error code.
;
DSKSET:	MVI	A,0D0H		;force intrp command
	OUT	DCOM
	MVI	D,READC		;get read command
	MOV	A,C		;get sector number
	OUT	SECTP
	IN	DSTAT		;check head load bit
	ANI	20H
	MVI	A,0		;set head load bit
	RZ
	MVI	A,4
	RET
;
;error routine
;
ERRMSG:	CMA			;show error on f/panel
	OUT	0FFH
	LXI	D,ERROR
	MVI	C,9
	CALL	ENTRY
	LXI	SP,STACK	;reset local stack
	JMP	BGIN2		;restart program
;
ERROR:	DB	BELL,0DH
	DB	'*********************************************',0DH,0AH
	DB	'*					    *',0DH,0AH
	DB	'*       E R R O R  in formatting disk       *',0DH,0AH
	DB	'*					    *',0DH,0AH
	DB	'*********************************************',0DH,0AH
	DB	0DH,0AH,'Check for write protected disk',0DH,0AH
	DB	BELL,'$'
DISKER:	DB	BELL,0DH
	DB	'*********************************************',0DH,0AH
	DB	'*					    *',0DH,0AH
	DB	'*    Fatal disk errors, try another disk    *',0DH,0AH
	DB	'*					    *',0DH,0AH
	DB	'*********************************************',0DH,0AH
	DB	BELL,'$'
MSG:	DB	0DH,'Tarbell Electronics Single density,single sided'
	DB	0DH,0AH
	DB	'Single density,double sided format program',0DH,0AH
	DB	'Version 1.4  dated 2-09-82',0DH,0AH
	DB	'Assembled to run on Tarbell Double Density Interface',0DH,0AH
	DB	0DH,0AH,'Formats 76 tracks',0DH,0AH
	DB	'26 sectors/track with 128 bytes/sector',0DH,0AH,0DH,0AH,'$'
RDY:	DB	'Format System,All or Quit (S,A or Q) $'
DRIVE:	DB	0DH,'Drive to format (A,B,C,D) or Q to quit? $'
DUBMSG:	DB	0DH,0AH,'Format a Double Sided Disk (Y or N)? $'
FMSG0:	DB	0DH,'Formatting Side 0 $'
RMSG0:	DB	0DH,'Reading    Side 0 $'
FMSG1:	DB	0DH,'Formatting Side 1 $'
RMSG1:	DB	0DH,'Reading    Side 1 $'
CRLF:	DB	0DH,0AH,'$'
;
	DS	128			;stack area
STACK:	DS	1			;internal stack
OLDSTK:	DS	2			;cpm stack saved here
SDRIVE:	DS	1			;drive select code
DUBSID:	DS	1			;0=single sided format
ERRCNT:	DS	1			;disk retrys
	END	BEGIN

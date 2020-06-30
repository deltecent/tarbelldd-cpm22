;double density test aid
;this program allows you to test double density
;disk which run with the new tarbell double density board.
;this program will read an entire disk and keep
;a running tab of errors. at the completion of the
;test, the type of errors found will be displayed.
;this program in conjunction with the 'dformat'
;program will allow  you to optimize your disk for
;the lowest amount of errors.
;
	MACLIB	MACRO
	MACLIB	SKEW
;
TRUE	EQU	0FFFFH
FALSE	EQU	NOT TRUE

FIRST	EQU	1		;first sector on disk
LAST	EQU	26		;last sector on disk
SKEWFSD	EQU	6		;skew factor for single density
SKEWFDD	EQU	1		;skew factor for double density
SECTDDB	EQU	51		;last sector for double den disk
SKFDEBL	EQU	8		;skew factor for double density
BELL	EQU	7		;bell code
BS	EQU	8		;back space code
SOL	EQU	FALSE		;true if using a sol
BDOS	EQU	5
WBOOT	EQU	0

	IF	SOL
ADR0	EQU	060H
CMD	EQU	078H

	ELSE

ADR0	EQU	0E0H		;dma address register port
CMD	EQU	0F8H
	ENDIF

WCT0	EQU	ADR0+1		;dma word count register port
CMND	EQU	ADR0+8		;dma command register port
STATUS	EQU	CMD
TRK	EQU	CMD+1
SEC	EQU	CMD+2
DAL	EQU	CMD+3
WAIT	EQU	CMD+4
INTRQ	EQU	CMD+5		;intrq port from 1791
RCMD	EQU	80H
STPRT	EQU	1		;0=3ms,1=6ms,2=10ms,3=15ms
HLAB	EQU	8		;0=no head load at beginning of seek
SEEK	EQU	10H+HLAB+STPRT	;seek command
RTYCNT	EQU	10		;10 retrys
INTRP	EQU	0D0H
RESTOR	EQU	STPRT		;restore command
PANEL	EQU	0FFH		;imsai front panel
SECS	EQU	LAST		;sectors/track
SSECS	EQU	26		;single density sectors/track
;
SIDE0	MACRO	DATA
	IF	NOT NUL DATA
	LDA	DATA	;;get storage value
	ENDIF
	ANI	10111000B
	OUT	WAIT	;;set to side 0
	ENDM
;
SIDE1	MACRO	DATA1
	IF	NOT NUL DATA1
	LDA	DATA1	;;get storage value
	ENDIF
	ORI	01000000B
	OUT	WAIT	;;change to side 1
	ENDM
;
FOLD	MACRO
	LOCAL	NOCONV
	CPI	'a'
	JC	NOCONV
	CPI	'z'+1
	JNC	NOCONV
	ANI	5FH
NOCONV:
	ENDM
;
	ORG 100H
;
START1:	LXI  SP,STACK	;set stack pointer.
	PRINT <'Tarbell Double Density Test Program'>

	IF	SOL
	PRINT <CR,LF,'SOL version 1.8 of 3-10-81'>

	ELSE

	PRINT <CR,LF,'STD version 2.0 of 9-29-81'>
	ENDIF

	PRINT <CR,LF,CR,LF,'Test disks formatted with:'>
	PRINT <CR,LF,'Track  0    = 26 128 byte sectors'>
	PRINT <CR,LF,'Track  1-76 = 51 128 byte sectors'>
;
START:	XRA A			;get a zero
	STA XFER		;default to dma operation
	LXI H,04080H		;init. read operation
	SHLD DMARED
	PRINT <CR,LF,CR,LF,'Title: '>
	INPUT DCBUFF,80
	PRINT <CR,LF,'Starting Track '>
	CALL INP
	STA STRACK
	PRINT <CR,LF,'Ending Track   '>
	CALL INP
	STA ETRACK
	PRINT <CR,LF,'Drive (A,B,C,D)? '>
	INPUT DCBUFF,6
	LDA  DCBUFF+2
	FOLD
DRIVE:	ANI 3			;strip ascii bits
	DCR A			;make it cpm drive number
	ADD A
	ADD A
	ADD A
	ADD A			;shift for latch select
	SIDE0			;select side 0 (default side).
	STA CLATCH		;save drive code
	PRINT <CR,LF,'Test a Double Sided Drive? (Y or N) '>
	INPUT  DCBUFF,6
	LDA	DCBUFF+2
	FOLD
	CPI 'N'			;no?
	JZ  NOTSID
	PRINT <CR,LF,'Side 0 or Side 1? (0 or 1) '>
	INPUT	DCBUFF,6
	LDA	DCBUFF+2
	CPI  '0'		;side 0?
	JZ  NOTSID
	SIDE1 CLATCH
	STA  CLATCH		;save the current drive side code.
NOTSID:	MVI A,RESTOR
	OUT CMD			;restore drive
	CALL DMALOP		;wait till drive restored
	PRINT <CR,LF,'Use DMA for testing (Y or N)? '>
	INPUT	DCBUFF,6
	LDA	DCBUFF+2
	FOLD
	CPI 'Y'			;use dma
	JZ  DTESTD		;yes, test using dma
	STA XFER		;no, set it for pgdt.
	PRINT <BEL>
	PRINT <CR,LF,CR,LF,'****************************',CR,LF>
	PRINT <'Requires a 4 MHz CPU to test',CR,LF>
	PRINT <'****************************',CR,LF>
DTESTD:	PRINT <CR,LF>
DTESTF:	PRINT <CR,'Insert test disk and hit return (cr) '>
	INPUT	DCBUFF,6
	LDA	DCBUFF+1
	ORA	A		;must be a zero
	JZ	DTESTE		;did not type cr, redo from start
	PRINT <CR,'                                                  '>
	JMP	DTESTF		;reprint the question
;
DTESTE:	PRINT <CR,LF>
	LXI H,SECNT		;point at error counters
	MVI B,TK-SECNT		;get length of table
	XRA A
CLRLP:	MOV M,A
	INX H
	DCR B
	JNZ CLRLP		;clear table
DOTEST:	LDA STRACK
	STA TK
	ORA A			;check if going to trk zero
	CZ  SDTEST		;yes, change sector count.
	LXI  H,4080H		;dma read and length
	SHLD DMARED		;set it
	LXI  H,SKEWDDB		;double density table
	SHLD TABLE
	MOV  A,M		;get sector bbyte
	STA  SECT		;save it
	CALL DENSET		;set up for double density
TLOOP:	XRA A			;test loop
	STA RCOUNT		;reset retry count
SEEKE:				;seek retry entry point
	CALL SEEKTK		;go seek to value in tk
	IN STATUS		;check status
	ANI 099H		;strip off head load,protect
				;index,track 0 bits from status
	JNZ SERROR		;not 0 then log error
	CALL CHECKRTY		;good ,go see if bad before
READLOOP:
	XRA A
	STA RCOUNT		;reset retry count
READE:				;retry entry point for readsec
	CHARSTAT
	JZ READE1		;skip if no char.
	CHARIN			;get it
	CPI 3
	JZ FORGET
READE1:	CALL READSEC		;go read sector pointed to by sect
	IN STATUS		;check 1793 status
	ORA A			;0 = good
	JNZ RERROR		;if bad go log and retry
SKIPIT:				;entry when max retrys is reached
	CALL CHECKRTY		;good ,go see if bad before
	LHLD TABLE		;get skew table address
	INX H
	SHLD TABLE
	MOV A,M			;get sector number
	ORA A			;is it end of table?
	JNZ SAMETK
;
;increment track (tk)
;
NEWTK:	CALL DENSET		;change to double density
	LDA  TK			;get track number
	INR A
	MOV B,A
	LDA ETRACK		;get last track to test
	CMP B			;check it aginst new track
	JM TOTAL		;if new tk > last tk then done
	MOV A,B			;get new track
	STA TK			;update tk pointer
	LXI H,4080H		;read command 128 bytes
	SHLD DMARED
	LXI H,SKEWDDB		;point to sector table
NEWTKD:	SHLD TABLE
	MOV  A,M		;get first sector
	STA SECT
	JMP TLOOP
;
SDTEST:	LDA	CLATCH		;are we doing double sided?
	ANI	40H		;check bit 6 for set.
	CPI	40H		;is it?
	RZ			;if so, trk 0 - side 1 = doub den.
	POP	H		;else, trk 0 side 0 = sing. den.
	LXI  H,SKEWSD		;point to single density table
	SHLD TABLE
	MOV  A,M		;get sector number
	STA  SECT		;save it
	LDA CLATCH		;get current density and drive
	ANI 0F7H		;make single density
	STA CLATCH		;save it
	OUT WAIT		;change density
	JMP TLOOP		;read single density
;
DENSET:	LDA CLATCH
	ORI 8			;double density enable
	STA CLATCH
	OUT WAIT
	RET
;
SAMETK:	STA SECT		;update sector pointer
	JMP READLOOP		;go do more
SERROR:	MOV B,A			;enter here from seek error
	INXM SECNT		;inc seek error counter
	LDA RCOUNT		;get retry counter
	INR A
	CPI RTYCNT+1		;see if max retrys
	JZ FORGET
	CPI 1			;see if first retry
	JNZ SEEKE		;not first then just retry
	CALL DSTATUS		;first error so print prameters
	JMP SEEKE		;now do retry
FORGET:	LXI D,FMSG		;message
	MVI C,9
	CALL BDOS
	JMP TOTAL
RERROR:				;enter for read errors
	MOV B,A			;save error
	ANI 4			;lost data?
	JZ E1			;0=no
	INXM LDCNT
E1:	MOV A,B			;get error status
	ANI 8			;crc error?
	JZ E2
	INXM CRCNT
E2:	MOV A,B
	ANI 0E3H		;check other bits
	JZ E4
	INXM OTHER
E4:	MOV A,B
	ANI 10H
	JZ E5
	INXM IDCNT
E5:	LDA RCOUNT
	INR A
	CPI RTYCNT+1
	STA RCOUNT
	JZ SKIPIT		;past max retrys then skip sector
	CPI 1
	JNZ READE		;not first error then just retry
	CALL DSTATUS		;first error, print it
	JMP READE		;now do retry
CHECKRTY:
	LDA RCOUNT		;get retry count
	ORA A			;see if its zero
	RZ			;if 0 then dont do anything
	LXI H,RTYMSG1		;point at middle of retry message
	CALL BIND1		;convert to decimal and put in message
	LXI D,RTYMSG		;point at retry message
	MVI C,9
	CALL BDOS		;print it
	RET
;
TOTAL:	PRINT <CR,LF,'Seek Errors  '>
	LHLD SECNT
	CALL DEC
	PRINT <CR,LF,'Lost Data    '>
	LHLD LDCNT
	CALL DEC
	PRINT <CR,LF,'CRC Errors   '>
	LHLD CRCNT
	CALL DEC
	PRINT <CR,LF,'ID Errors    '>
	LHLD IDCNT
	CALL DEC
	PRINT <CR,LF,'Other Errors '>
	LHLD OTHER
	CALL DEC
				;done ,now print total values of 
				;all error counters
	JMP START
;
DEC:	DECOUT
	RET
;
READSEC:
	LDA XFER		;check for dma testing
	ORA A			;is it zero?
	JNZ PGDT		;no, use program data transfer
	XRA A			;clear dma chip
	OUT CMND
	LHLD DMARED		;get operation
	DCX H			;count = count-1
	MOV A,L			;read count byte
	OUT WCT0		;tell dma controller
	MOV A,H			;get read command
	OUT WCT0		;  and tell dma controller
	LXI H,RDBUFF		;point to buffer
	MOV A,L			;get low memory address byte
	OUT ADR0		;  and send it to dma controller
	MOV A,H			;get high memory address byte
	OUT ADR0		;  and send it to dma controller
	LDA SECT
	OUT SEC			;tell 1791 what sector to read
	MVI A,41H		;get ch 0 request command
	OUT CMND		;  and send it to dma controller
	MVI B,RCMD
	CALL HDLD
	ORA B
	OUT CMD
DMALOP:	IN INTRQ		;check intrq port
	RLC			; bit 7
	JC DMALOP		;loop till not busy
	XRA	A		;clear dma chip
	OUT	CMND
	RET
;
HDLD:	IN  CMD
	ANI  20H
	MVI  A,0
	RZ
	MVI  A,4
	RET
;
SEEKTK:	LDA TK
	OUT DAL 		;tell 1791
	MVI A,SEEK
	OUT CMD
WAITRDY:JMP DMALOP		;loop till seek done
;
PGDT:	LXI H,RDBUFF		;point to buffer
	LDA SECT		;get sector to read
	OUT SEC			;tell controller chip
	MVI B,RCMD		;get disk read command
	CALL HDLD
	ORA  B
	OUT CMD			;tell controller
PGDTL:	IN  WAIT		;wait for intrq or drq.
	ORA A			;set flags
	RP			;return if done
	IN DAL			;get a byte from disk
	MOV M,A			;put into memory
	INX H			;bump pointer
	JMP PGDTL		;loop till done.
;
DSTATUS:LDA F1793		;get status bit msg flag byte
	ORA A			;is it zero?
	JNZ DERROR		;no, jmp past 1793 flag msg
	CMA			;yes, print 1793 flag bytes once
	STA F1793		;and make flag byte non-zero.
	PUSH B
	PRINT <CR,LF,CR,LF,'1793  RDY  -  RDT RNF CRC LSD DRQ BSY'>
	POP  B
DERROR:	MOV A,B
	LXI H,MSG1
	PUSH D
	CALL BINCON		;convert to hex
	POP D
	LXI H,MSG2
	IN TRK
	CALL BIND1
	LXI H,MSG3
	IN SEC
	CALL BIND1
	LXI B,MSG4
	IN DAL
	CALL CONVT
	MVI C,9
	LXI D,MSG0
	CALL BDOS
	RET
;
BINCON:	MVI	B,8		;loop count
	LXI	D,4		;byte count
BLOOP:	RLC			;check for binary 1
	JC	BONE		;jump if it is
	MVI	M,'0'		;no, show ascii zero
BUMP:	DAD	D		;bump pointer
	DCR	B		;decrease counter
	RZ			;we are done
	JMP	BLOOP		;more bits to convert
BONE:	MVI	M,'1'		;bit is a binary 1
	JMP	BUMP
;
CONVT:	MOV D,A			;save the value
	RAR
	RAR
	RAR
	RAR
	CALL BIN1		;convert to ascii
	MOV A,D
	CALL BIN1
	RET
BIN1:	ANI 0FH
	ADI '0'
	CPI 3AH
	JM DONE
	ADI 7
DONE:	STAX B
	INX B
	RET
;
MSG0:	DB 0AH,0DH,'Status '
MSG1:	DB '                               '
	DB ' Track '
MSG2:	DB 30H,30H
	DB ' Sector '
MSG3:	DB 30H,30H
	DB ' Data '
MSG4:	DB 30H,30H
	DB '$'
RTYMSG:	DB ' Retrys '
RTYMSG1:DB 30H,30H,'$'
FMSG:	DB 0DH,0AH
	DB 0DH,0AH,'F O R G E T  T H I S ! ! !',0DH,0AH,'$'
;
BIND1:	MVI B,10
	CALL BID1
	ADI '0'
	MOV M,A
	RET
BID1:	MVI M,'0'-1
	INR M
	SUB B
	JNC BID1+2
	ADD B
	INX H
	RET
INP:	INPUT DCBUFF,6
	LDA DCBUFF+1
	LXI H,DCBUFF+2
	LXI B,0
	MOV C,A
	DAD B
	MVI M,0FFH
	DECIN DCBUFF+2
	RET
;
STRACK:	DB 0		;starting track
ETRACK:	DB 76		;ending track
RCOUNT:	DB 0		;retry counter
SECNT:	DW 0		;seek error counter
LDCNT:	DW 0		;lost data counter
CRCNT:	DW 0		;crc error counter
IDCNT:	DW 0		;id not found error
OTHER:	DW 0		;other errors
F1793:	DB 0		;0=print 1793 error bits message once.
TK:	DB 1		;start at track 1+1
SECT:	DB 1
ESECT:	DB SECS+1	;max sectors per disk
TABLE:	DW  0		;skew table address storage
DMARED:	DW  04080H	;dma read operation storage,default to 128 byte
XFER:	DB 0		;dma or pgdt flag byte
CLATCH:	DS  1		;currentt drive code
	DS  64		;stack area
STACK:	DS  1
SKEWSD:	SKEW	FIRST,SSECS,SKEWFSD
SKEWDDB:SKEW	FIRST,SECTDDB,SKFDEBL
DCBUFF:	DS  9
RDBUFF:	DS  1		;read buffer
	END  START1

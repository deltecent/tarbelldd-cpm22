;
;THIS PROGRAM IS A MODIFICATION OF "COPYATOB.COM" WHICH
;HAS BEEN RE-WRITTEN TO OPERATE BOTH THROUGH CPM BDOS CALLS
;AND DIRECTLY WITH BIOS PRIMITIVES.  THE PROGRAM CAN BE
;USED TO COPY TRACKS 0 AND  1 WITH THE COMMAND "COPY SYSTEM"
;                    2  TO 76 WITH THE COMMAND "COPY DATA" AND
;                    0  TO 76 WITH THE COMMAND "COPY ALL"
;THE PROGRAM WILL OPERATE WITH A STANDARD CPM SYSTEM OF ANY 
;SIZE.  BECAUSE OF THE POTENTIAL POWER OF THIS PROGRAM
;THE INITIATING COMMAND IS TESTED FOR PRECISE SYNTAX.
;TONY GOLD (212) 722-3416.
;
;7/23/77
;THIS PROGRAM HAS BEEN REWRITTEN TO REMOVE THE DEPENDENCE
;ON THE LOCATION OF THE SCRATCH AREA, SO THAT IT CAN BE
;USED WITH THE DIGITAL SYSTEMS FDC3 CONTROLLER.
;
;ALSO THE PROGRAM PAUSES AFTER LOADING SO THAT THE DISKS
;CAN BE CHANGED.
;TOM KIRK (609) 921-0321.
;
;8-4-79
;G.W.MULCHIN
;D.M.M.SOFTWARE
;MODIFIED TO REMOVE THE ADDED JUMPS FOR READ AND WRITE
;IN THE TARBELL CBIOS.
;
;MODIFIED 11-20-80 BY DON TARBELL TO REPORT ERROR ON DRIVE A.
;
;MODIFIED 1-27-81 BY G.W.MULCHIN OF TARBELL ELECTRONICS.
;ADDED DOUBLE DENSITY COPY TO ALL FUNCTIONS.
;Added drive selection option
;
;SYSTEM EQUATES
;
CR	EQU	0DH
LF	EQU	0AH
EXITCPM	EQU	0		;WARMBOOT EXIT POINT
LASTSEC	EQU	26		;SINGLE DENSITY 26 SECTORS
DDSECT	EQU	51		;DOUBLE DENSITY 51 SECTORS
BASE	EQU	0		;FIND WBOOT JMP ADDRESS AT RST0
DUMYADR	EQU	0
TBUFF	EQU	80H
BDOS	EQU	5		;CP/M ENTRY POINT
;
	ORG	100H
;
	JMP	VECTOR
HOME:	JMP	DUMYADR
SELDSK:	JMP	DUMYADR
SETTRK:	JMP	DUMYADR
SETSEC:	JMP	DUMYADR
SETDMA:	JMP	DUMYADR
READ:	JMP	DUMYADR
WRITE:	JMP	DUMYADR
 ;
COMPERR:DB	CR,LF,'Disk compare ERROR! ! !$'
MESGD:	DB	'+Permanent Source Disk Error Exit $'
MESGE:	DB	'+Permanent Destination Disk Error Exit $'
SIGNON:	DB	CR,LF,'Single/Double density Disk Copy Program ver 1.3'
	DB	CR,LF,13,10,'+Source on Drive A:'
	DB	CR,LF,'+Object on Drive B:'
	DB	CR,LF,'+Type <cr>$'
SINOFF:	DB	CR,LF,'Type <cr> to Exit or & <cr> to Repeat$'
RMSG:	DB	CR,LF,'Disk read ERROR trk 0 sector 1 drive '
DRVNUM:	DB	'  $'
WRMSG:	DB	CR,LF,'The density of the 2 disk are not matched.'
	DB	CR,LF,'Both disk must be the same density$'
WMSG:	DB	CR,LF,'Invalid density on drive '
INVDRV:	DB	'   $'
READY:	DB	CR,LF,'Put your system disk back into drive'
	DB	CR,LF,'A and push return <cr> when ready.$'
CRLF:	DB	CR,LF,'$'
;
;SUBROUTINE TO READ THE FIRST TRACK,
;FIRST SECTOR OF EACH DRIVE AND RETURN
;THE DENSITY CODE FOR THAT DISKETTE.
;
TYPEDEN:MOV	A,C	;GET A COPY OF THE DRIVE
	ADI	'A'	;MAKE CP/M DRIVE NUMBER
	STA	INVDRV	;SAVE FOR ERROR MESSAGE
	STA	DRVNUM	;DITTO
	CALL	SELDSK	;SELECT THE DRIVE
	CALL	HOME	;HOME THE DRIVE
	LXI	H,BUF0	;USE BUFFER 0 TO READ INTO
	CALL	DMASET	;SET THE CP/M DMA ADDRESS.
	MVI	C,1	;READ STARTING AT SECTOR 1.
	CALL	SETSEC	;SET THE SECTOR IN THE CONTROLLER
	CALL	READ	;READ IN THE BIOS
	ORA	A	;ANY ERRORS?
	JNZ	RERROR	;IF <> 0 WE HAVE ERRORS.
	LDA	BUF0+7EH
	RET		;RETURN DENSITY CODE IN REG A.
;
;ERROR DETECTED IN READING A DISK
;
RERROR:	LXI	D,RMSG	;POINT TO READ ERROR MESSAGE
ERR1:	CALL	PNTMSG
	LXI	D,READY	;POINT TO READY MESSAGE
	CALL	PNTMSG
RERR1:	MVI	C,1	;WAIT TILL <CR> PUSHED
	CALL	BDOS
	CPI	CR
	JNZ	RERR1	;LOOP TILL A CR PUSHED
	RST	0	;GO BACK TO CP/M
;
;THE WRONG DENSITY OF DISK WAS DETECTED
;REPORT AN ERROR MESSAGE.
;
WRONG:	LXI	D,WMSG	;POINT TO MESSAGE
	JMP	ERR1	;USE COMMON ERROR EXIT POINT
 ;
WRNGDSK:LXI	D,WRMSG	;POINT TO MESSAGE
	JMP	ERR1
;
COPY:	MVI	C,0		;SELECT DRIVE 0
	CALL	TYPEDEN		;CHECK DENSITY OF DISK 0
	CPI	0E5H		;E5 IS OK = SING DENSITY.
	JZ	DENSING
	CPI	0E7H		;doub sided,sing density
	CZ	DUBSID
	JZ	DENS1
	ORA	A		;00 IS OK = SING DENSITY.
	JZ	DENS1
	CPI	0DFH		;doub sided,doub density?
	CZ	DUBSID
	JZ	DENS1
	CPI	0DDH		;DD IS OK = DOUBLE DENSITY.
	JNZ	WRONG		;ALL OTHERS INVALID.
	JMP	DENS1
;
;A DISK WITH EITHER A 00 OR AN E5 IS SINGLE DENSITY.
;THIS ROUTINE WILL MAKE EITHER LOOK ALIKE FOR THIS
;PROGRAM. A DOUBLE DENSITY DISK MUST MATCH THE OTHER
;EXACTLY.
;
DENSING:XRA	A		;GET A 0
DENS1:	STA	DENTYPE		;SAVE THE DENSITY CODE FOR DSK 0.
;
	MVI	C,1		;SELECT DSK 1.
	CALL	TYPEDEN		;CHECK DENSITY OF DSK 1.
	CPI	0E5H		;SINGLE DENSITY?
	JZ	OTHDEN1		;YES	
	CPI	0E7H		;doub sided, single density?
	JZ	OTHDEN
	ORA	A		;SINGLE DENSITY?
	JZ	OTHDEN		;YES
	CPI	0DFH		;doub sided, doub density?
	JZ	OTHDEN
	CPI	0DDH		;DOUBLE DENSITY?
	JNZ	WRONG		;WE DON'T HANDLE ANY OTHER TYPE.
	JMP	OTHDEN
;
;double sided copy operation detected.
;adjust starting and ending track values.
;
DUBSID:	PUSH	PSW		;save density and flags
	LHLD	TRKSRT		;get start and ending tracks.
	MOV	A,H		;get ending track value
	ADD	A		;double it
	MOV	H,A		;now = ending trk * 2
	MOV	A,L		;get starting track
	ADD	A		;double it
	MOV	L,A		;now = starting trk * 2
	SHLD	TRKSRT		;save new values
	POP	PSW		;restore density and flags
	RET
;
OTHDEN1:XRA	A		;GET A ZERO
OTHDEN:	MOV	C,A		;SAVE THE CODE IN REG C.
;
;WE NOW HAVE DETERMINED THE DENSITY OF EACH DISK.
;NOW WE MUST MAKE SURE WE ARE NOT TRYING TO COPY
;2 DISK WHICH ARE NOT THE SAME DENSITY. IF WE ARE,
;THEN WE HAVE AN ERROR.
;
	LDA	DENTYPE		;GET DENSITY CODE FOR DSK 0.
	CMP	C		;ARE THEY THE SAME?
	JNZ	WRNGDSK		;IF <> 0, ERROR.
;
;IF WE MAKE IT TO THIS POINT, WE HAVE
;2 DISK WHICH MATCH. SO THE COPY MAY
;PROCEED.
;
	MVI	C,0
	CALL	SELDSK	;SELECT DISK A
	LDA	TRKSRT	;FIRST TRACK TO MOVE
	STA	TRK	;MAKE CURRENT
	MOV	C,A
	CALL	SETTRK	;AND SELECT IT ON DISK A
	MVI	C,1
	CALL	SELDSK	;ALSO B
 	LDA	TRKSRT	;FIRST TRACK TO MOVE
	MOV	C,A
	CALL	SETTRK	;AND SELECT IT ON DISK B
RDLOOP:	MVI	C,0
	XRA	A
	STA	CMPERR
	CALL	SELDSK
	LDA	TRK	;GET TRACK
	MOV	C,A
	CALL	READT	;READ ENTIRE TRACK
RETRYW:	MVI	C,1
	CALL	SELDSK
	LDA	TRK
	MOV	C,A
	CALL	WRITET	;WRITE TRACK
	LDA	TRK
	MOV	C,A
	CALL	COMPT	;REREAD AND COMPARE
	JNZ	RETRYW	;RETRY IF ERR
	LDA	TRK
	INR	A
	STA	TRK
	LXI	H,TRKSRT+1	;POINT TO LAST TRACK+1 STORAGE
	CMP	M		;ARE WE DONE?
	JNZ	RDLOOP		;LOOP IF NOT
	RET
;
COMPT:	LXI	H,BUF1
	CALL	RT2		;REREAD INTO BUF1
	LXI	H,BUF0
	LXI	D,BUF1
	LXI	B,128*LASTSEC
CMPLP:	LDAX	D
	CMP	M
	JNZ	CERR
	INX	H
	INX	D
	DCX	B		;CHECK OF END OF BUFFER
	MOV	A,B
	ORA	C
	JNZ	CMPLP
	RET
;
CERR:	LXI	D,COMPERR	;COMPARE ERROR MESSAGE
	JMP	ERR1		;USE COMMON ROUTINE
;
DMASET:	PUSH	B
	MOV	C,L
	MOV	B,H
	CALL	SETDMA
	POP	B
	RET
;
READT:	LXI	H,BUF0		;TRACK # IN C
RT2:	SHLD	DMAAD
	CALL	DMASET
 	CALL	SETTRK
	CALL	TRKDEN		;GET SECTOR FOR DENSITY DOING.
	MOV	C,L		;PUT IT INTO
	MOV	B,H		;REG BC
	LDAX	B		;GET A SECTOR NUMBER
RT3:	INX	B		;POINT TO NEXT SECTOR
	PUSH	B
	MOV	C,A		;PASS THE SECTOR TO CPM
	CALL	SETSEC
	CALL	READ
RT4:	RAR			;WAS A BIT 0 SET BY DISK ERROR?
	CC	FAILR
	LHLD	DMAAD
	LXI	D,128
	DAD	D
	SHLD	DMAAD
	CALL	DMASET
	POP	B
	LDAX	B		;GET LAST SECTOR DONE
	ORA	A		;LAST ONE?
	RZ
	JMP	RT3
;
WRITET:	LXI	H,BUF0	;TRACK # IN C
WT2:	SHLD	DMAAD
	CALL	DMASET
	CALL	SETTRK
	CALL	TRKDEN		;GET SECTOR FOR DENSITY DOING.
	MOV	C,L
	MOV	B,H		;BC= SECTOR POINTER
	LDAX	B		;GET A SECTOR NUMBER
WT3:	INX	B		;POINT TO NEXT SECTOR
	PUSH	B
	MOV	C,A		;PASS TO BIOS IN REG C
	CALL	SETSEC
	CALL	WRITE
WT4:	RAR		;WAS A BIT 0 SET BY DISK ERROR?
	CC	FAILW
	LHLD	DMAAD
	LXI	D,128
	DAD	D
	SHLD	DMAAD
	CALL	DMASET
	POP	B
	LDAX	B		;GET LAST SECTOR DONE
	ORA	A		;END OF TABLE?
	RZ
	JMP	WT3
;
;RETURN POINTER IN H,L FOR SECTOR TABLE
;INDICATED BY THE TYPE OF COPY OPERATION
;GOING ON.
;
TRKDEN:	LDA	DENTYPE		;GET DENSITY OF DISKS.
	CPI	0DDH		;DOUBLE DENSITY?
	JZ	TRKSDD		;YES, DOING A DOUBLE DENSITY
	CPI	0DFH		;double sided, double density?
	MVI	A,2		;1st 2 trks are single density
	STA	TRKSD2+1
	JZ	TRKSDD
 	LHLD	STABLE		;NO, WE ARE DOING SINGLE DEN.
	RET			;RETURN SECTOR TABLE IN H,L
;
;COPYING A DOUBLE DENSITY DISK
;MUST DETERMINE WHEN COPYING TO
;TRACKS > 1.
;
TRKSDD:	LDA	OPER		;GET OPERATION FLAG
	CPI	4		;DOING DATA ONLY?
	LHLD	DTABLE		;POINT TO DD SECT TABL IN CASE WE ARE
	RNC			;RETURN THE POINTER
	LDA	TRK		;WE ARE DOING EITHER 'S' OR 'A' COPY
TRKSD2:	CPI	1		;DOING < TRK 1?
	LHLD	STABLE		;IF SO, RETURN SINGLE DENSITY TABLE
	RC
	LHLD	DTABLE		;MUST BE DOING >= TRK 1
	RET			;RETURN DOUBLE DENSITY TABLE.
;
;SET UP JUMP VECTORS FOR  ACCESS TO BIOS PRIMITIVES
;
VECTOR:	LHLD	BASE+1	;GET WBOOT ADDRESS
	SPHL		;SAVE IT IN SP FOR DAD
;
	LXI	H,15H
	DAD	SP
	SHLD	HOME+1
;
	LXI	H,18H
	DAD	SP
	SHLD	SELDSK+1
;
	LXI	H,1BH
	DAD	SP
	SHLD	SETTRK+1
;
	LXI	H,1EH
	DAD	SP
	SHLD	SETSEC+1
;
	LXI	H,21H
	DAD	SP
	SHLD	SETDMA+1
;
	LXI	H,24H
	DAD	SP
	SHLD	READ+1
;
	LXI	H,27H
	DAD	SP
	SHLD	WRITE+1
;
	LXI	SP,STKTOP
;
;THIS ROUTINE SETS UP THE PARAMETERS FOR THE COPY ROUTINE.
;COPY CAN BE USED TO TRANSFER:	SYS	TRACKS  0- 1
;				DAT	TRACKS  2-76
 ;				ALL	TRACKS	0-76
;THE ROUTINE SEARCHES THE DEFAULT BUFFER AT 80H FOR THE
;RUN PARAMETER TO BE USED
;
RUNTYP:	JMP	BUFMSR
;
SYSMSG:	DB	'YSTEM$'	;SYSTEM MESSAGE
DATMSG:	DB	'ATA$'		;DATA MESSAGE
ALLMSG:	DB	'LL$'		;ALL MESSAGE
TRKSRT:	DW	0		;STORAGE FOR FIRST AND LAST+1 TRACK NUMBERS
CMDER1:	DB	'+COMMAND "COPY$'
CMDER2:	DB	'" HAS SYNTAX ERROR',0DH,0AH,'$'
CMDINF:	DB	'This Program is initiated with the Command',0DH,0AH
	DB	'"COPY SYSTEM", "COPY DATA" OR "COPY ALL"$'
DONMSG:	DB	'Function Complete$'
MESGO:	DB	'Shall we go on regardless of the Error? (Y/N)$'
;
;FIRST WE MEASURE THE INPUT BUFFER MESSAGE
;AND DELIMIT IT WITH A $ PER BDOS CALL 9
;
BUFMSR:	LXI	H,TBUFF
	XRA	A		;CLEAR ACC.
	ADD	M		;GET MESSAGE SIZE
	JZ	NOMSG		;NONE FOUND
	INX	H		;ADD FOR ADDR. PAST MESSAGE
	MVI	B,0		;EMPTY FOR DAD
	MOV	C,A
	DAD	B		;ADD CHARACTER COUNT TO HL
	MVI	M,'$'		;END BUFFER CHARACTER
;
;NEXT IS A TEST FOR WHICH MESSAGE IS PRESENT
;
	LDA	TBUFF+2		;FIRST CHARACTER ADDRESS
	CPI	'S'
	JZ	SYSSET
	CPI	'D'
	JZ	DATSET
	CPI	'A'
	JZ	ALLSET
	JMP	BADMSG		;FIRST CHARACTER NOT ONE OF 3 PERMITTED
;
SYSSET:	LXI	D,SYSMSG
	MVI	C,6
	CALL	MSGTST
	MVI	L,0		;FIRST TRACK TO TRANSFER
	MVI	H,2		;LAST TRACK PLUS ONE
	MVI	A,1		;1=SYSTEM COPY OPERATION
	JMP	PUTPAR
;
DATSET:	LXI	D,DATMSG
	MVI	C,4
	CALL	MSGTST
	MVI	L,2		;FIRST TRACK TO TRANSFER
	MVI	H,77		;LAST TRACK PLUS ONE
	MVI	A,4		;4=DATA COPY OPERATION
	JMP	PUTPAR
 ;
ALLSET:	LXI	D,ALLMSG
	MVI	C,3
	CALL	MSGTST
	MVI	L,0		;FIRST TRACK TO TRANSFER
	MVI	H,77		;LAST TRACK PLUS ONE
	MVI	A,2		;2=COPY ALL TRACKS
PUTPAR:	STA	OPER		;SAVE OPERATION CODE
	SHLD	TRKSRT		;PUT PARAMETERS IN TRKSRT AND TRKSRT+1
	LXI	D,SIGNON
	CALL	PNTMSG
AGIN:	LXI	SP,STKTOP
	MVI	C,1
	CALL	BDOS
	CPI	'C'-40H		;CNTL-C?
	JZ	EXITCPM
	CPI	CR
	JNZ	AGIN
	LXI	D,CRLF
	CALL	PNTMSG
;
	CALL	COPY		;MAIN ROUTINE
	LXI	D,DONMSG	;SAY WE'RE DONE
	CALL	PNTMSG
	JMP	EXIT		;DONE. NOW GET OUT
;
MSGTST:	LXI	H,TBUFF+3
	LDAX	D
	CMP	M		;SAME AS MESSAGE?
	JNZ	BADMSG
	INX	H
	INX	D
	DCR	C		;REDUCE CHARACTER COUNTER
	RZ			;FINISHED OK
	JMP	MSGTST+3	;CHECK OUT NEXT CHARACTER
;
BADMSG:	LXI	D,CMDER1
	CALL	PNTMSG
	LXI	D,TBUFF+1		;PRINT ERRONEOUS COMMAND
	CALL	PNTMSG
	LXI	D,CMDER2
	CALL	PNTMSG
NOMSG:	LXI	D,CMDINF
	CALL	PNTMSG
	JMP	EXITCPM
;
FAILR:	LXI	D,MESGD
	JMP	DIE
;
FAILW:	LXI	D,MESGE
DIE:	CALL	PNTMSG
	LXI	D,MESGO		;ASK WHETHER TO GO ON.
	CALL	PNTMSG
	MVI	C,1	;READ ANSWER (Y/N).
	CALL	BDOS
	CPI	'Y'	;WAS ANSWER Y?
 	RZ		;RETURN IF SO.
	CPI	'y'
	RZ
;
EXIT:	LXI	D,SINOFF
	CALL	PNTMSG
	MVI	C,1
	CALL	BDOS
	CPI	'&'
	JZ	AGIN
	CPI	CR
	JNZ	EXIT
	JMP	EXITCPM
;
; PRINT MESSAGE AT DE.
;
PNTMSG:	MVI	C,9
	JMP	BDOS	;CALL BDOS & RETURN.
;
;THE FOLLOWING IS A SINGLE DENSITY 26 SECTOR SKEW TABLE.
;
SINTAB:	DB	1,2,3,4,5,6,7,8,9,10,11,12,13,14
	DB	15,16,17,18,19,20,21,22,23,24,25,26,0
;
;THE FOLLOWING IS A DOUBLE DENSITY 51 SECTOR SKEW TABLE.
;
DUBTAB:	DB	1,10,19,28,37,46,4,13,22,31,40,49,7,16,25
	DB	34,43,2,11,20,29,38,47,5,14,23,32,41,50,8
	DB	17,26,35,44,3,12,21,30,39,48,6,15,24,33
	DB	42,51,9,18,27,36,45,0
;
STABLE:	DW	SINTAB	;POINTER TO SINGLE DENSITY TABLE
DTABLE:	DW	DUBTAB	;POINTER TO DOUBLE DENSITY TABLE
DENTYPE:DS	1	;DENSITY CODE STORAGE
OPER:	DS	1	;COPY OPERATION BYTE
CMPERR:	DS	1	;NUMBER OF COMPARE ERRORS
TRK:	DS	1
DMAAD:	DS	2
STK:	DS	32
STKTOP:	DS	1
BUF0:	DS	128*DDSECT	;ROOM FOR DOUBLE DENSITY
BUF1:	DS	128*DDSECT	;DITTO
	END

;
;program to read or write a double density 51 x 128 byte
;disk. this program is just like sysgen.
;
;track 0 = single density 128 bytes x 26 sectors.
;track 1 = double density 128 bytes x 51 sectors.
;
;all of track 1 is read or written with this program.
;if running double sided, track 1 now becomes
;track 0 on side 1. it is double density,
;with 51 sectors of 128 bytes.
;program uses function 10 for all console input
;
;last modification 12-03-81
;g.w.mulchin, tarbell electronics
;
	ORG	100H
;
;system equates
;
FALSE	EQU	0		;define value of false.
TRUE	EQU	NOT FALSE	;define value of true.
DMACNTL	EQU	TRUE		;true if using dma control
DISK	EQU	0F8H		;disk port base address.
STPRAT	EQU	1		;0=3ms,1=6ms,2=10ms,3=15ms
ADR0	EQU	0E0H		;dma address port.
WCT0	EQU	0E1H		;dma word count port.
CMND	EQU	0E8H		;dma command port.
DCOM	EQU	DISK		;command port.
DSTAT	EQU	DISK		;status port.
SECT	EQU	DISK+2		;sector port.
WAIT	EQU	DISK+4		;wait port.
DCONT	EQU	DISK+4		;control port.
DMACHK	EQU	DISK+5		;dma check port.
SYSTEM	EQU	0900H		;start of cpm image
SDSPT	EQU	26		;26 sectors / track.
DDSPT	EQU	51		;51 sectors / track.
NSECTS	EQU	SDSPT + DDSPT	;total system sectors.
RTCNT	EQU	10		;number of retrys.
DMAW	EQU	80H		;dma write command
DMAR	EQU	40H		;dma read command
B128	EQU	128		;128 byte count
CR	EQU	0DH
LF	EQU	0AH
BEL	EQU	7		;bell code
IDBUF	EQU	97EH		;id byte location in memory
BOOT	EQU	0
BDOS	EQU	5
PRINTB	EQU	9		;print buffer function
RCB	EQU	10		;read console buffer <func 10>
;
BEGIN:	JMP	INIT		;jump around storage
;
MSG1:	DB	CR,LF,'Tarbell 51 x 128 Sysgen program'
	DB	CR,LF,'Ver 1.5, Dated 12-03-81'
MSG1A:	DB	CR,LF,'Source drive or <return to skip> $'
MSG3:	DB	CR,LF,'Source drive = $'
MSG2:	DB	CR,LF,'Destination drive or <return to reboot> $'
MSG4:	DB	CR,LF,'Destination drive = $'
READY:	DB	' , type return when ready$'
WRITER:	DB	CR,LF,BEL,'Disk write error$'
RRERR:	DB	CR,LF,BEL,'Disk read error$'
ERROR:	DB	CR,LF,BEL,'Invalid drive select$'
MSG5:	DB	CR,LF,'Reading a Double Sided disk (Y or N) $'
MSG6:	DB	CR,LF,'Writing a Double Sided disk (Y or N) $'
NMERR:	DB	CR,LF,BEL,'Mis-match of drive ID byte.$'
KEYBUF:	DB	3,0,0,0,0
;
;subroutines
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
;print buffer routine
;
;enter:	d,e -> message to print
;exit:	none
;regs:	d,e c
;
PRINT:	MVI	C,PRINTB	;print buffer function
	JMP	BDOS		;use bdos to print
;
;select drive routine
;
DSELDSK:ADD	A		;shift
	ADD	A		; left
	ADD	A		;  four
	ADD	A		;   times
	OUT	DCONT		;send the select code
	STA	CLATCH		;save it
	RET
;
;home selected drive
;
DHOME:	MVI	A,STPRAT	;restore at step rate
	OUT	DCOM
	IN	WAIT		;wait for intrq.
	RET
;
;main line starts here
;
INIT:	LXI	SP,STACK	;set local stack
	LXI	D,MSG1		;show opening message
GDRV:	CALL	PRINT
	CALL	INPUT		;get source drive
	ORA	A		;= carriage return?
	JZ	DESTDRV		;yes, memory already set
	STA	READY		;show drive selected
	ANI	7		;strip ascii
	DCR	A		;make cpm drive number
	CPI	4		;check drive limits
	STA	SELD		;modified for cpm select
	JC	OK
	LXI	D,ERROR		;point to error message
	CALL	PRINT
	LXI	D,MSG1A
	JMP	GDRV		;try again
;
OK:	LXI	D,MSG5		;reading double sided?
	CALL	PRINT
	CALL	INPUT		;get response
	CPI	'N'		;no?
	MVI	A,0		;0 = doing single sided disk
	JZ	OK2		;yes, just doing single sided
	MVI	A,1		;doing double sided, set a flag
OK2:	STA	SIDED		;save the flag
	LXI	D,MSG3
	CALL	PRINT
	LXI	D,READY		;print ready message
	CALL	PRINT
OK1:	CALL	INPUT		;get cr
	ORA	A		;did we get a cr?
	JNZ	OK1		;loop till a cr is typed
	LDA	SELD		;get drive to read
	CALL	DSELDSK
	CALL	DHOME		;home the drive
	CALL	READDSK		;read the selected drive
;
DESTDRV:LXI	D,MSG2		;get destination drive to do
DDRV:	CALL	PRINT
	CALL	INPUT		;get source drive
	ORA	A		;= 0?
	JZ	BOOT		;all done
	STA	READY		;show drive selected
	ANI	7		;strip ascii
	DCR	A		;make cpm drive number
	CPI	4		;check drive limits
	STA	SELD		;modified for cpm select
	JC	DOK
	LXI	D,ERROR		;point to error message
	CALL	PRINT
	LXI	D,MSG1A
	JMP	DDRV		;try again
;
DOK:	LXI	D,MSG6		;writing double sided drive
	CALL	PRINT
	CALL	INPUT		;get response
	CPI	'N'		;is it no?
	MVI	A,0		;set flag for no in case
	MVI	B,0DDH		;talking to single sided?
	JZ	DOK2
	MVI	A,1		;yes, set = doub sided wanted
	MVI	B,0DFH		;must be using double sided
DOK2:	STA	SIDED		;save the flag code
	LDA	IDBUF		;get the id byte in memory
	CMP	B		;are they the same?
	JNZ	NOMTCH		;jump if they dont match
	LXI	D,MSG4		;point to message
	CALL	PRINT
	LXI	D,READY		;ready message
	CALL	PRINT
DOK1:	CALL	INPUT		;get a cr
	ORA	A		;must be zero
	JNZ	DOK1		;loop till cr
	LDA	SELD		;get the selected drive
	CALL	DSELDSK		;select it
	CALL	DHOME		;home the drive
	CALL	DSKWRT		;write the operating system
	JMP	DESTDRV
;
NOMTCH:	LXI	D,NMERR		;point to mismatch error
	CALL	PRINT		;print it
	JMP	DESTDRV		;retry
;
READDSK	EQU	$
;
	IF	DMACNTL
	LXI	H,DMAR SHL 8 OR B128
	SHLD	WRITOP
	ENDIF
;
	MVI	A,SDSPT+1	;number of single density sects
	STA	RSECTSZ+1
	MVI	E,RTCNT		;get retry count.
RBLOOP:	LXI	H,SYSTEM	;cp/m starts here.
	SHLD	SYSVAL		;save it
	MVI	D,NSECTS	;number of sectors to write.
RNTRK:	MVI	C,1		;sector number.
	MVI	B,080H		;read command.
RNSEC:	CALL	RRED		;read first sector.
	DCR	D		;if done,
	RZ
	INR	C		;increment sector count.
	MOV	A,C		;done with
RSECTSZ:CPI	SDSPT+1		;this track?
	JC	RNSEC		;if not, read next sector.
	MVI	A,DDSPT+1	;number of doub den sectors
	STA	RSECTSZ+1	;modify the code.
	CALL	SETDDEN		;set up for double density
	JMP	RNTRK
;
SETDDEN:LDA	CLATCH		;get current code
	ORI	8		;set double density code
	STA	CLATCH		;save it
	OUT	WAIT		;set latch for d.density
	LDA	SIDED		;doing doub sided?
	ORA	A		;= to 0?
	JNZ	RSIDED		;not =, doing double sided
	MVI	A,5BH		;step command.
	OUT	DCOM		;issue it.
	IN	WAIT		;wait until done.
	RET
;
RSIDED:	LDA	CLATCH		;get current drive code
	ORI	40H		;switch side
	OUT	WAIT		;switch side now
	RET
;
RRED:
	IF	DMACNTL
	CALL	DMARW		;use common routine
	ENDIF
;
	IF	NOT DMACNTL	;if not using dma control.
DATA	EQU	DISK+3		;data port.
;
	MVI	A,0D0H		;force intrp command
	OUT	DCOM
	MOV	A,C		;get the sector to do
	OUT	SECT		;send it
	CALL	HDLD		;check for head loaded
	ORA	B		;merge in read command
	LHLD	SYSVAL
	OUT	DCOM		;send read command
RLOOP:	IN	WAIT		;wait for drq.
	ORA	A		;set flags.
	JP	RCHK		;jump if done.
	IN	DATA
	MOV	M,A		;put in memory.
	INX	H		;increment pointer.
	JMP	RLOOP		;loop until done.
RCHK	EQU	$
	ENDIF

	SHLD	SYSVAL		;save next address
	IN	DSTAT		;read status.
	ANI	09DH		;look at error bits.
	RZ			;ok if zero.
	DCR	E		;decrement retry count.
	JNZ	RBLOOP		;try again if not zero.
	LXI	D,RRERR		;retry exausted
	CALL	PRINT		;print the error message
	JMP	BOOT		; and return to cpm.
;
DSKWRT	EQU	$
;
	IF	DMACNTL
	LXI	H,DMAW SHL 8 OR B128
	SHLD	WRITOP
	ENDIF
;
	MVI	A,SDSPT+1	;number of single density sects
	STA	SECTSZ+1
	MVI	E,RTCNT		;get retry count.
BLOOP:	LXI	H,SYSTEM	;cp/m starts here.
	SHLD	SYSVAL		;save it
	MVI	D,NSECTS	;number of sectors to write.
WNTRK:	MVI	C,1		;sector number.
	MVI	B,0A0H		;for head load.
WNSEC:	CALL	WRIT		;write first sector.
	DCR	D		;if done,
	RZ
	INR	C		;increment sector count.
	MOV	A,C		;done with
SECTSZ:	CPI	SDSPT+1		;this track?
	JC	WNSEC		;if not,write next sector.
	MVI	A,DDSPT+1	;number of doub den sectors
	STA	SECTSZ+1	;modify the code.
	CALL	SETDDEN		;set up for double density
	JMP	WNTRK		;write next track.
;
WRIT:
	IF	DMACNTL
	CALL	DMARW		;use common routine
	ENDIF

	IF	NOT DMACNTL	;if not using dma control.
	MVI	A,0D0H		;force intrp command
	OUT	DCOM
	MOV	A,C		;get the sector to do
	OUT	SECT		;send it
	CALL	HDLD		;check for head loaded
	ORA	B		;merge in write command
	LHLD	SYSVAL
	OUT	DCOM		;send write command
WLOOP:	IN	WAIT		;wait for drq.
	ORA	A		;set flags.
	JP	WCHK		;jump if done.
	MOV	A,M		;put in memory.
	OUT	DATA
	INX	H		;increment pointer.
	JMP	WLOOP		;loop until done.
WCHK	EQU	$
	ENDIF

	SHLD	SYSVAL		;save next address
	IN	DSTAT		;read status.
	ANI	0FDH		;look at error bits.
	RZ			;ok if zero.
	DCR	E		;decrement retry count.
	JNZ	BLOOP		;try again if not zero.
	LXI	D,WRITER
	CALL	PRINT
	JMP	BOOT
;
DMARW:
	IF	DMACNTL		;if using dma control.
	XRA	A		;clear chan 0
	OUT	CMND
	MVI	A,0D0H		;force intrp command
	OUT	DCOM		;clear floppy chip
	PUSH	D		;save d,e
	LHLD	WRITOP		;get write operation
	XCHG
	LHLD	SYSVAL		;get memory pointer
	DCX	D		;count = count-1
	MOV	A,E		;count byte
	OUT	WCT0
	MOV	A,D		;write command
	OUT	WCT0
	INX	D
	MOV	A,L		;get low address byte
	OUT	ADR0
	MOV	A,H		;high address byte
	OUT	ADR0
	MVI	A,41H		;chan 0 request
	OUT	CMND
	MOV	A,C		;sector in a.
	OUT	SECT		;set sector register.
	CALL	HDLD
	ORA	B		;get head load bit.
	OUT	DCOM		;issue command.
RLOPP:	IN	DMACHK		;check dma status
	RLC			; bit 7
	JC	RLOPP		;loop if carry
	XRA	A		;clear dma chip
	OUT	CMND
	MOV	A,D
	ANI	3FH		;strip command byte
	MOV	D,A
	DAD	D		;h,l = (h,l + d,e)
	POP	D
	RET
	ENDIF
;
;check head load bit
;
HDLD:	IN	DSTAT		;get disk status
	ANI	20H		;mask head load bit
	MVI	A,4		;get a 4 for load head
	RZ			;reload the head
	MVI	A,0		;else, head is load already
	RET
;
	IF	DMACNTL
WRITOP:	DS	2		;dma write operation storage
	ENDIF
;
SYSVAL:	DS	2		;system pointer storage
CLATCH:	DS	1		;current drive select code
SIDED:	DS	1		;doub sided flag byte
SELD:	DS	1		;current drive to select
	DS	30		;stack area
STACK:	DS	1
;
	END	BEGIN

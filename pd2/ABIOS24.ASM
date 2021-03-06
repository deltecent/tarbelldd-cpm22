; CP/M BASIC INPUT/OUTPUT OPERATING SYSTEM (BIOS)
; TARBELL ELECTRONICS CPM 1.4 VERSION OF 2-04-82.
;
; THIS MODULE CONTAINS ALL THE INPUT/OUTPUT ROUTINES FOR
; THE CP/M SYSTEM, INCLUDING THE DISK ROUTINES FOR AUTOMATIC
; SELECTION OF THE DISK DENSITY AND THE NECESSARY DMA ROUTINES.
; THIS SECTION ALSO DEFINES THE I/O PORTS AND STATUS BITS. BY
; SETTING THE PROPER VALUES FOR THE EQU STATEMENTS, THE I/O MAY BE
; AUTOMATICALLY RECONFIGURED TO FIT MOST SITUATIONS. THE TRUE AND
; FALSE ONES CONTROL CONDITIONAL ASSEMBLIES OF DIFFERENT SECTIONS
; OF I/O ROUTINES TO FIT DIFFERENT INTERFACE REQUIREMENTS.

TRUE	EQU  0FFFFH	;DEFINE VALUE OF TRUE.
FALSE	EQU  NOT TRUE	;DEFINE VALUE OF FALSE.

***************************************************
*** THIS BEGINS THE AREA WHICH REQUIRES CHANGES ***
***      FOR DIFFERENT CONSOLE I/O SYSTEMS      ***
***************************************************

MSIZE	EQU  24		;MEMORY SIZE IN KBYTES.
INTRP	EQU  FALSE	;TRUE IF INTERRUPTS ALLOWED.
TESTING	EQU  FALSE	;TRUE FOR TESTING ERRORS
TARBELL	EQU  FALSE	;TRUE IF USING THE TARBELL Z-80 CPU.
IOBASE	EQU  0		;BASE IO ADDR FOR TARBELL CPU (0 or 10 hex).
TIMER	EQU  FALSE	;TRUE IF USING CPU TIMER (Tarbell CPU board).
STD	EQU  TRUE	;TRUE IF STANDARD I/O.
VDB8024	EQU  FALSE	;TRUE IF USING SD SALES VDB-8024.
DELTA	EQU  FALSE	;TRUE IF USING DELTA CPU CARD.
MSIO2	EQU  FALSE	;TRUE IF MITS 2SIO.
ISIO2	EQU  FALSE	;TRUE IF IMSAI SIO-2.
TUART	EQU  FALSE	;TRUE IF CROMEMCO TUART.
VDM	EQU  FALSE	;TRUE IF PROC TECH VDM.
FLASH	EQU  FALSE	;TRUE IF VG FLASHWRITER.
VB1	EQU  FALSE	;TRUE IF SSM VB1-B.
OTHER	EQU  FALSE	;TRUE IF SOMETHING ELSE.
SOLOS	EQU  FALSE	;TRUE IF PROC TECH SOLOS.
BACKSP	EQU  TRUE	;AUTO-BACKSPACE FOR CRT'S.
DUBSID	EQU  FALSE	;TRUE FOR DOUBLE SIDED DRIVES.(1 LOGICAL DRIVE)
DMACNTL	EQU  FALSE	;TRUE IF DMA CONTROLLER
SPOOL	EQU  FALSE	;TRUE IF USING KLH SPOOLER
TARDEL	EQU  TARBELL OR DELTA	;IF USING TARBELL OR DELTA CPU.
;
	IF NOT SOLOS AND NOT TARDEL	;IF NOT PROC TECH SOLOS,
CSTAT	EQU  0		;CONSOLE STATUS PORT.
CCOM	EQU  0		;CONSOLE COMMAND PORT.
CDATA	EQU  1		;CONSOLE DATA PORT.
LSTAT	EQU  2		;LIST STATUS PORT.
LCOM	EQU  2		;LIST COMMAND PORT.
LDATA	EQU  3		;LIST DATA PORT.
	ENDIF
;
CONUL	EQU  FALSE	;CONSOLE NULLS?
CNULL	EQU  16		;CONSOLE NULL COUNT.
LSTNUL	EQU  FALSE	;LIST DEVICE NULLS?
LNULL	EQU  0		;LIST NULL COUNT.
LSTPAG	EQU  FALSE	;LIST DEVICE PAGING?
LINCNT	EQU  66		;LINES PER PAGE.
HLAB	EQU  0		;8 FOR HD LD AT BEG OF SEEK.
STPRAT	EQU  2		;RATE 0=3ms,1=6MS, 2=10MS, 3=20MS.
DUAL	EQU  FALSE	;TRUE IF DUAL DRIVE.(2 HEADS MOVE TOGETHER)

*******************************************************
*** THIS IS THE END OF THE AREA WHICH NORMALLY NEED ***
***     BE CHANGED FOR MOST CONSOLE I/O SYSTEMS     ***
*******************************************************

VIDEO	EQU  VDM OR FLASH OR VB1    ;TRUE FOR ANY VIDEO.
RDYLO	EQU  STD OR SOLOS OR OTHER  ;STATUS READY WHEN LOW.
RDYHI	EQU  NOT RDYLO
;
	IF   TARDEL	;IF USING TARBELL OR DELTA CPU
CCOM	EQU  IOBASE+1	;CONSOLE COMMAND PORT
CSTAT	EQU  IOBASE+1	;CONSOLE STATUS PORT ( CHAN A.)
CDATA	EQU  IOBASE+0	;CONSOLE DATA PORT
LCOM	EQU  IOBASE+3	;LIST COMMAND PORT
LSTAT	EQU  IOBASE+3	;LIST STATUS PORT (CHAN B.)
LDATA	EQU  IOBASE+2	;LIST DATA PORT
	ENDIF
;
	IF	TIMER AND TARBELL	;MUST BE USING TARBELL CPU.
;
; TIMER EQUATES
;
TCH0	EQU	IOBASE+4	;TIMER CHAN 0 ADDRESS
TCH1	EQU	IOBASE+5	;TIMER CHAN 1 ADDRESS
TCH2	EQU	IOBASE+6	;TIMER CHAN 2 ADDRESS
TCMND	EQU	IOBASE+7	;TIMER COMMAND PORT
IMASK	EQU	IOBASE+8	;INTERRUPT MASKING PORT
CNTR0	EQU	00000000B	;counter 0
CNTR1	EQU	01000000B	;counter 1
CNTR2	EQU	10000000B	;counter 2
RLWORD	EQU	00110000B	;read/load lsb 1st, msb 2nd.
RLHBYTE	EQU	00100000B	;read/load msb only.
RLLBYTE	EQU	00010000B	;read/load lsb only.
CNTRLT	EQU	00000000B	;counter latching operation.
BINARY	EQU	00000000B	;select binary operation.
BCD	EQU	00000001B	;select BCD operation.
MODE0	EQU	00000000B	;interrupt on terminal count.
MODE1	EQU	00000010B	;programmable One-shot.
MODE2	EQU	00000100B	;rate generator.
MODE3	EQU	00000110B	;square wave rate generator.
MODE4	EQU	00001000B	;software triggered strobe.
MODE5	EQU	00001010B	;hardware triggered strobe.
	ENDIF

	IF   VDM		;IF PROC TECH VDM1,
SCREEN	EQU  0CC00H		;SCREEN PLACE IN MEMORY.
	ENDIF

	IF  FLASH OR VB1
SCREEN	EQU  0F800H		;SCREEN PLACE IS DIFFERENT.
	ENDIF

	IF  FLASH		;IF VG FLASHWRITTER
ENDSCR	EQU (SCREEN+2048) SHR 8
	ENDIF

	IF  VB1 OR VDM			;IF SSM VB1-B BOARD
ENDSCR	EQU (SCREEN+1024) SHR 8
	ENDIF
;
	IF  VIDEO
LINES15 EQU SCREEN + 64		;VIDEO LINES
SCRLCNT EQU 960			;LINES TO SCROLL
SCRNTOP EQU SCREEN + SCRLCNT	;TOP OF SCREEN
	ENDIF
;
BKSP	EQU 08H			;BACKSPACE EQUATE
LF	EQU 0AH			;LINEFEED EQUATE
CR	EQU 0DH			;CARRIAGE RET EQUATE
FF	EQU 0CH			;FORM-FEED EQUATE.
;
DDEN	EQU  08H	;DOUBLE DENSITY ENABLE CODE
DDDSB	EQU  0F7H	;DOUBL. DENSITY DISABLE CODE
;
	IF   SOLOS		;IF PROC TECH SOLOS,
CSTAT	EQU  0FAH		;CONSOLE STATUS PORT.
KBD	EQU  0C02EH		;SOLOS KEYBOARD.
CLRSCR	EQU  0C0D5H		;CLEAR SCREEN.
SCRN	EQU  0C054H		;SOLOS OUTPUT.
	ENDIF

	IF NOT SOLOS		;IF NOT PROC TECH SOLOS,
DMAP	EQU  0E0H		;DMA BASE ADDRESS.
DISK	EQU  0F8H		;DISK BASE ADDRESS.
	ENDIF
;
	IF SOLOS		;IF PROC TECH SOLOS,
DMAP	EQU  060H		;DMA BASE ADDRESS.
DISK	EQU  078H		;DIFFERENT DISK PORTS.
	ENDIF
;
ADR0	EQU  DMAP+0		;DMA ADDRESS REG PORT.
WCT0	EQU  DMAP+1		;DMA WORD COUNT REG PORT.
CMND	EQU  DMAP+8		;DMA COMMAND PORT.
DCOM	EQU  DISK		;DISK COMMAND PORT.
DSTAT	EQU  DISK		;DISK STATUS PORT.
TRACK	EQU  DISK+1		;DISK TRACK PORT.
SECTP	EQU  DISK+2		;DISK SECTOR PORT.
DDATA	EQU  DISK+3		;DISK DATA PORT.
WAIT	EQU  DISK+4		;DISK WAIT PORT.
DCONT	EQU  DISK+4		;DISK CONTROL PORT.
DMACHK	EQU  DISK+5		;DMA CHECK PORT.
RTCNT	EQU  10			;RETRY COUNT.

	IF   STD		;IF STANDARD I/O,
CKBR	EQU  00000001B		;KEYBOARD READY BIT.
CPTR	EQU  10000000B		;CONS OUTPUT RDY BIT.
	ENDIF

	IF   VDB8024
CKBR	EQU  00000010B		;KEYBOARD RDY BIT.
CPTR	EQU  00000100B		;CON RDY BIT.
	ENDIF

	IF   MSIO2		;IF MITS 2SIO,
CKBR	EQU  00000001B		;KEYBOARD READY BIT.
CPTR	EQU  00000010B		;PRINT READY BIT.
	ENDIF

	IF   TARDEL OR ISIO2		;IF IMSAI SIO-2,
CKBR	EQU  00000010B		;KEYBOARD READY BIT.
CPTR	EQU  00000001B		;PRINT READY BIT.
	ENDIF

	IF   TUART		;IF CROMEMCO TUART,
CKBR	EQU  01000000B		;KEYBOARD READY BIT.
CPTR	EQU  10000000B		;PRINT READY BIT.
	ENDIF

	IF   SOLOS		;IF PROC TECH SOLOS,
CKBR	EQU  00000001B		;KEYBOARD READY BIT.
CPTR	EQU  10000000B		;DUMMY EQU.
	ENDIF

	IF OTHER		;IF SOMETHING ELSE,
CKBR	EQU  00000010B		;KEYBOARD READY BIT.
CPTR	EQU  10000000B		;PRINTER READY BIT.
	ENDIF

LRBIT	EQU  CPTR		;LISTER READY BIT.
IOBYTE	EQU  3			;ADDRESS OF I/O BYTE.
CBASE	EQU  (MSIZE-17)*1024	;BIAS FOR LARGER THAN 17K.
CPMB	EQU  CBASE+2900H	;START OF CPM.
BDOS	EQU  CBASE+3106H	;START OF BDOS 1.4.
CPML	EQU  1500H		;LENGTH OF CPM SYSTEM-BIOS.
NSECTS	EQU  25			;NUMBER OF SECTORS TO READ.
;
	ORG  CPMB+1072H		;CP/M PATCH.
	CALL CPMB+0AF4H
	NOP!NOP!NOP
	MOV  A,C
	LXI  H,CPMB+14F8H
;
	ORG  CPMB+1500H		;START OF BIOS.
;
; I/O JUMP VECTOR
; THIS IS WHERE CPM CALLS WHENEVER IT NEEDS
; TO DO ANY INPUT/OUTPUT OPERATION.
; USER PROGRAMS MAY USE THESE ENTRY POINTS
; ALSO, BUT NOTE THAT THE LOCATION OF THIS
; VECTOR CHANGES WITH THE MEMORY SIZE.
;
	JMP  BOOT		;FROM COLD START LOADER.
WBOOTE:	JMP  WBOOT		;FROM WARM BOOT.
	JMP  CONST		;CHECK CONSOLE KB STATUS.
	JMP  CONIN		;READ CONSOLE CHARACTER.
	JMP  CONOT		;WRITE CONSOLE CHARACTER.
	JMP  LIST		;WRITE LISTING CHAR.
	JMP  PUNCH		;WRITE PUNCH CHAR.
	JMP  READER		;READ READER CHAR.
	JMP  HOME		;MOVE DISK TO TRACK ZERO.
	JMP  SELDSK		;SELECT DISK DRIVE.
	JMP  SETTRK		;SEEK TO TRACK IN REG A.
	JMP  SETSEC		;SET SECTOR NUMBER.
	JMP  SETDMA		;SET DISK STARTING ADR.
	JMP  READ		;READ SELECTED SECTOR.
	JMP  WRITE		;WRITE SELECTED SECTOR.
;
	IF   SPOOL		;IF USING KLH SPOOLER
	DB   0FFH		;FLAG FOR SPOOLER.
	DW   LTBSY		;LISTER STATUS LOCATION
	DW   LTBSY		;FOR SPOOLER - -
	DW   LTBSY		;I DON'T KNOW WHY IT'S
	DW   LTBSY		;HERE 4 TIMES EITHER.
	ENDIF
;
;THE FOLLOWING TABLE DEFINES CP/M AS EITHER SINGLE OR
;DOUBLE DENSITY AND IS CHANGED ON THE FLY WHEN A DISK
;IS SELECTED. THE ORDER OF THIS TABLE MUST BE AS SHOWN.
;
SDTAB:	DB  00H,4EH,26,63,3,7,242	;SINGLE DENSITY TABLE

	IF  DUBSID
	DB  02H,4EH,26,63,4,15,242	;SINGLE DEN. DOUB SIDED.
	ENDIF

	DB  01H,0CH,51,95,4,15,237	;SINGLE SIDED, DOUB DEN.

	IF  DUBSID
	DB  03H,0CH,51,95,5,31,237	;DOUB SIDED, DOUB DEN.
	ENDIF
;
; BOOT
; THIS SECTION IS EXECUTED WHENEVER RESET AND RUN
; IS PUSHED, AFTER THE COLDSTART LOADER READS IN
; THE CPM SYSTEM.
;
BOOT:	LXI  SP,80H	;SET STACK POINTER.

	IF  INTRP	;IF INTERRUPTS ALLOWED,
	EI		;ENABLE THEM HERE.
	ENDIF

	IF   TIMER AND TARBELL	;IF USING TARBELL CPU
	MVI  A,CNTR0+RLWORD+MODE2+BINARY	;INIT 8253
	OUT  TCMND		;SEND IT TO COMMAND PORT
	LXI  B,33333		;TIME CONSTANT FOR 60 HZ
	MOV  A,C
	OUT  TCH0		;LS BYTE OF COUNT
	MOV  A,B
	OUT  TCH0		;MS BYTE OF COUNT
	ENDIF

	IF   STD	;IF STANDARD I/O,
	NOP!NOP!NOP!NOP	;LEAVE SPACE FOR INIT.
	NOP!NOP!NOP!NOP
	NOP!NOP!NOP!NOP
	NOP!NOP!NOP!NOP
	ENDIF

	IF   MSIO2	;IF MITS 2SIO,
	MVI  A,3	;INITIALIZE 2SIO.
	OUT  CCOM
	OUT  LCOM
	MVI  A,11H
	OUT  CCOM
	OUT  LCOM
	ENDIF

	IF   TARDEL OR ISIO2
	LXI  H,IOINIT		;point to 8251 init. bytes
	MVI  B,4		;there are 4 of them
INITI0:	MOV  A,M		;get a byte
	OUT  CCOM		;out to command port of console
	OUT  LCOM		;out to command port of lister
	INX  H			;bump pointer
	DCR  B			;decrease count
	JNZ  INITI0		;loop till done.
	ENDIF

	IF   TUART	;IF CROMEMCO TUART,
	MVI  A,1	;SET A = 1.
	OUT  54H	;SELECT DEVICE A.
	OUT  52H	;RESET DEVICE B.
	LXI  H,BAUDRS	;GET ADR OF BAUD RATE TABLE.
	MVI  A,11H	;OCTUPLE THE CLOCK.
IT1:	OUT  02H	;& RESET CURRENT DEV.
	MOV  A,M	;GET BAUD RATE FROM TABLE.
	INX  H		;INCREMENT POINTER.
	OUT  0		;SET BAUD RATE.
	CALL CONIN	;READ KEYBOARD.
	CALL CONIN	;READ KEYBOARD AGAIN.
	CPI  0DH	;IF NOT CARRIAGE-RETURN,
	MVI  A,1	;SLOW THE CLOCK.
	JNZ  IT1	;UNTIL A CARRIAGE-RETURN.
	ENDIF

	IF   SOLOS	;IF PROC TECH SOLOS,
	CALL CLRSCR	;CLEAR SCREEN.
	ENDIF

	XRA  A		;CLEAR SCRATCH AREA.
	IF   VDM	;IF PROC TECH VDM,
	OUT  0C8H	;CLEAR SCROLL PORT
	ENDIF
	STA  LATCH	;LATCH = 0
	STA  IOBYTE	;CLEAR I/O BYTE.
	MVI  C,ENDZ-STARTZ    ;GET LENGTH OF ZERO AREA.
	LXI  H,STARTZ	;GET SCRATCH ADDRESS.
BOOTL:	MOV  M,A	;PUT ZERO IN MEMORY.
	INX  H		;INCREMENT POINTER.
	DCR  C		;DECREMENT COUNTER.
	JNZ  BOOTL	;LOOP TILL DONE.

	IF   VIDEO	;IF ANY VIDEO BOARD,
	CALL CLEAR	;CLEAR SCREEN.
	ENDIF

	IN   CDATA	;CLEAR CONSOLE STATUS.
	LXI  H,SMSG	;PRINT OPENING MESSAGE.
	CALL PMSG
	CALL CONIN	;READ # OF DISKS.
	MOV  C,A	;ECHO THE CHAR.
	CALL CONOT
	ANI  7		;LOOK AT 3 LSB'S.
	STA  NODSKS	;SAVE IT.
	MVI  C,0	;SELECT DRIVE 0
GOCPM:	CALL SETUP	;SET UP JUMPS.
	LDA  DISKNO	;GET DISK NUMBER TO
	MOV  C,A	;PASS TO CCP IN C.
	CALL SELDEN	;CHECK THE DENSITY OF DISK.
	JMP  CPMB	;JUMP TO CCP.

	IF   TARDEL OR ISIO2
IOINIT:	DB   0AAH,040H,0CEH,037H
	ENDIF

	IF   TUART	;IF CROMEMCO TUART,
BAUDRS:	DB   94H,0CEH,0A2H,92H,88H,84H,82H,1
	ENDIF
;
;DISK SET UP ROUTINE. THIS ROUTINE IS COMMON TO BOTH THE
;READ AND WRITE ROUTINES FOR DMA OPERATION.
;
	IF DMACNTL		;IF USING DMA CONTROL
;
DMARW:	STA  ERCNT		;SAVE ERROR COUNT.
RWDMA:	LDA  SECT		;GET SECTOR TO READ/WRITE
	OUT  SECTP		;AND SEND IT FLOPPY CHIP.
	LHLD DMAADD		;GET CPM DMA ADDRESS.
DMARWE:	XRA  A			;CLEAR ACCUM.
	OUT  CMND		;RESET DMA CHIP.
	MOV  A,C		;FORCE INTERRUPT COMMAND BYTE
	OUT  DCOM		;SEND IT TO CONTROLLER.
	MOV  A,E		;BYTE COUNT TO TRANSFER
	DCR  A			;COUNT = COUNT - 1.
	OUT  WCT0		;SEND IT TO DMA CHIP.
	MOV  A,D		;GET READ/WRITE CODE.
	OUT  WCT0		;AND TELL DMA CHIP WHAT TO DO.
	MOV  A,L		;GET LOW ADDRESS BYTE
	OUT  ADR0		;AND SEND IT TO DMA CHIP.
	MOV  A,H		;GET HIGH ADDRESS BYTE
	OUT  ADR0		;AND SEND IT TO DMA CHIP.
	MVI  A,41H		;SET UP FOR REQUEST CH. 0
	OUT  CMND		;SEND IT TO CONTROLLER.
	CALL HDLD		;CHECK HEAD LOAD BIT.
	ORA  B			;'OR' IN THE READ/WRITE BITS.
	OUT  DCOM		;TELL FLOPPY CHIP WHAT TO DO.
;
;ADJUST H,L FOR 128 BYTE INCREASE.
;
	PUSH D			;SAVE D,E
	MOV  A,D		;GET DMA COMMAND BYTE
	ANI  3FH		;STRIP OFF COMMAND BITS 7 & 6
	MOV  D,A		;NOW SET FOR H,L ADJUST.
	DAD  D			;ADD IT TO H,L.
	POP  D			;RESTORE D,E
;
;GENERAL PURPOSE WAIT ROUTINE.
;
	MVI  A,60H		;COUNT VALUE.
CNTLOOP:DCR  A
	JNZ  CNTLOOP		;LOOP TILL = ZERO.
SLOOP:	IN   DMACHK		;CHECK FOR OPERATION DONE.
	RLC			;BY LOOKING AT BIT 7.
	JC   SLOOP		;LOOP TILL BIT 7 = 0.
	IN   DSTAT		;CHECK AND RETURN DISK STATUS.
	RET			;RETURN TO CALLER.
	ENDIF
;
; SET UP JUMPS INTO CP/M IN LOWER MEMORY.
;
SETUP:	MVI  A,0C3H	;PUT JMP TO WBOOT
	STA  0		;ADR AT ZERO.
	LXI  H,WBOOTE
	SHLD 1
	STA  5
	LXI  H,BDOS	;PUT JUMP TO BDOS
	SHLD 6		;AT ADR 5,6,7.
	LXI  H,80H	;SET DEFAULT DMA ADR.
	SHLD DMAADD
	RET		;RETURN FROM SETUP.
;
; WARM-BOOT:  READ ALL OF CPM BACK IN
; EXCEPT BIOS, THEN JUMP TO CCP.
;
WBOOT:	LXI  SP,80H	;SET STACK POINTER.

	IF  INTRP	;IF INTERRUPTS ALLOWED,
	EI		;ALLOW THEM HERE.
	ENDIF

	IF   LSTPAG	;IF LIST DEVICE PAGING,
	XRA  A		;RESET LINE-FEED COUNT.
	STA  LFCNT
	ENDIF

	LDA  DISKNO	;SAVE DISK NUMBER.
	PUSH PSW	;SAVE ON STACK
	MVI  C,0	;SELECT DRIVE A
	CALL SELDSK	;SELECT DRIVE A
	CALL HOME	;HOME THE DRIVE
	LXI  H,0	;CLEAR H,L
	SHLD DRVFLG	;CLEAR DRIVE FLAGS
	SHLD DRVFLG+2
	MVI  B,NSECTS	;GET # SECTORS FOR CPM READ.
	MVI  C,2	;SECTOR TO START AT  (C)=2.

	IF  INTRP	;IF INTERRUPTS ALLOWED,
	DI		;DISABLE THEM HERE.
	ENDIF

	LXI  H,CPMB	;GET STARTING ADDRESS.
RBLK1:	SHLD DMAADD	;SET STARTING ADDRESS.
	CALL SETSEC	;READ STARTING AT SECTOR IN C.
	PUSH B
	CALL READ
	POP  B
	JNZ  RDERR	;IF ERROR, PRINT MESSAGE.
	INR  C		;INCREMENT SECTOR NUMBER.
	DCR  B		;DECREMENT SECTOR COUNT.
	JNZ  RBLK1	;ALL DONE WHEN D=0.
ALDON:	POP  PSW	;RESTORE DISK NUMBER.

	IF  INTRP	;IF INTERRUPTS ALLOWED,
	EI		;ALLOW THEM AGAIN HERE.
	ENDIF

	STA  DISKNO
	JMP  GOCPM	;GO BACK TO CPM.
;
RDERR:	LXI  H,BTMSG	;GET ADDRESS OF "BOOT ERROR".
	CALL PMSG	;PRINT IT.
	CALL CONIN	;READ A CHAR FROM CONSOLE.
	JMP  WBOOT	;DO A WARM BOOT.
;
; CHECK CONSOLE INPUT STATUS.
;
CONST:	IN   CSTAT	;READ CONSOLE STATUS.
	ANI  CKBR	;LOOK AT KB READY BIT.
	MVI  A,0	;SET A=0 FOR RETURN.

	IF   RDYLO	;IF STATUS READY LOW,
	RNZ		;NOT READY WHEN NOT 0.
	ENDIF

	IF   RDYHI	;IF STATUS READY HIGH,
	RZ		;NOT READY WHEN ZERO.
	ENDIF

	CMA		;IF READY A=FF.
	RET		;RETURN FROM CONST.
;
; READ A CHARACTER FROM CONSOLE.
;
CONIN:
	IF NOT SOLOS	;IF NOT PROC TECH SOLOS,
	IN   CSTAT	;READ CONSOLE STATUS.
	ANI  CKBR	;IF NOT READY,
	ENDIF

	IF   SOLOS	;IF PROC TECH SOLOS,
	CALL KBD	;READ SOL KEYBOARD.
	JZ   CONIN	;READY WHEN NOT ZERO.
	ENDIF

	IF RDYLO AND NOT SOLOS
	JNZ  CONIN	;LOOP UNTIL LOW.
	ENDIF

	IF   RDYHI	;IF READY WHEN HIGH,
	JZ   CONIN	;LOOP UNTIL HIGH.
	ENDIF

	IF NOT SOLOS	;IF NOT PROC TECH SOLOS,
	IN   CDATA	;READ A CHARACTER.
	ENDIF

	ANI  7FH	;MAKE MOST SIG. BIT = 0.

	IF BACKSP	;IF BACKSPACE ACTIVATED,
	CPI  7FH	;IS IT A RUBOUT?
	RNZ		;RETURN IF NOT.
	MVI  A,0FFH	;SET NO PRINT FLAG.
	STA  CONOTF
	MVI  A,7FH	;RESTORE RUBOUT.
	ENDIF

	RET		;RETURN FROM CONIN.
;
; WRITE A CHARACTER TO THE CONSOLE DEVICE.
;
CONOT:
	IF   BACKSP	;IF BACKSPACE ACTIVATED,
	MOV  A,C	;GET CHARACTER.
	CPI  7FH	;IS IT A RUBOUT?
	RZ		;IF SO, DON'T PRINT IT.
	LDA  CONOTF	;GET NO PRINT FLAG.
	ORA  A		;SET CPU FLAGS.
	JZ   CONOTA	;NOT SET, SO PRINT.
	XRA  A		;RESET THE FLAG
	STA  CONOTF	;TO ZERO.
	MVI  C,8	;PRINT BACKSPACE.
	CALL CONOTA
	MVI  C,20H	;PRINT SPACE.
	CALL CONOTA
	MVI  C,8	;ANOTHER BACKSPACE.
CONOTA:
	ENDIF

	IF CONUL AND NOT VIDEO  ;IF NULLS REQUIRED,
	MVI  A,0DH	;IF IT'S A CR,
	CMP  C		;THEN HOP OUT
	JZ   CONULL	;TO NULL ROUTINE.
	ENDIF
CONOT1:
	IF NOT VIDEO AND NOT SOLOS
	IN   CSTAT	;READ CONSOLE STATUS.
	ANI  CPTR	;IF NOT READY,
	ENDIF

	IF RDYLO AND NOT VIDEO AND NOT SOLOS
	JNZ  CONOT1	;LOOP UNTIL LOW.
	ENDIF

	IF RDYHI AND NOT VIDEO  ;IF READY WHEN HIGH,
	JZ   CONOT1	;LOOP UNTIL HIGH.
	ENDIF

	IF NOT VIDEO AND NOT SOLOS
	MOV  A,C	;GET CHARACTER.
	OUT  CDATA	;PRINT IT.
	RET		;RETURN.
	ENDIF

	IF CONUL AND NOT VIDEO
CONULL:	PUSH B		;SAVE B&C.
	MVI  B,CNULL+1	;GET NULL COUNT.
CONUL1:	CALL CONOT1	;PRINT CR.
	MVI  C,0	;GET NULL CHAR.
	DCR  B		;DECREMENT COUNTER.
	JNZ  CONUL1	;DO NEXT NULL.
	POP  B		;RESTORE B&C.
	MOV  A,C	;RESTORE A.
	RET		;RETURN.
	ENDIF

	IF   SOLOS	;IF PROC TECH SOLOS,
	PUSH B		;SAVE B&C.
	MOV  B,C	;PUT CHAR IN B REG.
	CALL SCRN	;OUTPUT CHAR TO SOLOS.
	POP  B		;RESTORE B&C.
	MOV  A,C	;PUT CHAR IN A.
	RET		;RETURN FROM CONOT.
	ENDIF

	IF   VIDEO	;IF ANY VIDEO BOARD,
;
;	VIDEO DRIVER FOR
;	VB1-B OR VDM 1 BOARD.
;	WRITTEN BY G.W.MULCHIN
;	9-16-78
;
	MOV A,C		;GET THE CHAR INTO REG A
	PUSH H		;SAVE REGISTERS
	PUSH D
	PUSH B
	PUSH PSW	;CHAR. IS IN REG A
	CALL VIDPRO	;DO VIDEO ROUTINE
	POP PSW		;RESTORE REGISTERS
	POP B
	POP D
	POP H
	RET		;BACK TO CALLER
;
VIDPRO:	LHLD VDMP	;GET SCREEN POSITION POINTER
	CPI CR		;IS IT CARRIAGE RETURN?
	JZ CARRET
	CPI LF		;IS IT LINEFEED?
	JZ LFNOT	;PUT IN A BLANK
	CPI BKSP	;IS IT A RUBOUT?
	JZ BS
	CPI  FF		;IS IT CNTL-L?
	JZ CLEAR
	MOV M,A		;IT HAS TO BE DATA
UPDATE:	INX H		;UPDATE POSITION
GONE:	MVI M,0A0H	;PUT CURSOR ON SCREEN
	JMP MAXLIN	;CHECK FOR LINE > 64
LFNOT:	MVI M,' '	;PUT IN A SPACE
	JMP UPDATE	;GET OUT NOW
BS:	MVI M,' '
	LHLD VDMP	;GET CURRENT POSITION
	DCX H
	SHLD VDMP	;SAVE CURSOR POSITION
	JMP GONE
CARRET:	MVI M,' '	;CHAR. IS A CARRIAGE RET.
	MOV A,L		;UPDATE NEXT POSITION
	ANI 0C0H
	ADI 40H		;SET UP FOR NEW LINE
	MOV L,A		;ADDRESS OF NEW LINE
	MVI A,0
	ADC H
	MOV H,A
MAXLIN:	SHLD VDMP	;SAVE POINTER FOR NEXT CHAR.
	MVI A,7FH
	ANA L
	RNZ		;EXIT BACK TO MAIN PROGRAM
	MVI M,' '
	LXI H,SCRNTOP
	SHLD VDMP
	LXI H,LINES15	;15 LINES OF SCREEN DATA
	LXI D,SCREEN	;TOP OF SCREEN. SET UP
	LXI B,SCRLCNT	; TO SCROLL 15 LINES
SCROLL:	MOV A,M		;START SCROLLLING UP
	STAX D		;STUFF REG A BY WAY OF D,E
	INX H
	INX D
	DCX B
	XRA A
	CMP B		;15 LINES YET?
	JNZ SCROLL
	CMP C
	JNZ SCROLL	;NOT DONE YET!
	LXI H,SCRNTOP
BLANK:	MVI M,' '	;PUT BLANK ON SCREEN
	INX H		;BLANK ENTIRE DATA LINE
	MOV A,L
	ANI 3FH
	JNZ BLANK
	LXI H,SCRNTOP
	MVI M,0A0H	;STUFF CURSOR BACK
	RET		;ALL DONE.
CLEAR:	LXI H,SCREEN	;CLEAR SCREEN
	MVI A,ENDSCR	;THIS IS END CHECK
CLERA:	CMP H		;IS IT END YET?
	JZ FINISH
	MVI M,' '	;PUT SPACE ON SCREEN
	INX H		;BUMP POINTER
	JMP CLERA	;GO BACK IF NOT DONE
FINISH:	LXI H,SCRNTOP
	MVI M,0A0H	;STUFF CURSOR BACK AGAIN
	SHLD VDMP	;SAVE CURSOR POSITION.
	RET		;ALL DONE.
	ENDIF		;END OF VDM DRIVER.
;
; SELECT DISK NUMBER ACCORDING TO REGISTER C.
; ALSO CHECK IF DISK HAS BEEN LOGGED IN BEFORE.
; IF NOT, LOG IT IN AND CHECK DENSITY
;
SELDSK:	MOV  A,C	;GET NEW DISK NUMBER.
	ANI  3		;ONLY LOOK AT 2 LSB'S.
	LXI  H,DISKNO	;GET ADR OF OLD DISK NO.
	CMP  M		;NEW = OLD?
	RZ		;IF SO, RETURN.
	PUSH A		;SAVE DISK NUMBER.
	LDA  NODSKS	;GET NUMBER OF DISKS.
	DCR  A		;IF MORE THAN ONE DISK,
	JNZ  SELMOR	;TAKE CARE OF IT.
	LXI  H,MNTMSG	;GET ADR OF MOUNT MESSAGE.
	CALL PMSG	;PRINT "MOUNT ".
	POP  A		;GET DISK NUMBER.
	STA  DISKNO	;UPDATE OLD WITH NEW.
	ADI  'A'	;ADD ASCII FOR 'A'.
	MOV  C,A	;PUT INTO C.
	CALL CONOT	;PRINT IT.
	CALL CONIN	;READ A CARRIAGE RETURN.
	XRA  A		;SET A=0 FOR NO ERRO IND.
	RET		;RETURN FROM SELDSK.
SELMOR:	POP  A		;MAKE STACK RIGHT.
	MOV  A,M	;GET OLD DISK NUMBER.
	IF   DUAL	;IF DUAL DRIVE,
	ANI  0FEH	;CLEAR OUT BIT 0.
	ENDIF

	MOV  E,A	;PUT OLD DISK NO. IN D&E.
	MVI  D,0
	LXI  H,TRTAB	;GET ADDRESS OF TRACK TABLE.
	PUSH H		;SAVE FOR LATER
	DAD  D		;ADD DISK NO. TO ADDRESS.
	IN   TRACK	;READ 1771 TRACK REGISTER.
	MOV  M,A	;PUT INTO TABLE.
	MOV  A,C	;GET NEW DISK NUMBER.

	IF   DUAL	;IF A DUAL DRIVE,
	ANI  0FEH	;CLEAR BIT 0.
	ENDIF

	MOV  E,A	;PUT NEW DISK NO. IN D&E.
	POP  H		;RESTORE ADDRESS OF TRACK TABLE
	DAD  D		;ADD DISK NO. TO ADDRESS.
	MOV  A,M	;GET NEW TRACK NUMBER.
	OUT  TRACK	;PUT INTO 1771 TRACK REG.
	MOV  A,C	;UPDATE OLD DISK NUMBER.
SELDEN:	STA  DISKNO
	ADD  A		;PUT BITS 1&2 AT 4&5.
	ADD  A
	ADD  A
	ADD  A
	STA  LATCH	;SAVE NEW LATCH CODE.
;
;SELECT DENSITY BASED ON BYTE VALUE
;IN TRACK 0 SECTOR 1 ADDRESS 7EH.
;IF THIS BYTE IS A 0DDH, THEN THE
;DISK IS DOUBLE DENSITY, ELSE, IT'S
;SINGLE DENSITY.
;
DENSITY:PUSH B		;SAVE B,C
	LXI H,DRVFLG	;INDEX INTO DRIVE BYTE FLAG
	MVI B,0		;ZERO REG B
	DAD B		;ADD THE DRIVE NUMBER
	MOV A,M		;GET THE BYTE FLAG
	ORA A		;SET THE FLAGS
	JM LOGED	;SKIP IF LOGGED IN BEFORE
	PUSH H		;SAVE DRIVE TABLE POINTER.
	LDA  LATCH
	OUT  DCONT	;SELECT DRIVE
	LHLD DMAADD	;GET PRESENT DMA ADDRESS
	PUSH H		;SAVE ON STACK
	CALL HOME	;HOME DRIVE
	MVI A,1		;SET FOR SECTOR 1
	STA  SECT	;SAVE SECTOR TO READ
	LXI H,DBUFF	;POINT TO DMA BUFFER
	SHLD DMAADD	;SET UP THE DMA ADDRESS
	CALL READ	;READ TRK 0, SEC 1 INTO DBUFF
	POP  H		;RECOVER DMAADD FROM STACK
	SHLD DMAADD	;RESTORE IT
	POP  H		;RESTORE DRIVE TABLE POINTER.
	LDA DBUFF+7EH	;GET THE DENSITY CODE BYTE
	ORI  80H	;set logged in bit
	MOV  M,A	;place it in flag table.
LOGED:	LXI  B,7	;index value through drive table.
	ANI  12H	;MASK DENSITY AND SIDE BITS OUT.
	ORA  A		;SINGLE DENSITY?
	LXI  H,SDTAB	;point to start of tables
	JZ   DENSIT1	;yes, overlay param. block
;
	IF   DUBSID
	DAD  B		;no, add offset to next table
	CPI  2		;single den doub sided?
	JZ   DENSIT1	;yes
	DAD  B		;no
	CPI  10H	;doub den single sided?
	JZ   DENSIT1	;yes
	ENDIF
;
	DAD  B		;no, must be doub den , doub sided
DENSIT1:XCHG		;drive table pointer --> d,e
	LDAX D		;GET LOG BYTE
	INX  D		;BUMP POINTER
	STA  DENS	;SET DENSITY
	LDAX D		;GET A BYTE FROM TABLE
	INX  D		;BUMP POINTER
	STA BDOS+15	;CHANGE TRANS FUNCTION
	LXI H,BDOS+52	;POINT TO CONSTANT DATA AREA (CP/M)
	MVI B,5		;COUNT = 5
MOVE:	LDAX D		;GET A BYTE FROM TABLE
	MOV M,A		;OVERLAY CP/M
	INX D		;BUMP
	INX H		; POINTERS
	DCR B		;DECREASE COUNT
	JNZ MOVE	; AND LOOP TILL DONE
	POP  B		;RESTORE B,C
	XRA  A		;SET A = 0.
	RET		;RETURN FROM SELDSK.
;
; MOVE DISK TO TRACK ZERO.
;
HOME:	MVI  A,0+STPRAT	;RESTORE
	OUT  DCOM
	MVI  C,0	;TRACK 0
;
; SET TRACK NUMBER TO WHATEVER IS IN REGISTER C.
; ALSO PERFORM MOVE TO THE CORRECT TRACK (SEEK).
;
SETTRK:	LHLD LATCH		;get new and old latch.
	MOV  A,H		;get latch value.
	ANI  0B7H		;strip density and side bits.
	MOV  H,A		;restore it.
;
	IF   DUBSID		;if using double sided drive.
	LDA  DENS		;check if double sided.
	RRC
	RRC			;look at bit 1.
	JNC  NOTSID		;if bit 1 = 0, it's single sided.
	MOV  A,C		;it's doub sided, so get track number.
	RRC			;divide by 2.
	MOV  B,A		;save it in reg b.
	MOV  A,L		;get old latch value.
	JC   SIDE2		;change side if odd track.
	ANI  0BFH		;clear side bit from latch.
	JMP  SETLAT		;go set the latch.
;
SIDE2:	ORI  40H		;turn on side select bit.
SETLAT:	STA  CLATCH		;save it for later.
	ANI  0BFH		;clear side bit.
	CALL OLDLAT		;check for drive change.
	MOV  A,B		;restore doub sided trk number.
	ANI  7FH		;clear bit 7.
	MOV  C,A		;trk number now in reg c.
	JMP  TRKSET		;check for density of track going to.
	ENDIF
;
	IF   NOT DUBSID		;if not using double sided drive
	JMP  NOTSID		;jump around subroutine.
	ENDIF
;
OLDLAT:	CMP  H			;new = old?
	MVI  A,0FFH		;if not, set = ff
	JNZ  SFLAG
	CMA			;new = old, set = 0.
SFLAG:	STA  HLSF		;save head load select flag.
	RET
;
NOTSID:	MOV  A,L		;get latch value.
	STA  CLATCH		;save it
	CALL OLDLAT		;check for drive change.
;
TRKSET:	LDA  DENS	;CHECK DRIVE DENSITY FLAG
	RRC		;IS IT ZERO ?
	JNC  TRKSD	;YES, WE ARE SINGLE DENSITY
	MOV  A,C	;RESTORE TRACK NUMBER
	CPI  1		;IS IT TRACK 1 ?
	JC   TRKSD	;IF LESS THEN, SET SINGLE DEN.
	LDA  CLATCH	;GET THE CURRENT LATCH VALUE
	ORI  DDEN	;SET BIT 4 ON (DOUB DENSITY ON)
	JMP  TRKDD
TRKSD:	LDA  CLATCH	;GET CURRENT LATCH VALUE
	ANI  DDDSB	;TURN OFF BIT 4 (SINGLE DENSITY ON)
TRKDD:	STA  CLATCH	;SAVE NEW CURRENT LATCH VALUE
	OUT  DCONT	;  AND SET THE HARDWARE LATCH
	MOV  A,C	;RESTORE TRACK NUMBER
	STA  TRK	;UPDATE OLD WITH NEW.
;
; MOVE THE HEAD TO THE TRACK IN REGISTER A.
;
SEEK:	PUSH B		;SAVE B&C.
	MOV  B,A	;SAVE DESTINATION TRACK.
	MVI  A,RTCNT	;GET RETRY COUNT.
SRETRY:	STA  SERCNT	;STORE IN ERROR COUNTER.
	IN   TRACK	;READ PRESENT TRACK NO.
	MOV  C,A	;SAVE IN C.
	MOV  A,C	;DELAY.
	CMP  B		;SAME AS NEW TRACK NO.?
	MOV  A,B
	JNZ  NOTHR	;JUMP IF NOT THERE.
THERE:	POP  B		;RESTORE B&C.
	RET		;RETURN FROM SEEK.
NOTHR:
;DELAY LOOP TO ALLOW TUNNEL
;ERASE TO END DURING WRITE.
;
	PUSH PSW
	MVI  A,0D0H	;COUNT = 208
BUSY1:	DCR  A		;LOOP
	JNZ  BUSY1	;  TILL ZERO
	POP  PSW
	MOV  A,B	;RESTORE A FROM B.
	OUT  DDATA	;TRACK TO DATA REGISTER.
	MVI  A,14H+STPRAT+HLAB  ;GET STEP RATE, DO
	OUT  DCOM	;SEEK WITH VERIFY.

	IF   NOT DMACNTL
	IN   WAIT
	IN   DSTAT	;CHECK STATUS
	ENDIF

	IF   DMACNTL
BUSY2:	CALL SLOOP	;USE DMA CHECK PORT
	ENDIF

	ANI  91H	;LOOK AT BITS.
	JZ  THERE	;OK IF ZERO.

	IF TESTING	;IF TESTING FOR ERRORS
	PUSH H		;SAVE H&L.
	LXI  H,SECNT	;GET ADR OF SEEK ERR CTR.
	INR  M		;ONE MORE SEEK ERROR.
	POP  H		;RESTORE H&L.
	ENDIF

	LDA  SERCNT	;GET ERROR COUNT.
	DCR  A		;DECREMENT COUNT.
	JNZ  SRETRY	;RETRY SEEK.
	POP  B		;RESTORE B&C.
	LXI  H,SKMSG	;PRINT "SEEK ".
	IN   DSTAT	;READ DISK STATUS.
	ANI  91H	;LOOK AT ERROR BITS.
	MOV  D,A	;PUT IN REG D.
	JMP  ERMSG	;DO COMMON ERR MESSAGES.
;
; SET DISK SECTOR NUMBER.
;
SETSEC:  MOV  A,C	;GET SECTOR NUMBER.
         STA  SECT	;PUT AT SECT # ADDRESS.
         RET		;RETURN FROM SETSEC.
;
; SET DISK DMA ADDRESS.
;
SETDMA:  MOV  H,B	;MOVE B&C TO H&L.
         MOV  L,C
         SHLD DMAADD	;PUT AT DMA ADR ADDRESS.
         RET		;RETURN FROM SETDMA.
;
; HDLD - GET HEAD-LOAD BIT IF REQUIRED.
;
HDLD:	LDA  HLSF	;GET HEAD-LOAD FLAG.
	ORA  A		;IS A = ZERO?
	JZ   HDLD1	;HOP IF SO.
	CMA		;SET A = 0.
	STA  HLSF	;SET FLAG = 0 IF NOT.
;
; IF CHANGING TO A NEW DRIVE, PERFORM A SEEK
; TO THE SAME TRACK TO ALLOW THE HEAD TO UNLOAD.
;
	IN   TRACK	;GET PRESENT TRACK
	OUT  DDATA	; AND TELL CONTROLLER
	MVI  A,10H+STPRAT	;GET STEP COMMAND
	OUT  DCOM	;SEND IT TO FLOPPY CONTROLLER

	IF   NOT DMACNTL
	IN   WAIT	;WAIT FOR INTRQ
	ENDIF

	IF   DMACNTL
	CALL SLOOP	;USE DMA CHECK PORT
	ENDIF

HDLD1:	IN   DSTAT	;READ 1771 STATUS.
	ANI  20H	;LOOK AT HL BIT.
	MVI  A,4
	RZ
	SUB  A		;HEAD IS LOADED
	RET		;RETURN FROM HDLD.
;
	IF   NOT DMACNTL
DSKSET:	STA  ERCNT	;SAVE RETRY COOUNT
	MVI  A,0D0H	;CAUSE INTRP
	OUT  DCOM
	XTHL		;SOME
	XTHL		;DELAY
	ENDIF

	IF   INTRP
	DI
	ENDIF

	IF   NOT DMACNTL
	LHLD DMAADD	;STARTING ADDRESS
	LDA  SECT	;GET SECTOR NUMBER
	OUT  SECTP	;TELL CONTROLLER
	CALL HDLD	;CHECK FOR HEAD LOADED
	RET
	ENDIF
;
; READ THE SECTOR AT SECT, FROM THE PRESENT TRACK.
; USE STARTING ADDRESS AT DMAADD.
;
READ:	MVI  A,RTCNT	;GET RETRY COUNT.
RRETRY:
	IF   DMACNTL
	LXI  B,80D0H	;FLOPPY READ, FORCE INTRP.
	LXI  D,4080H	;DMA READ, BYTE COUNT.
	CALL DMARW	;COMMON READ/WRITE ROUTINE.
	ENDIF

	IF  INTRP	;IF INTERRUPTS ALLOWED,
	DI		;DISABLE THEM HERE.
	ENDIF

	IF   NOT DMACNTL
	MVI  B,80H	;FLOPPY READ COMMAND.
	CALL DSKSET	;SET UP DISK CONTROLLER
	ORA  B		;SET READ COMMAND
READE:	OUT  DCOM	;SEND COMMAND TO 1771.
RLOOP:	IN   WAIT	;WAIT FOR DRQ OR INTRQ.
	ORA  A		;SET FLAGS.
	JP   RDDONE	;DONE IF INTRQ.
	IN   DDATA	;READ A DATA BYTE FROM DISK.
	MOV  M,A	;PUT BYTE INTO MEMORY.
	INX  H		;INCREMENT MEMORY POINTER.
	JMP  RLOOP	;KEEP READING.
RDDONE:	IN   DSTAT	;READ DISK STATUS.
	ENDIF

	IF  INTRP	;IF INTERRUPTS ALLOWED,
	EI		;ALLOW AGAIN HERE.
	ENDIF

	ANI  9DH	;LOOK AT ERROR BITS.
	RZ		;RETURN IF NONE.
	CALL ERCHK	;CHECK FOR SEEK ERROR.

	IF  TESTING
	LXI  H,RECNT	;GET RD ERR COUNT ADDR.
	INR  M		;ONE MORE ERROR.
	MOV  A,M
	CMA
	OUT  0FFH
	ENDIF

	LDA  ERCNT	;GET ERROR COUNT.
	DCR  A		;DECREMENT COUNT.
	JNZ  RRETRY	;TRY TO READ AGAIN.
	LXI  H,RDMSG	;PRINT "READ ".
ERMSG:	CALL PMSG	;PRINT ORIGIN MESSAGE.
ERMSG1:
	IF NOT VIDEO	;NEED MORE ROOM?
	MOV  A,D	;GET ERROR BITS.
	ANI  10H	;IF BIT 4 IS HIGH,
	LXI  H,RNMSG	;PRINT "RECORD NOT FOUND"
	CNZ PMSG
	MOV  A,D	;GET ERROR BITS.
	ANI  8H		;IF BIT 3 IS HIGH,
	LXI  H,CRCMSG	;PRINT "CRC ERROR".
	CNZ PMSG
	ENDIF

	LXI  H,ERRMSG	;PRINT "ERROR."
	CALL PMSG
	MVI  A,1	;SET FOR PERM ERR MSG.
	ORA  A		;SET FLAGS.
	RET
;
; ERCHK - CHECK FOR RECORD NOT FOUND ERROR.
;
ERCHK:	MOV  D,A	;SAVE ERROR BITS IN D.
	ANI  10H	;IF RECORD NOT FOUND,
	RZ
;
;CHECK FOR SEEK TO CORRECT TRACK,
;AND CHANGE IF NECESSARY.
;
CHKSK:	MVI  A,0C4H	;SEND COMMAND TO 1771
	OUT  DCOM	;TO READ ADDRESS.

	IF   NOT DMACNTL
	IN   WAIT	;WAIT FOR DRQ OR INTRQ.
	ENDIF

	IF   DMACNTL
	CALL SLOOP
	ENDIF

	IN   DDATA	;READ THE TRACK ADDRESS.
	MOV  B,A	;SAVE IN REGISTER B.
CHKS2:	IN   WAIT	;WAIT FOR INTRQ.
	ORA  A		;SET FLAGS.
	JP   CHKS3	;DONE WITH READ ADR OP.
	IN   DDATA	;READ ANOTHER BYTE.
	JMP  CHKS2	;DO IT AGAIN.
CHKS3:	IN   DSTAT	;READ DISK STATUS.
	ORA  A		;SET FLAGS.
	JZ   CHKS4	;READ ADR OK IF 0.
	CALL HOME	;OTHERWISE, HOME FIRST.
CHKS5:	LDA  TRK
	JMP  SEEK
CHKS4:	MOV  A,B	;UPDATE TRACK REGISTER.
	OUT  TRACK
	JMP  CHKS5	;RETURN FROM ERCHK.
;
; WRITE THE SECTOR AT SECT, ON THE PRESENT TRACK.
; USE STARTING ADDRESS AT DMAADD.
;
WRITE:	MVI  A,RTCNT	;GET RETRY COUNT.
WRETRY:
	IF   DMACNTL
	LXI  B,0A0D0H	;FLOPPY WRITE, FORCE INTRP
	LXI  D,08080H	;DMA WRITE, BYTE COUNT
	CALL DMARW	;COMMON ROUTINE
	ENDIF

	IF   NOT DMACNTL
	MVI  B,0A0H	;WRITE COMMAND
	CALL DSKSET
	ORA  B
WRITE2:	OUT  DCOM
WLOOP1:	IN   WAIT	;WAIT FOR READY.
	ORA  A		;SET FLAGS.
	JP   WDONE	;HOP OUT WHEN DONE.
	MOV  A,M	;GET BYTE FROM MEM.
	OUT  DDATA	;WRITE ONTO DISK.
	INX  H		;INCREMENT MEM PTR.
	JMP  WLOOP1	;KEEP WRITING.
WDONE:	IN   DSTAT
	ENDIF

	IF  INTRP	;IF INTERRUPTS ALLOWED,
	EI		;ENABLE AGAIN HERE.
	ENDIF

	ANI  0FDH	;LOOK AT THESE BITS.
	RZ		;RETURN IF NO ERR.
	CALL ERCHK	;CHECK/CORRECT SEEK ERR.

	IF  TESTING	;IF TESTING FOR ERRORS
	LXI  H,WECNT	;GET ADR OF WRITE ERR CTR.
	INR  M		;ONE MORE WRITE ERROR.
	MOV  A,M
	CMA
	OUT  0FFH
	ENDIF

	LDA  ERCNT	;GET ERROR COUNT.
	DCR  A		;DECREMENT COUNT.
	JNZ  WRETRY	;TRY TO WRITE AGAIN.
	LXI  H,WTMSG	;PRINT "WRITE ".

	IF NOT VIDEO	;NEED MORE ROOM?
	CALL PMSG
	JMP  ERMSG1	;DO COMMON MESSAGES.
	ENDIF

	IF   VIDEO	;WE NEED A RETURN.
	JMP  ERMSG
	ENDIF
;
; PRINT THE MESSAGE AT H&L UNTIL A ZERO.
;
PMSG:    MOV  A,M	;GET A CHARACTER.
         ORA  A		;IF IT'S ZERO,
         RZ		;RETURN.
         MOV  C,A	;OTHERWISE,
         CALL CONOT	;PRINT IT.
         INX  H		;INCREMENT H&L,
         JMP  PMSG	;AND GET ANOTHER.
;
; CBIOS MESSAGES
;
	IF NOT VIDEO	;NEED MORE ROOM?
RNMSG:	DB   'ID ',0
CRCMSG:	DB   'CRC ',0
	ENDIF

RDMSG:	DB   0DH,0AH,'Read ',0
WTMSG:	DB   0DH,0AH,'Write ',0
BTMSG:	DB   'Boot '
ERRMSG:	DB   'ERROR.',0
SKMSG:	DB   0DH,0AH,'Seek ',0
MNTMSG:	DB   0DH,0AH,'Mount ',0
SMSG:	DB   0DH,0AH,'Tarbell '
	DB   MSIZE/10+'0',MSIZE MOD 10 + '0'
	DB   'K CPM V1.4 of 2-04-82'
	DB   0DH,0AH

	IF  TARBELL	;IF USING TARBELL CPU.
	DB  'Tarbell CPU, '
	ENDIF

	IF  STD		;IF STANDARD I/O,
	DB   'Standard '
	ENDIF

	IF  MSIO2	;IF MITS 2SIO,
	DB   '2SIO '
	ENDIF

	IF  ISIO2	;IF IMSAI SIO-2,
	DB  'SIO-2 '
	ENDIF

	IF  TUART	;IF TUART,
	DB  'Tuart '
	ENDIF

	IF  SOLOS	;IF PROC TECH SOLOS,
	DB  'Solos '
	ENDIF

	IF   VDM	;IF PROC TECH VDM,
	DB   'VDM '
	ENDIF

	IF   FLASH	;IF VG FLASHWRITER,
	DB   'Flashwriter '
	ENDIF

	IF   VB1	;IF SSM VB1-B,
	DB   'VB1 '
	ENDIF

	IF  DUBSID	;IF DOUBLE-SIDED,
	DB   'Double-Sided '
	ENDIF

	IF  DUAL	;IF DUAL DRIVE,
	DB  'Dual '
	ENDIF

	IF  DMACNTL	;IF USING DMA CONTROL
	DB  'DMA '
	ENDIF
	DB   'VER.'

	DB   0DH,0AH,'How Many Disks? ',0
;
; WRITE A CHARACTER ON LISTING DEVICE.
;
LIST:
	IF LSTNUL  	;IF NULLS OR PAGING,
	MVI  A,0DH	;IF IT'S A CR,
	CMP  C		;THEN HOP OUT TO
	JZ   LINUL	;NULL ROUTINE.
	ENDIF

	IF LSTPAG	;IF PAGING
	MVI A,0AH	;GET A LINEFEED
	CMP C		;DOES IT MATCH?
	JZ LINUL3
	ENDIF

LTBSY:	IN   LSTAT	;READ LISTER STATUS.

	IF   NOT TARDEL
	ANI  LRBIT	;LOOK AT READY BIT.
	ENDIF

	IF   TARDEL
	ANI  81H	;MASK
	XRI  81H
	ENDIF

	IF   TARDEL OR RDYLO	;IF READY WHEN LOW,
	JNZ  LTBSY	;LOOP TILL LOW.
	ENDIF

	IF   NOT TARDEL AND RDYHI	;IF READY WHEN HIGH,
	JZ   LTBSY	;LOOP TILL HIGH.
	ENDIF

	MOV  A,C	;GET DATA BYTE.
	OUT  LDATA	;PRINT IT.
	RET		;RETURN FROM LIST.

	IF LSTNUL OR LSTPAG  ;IF NULLS OR PAGING,
LINUL:	PUSH B		;SAVE B&C.
	MVI  B,(LNULL AND 0FFH)+1 ;GET NULL COUNT
LINUL1:	CALL LTBSY	;PRINT (CR FIRST).
	MVI  C,0	;GET NULL CHAR.
	DCR  B		;DECREMENT COUNTER.
	JNZ  LINUL1	;DO NEXT NULL.
	JMP  LINUL2	;EXIT THE ROUTINE.
	ENDIF

	IF   LSTPAG	;IF LIST DEV. PAGING,
LINUL3:	PUSH B		;SAVE B,C PAIR
	LDA  LFCNT	;GET LINE-FEED COUNT.
	INR  A		;INCREMENT IT.
	STA  LFCNT	;SAVE IT BACK.
	CPI  LINCNT-(LINCNT/11)  ;END OF PAGE?
	MVI  B,1	;SET UP FOR 1 LF.
	JNZ  NOTEOP	;HOP IF NOT END.
	XRA  A		;SET LF COUNT = 0.
	STA  LFCNT
	MVI  B,(LINCNT/11)+1  ;BETWEEN PAGES.
NOTEOP:	MVI  C,0AH	;GET LINE-FEED CODE.
LSTPA1:	CALL LTBSY	;PRINT LINE-FEED.
	DCR  B		;DECREMENT LF COUNTER.
	JNZ  LSTPA1	;DO NEXT LINE FEED?
	ENDIF

	IF LSTNUL OR LSTPAG  ;IF NULLS OR PAGING,
LINUL2:	POP  B		;RESTORE B&C.
	MOV  A,C	;RESTORE A.
	RET		;RETURN FROM LIST.
	ENDIF
;
; PUNCH PAPER TAPE.
;
PUNCH:	RET		;RETURN FROM PUNCH.
;
;  NORMALLY USED TO READ PAPER TAPE.
;
READER:	RET		;RETURN FROM READER.
;
;NOTE:  AS THERE ARE ONLY NINE SECTORS
;AVAILABLE FOR CBIOS ON THE SECOND SYSTEM TRACK (1),
;THE LAST ADDRESS BEFORE THIS POINT SHOULD BE NO
;GREATER THAN THE CBIOS STARTING ADDRESS + 047F (HEX).
;THIS WILL NORMALLY BE XE7F (HEX).
;
; BIOS SCRATCH AREA.
;
TRK:	DS   1		;CURRENT TRACK NUMBER.
SECT:	DS   1		;CURRENT SECTOR NUMBER.
DMAADD:	DS   2		;DISK TRANSFER ADDRESS.
;
; THE NEXT SEVERAL BYTES, BETWEEN STARTZ AND
; ENDZ, ARE SET TO ZERO AT COLD BOOT TIME.
;
STARTZ:			;START OF ZEROED AREA.
DISKNO:	DS   1		;DISK NUMBER (TO CP/M).

	IF  TESTING
;
; ERROR COUNTS.  THESE LOCATIONS KEEP TRACK OF THE
; NUMBER OF ERRRS THAT OCCUR DURING READ, WRITE,
; OR SEEK OPERATIONS.  THEY ARE INITIALIZED ONLY
; WHEN A COLD-START IS PERFORMED BY THE BOOOTSTRAP.
;
RECNT:	DS   1		;READ ERROR COUNT.
WECNT:	DS   1		;WRITE ERROR COUNT.
SECNT:	DS   1		;SEEK ERROR COUNT.
	ENDIF
;
; SPECIAL FLAGS.
;
CONOTF:	DS   1		;NO-PRINT FLAG (WHEN FF).
HLSF:	DS   1		;HEAD-LOAD SELECT FLAG.

	IF  LSTPAG
LFCNT:	DS   1		;PAGING LINE-FEED COUNT.
	ENDIF
;
; TRTAB - DISK TRACK TABLE - PRESENT POSITION OF
;	HEADS FOR UP TO 4 DRIVES.
;
TRTAB:	DS   4
DRVFLG:	DS   4		;DRIVE FLAG BYTES FOR 4 DRIVES
DENS:	DS   1		;CURRENT DRIVE FLAG BYTE
;
; VDM SCRATCH AREA.
;
ENDZ:			;END OF ZEROED AREA.
	IF   VIDEO	;IF VIDEO BOARD IN,
VDMP:	DS   2		;VIDEO CURSOR POSITION.
	ENDIF

NODSKS:	DS   1		;NUMBER OF DISKS.
ERCNT:	DS   1		;ERROR COUNT FOR RETRIES.
SERCNT:	DS   1		;SEEK RETRY COUNTER.
LATCH:	DS   1		;NEW CODE FOR LATCH.
CLATCH:	DS   1		;CURRENT CODE IN LATCH.
DBUFF:	DS   128	;DENSITY SELECT BUFFER
         END

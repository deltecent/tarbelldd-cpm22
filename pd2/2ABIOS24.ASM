;-------------------------------------------------
; cp/m basic input/output operating system (bios)
; tarbell electronics
; 2.x version of 01-29-82
; copyright (c) 1980 tarbell electronics
;--------------------------------------------------
; this bios module is the cpm v2.x auto select bios.
; this bios reads single or double density disk.
; the double density disk contains 51 sectors/track,
; 77 tracks. track 0 = single density, tracks 1 - 76
; are double density at 51 sectors per track.
; note:  if you leave dmacntl false, you must have a cpu
; which runs at 4 mhz to run double density.
; this bios now supports double sided single/double density.
; this section defines the i/o ports and status bits.
; by setting the proper values for the equ statements,
; the i/o may be automatically reconfigured to fit most
; situations. the true and false ones control conditional
; assemblies of different sections of i/o routines to fit
; different interface requirements.
;
TRUE	EQU  0FFFFH		;define value of true.
FALSE	EQU  NOT TRUE		;define value of false.
;
;***************************************************
;*** this begins the area which requires changes ***
;***      for different console i/o systems      ***
;***************************************************
;
MSIZE	EQU  24		;memory size in kbytes.
INTRP	EQU  FALSE	;true if interrupts allowed.
TARBELL	EQU  FALSE	;true if using the tarbell z-80 cpu.
IOBASE	EQU  0		;base io addr for tarbell cpu (0 or 10 hex).
TIMER	EQU  FALSE	;true if using cpu timer (tarbell cpu board).
STD	EQU  TRUE	;true if standard i/o.
MSIO2	EQU  FALSE	;true if mits 2sio.
VDB8024	EQU  FALSE	;true if using vdb-8024 board.
DELTA	EQU  FALSE	;true if using delta products cpu.
ISIO2	EQU  FALSE	;true if imsai sio-2.
TUART	EQU  FALSE	;true if cromemco tuart.
VIDEO	EQU  FALSE	;true if using a memory mapped video board.
OTHER	EQU  FALSE	;true if something else.
SOLOS	EQU  FALSE	;true if proc tech solos.
DUBSID	EQU  FALSE	;true for double sided drives (1 logical drive).
DMACNTL	EQU  FALSE	;true if using dma control.
NDISK	EQU  4		;defines the number drives in system.
;
RDYLO	EQU  STD OR SOLOS OR OTHER  ;status ready when low.
RDYHI	EQU  NOT RDYLO
TARDEL	EQU  TARBELL OR DELTA	;if using tarbell or delta cpu.
;
	IF  VIDEO	;if using a video board
OUTADDR	EQU  00000H	;put output address here
	ENDIF
;
	IF NOT SOLOS AND NOT TARDEL	;if not proc tech solos,
CSTAT	EQU  0		;console status port.
CCOM	EQU  0		;console command port.
CDATA	EQU  1		;console data port.
LSTAT	EQU  2		;list status port.
LCOM	EQU  2		;list command port.
LDATA	EQU  3		;list data port.
	ENDIF
;
CONUL	EQU  FALSE	;console nulls?
CNULL	EQU  16		;console null count.
LSTNUL	EQU  FALSE	;list device nulls?
LNULL	EQU  0		;list null count.
LSTPAG	EQU  FALSE	;list device paging?
LINCNT	EQU  66		;lines per page.
HLAB	EQU  0		;8 for hd ld at beg of seek.
STPRAT	EQU  2		;rate 0=3ms,1=6ms, 2=10ms, 3=20ms.
DUAL	EQU  FALSE	;true if dual headed (2 heads moving together).
;
;*******************************************************
;*** this is the end of the area which normally need ***
;***     be changed for most console i/o systems     ***
;*******************************************************
;
	IF   TARDEL	;if using tarbell or delta cpu
CCOM	EQU  IOBASE+1	;console command port
CSTAT	EQU  IOBASE+1	;console status port ( chan a.)
CDATA	EQU  IOBASE+0	;console data port
LCOM	EQU  IOBASE+3	;list command port
LSTAT	EQU  IOBASE+3	;list status port (chan b.)
LDATA	EQU  IOBASE+2	;list data port
	ENDIF
;
	IF	TIMER AND TARBELL	;must be using tarbell cpu.
;
; timer equates
;
TCH0	EQU	IOBASE+4	;timer chan 0 address
TCH1	EQU	IOBASE+5	;timer chan 1 address
TCH2	EQU	IOBASE+6	;timer chan 2 address
TCMND	EQU	IOBASE+7	;timer command port
IMASK	EQU	IOBASE+8	;interrupt masking port
CNTR0	EQU	00000000B	;counter 0
CNTR1	EQU	01000000B	;counter 1
CNTR2	EQU	10000000B	;counter 2
RLWORD	EQU	00110000B	;read/load lsb 1st, msb 2nd.
RLHBYTE	EQU	00100000B	;read/load msb only.
RLLBYTE	EQU	00010000B	;read/load lsb only.
CNTRLT	EQU	00000000B	;counter latching operation.
BINARY	EQU	00000000B	;select binary operation.
BCD	EQU	00000001B	;select bcd operation.
MODE0	EQU	00000000B	;interrupt on terminal count.
MODE1	EQU	00000010B	;programmable one-shot.
MODE2	EQU	00000100B	;rate generator.
MODE3	EQU	00000110B	;square wave rate generator.
MODE4	EQU	00001000B	;software triggered strobe.
MODE5	EQU	00001010B	;hardware triggered strobe.
	ENDIF
;
	IF   SOLOS		;if proc tech solos,
CSTAT	EQU  0FAH		;console status port.
KBD	EQU  0C02EH		;solos keyboard.
CLRSCR	EQU  0C0D5H		;clear screen.
SCRN	EQU  0C054H		;solos output.
	ENDIF
;
	IF NOT SOLOS		;if not proc tech solos,
DMAP	EQU  0E0H		;dma base address.
DISK	EQU  0F8H		;disk base address.
	ENDIF
;
	IF SOLOS		;if proc tech solos,
DMAP	EQU  060H		;dma base address.
DISK	EQU  078H		;different disk ports.
	ENDIF
;
ADR0	EQU  DMAP+0		;dma address reg port.
WCT0	EQU  DMAP+1		;dma word count reg port.
CMND	EQU  DMAP+8		;dma command port.
DCOM	EQU  DISK		;disk command port.
DSTAT	EQU  DISK		;disk status port.
TRACK	EQU  DISK+1		;disk track port.
SECTP	EQU  DISK+2		;disk sector port.
DDATA	EQU  DISK+3		;disk data port.
WAIT	EQU  DISK+4		;disk wait port.
DCONT	EQU  DISK+4		;disk control port.
DMACHK	EQU  DISK+5		;dma check port.
RTCNT	EQU  10			;retry count.
;
	IF   STD		;if standard i/o,
CKBR	EQU  00000001B		;keyboard ready bit.
CPTR	EQU  10000000B		;cons output rdy bit.
	ENDIF
;
	IF   MSIO2		;if mits 2sio,
CKBR	EQU  00000001B		;keyboard ready bit.
CPTR	EQU  00000010B		;print ready bit.
	ENDIF
;
	IF   VDB8024		;if vdb-8024 board.
CKBR	EQU  00000010B		;keyboard ready bit.
CPTR	EQU  00000100B		;cons output rdy bit.
	ENDIF
;
	IF   ISIO2
CKBR	EQU  00000010B		;keyboard ready bit.
CPTR	EQU  00000001B		;print ready bit.
	ENDIF
;
	IF   TARDEL
CKBR	EQU  00000010B		;keyboard ready bit.
CPTR	EQU  00000001B		;print ready bit.
	ENDIF
;
	IF   TUART		;if cromemco tuart,
CKBR	EQU  01000000B		;keyboard ready bit.
CPTR	EQU  10000000B		;print ready bit.
	ENDIF
;
	IF   SOLOS		;if proc tech solos,
CKBR	EQU  00000001B		;keyboard ready bit.
CPTR	EQU  10000000B		;dummy equ.
	ENDIF
;
	IF   OTHER		;if something else,
CKBR	EQU  00000010B		;keyboard ready bit.
CPTR	EQU  10000000B		;printer ready bit.
	ENDIF
;
LRBIT	EQU  CPTR		;lister ready bit.
;
IOBYTE	EQU  3			;address of i/o byte.
CBASE	EQU  (MSIZE-20)*1024  	;bias for larger than 20k.
CPMB	EQU  CBASE+3400H	;start of cpm 2.0
BDOS	EQU  CPMB+806H		;start of bdos 2.0.
BIOS	EQU  CPMB+1600H		;start of cbios io.
CDISK	EQU  4			;location 4 is current disk.
NSECTS	EQU  17			;number of sectors in it.
;
	ORG  CPMB+8
;
SMSG:	DB   0DH,0AH,'Tarbell '
	DB   MSIZE/10+'0',MSIZE MOD 10+'0'
	DB   'K CPM 2.2',0DH,0AH
	DB   'Auto-Select '
	IF   DUBSID
	DB   'Double Sided '
	ENDIF
	DB   'ver of 01-29-82',0
;
; boot
; this section is executed whenever reset and run
; is pushed, after the coldstart loader reads in
; the cpm system.
;
BOOT:	LXI  SP,80H		;set stack pointer.
;
	IF INTRP AND NOT DMACNTL;if interrupts allowed,
	EI			;enable them here.
	ENDIF
;
	IF   MSIO2		;if mits 2sio,
	MVI  A,3		;initialize 2sio.
	OUT  CCOM
	OUT  LCOM
	MVI  A,11H
	OUT  CCOM
	OUT  LCOM
	ENDIF
;
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
;
	IF   TUART		;if cromemco tuart,
	MVI  A,1		;set a = 1.
	OUT  54H		;select device a.
	OUT  52H		;reset device b.
	LXI  H,BAUDRS		;get adr of baud rate table.
	MVI  A,11H		;octuple the clock.
IT1:	OUT  02H		;& reset current dev.
	MOV  A,M		;get baud rate from table.
	INX  H			;increment pointer.
	OUT  0			;set baud rate.
	CALL CONIN		;read keyboard.
	CALL CONIN		;read keyboard again.
	CPI  0DH		;if not carriage-return,
	MVI  A,1		;slow the clock.
	JNZ  IT1		;until a carriage-return.
	ENDIF
;
	IF   SOLOS		;if proc tech solos,
	CALL CLRSCR		;clear screen.
	ENDIF
;
	IF DMACNTL
	LXI  H,RWDMA		;point to dma routine
	SHLD DMAENT+1		;modify boot jmp address.
	ENDIF
;
	IF   TIMER AND TARBELL	;if using tarbell cpu
	MVI  A,CNTR0+RLWORD+MODE2+BINARY	;init 8253
	OUT  TCMND		;send it to command port
	LXI  B,33333		;time constant for 60 hz
	MOV  A,C
	OUT  TCH0		;ls byte of count
	MOV  A,B
	OUT  TCH0		;ms byte of count
	ENDIF
;
	JMP  BOOTF		;finish boot
;
	IF   TARDEL OR ISIO2
IOINIT:	DB   0AAH,040H,0CEH,037H
	ENDIF
;
	IF   TUART		;if cromemco tuart,
BAUDRS:	DB   94H,0CEH,0A2H,92H,88H,84H,82H,1
	ENDIF
;
	ORG  BIOS-64		;hide rest of boot here.
BOOTF:	XRA  A			;clear scratch area.
	STA  IOBYTE		;clear i/o byte.
	STA  CDISK		;select drive zero
	MVI  B,ENDZ-STARTZ	;get length of zero area.
	LXI  H,STARTZ		;get scratch address.
BOOTL:	MOV  M,A		;put zero in memory.
	INX  H			;increment pointer.
	DCR  B			;decrement counter.
	JNZ  BOOTL		;loop till done.
	IN   CDATA		;clear console status.
	LXI  H,SMSG		;point to sign on.
PMSG:	MOV  A,M		;get a byte of the message
	INX  H			;bump memory pointer.
	ORA  A			;is it a zero?
	JZ   GOCPM		;yes, we are done, jmp to cpm.
	MOV  C,A		;nope, print more message.
	CALL CONOT		;use the conot routine.
	JMP  PMSG		;and loop till done.
;
	ORG  BIOS		;start of cbios structure.
;
; i/o jump vector
; this is where cpm calls whenever it needs to do any input/output
; operation. user programs may use these entry points also, but note
; that the location of this vector changes with the memory size.
;
DMAENT:	JMP  BOOT		;from sboot loader,changed for dma.
WBOOTE:	JMP  WBOOT		;from warm boot.
	JMP  CONST		;check console kb status.
	JMP  CONIN		;read console character.
	JMP  CONOT		;write console character.
	JMP  LIST		;write listing char.
	JMP  PUNCH		;write punch char.
	JMP  READER		;read reader char.
	JMP  HOME		;move disk to track zero.
	JMP  SELDSK		;select disk drive.
	JMP  SETTRK		;seek to track in reg a.
	JMP  SETSEC		;set sector number.
	JMP  SETDMA		;set disk starting adr.
	JMP  READ		;read selected sector.
	JMP  WRITE		;write selected sector.
	JMP  PRSTAT		;list status check.
	JMP  SECTRAN		;sector translate routine.
;
; this section defines the the disk parameters
;
DPBASE	EQU  $			;base of disk parameter block
DPE0:	DW   XLT0,0000H		;translate table
	DW   0000H,0000H	;scratch area
	DW   DIRBUF,SDTAB+3	;dir buff, parm block
	DW   CSV0,ALV0		;check, alloc vectors
;
DPE1:	DW   XLT1,0000H
	DW   0000H,0000H
	DW   DIRBUF,DPB1
	DW   CSV1,ALV1
;
DPE2:	DW   XLT2,0000H
	DW   0000H,0000H
	DW   DIRBUF,DPB2
	DW   CSV2,ALV2
;
DPE3:	DW   XLT3,0000H
	DW   0000H,0000H
	DW   DIRBUF,DPB3
	DW   CSV3,ALV3
;
;the following describes the disk physical nature, such as
;sectors/track,directory size, etc...
;the following table defines a single density drive.
;
SDTAB:	EQU  $			;one of 4 disk parm. blocks
	DB   00H		;log byte single density
	DW   XLT0		;use single density translate tab.
	DW   26			;sectors/track
	DB   3			;block shift
	DB   7			;block mask
	DB   0			;extnt mask
	DW   242		;disk size - 1
	DW   63			;directory max.
	DB   192		;alloc0
	DB   0			;alloc1
	DW   16			;check size
	DW   2			;number of system tracks
;
	IF   DUBSID		;is using double sided drives.
;
; defines a single density/ double sided disk
;
	DB   02H		;log byte doub sided
	DW   XLT0
	DW   26
	DB   4
	DB   15
	DB   0
	DW   242
	DW   95			;allow 95 entrys for dir.
	DB   192
	DB   0
	DW   24
	DW   2
	ENDIF
;
;the following table defines a double density drive.
;
DDTAB:	DB   01H		;log byte doub den/sing sided
	DW   0			;no sector translate table.
	DW   51			;51 sectors.
	DB   4			;block shift.
	DB   15			;block mask.
	DB   0			;extent mask.
	DW   237		;disk size -1
	DW   95			;directory max.
	DB   192		;alloc0
	DB   0			;alloc1
	DW   24			;check size
	DW   2			;number of system tracks.
;
	IF   DUBSID		;if using double sided drives.
;
; defines a double density/doub sided drive
;
	DB   03H		;log byte and dub sided
	DW   0
	DW   51
	DB   5
	DB   31
	DB   0
	DW   237
	DW   95
	DB   192
	DB   0
	DW   24
	DW   2
	ENDIF
;
;sector translation table
;
XLT0	EQU  $			;start of trans. table
	DB   1,7,13,19,25
	DB   5,11,17,23,3
	DB   9,15,21,2,8
	DB   14,20,26,6,12
	DB   18,24,4,10,16,22
;
DPB1	EQU  SDTAB+3		;equivalent parameters
XLT1	EQU  XLT0		;same translate table
;
DPB2	EQU  SDTAB+3
XLT2	EQU  XLT0
;
DPB3	EQU  SDTAB+3
XLT3	EQU  XLT0
;
;disk set up routine. this routine is common to both the
;read and write routines for dma operation. this routine
;may be used stand alone by passing parameters to it and
;jumping to wboot-3 hex. this jump vector is changed when
;cp/m is booted up.
;
;entery point = rwdma:
;
;user must set up dmaadd for memory address and
;user must set up disk sector with 'setsec' entry
;the track to read or write must be set up using 'settrk'
;before using rwdma routine externally.
;
;entry parameters:
;b   = floppy disk (1793) read/write command byte
;c   = floppy disk (1793) force interrupt command byte
;d   = dma (8257) read/write command + high byte count
;e   = dma (8257) low byte count (80 hex = 128 bytes)
;
;exit values
;b,c = floppy commands
;d,e = dma command + byte count.
;h,l = (h,l + d,e)
;a   = floppy disk status byte
;
;stack usage is 1 level deep.
;
	IF DMACNTL		;if using dma control
;
DMARW:	STA  ERCNT		;save error count.
RWDMA:	LDA  SECT		;get sector to read/write
	OUT  SECTP		;and send it floppy chip.
	LHLD DMAADD		;get cpm dma address.
DMARWE:	XRA  A			;clear accum.
	OUT  CMND		;reset dma chip.
	MOV  A,C		;force interrupt command byte
	OUT  DCOM		;send it to controller.
	MOV  A,E		;byte count to transfer
	DCR  A			;count = count - 1.
	OUT  WCT0		;send it to dma chip.
	MOV  A,D		;get read/write code.
	OUT  WCT0		;and tell dma chip what to do.
	MOV  A,L		;get low address byte
	OUT  ADR0		;and send it to dma chip.
	MOV  A,H		;get high address byte
	OUT  ADR0		;and send it to dma chip.
	MVI  A,41H		;set up for request ch. 0
	OUT  CMND		;send it to controller.
	CALL HDLD		;check head load bit.
	ORA  B			;'or' in the read/write bits.
	OUT  DCOM		;tell floppy chip what to do.
;
;adjust h,l for 128 byte increase.
;
	PUSH D			;save d,e
	MOV  A,D		;get dma command byte
	ANI  3FH		;strip off command bits 7 & 6
	MOV  D,A		;now set for h,l adjust.
	DAD  D			;add it to h,l.
	POP  D			;restore d,e
;
;general purpose wait routine.
;
	MVI  A,20H		;count value.
CNTLOOP:DCR  A
	JNZ  CNTLOOP		;loop till = zero.
SLOOP:	IN   DMACHK		;check for operation done.
	RLC			;by looking at bit 7.
	JC   SLOOP		;loop till bit 7 = 0.
	IN   DSTAT		;check and return disk status.
	RET			;return to caller.
	ENDIF
;
;warm-boot - read the ccp back into memory. bdos and bios
;assumed still in memory. if they are not, a cold start will
;have to be done to bring them back into memory.
;
WBOOT:	LXI  SP,80H		;set stack pointer.
;
	IF INTRP AND NOT DMACNTL;if interrupts allowed,
	EI			;allow them here.
	ENDIF
;
	IF   LSTPAG		;if list device paging,
	XRA  A			;reset line-feed count.
	STA  LFCNT
	ENDIF
;
	MVI  C,0		;select disk 0.
	CALL SELDSK
	CALL HOME		;move to track zero.
	LXI  H,0		;clear h,l
	SHLD DRVFLG		;clear drive flags
	SHLD DRVFLG+2
	MVI  B,NSECTS		;get # sectors for cpm read.
	MVI  C,2		;track (b)=0, sector (c)=2.
;
	IF INTRP AND NOT DMACNTL;if interrupts allowed,
	DI			;disable them here.
	ENDIF
;
	LXI  H,CPMB		;get starting address.
RBLK1:	SHLD DMAADD		;set starting address.
	CALL SETSEC		;read starting at sector in c.
	PUSH B
	CALL READ		;read a sector back.
	POP  B
	JNZ  RDERR		;if error, print message.
	INR  C			;increment sector number.
	DCR  B			;decrement sector count.
	JNZ  RBLK1		;not zero, keep reading
;
	IF INTRP AND NOT DMACNTL;if interrupts allowed,
	EI			;allow them again here.
	ENDIF
;
; set up jumps into cp/m in lower memory.
;
GOCPM:	MVI  A,0C3H		;put jmp to wboot
	STA  0			;adr at zero.
	LXI  H,WBOOTE		;warmboot entry point
	SHLD 1			;set it.
	STA  5			;set jump instruction.
	LXI  H,BDOS		;put jump to bdos
	SHLD 6			;at adr 5,6,7.
	LXI  H,80H		;set default dma adr.
	SHLD DMAADD		;save it.
	LDA  CDISK		;get disk number to
	MOV  C,A		;pass to ccp in c.
	JMP  CPMB		;jump to ccp.
;
RDERR:	CALL RECOV		;we have an error in booting.
	JMP  WBOOT		;do a warm boot.
;
; check console input status.
;
CONST:	CALL STATCON		;check console status port.
CONST1:	MVI  A,0		;set a=0 for return.
;
	IF   RDYLO		;if status ready low,
	RNZ			;not ready when not 0.
	ENDIF
;
	IF   RDYHI		;if status ready high,
	RZ			;not ready when zero.
	ENDIF
;
	CMA			;if ready a=ff.
	RET			;return from const.
;
; statcon - check keyboard status
;
	IF   NOT SOLOS
STATCON:IN   CSTAT		;in status port
	ANI  CKBR		;mask ready bit.
	RET
	ENDIF
;
; read a character from console.
;
CONIN:
	IF   NOT SOLOS		;if not proc tech solos,
	CALL STATCON		;read console status.
	ENDIF
;
	IF   SOLOS		;if proc tech solos,
	CALL KBD		;read sol keyboard.
	JZ   CONIN		;ready when not zero.
	ENDIF
;
	IF   RDYLO AND NOT SOLOS
	JNZ  CONIN		;loop until low.
	ENDIF
;
	IF   RDYHI		;if ready when high,
	JZ   CONIN		;loop until high.
	ENDIF
;
	IF   NOT SOLOS		;if not proc tech solos,
	IN   CDATA		;read a character.
	ENDIF
;
	ANI  7FH		;make most sig. bit = 0.
	RET			;return from conin.
;
; write a character to the console device.
;
CONOT:
	IF CONUL		;if nulls required,
	MVI  A,0AH		;if it's a lf,
	CMP  C			;then hop out
	JZ   CONULL		;to null routine.
	ENDIF
CONOT1:
	IF NOT SOLOS AND NOT VIDEO
	IN   CSTAT		;read console status.
	ANI  CPTR		;if not ready,
	ENDIF
;
	IF RDYLO AND NOT SOLOS AND NOT VIDEO
	JNZ  CONOT1		;loop until low.
	ENDIF
;
	IF RDYHI AND NOT VIDEO	;if ready when high,
	JZ   CONOT1		;loop until high.
	ENDIF
;
	IF NOT SOLOS AND NOT VIDEO
	MOV  A,C		;get character.
	OUT  CDATA		;print it.
	RET			;return.
	ENDIF
;
;this routine calles your video driver routine which must
;be in rom. all registers must be saved and restored by your
;video driver in order to be compatiable with cpm. cpm passes
;the char. to be output in the  c register. make any changes
;in this routine to pass the char from reg c to the register
;your video driver expects it to be in.
;
	IF  VIDEO		;if using a video driver in rom.
	MOV  A,C		;get the cpm char into reg a
	CALL OUTADDR		;call your video driver.
	RET			;return to cpm.
	ENDIF
;
	IF CONUL
CONULL:	PUSH B			;save b&c.
	MVI  B,CNULL+1		;get null count.
CONUL1:	CALL CONOT1		;print cr.
	MVI  C,0		;get null char.
	DCR  B			;decrement counter.
	JNZ  CONUL1		;do next null.
	POP  B			;restore b&c.
	MOV  A,C		;restore a.
	RET			;return.
	ENDIF
;
	IF   SOLOS		;if proc tech solos,
	PUSH B			;save b&c.
	MOV  B,C		;put char in b reg.
	CALL SCRN		;output char to solos.
	POP  B			;restore b&c.
	MOV  A,C		;put char in a.
	RET			;return from conot.
	ENDIF
;
; select disk number according to register c.
;
SELDSK:	LXI  H,0		;set up for error code
	MOV  A,C		;get new drive.
	CPI  NDISK		;calling undefined drive ?
	RNC			;if no cy, h,l tells cpm yes.
	LXI  H,DISKNO		;get old drive number.
	MOV  A,M		;get old disk number.
;
	IF   DUAL		;if dual drive,
	ANI  0FEH		;clear out bit 0.
	ENDIF
;
	MOV  E,A		;put old disk no. in d&e.
	MVI  D,0
	LXI  H,TRTAB		;get address of track table.
	PUSH H			;save address of trtab.
	DAD  D			;add disk no. to address.
	IN   TRACK		;read 1771 track register.
	MOV  M,A		;put into table.
	MOV  A,C		;get new disk number.
;
	IF   DUAL		;if a dual drive,
	ANI  0FEH		;clear bit 0.
	ENDIF
;
	MOV  E,A		;put new disk no. in d&e.
	POP  H			;restore address of trtab.
	DAD  D			;add disk no. to address.
	MOV  A,M		;get new track number.
	OUT  TRACK		;put into 1771 track reg.
	MOV  A,C		;update old disk number.
	STA  DISKNO
	ADD  A			;put bits 1&2 at 4&5.
	ADD  A
	ADD  A
	ADD  A
	STA  LATCH		;save new latch code.
DENSITY:LXI  H,DRVFLG		;point to drive den. flag
	MVI  B,0		;clear reg b.
	DAD  B			;index into drive flag loc.
	MOV  A,M		;get the flag byte
	ORA  A			;logged in?
	JM   LOGED		;yes, it's logged.
	PUSH H			;no, save flag address.
	LDA  LATCH		;get latch code
	OUT  DCONT		;change latch or density
;
;read track 0 sector 1 for density byte at 7e hex.
;
	MVI  A,1		;sector 1.
	STA  SECT		;save the sector value.
	CALL HOME		;home the drive.
	LHLD DMAADD		;get cp/m dma address value
	PUSH H			;save it on the stack.
	LXI  H,DBUFF		;point to the dma buffer.
	SHLD DMAADD		;set up read dma address.
;
;read the data using read routine.
;
	CALL READ		;cbios read routine.
;
;get density byte value and determine drive status.
;
	POP  H			;restore dma address from the stack.
	SHLD DMAADD		; and restore the cp/m dma address.
	POP  H			;restore density flag address.
	LDA  DBUFF+7EH		;index into dbuff to location dbuff+7e.
	ORI  80H		;set logged in bit
	MOV  M,A		;place it in flag table.
LOGED:	LXI  B,18		;index value through drive table.
	ANI  12H		;mask density and side bits out.
	ORA  A			;single density?
	LXI  H,SDTAB		;point to start of tables
	JZ   DENSIT1		;yes, overlay param. block
;
	IF   DUBSID
	DAD  B			;no, add offset to next table
	CPI  2			;single den doub sided?
	JZ   DENSIT1		;yes
	DAD  B			;no
	CPI  10H		;doub den single sided?
	JZ   DENSIT1		;yes
	ENDIF
;
	DAD  B			;no, must be doub den , doub sided
DENSIT1:XCHG			;drive table pointer --> d,e
	LDAX D			;get log and drive type byte.
	INX  D			;bump pointer
	STA  DENS		;set current drive density.
	PUSH D			;save drive table pointer.
	CALL PARINDX		;compute parameter overlay area.
	POP  D			;restore drive table pointer.
	LXI  B,0208H		;b = 2, c = 8 (count values).
MOVE:	LDAX D			;get xlt0 byte.
	MOV  M,A		;and put it into dw table for drive.
	INX  D			;bump
	INX  H			; pointers
	DCR  B			;decrease count.
	JNZ  MOVE		; and loop till zero.
	DAD  B			;now add index into dpb0 area.
	MOV  M,E		;get low pointer byte.
	INX  H			;bump pointer.
	MOV  M,D		;get high pointer byte.
;
;select drive as a function of h,l
;
PARINDX:LHLD DISKNO		;load disk number and zero byte
	LXI  D,DPBASE		;point to disk parm start.
	DAD  H			;*2
	DAD  H			;*4
	DAD  H			;*8
	DAD  H			;*16
	DAD  D			;compute index for the drive
	XRA  A			;set a = 0.
	RET			;return from seldsk.
;
; move disk to track zero.
;
HOME:	MVI  C,0		;seek to track zero.
	MVI  A,STPRAT		;restore command
	OUT  DCOM		;tell controller.
;
; set track number to whatever is in register c.
; also perform move to the correct track (seek).
;
SETTRK:
	LHLD LATCH		;get new and old latch.
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
TRKSET:	LDA  DENS		;check drive density flag.
	RRC			;is bit 0 = 0?
	JNC  TRKSD		;yes, we are single density.
	MOV  A,C		;no, restore track number.
	CPI  1			;is it track 1?
	JC   TRKSD		;if less than, set single density.
	LDA  CLATCH		;get current latch value.
	ORI  8			;set for double density.
	JMP  TRKDD
;
TRKSD:	LDA  CLATCH		;get current latch value.
	ANI  0F7H		;turn off bit 4 (single density).
TRKDD:	STA  CLATCH		;save new latch value.
	OUT  DCONT		;select disk and make density change.
	MOV  A,C		;restore track value
	STA  TRK		;update old with new.
;
; move the head to the track in register a.
;
SEEK:	PUSH B			;save b&c.
	MOV  B,A		;save destination track.
	MVI  A,RTCNT		;get retry count.
SRETRY:	STA  SERCNT		;store in error counter.
	IN   TRACK		;read present track no.
	CMP  B			;same as new track no.?
	JNZ  NOTHR		;jump if not there.
THERE:	POP  B			;restore b&c.
	RET			;return from seek.
NOTHR:	MOV  A,B		;restore a from b.
	OUT  DDATA		;track to data register.
	MVI  A,14H+STPRAT+HLAB  ;get step rate, do
	OUT  DCOM		;seek with verify.
;
	IF NOT DMACNTL
	IN   WAIT		;wait for intrq.
	IN   DSTAT		;read status.
	ENDIF
;
	IF DMACNTL
	CALL SLOOP		;no wait status check.
	ENDIF
;
	ANI  91H		;look at bits.
	JZ  THERE		;ok if zero.
	LDA  SERCNT		;get error count.
	DCR  A			;decrement count.
	JNZ  SRETRY		;retry seek.
	POP  B			;restore b&c.
	PUSH B			;save
	CALL RECOV		;if seek retry = 10 check
	POP  B
	MOV  A,C		;recover track number.
	JMP  SEEK		; for cntl-c for abort.
;
; set disk sector number.
;
SETSEC:  MOV  A,C		;get sector number.
         STA  SECT		;put at sect # address.
         RET			;return from setsec.
;
;translate the sector given b,c using
;the translate table;given by d,e
;
SECTRAN:
	MOV  L,C		;get physical sector number
	INR  L			;bump it by one.
	MOV  A,D		;are we using no xlat table?
	ORA  E			;it will be zero if not.
	RZ			;return if it is zero.
	XCHG			;h,l = trans
	DAD  B			;h,l = trans (sector)
	MOV  L,M		;l   = trans (sector)
	MVI  H,0		;clear reg h
	RET			;h,l = translated sector
;
; set disk dma address.
;
SETDMA:	MOV  H,B		;move b&c to h&l.
	MOV  L,C
	SHLD DMAADD		;put at dma adr address.
	RET			;return from setdma.
;
; hdld - get head-load bit if required.
;
HDLD:	LDA  HLSF		;get head-load flag.
	ORA  A			;is a = zero?
	JZ   HDLD1		;hop if so.
	CMA			;set a = 0.
	STA  HLSF		;set flag = 0 if not.
;
;if changing to a new drive, perform a seek to
;the same track to unload the head on new drive.
;
	IN   TRACK		;get present track
	OUT  DDATA		;tell controller.
	MVI  A,10H+STPRAT
	OUT  DCOM
;
	IF   NOT DMACNTL
	IN   WAIT		;wait for intrq.
	ENDIF
;
	IF   DMACNTL
	CALL SLOOP		;check dma status port.
	ENDIF
;
HDLD1:	IN   DSTAT		;read 1771 status.
	ANI  20H		;look at hl bit.
	MVI  A,4
	RZ			;return if head is not loaded.
	SUB  A			;head is already loaded.
	RET			;return from hdld.
;
; read the sector at sect, from the present track,
; use starting address at dmaadd.
;
READ:	MVI  A,RTCNT		;get retry count.
RRETRY:
	IF DMACNTL
	LXI  B,80D0H		;floppy read, force interrupt.
	LXI  D,4080H		;dma read, dma count byte
	CALL DMARW		;enter common read/write routine.
	ENDIF
;
	IF NOT DMACNTL
	MVI  B,80H		;floppy read command byte.
	CALL DSKSET		;set up disk controller.
	ORA  B			;'or' in the read command.
READE:	OUT  DCOM		;send command to 1771.
RLOOP:	IN   WAIT		;wait for drq or intrq.
	ORA  A			;set flags.
	JP   RDDONE		;done if intrq.
	IN   DDATA		;read a data byte from disk.
	MOV  M,A		;put byte into memory.
	INX  H			;increment memory pointer.
	JMP  RLOOP		;keep reading.
RDDONE:	IN   DSTAT		;read disk status.
	ENDIF
;
	IF INTRP AND NOT DMACNTL;if interrupts allowed,
	EI			;allow again here.
	ENDIF
;
	ANI  9DH		;look at error bits.
	RZ			;return if none.
	CALL ERCHK		;check for seek error.
	JNZ  RRETRY		;try to read again.
	CALL RECOV		;check for abort or continue
	JMP  READ		;if not cntl-c, try to read again.
;
;recov
;this routine is called by any read,write,seek routine if the retry
;count goes to 10. if it does,this routine calls conin for a key to
;be pushed. if the key is a cntl-c, then a warmboot is executed. if
;any other key is pushed, then a return is made back to the caller
;and that routine is retried for 10 more times.
;
RECOV:
	MVI  C,'e'		;error code
	CALL CONOT		;print it
	CALL CONIN		;check for pushed key.
	CPI  03H		;is it a cntl-c ?
	RNZ			;return to caller if not.
	JMP  WBOOT		;yes, do warmboot.
;
; erchk - check for record not found error.
;
ERCHK:	ANI  10H		;if record not found,
	JNZ  CHKSK		;do a check on seek.
CHKOK:	LDA  ERCNT		;get retrys allowed
	DCR  A			;decrease it,
	RET			;and return with number.
;
;check for seek to correct track,
;and change if necessary.
;
	IF NOT DMACNTL
CHKSK:	MVI  A,0C4H		;send command to 1771
	OUT  DCOM		;to read address.
	IN   WAIT		;wait for drq or intrq.
	IN   DDATA		;read the track address.
	PUSH PSW		;save it on the stack.
CHKS2:	IN   DMACHK		;wait for intrq.
	ORA  A			;set flags.
	JP   CHKS3		;done with read adr op.
	IN   DDATA		;read another byte.
	JMP  CHKS2		;do it again.
CHKS3:	IN   DSTAT		;read disk status.
	ENDIF
;
	IF   DMACNTL
CHKSK:	LXI  H,BIOS-7		;point to unused space
	LXI  B,0C4D0H		;read address, force interrupt cmnds.
	LXI  D,04006H		;dma read, count byte
	CALL DMARWE		;read the id using dma control.
	ORA  A			;set flags.
	JZ   CHKS4		;read adr ok if 0.
	CALL HOME		;otherwise, home first.
	JMP  CHKS5
	ENDIF
;
	IF   NOT DMACNTL
CHKS4:	POP  PSW		;update track register.
	ENDIF
;
	IF   DMACNTL
CHKS4:	IN   SECTP		;get the track byte
	ENDIF
;
	OUT  TRACK
CHKS5:	LDA  TRK		;get required track no.
	CALL SEEK		;move the head to it.
	JMP  CHKOK		;exit from error check.
;
	IF   NOT DMACNTL
DSKSET:	STA  ERCNT		;store in error ctr.
	MVI  A,0D0H		;cause interrupt.
	OUT  DCOM
	XTHL			;some
	XTHL			; delay
	ENDIF
;
	IF INTRP AND NOT DMACNTL;if interrupts allowed,
	DI			;disable them here.
	ENDIF
;
	IF   NOT DMACNTL
	LHLD DMAADD		;get starting addr.
	LDA  SECT		;get sector number.
	OUT  SECTP		;set sector into 1771.
	CALL HDLD		;get head-load bit?
	RET			;return to caller
	ENDIF
;
; write the sector at sect, on the present track,
; use starting address at dmaadd.
;
WRITE:	MVI  A,RTCNT		;get retry count.
WRETRY:
	IF   DMACNTL
	LXI  B,0A0D0H		;floppy write, force interrupt.
	LXI  D,08080H		;dma write, dma count byte.
	CALL DMARW		;enter common read/write routine.
	ENDIF
;
	IF   NOT DMACNTL
	MVI  B,0A0H		;floppy write command byte.
	CALL DSKSET		;set up floppy controller.
	ORA  B			;'or' in write command.
WRITE2:	OUT  DCOM
WLOOP:	IN   WAIT		;wait for ready.
	ORA  A			;set flags.
	JP   WDONE		;hop out when done.
	MOV  A,M		;get byte from mem.
	OUT  DDATA		;write onto disk.
	INX  H			;increment mem ptr.
	JMP  WLOOP		;keep writing.
WDONE:	IN   DSTAT		;read disk status.
	ENDIF
;
	IF INTRP AND NOT DMACNTL;if interrupts allowed,
	EI			;enable again here.
	ENDIF
;
	ANI  0FDH		;look at these bits.
	RZ			;return if no err.
	CALL ERCHK		;check/correct seek err.
	JNZ  WRETRY		;try to write again.
	CALL RECOV		;check for abort
	JMP  WRITE		;retry write again.
;
;list status check routine
;
PRSTAT:	CALL PSTAT		;check printer status port.
;
	MVI  A,0		;return status activity.
;
	IF   TARDEL OR RDYLO
	RNZ
	ENDIF
;
	IF   NOT TARDEL AND RDYHI
	RZ
	ENDIF
;
	CMA			;invert it
;
; punch and reader are not supported.
;
PUNCH:
READER:	RET
;
;pstat - printer status check routine.
;
PSTAT:	IN   LSTAT		;read printer status port.
;
	IF   NOT TARDEL
	ANI  LRBIT
	ENDIF
;
	IF   TARDEL
	ANI  81H		;mask ready bits
	XRI  81H
	ENDIF
;
	RET			;return to caller
;
; write a character on listing device.
;
LIST:
	IF   LSTNUL  		;if nulls or paging,
	MVI  A,0DH		;if it's a cr,
	CMP  C			;then hop out to
	JZ   LINUL		;null routine.
	ENDIF
;
	IF   LSTPAG		;if paging
	MVI  A,0AH		;get a linefeed
	CMP  C			;does it match?
	JZ   LINUL3
	MOV  A,C
	CPI  0CH
	RZ
	ENDIF
;
LTBSY:	CALL PSTAT		;read lister status.
;
	IF   TARDEL OR RDYLO
	JNZ  LTBSY		;loop till low.
	ENDIF
;
	IF   NOT TARDEL AND RDYHI
	JZ   LTBSY		;loop till high.
	ENDIF
;
	MOV  A,C		;get data byte.
	OUT  LDATA		;print it.
	RET			;return from list.
;
	IF   LSTNUL		;if list nulls
LINUL:	PUSH B			;save b&c.
	MVI  B,(LNULL AND 0FFH)+1 ;get null count
LINUL1:	CALL LTBSY		;print (cr first).
	MVI  C,0		;get null char.
	DCR  B			;decrement counter.
	JNZ  LINUL1		;do next null.
	JMP  LINUL2		;exit the routine.
	ENDIF
;
	IF   LSTPAG		;if list dev. paging,
LINUL3:	PUSH B			;save b,c pair
	LDA  LFCNT		;get line-feed count.
	INR  A			;increment it.
	STA  LFCNT		;save it back.
	CPI  LINCNT-(LINCNT/11) ;end of page?
	MVI  B,1		;set up for 1 lf.
	JNZ  NOTEOP		;hop if not end.
	XRA  A			;set lf count = 0.
	STA  LFCNT
	MVI  B,(LINCNT/11)+1	;between pages.
NOTEOP:	MVI  C,0AH		;get line-feed code.
LSTPA1:	CALL LTBSY		;print line-feed.
	DCR  B			;decrement lf counter.
	JNZ  LSTPA1		;do next line feed?
	ENDIF
;
	IF   LSTNUL OR LSTPAG	;if nulls or paging,
LINUL2:	POP  B			;restore b&c.
	MOV  A,C		;restore a.
	RET			;return from list.
	ENDIF
;
ENDPROG	EQU	$-1		;ending address.
;
;note:  as there are only six (6) sectors available for cbios on
;the second system track (1), the last address before this point
;should be no greater than the cbios starting address + 037f (hex).
;this will normally be xd7f (hex).
;
; bios scratch area.
;
TRK:	DS   1			;current track number.
SECT:	DS   1			;current sector number.
DMAADD:	DS   2			;disk transfer address.
;
; the next several bytes, between startz and
; endz, are set to zero at cold boot time.
;
STARTZ:				;start of zeroed area.
;
DISKNO:	DS   2			;disk number
;
; special flags.
;
HLSF:	DS   1			;head-load select flag.
LFCNT:	DS   1			;paging line-feed count.
;
; trtab - disk track table - present position of
;	heads for up to 4 drives.
;
TRTAB:	DS   4
DRVFLG:	DS   4			;drive density flags.
DENS:	DS   1			;current drive density value.
ERCNT:	DS   1			;error count for retries.
SERCNT:	DS   1			;seek retry counter.
LATCH:	DS   1			;new code for latch.
CLATCH:	DS   1			;current code in latch.
;
ENDZ	EQU  $
;
BEGDAT	EQU  $
DIRBUF:	DS   128		;directory buffer
ALV0:	DS   31
CSV0:	DS   24
ALV1:	DS   31
CSV1:	DS   24
ALV2:	DS   31
CSV2:	DS   24
ALV3:	DS   31
CSV3:	DS   24
ENDDAT	EQU  $
DATSIZ	EQU  $-BEGDAT		;total size of disk parm storage.
;
DBUFF:	DS   128		;128 byte density select buffer.
;
	ORG  ENDPROG		;show actual ending address of bios
	END

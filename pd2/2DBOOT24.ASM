;
; tarbell electronics cp/m coldstart loader
; version of 10-27-81.
;--------------------------------------------------------------
; modified for dma control - 1-5-80.
; modified for reading larger bios from trk 1  - 6-5-80.
; modified for tarbell cpu card  -  7-3-80.
; modified to clear extended latch on disk board 6-29-81
; modified for doub den side 1 system track 9-29-81
; added larger sector check in seccmp + 1 lable  10-27-81
; g.w.mulchin
; tarbell electronics
;--------------------------------------------------------------
; copyright (c) 1980, 1981 tarbell electronics
;
;
;*****************************************************************
;*                                                               *
;*                       ** note **                              *
;*			=============				 *
;*								 *
;*	the equate for double density (doubden) must only be     *
;* set true for a disk which is formatted in double density only *
;* and one which you wish to put an operating system on to.      *
;* otherwise, leave it false if you are building an operating    *
;* system on to a single density formatted disk.                 *
;*								 *
;*****************************************************************
;
;
; this program is loaded at location zero by the bootstrap program,
; and executed. its purpose is to load and execute the cp/m disk
; operating system at the top of the memory in use.
;
FALSE	EQU  0		;define value of false.
TRUE	EQU  NOT FALSE	;define value of true.
;
;********* this is the area to make changes in *******************
;********* for different system configurations *******************
;								**
MSIZE	EQU  24		;memory size in decimal kb.		**
TARBELL	EQU  FALSE	;true if using tarbell cpu.		**
DUBSID	EQU  FALSE	;true for double sided systems.		**
DELTA	EQU  FALSE	;true if using delta cpu card		**
DOUBDEN	EQU  FALSE	;true if doub. den disk.        	**
DMACNTL	EQU  FALSE	;true if using dma control		**
BASE	EQU  0		;tarbell i/o ports (00 or 10 hex)	**
DDS	EQU  26		;sectors in trk 1 , (range = 26 to 51)	**
DISK	EQU  0F8H	;disk port base address.		**
;								**
;*****************************************************************
;
	IF   TARBELL
IO	EQU  BASE	;i/o ports on tarbell cpu.
MMENB	EQU  IO+10	;memory management enable port.
MEMMAG	EQU  BASE+32	;memory management port.
	ENDIF

ADR0	EQU  0E0H	;dma address port.
WCT0	EQU  0E1H	;dma word count port.
CMND	EQU  0E8H	;dma command port.
DCOM	EQU  DISK	;command port.
DSTAT	EQU  DISK	;status port.
TRACK	EQU  DISK+1	;track port.
SECT	EQU  DISK+2	;sector port.
DATA	EQU  DISK+3	;data port.
WAIT	EQU  DISK+4	;wait port.
DCONT	EQU  DISK+4	;control port.
DMACHK	EQU  DISK+5	;dma check port.
EXTMEM	EQU  DISK+5	;extended disk latch
PANEL	EQU  0FFH	;front panel machines.
CBASE	EQU  (MSIZE-20)*1024
CPMB	EQU  CBASE+3400H;start of cp/m.
BOOTE	EQU  CPMB+1600H	;cold boot entry point.
SPT	EQU  26		;number of sectors per track. (sing den)
SDS	EQU  25		;always 25 sectors to read in trk 1.
NSECTS	EQU  SDS + DDS	;sectors of cp/m.
RTCNT	EQU  10		;number of retrys.
;
	ORG  0		;start of loader.
;
BOOT:
	IF   TARBELL	;if using tarbell cpu
	LXI  D,1000H	;count=16, data byte = 0
	MVI  C,MEMMAG AND 0FFH
MLOOP:	MOV  A,E	;get address value
	ORA  C		;make i/o port value
	STA  MOUT+1	;modify port on the fly
	MOV  A,E	;get init value.
	CMA		;flip it for ram on cpu
MOUT:	OUT  BASE	;put it to ram on cpu
	INR  E		;bump data value
	DCR  D		;decrease count
	JNZ  MLOOP	;loop 16 times.
	OUT  MMENB	;enable memory management.
	ENDIF
;
	IF   DELTA	;if using delta cpu.
	MVI  A,1	;get a 1 in reg a.
	OUT  9		; and disable cpu rom slot.
	ENDIF
;
	XRA  A		;clear accum
	OUT  EXTMEM	;clear extended disk latch
	MVI  E,RTCNT	;get retry count.
BLOOP:	LXI  SP,100H	;set stack pointer.
	LXI  H,CPMB	;cp/m starts here.
	MVI  D,NSECTS	;number of sectors to read.
	MVI  C,2	;sector number.
RNTRK:	MVI  B,4	;for head load.
RNSEC:	CALL READ	;read first sector.
	DCR  D		;if done,
	JZ   BOOTE	;go to cp/m.
	MVI  B,0	;for no head load.
	INR  C		;increment sector count.
	MOV  A,C	;done with
SECCMP:	CPI  SPT+1	;this track?
	JC   RNSEC	;if not, read next sector.
;
	IF   DOUBDEN AND NOT DUBSID
	MVI  A,DDS + 1	;number of sectors to read on trk 1.
	STA  SECCMP+1	;modify sector compare value.
	MVI  A,8	;get set double density code
	OUT  WAIT	;set latch for d.density
	ENDIF
;
	IF   NOT DUBSID
	MVI  A,5BH	;step command.
	OUT  DCOM	;issue it.
	IN   WAIT	;wait until done.
	ENDIF
;
	IF   DUBSID	;if double sided system.
	MVI  A,DDS + 1	;number of sectors to read on trk 1.
	STA  SECCMP+1	;modify sector compare value.
	MVI  A,48H	;side select and density select
	OUT  DCONT	;issue it.
	ENDIF
;
	MVI  C,1	;sector number.
	JMP  RNTRK	;read next track.
;
READ:
	IF   DMACNTL	;if using dma control.
	MVI  A,41H	;set up for chan 0 req.
	OUT  CMND
	MVI  A,7FH	;count for 128 bytes
	OUT  WCT0
	MVI  A,40H	;read command
	OUT  WCT0
	MOV  A,L	;get low address byte
	OUT  ADR0
	MOV  A,H	;high address byte
	OUT  ADR0
	ENDIF
;
	MOV  A,C	;sector in a.
	OUT  SECT	;set sector register.
	MVI  A,88H	;command for read.
	ORA  B		;get head load bit.
	OUT  DCOM	;issue command.
;
	IF   NOT DMACNTL;if not using dma control.
RLOOP:	IN   WAIT	;wait for drq.
	ORA  A		;set flags.
	JP   CHECK	;jump if done.
	IN   DATA	;read data.
	MOV  M,A	;put in memory.
	INX  H		;increment pointer.
	JMP  RLOOP	;loop until done.
	ENDIF
;
	IF  DMACNTL
SLOPP:	IN   DMACHK	;check dma status
	RLC		; bit 7
	JC   SLOPP	;loop if carry
	PUSH B		;save b,c pair
	LXI  B,128	;count set for 128 bytes
	DAD  B		;adjust h,l by 128 bytes
	POP  B		;restore bc
	ENDIF
;
CHECK:	IN   DSTAT	;read status.
	ANI  9DH	;look at error bits.
	RZ		;ok if zero.
	DCR  E		;decrement retry count.
	JNZ  BLOOP	;try again if not zero.
	CMA		;flip for front panel
	OUT  PANEL	;show error code from floppy.
HERE:	JMP  HERE	;loop.
;
	ORG  7DH	;put jump here.
;
	IF   DOUBDEN AND NOT DUBSID	;if running double density
	RST  0		;do restart 0
	DB   0DDH	;this byte must be here if doub den.
	DB   0		;this byte unused
	ENDIF
;
	IF   DOUBDEN AND DUBSID
	RST  0
	DB   0DFH
	DB   0
	ENDIF
;
	IF   NOT DOUBDEN AND NOT DUBSID
	RST  0		;do warm boot with rst inst.
	DB   0E5H
	DB   0
	ENDIF
;
	IF   NOT DOUBDEN AND DUBSID
	RST  0
	DB   0E7H
	DB   0
	ENDIF
;
	END   BOOT	;end of boot.

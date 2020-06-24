;*****************************************************************************
;
;  Flop2PC - Transfer floppy image to PC over a serial port
;		(for Tarbell double density controller)
;
;	This program transmits an image of a SSSD soft-sectored 8" floppy
;	to a PC. The image is transmitted through a 2SIO at I/O address
;	010h or 012h, or an SIO at address 0 using the XMODEM protocol.
;
;	The program talks directly to the Tarbell controller and does not
;	require CP/M or an OS to function.

;	This program works best if console port and the transfer port
;	are not the same device. Otherwise, most error messages won't
;	be seen as the file transfer dialog box prevents their display.
;
;	The program runs standalone at 0x100 or under CP/M. The program
;	is exited with a CTRL-C and either warm boots CP/M or just starts
;       over when running stand alone.
;
;	Written by Mike Douglas
;
;       Modified by Patrick Linstruth for Tarbell Double Density Controller
;
;	Rev	 Date	    Desc
;	1.0	 06/24/20   Modify Tarbell SD FLOP2PC to support double
;                           density controller. Version 1.0 version only
;                           supports programmed I/O and single density.
;
;*****************************************************************************

; Disk information equates

NUMTRK	equ	77		;number of tracks
NUMSEC	equ	26		;number of sectors per track
SECLEN	equ	128		;sector length (as transmitted)
MINDRV	equ	0		;first drive number
MAXDRV	equ	3		;max drive number 

TRKLEN	equ	(NUMSEC*SECLEN)	;length of track in bytes
RDTRIES	equ	3		;disk retries per retry step

; Specify head settle delay (in addition to the 10ms step delay provided
;    by the 179X), and the amount of time to delay between reversing
;    track steps (e.g., step in/out or step out/in sequence). 
;
; Set ONEMS to give a 1ms delay for a 19 cycle loop (8080) or a 18 cycle
;    loop (Z80)

HDSETL	equ	10		;10ms additional head settle after step
STPREV	equ	10		;10ms delay when reversing step direction
ONEMS	equ	105		;105*19 cycles = 1ms at 2Mhz (8080)
;ONEMS	equ	267		;222*18 cycles = 1ms at 4Mhz (Z80)

; Monitor, CP/M boot entry points

MONITOR	set	init		;no monitor, just start over
CPMBOOT	set	0		;CP/M warm boot jump vector

; XMODEM equates

PKTLEN	equ	128		;128 byte xmodem packet length
SOH	equ	001h
EOT	equ	004h
ACK	equ	006h
NAK	equ	015h
EOF	equ	01ah		;ctrl-z character
XMTRIES	equ	10		;number of xmodem retries

; CP/M Equates

WBOOT	equ	0		;warm boot jump vector

; Misc equates

CR	equ	13		;ascii for carriage return
LF	equ	10		;ascii for line feed
DEL	equ	7fh		;ascii DEL
BS	equ	08h		;ascii backspace
CTRLC	equ	03		;ascii for control-c
JMPINST	equ	0c3h		;jump instruction opcode

	org	0100h		;load address
;-----------------------------------------------------------------------------
;   Initialize for transfer
;-----------------------------------------------------------------------------
init	lxi	sp,ourStk	;initialize stack pointer
	call	chkCpm		;set flag for CP/M or not
	call	sizeRam		;determine amount of RAM available
	call	s2Init		;initialize the 88-2SIO ports
	mvi	a,MINDRV	;a=default drive
	sta	drvNum		;need for pgmExit

;  Display welcome message, then get the drive number and port number
;    to use for the transfer from the operator.

	lxi	h,mWelcom	;display welcome message
	call	dispMsg

; getDrv - get drive number or letter from the user.

; getDrv - get drive number or letter from the user.

getDrv	lxi	h,mDrive	;display drive number prompt
	call	dispMsg
	call	rcvCon		;get byte from the console
	ori	20h		;upper case letters to lower case
	cpi	'x'		;exit requested?
	jz	pgmExit		;yes

	lxi	h,baseDrv	;ascii 1st drive - baseDrv = 0
	sub	m
	cpi	MAXDRV-MINDRV+1	;validate >=min drive and <= max drive
	jnc	getDrv		;invalid, prompt again

	adi	MINDRV		;restore offset of 1st drive (if any)
	sta	drvNum		;save the drive number to use

	call	dRestor		;restore to track 0 (selects drive)

; getPort - get serial port number from the user.

getPort	lxi	h,mPort		;display transfer port prompt
	call	dispMsg
	call	rcvCon		;get byte from the console
	ori	20h		;upper to lower case, nums not affected
	cpi	'x'		;exit requested?
	jz	pgmExit		;yes

	sui	'1'		;'1' - '3' to bianry 0-2
	cpi	3		;validate ascii 1-3
	jnc	getPort		;invalid, prompt again

	sta	xfrPort		;save the port to use

; Prompt the user to start the XMODEM receive operation on the PC. 
;    Wait for a clear receive line for a least one second, then start
;    looking for NAK or 'C' (crc protocol) from the PC

	lxi	h,mStart	;display start file transfer prompt
	call	dispMsg

clrRcv1	call	rcvByte		;loop until input clear for 1 second
	jnz	clrRcv1

	xra	a		;set CRC flag to false (checksum mode)
	sta	crcFlag

waitNak	call	chkQuit		;give user chance to abort
	call	rcvByte		;wait for a character
	cpi	NAK
	jz	haveNak		;have a NAK, use checksum protocol

	cpi	'C'		;CRC protocol requested?
	jnz	waitNak		;no

	sta	crcFlag		;set crc flag non-zero = CRC mode

;  NAK or 'C' received meaning the XMODEM receive has started. Initialize
;     for the transfer.

haveNak	xra	a		;init track we want to zero
	sta	trkNum
	sta	lastSec		;last sector accessed

	inr	a		;init xmodem block number to one
	sta	blkNum

	lxi	h,trkBuf	;trkBuf is initial starting point for
	shld	sndPtr		;   XMODEM send

;-----------------------------------------------------------------------------
;  mainLp - Loop through all tracks on the disk buffering as many tracks
;    as will fit in RAM before sending via xmodem, then repeat.
;-----------------------------------------------------------------------------
mainLp	lxi	h,trkBuf	;disk buffering always start at trkBuf
	shld	trkPtr

; Read and buffer bufTrks tracks unless all tracks on drive reached first

bufLoop	call	readTrk		;read into trkBuf

	lda	trkNum		;increment track number (preserve HL)
	inr	a
	sta	trkNum	
	cpi	NUMTRK		;done all tracks on the disk?
	jz	sendBuf		;yes, go send the buffered tracks

	lda	trkErr		;read failure on the track?
	ora	a		;if so, send buffered tracks now
	jnz	sendBuf		;so XMODEM won't time out

	xchg			;de=current track pointer
	lhld	bufEnd		;hl=end of buffering space
	call	cmpDeHl		;compare current-end
	jc	bufLoop		;still room, keep going	

; Track buffer is full or all tracks have been read. Send the buffered
;    tracks via xmodem.

sendBuf	call	sndTrks		;send the buffered tracks via xmodem
	lda	trkNum
	cpi	NUMTRK		;done all tracks?
	jnz	mainLp		;no, not done yet

; The entire disk has been read and (mostly) transmitted. See if there are
;    left over bytes to send. If so, send them.

	mov	a,l		;hl->next packet to send, a=lsb of ptr
	cpi	trkBuf AND 0ffh	;pointing to lsb of address of trkBuf?
	jz	noExtra		;same, no extra bytes to send

	call	sndPkt		;otherwise, send one last packet

; Send EOT and wait for response. Then display the success message and
;    start the program over.

noExtra	call	sndEot		;send and get response for EOT
	lxi	h,mDone		;print the all done message
	call	dispMsg
	jmp	getDrv		;start over asking for a drive
	
;-----------------------------------------------------------------------------
; readTrk - read NUMSEC sectors from the current track into a trkBuf as
;   pointed to by trkPtr. After the track is read, trkPtr is updated
;   by the length of a track to point to the next track buffer. This
;   saved value is also returned in HL.
;-----------------------------------------------------------------------------
readTrk	lxi	h,trkNum	;get desired track from trkNum	
	mov	l,m		;and put into l
	call	dSeek		;seek to the track

	xra	a
	sta	trkErr		;no error on this track yet

	mvi	a,2		;init retry step
	sta	rtStep

; To make sure the head is settled following the track step, yet still
;    minimize latency, add 4 to the last sector number accessed (and
;    wrap as needed). When this sector number is used in the call to
;    dNxtSec, a total delay of about 24 ms has transpired since the step
;    was issued. This give 10ms for the step plus 14 ms of head settle time.

	lda	lastSec		;last sector accessed
	adi	4		;bump by four sector times
	cpi	NUMSEC+1	;past 26?
	jc	noWrap

	sui	NUMSEC		;wrap to sector 1-n

noWrap	mov	e,a		;e=new "last" sector number

; Read an entire track. Start after the sector in e. 

	mvi	d,NUMSEC	;d=sector counter

secLoop	call	dNxtSec		;e=next sector, bc=offset within track

stpLoop	lhld	trkPtr		;hl->start of current track buffer
	dad	b		;hl->sector buffer

	call	chkQuit		;check for ctrl-c from operator

	call	dRead		;read the sector
	jnz	secRtry		;error, run retry logic	

; Decrement sector count. If full track is done, increment trkPtr
;   to point to the next track buffer in trkBuf and exit.

nxtSec	dcr	d		;decrement sector count
	jnz	secLoop

	lhld	trkPtr		;hl=current track pointer
	lxi	d,TRKLEN	;de=bytes in a track
	dad	d		;hl=start of next track in trkBuf
	shld	trkPtr
	ret

;--------------------------------------------------------------------------
; secRtry - Read error retry logic. Three retry steps are tried in
;   the order shown below:
;
;   Step    Action
;    2	Re-read RDTRIES times
;    1	Seek out one track and back, then re-read RDTRIES times
;    0	Seek in one track and back, then re-read RDTRIES times
;
;    Upon entry, if the error is "sector not found," then retries are
;    not performed since the controller has already tried to read the
;    address mark across three revolutions.
;--------------------------------------------------------------------------	
secRtry	ani	sSECERR		;sector not found error?
	jnz	nxtStep		;yes, skip retries, go to next step

	mvi	a,RDTRIES	;init retry counter
	sta	rdRtry

retryLp	call	dWtSec		;get bc=offset of sector e in track
	lhld	trkPtr		;hl->start of current track buffer
	dad	b		;hl->sector buffer

	call	chkQuit		;check for ctrl-c
	
	call	dRead		;read the sector
	jz	rtDone		;success, retry is done

	lxi	h,rdRtry	;decrement retry counter
	dcr	m
	jnz	retryLp		;try again

; nxtStep - move to the next retry step

nxtStep	lxi	h,rtStep	;decrement to next retry step
	dcr	m
		
	jz	skPast		;step 0, step in one track and come back	
	jp	skBack		;step 1, step out one track and come back

; All retry steps failed. Display the error, then jump back into the main
;    read loop which will resume at the next sector.

	call	dspErr		;give up, display the error

; rtDone - retry logic is done. Reset the retry step counter and
;    jump to end of sector processing above

rtDone	mvi	a,2		;restart retry step counter
	sta	rtStep
	jmp	nxtSec

;-----------------------------------------------------------------------------
; skBack - step out then back in, retry read
; skPast - step in then back out, retry read
;-----------------------------------------------------------------------------
skBack	lda	trkNum		;a=current track
	dcr	a		;move out one track
	jp	doBump		;not before track zero, do the step out

skPast	lda	trkNum		;a=current track
	inr	a		;move in one track
	cpi	NUMTRK		;past end?
	jnc	skBack		;yes, do seek back instead
	
doBump	mov	l,a
	call	dSeek		;issue step out or in

	mvi	a,STPREV	;delay for step direction reversal
	call	delayMs

	lxi	h,trkNum	;get desired track from trkNum
	mov	l,m		;and put into l
	call	dSeek		;seek back to the track

	mvi	a,HDSETL	;delay head settle time after step
	call	delayMs

	call	dWtSec		;get bc=offset of sector within track
	jmp	stpLoop		;start reads for new step

;-----------------------------------------------------------------------------
; sndTrks - send the tracks buffered in trkBuf via xmodem. trkPtr points
;    to the end+1 of the data to send
;-----------------------------------------------------------------------------
sndTrks	lhld	trkPtr		;hl=end of buffered data + 1
	xchg			;de=end of buffered data + 1
	lhld	sndPtr		;hl=start tranmission address

sndLoop	push	d		;save end pointer
	call	sndPkt		;send a packet
	pop	d		;de=end pointer

; At this point, hl->start of next packet and de->last byte read from disk+1.
;    If the next XMODEM packet will go past the end of the disk data,
;    we don't want to send it yet.

	lxi	b,PKTLEN	;bc=length of XMODEM packet
	dad	b		;hl=address at end of NEXT packet + 1
	call	cmpDeHl		;compare disk end - end of next packet
	jc	sndDone		;next packet will pass the end, stop

	lxi	b,-PKTLEN	;restore hl
	dad	b
	jmp	sndLoop

; sndDone - all the packets we can send have been sent. Move any bytes
;    left over to just before the start of trkBuf. The next group of
;    xmodem packets will be transmitted starting there.

sndDone	call	subDeHl		;hl=de-hl = left over byte count - PKTLEN
	mov	a,l		;a=left over count - PKTLEN
	adi	PKTLEN		;a=left over byte count
	mov	b,a		;b=count of bytes to move
	lxi	h,trkBuf	;hl->start of trkBuf
	jz	mvDone		;no bytes to move, we're done

; Copy the leftover data backwards to just before the track buffer. The
;   next XMODEM send sequence will start at the beginning of this copied
;   data instead of at the start of trkBuf.

moveLp	dcx	h		;hl->memory just before trkBuf
	dcx	d		;de->unsent bytes from end of trkBuf
	ldax	d		;move from end of trkBuf to before trkBuf
	mov	m,a	
	dcr	b
	jnz	moveLp

mvDone	shld	sndPtr		;save address from which to send next time
	ret

;-----------------------------------------------------------------------------
; sndPkt - send an xmodem format 128 byte packet. HL points to the 128 byte
;    buffer to send. On exit, HL points to the next 128 byte boundary.
;-----------------------------------------------------------------------------
sndPkt	mvi	a,XMTRIES	;init retry counter
	sta	xmRetry

; First, send header bytes

reSend	call	chkQuit		;check for ctrl-c
	push	h		;save hl for possible re-send
	mvi	a,SOH		;1st byte is SOH
	call	sndByte
	lda	blkNum		;2nd byte is the block number
	call	sndByte
	cma			;2nd complement of block number
	call	sndByte

; Init checksum and CRC and packet length for transmission of data portion

	xra	a		;init crc
	sta	crc16
	sta	crc16+1
	lxi	d,PKTLEN*256	;d=byte counter, e=0 (checksum)

; Loop sending the data bytes and updating checksum and CRC

pktLoop	mov	a,m
	call	sndByte		;send and update checksum in e
	call	calCrc		;update the CRC
	inx	h		;point to next byte
	dcr	d		;decrement bytes remaining
	jnz	pktLoop

; Send checksum or CRC based on crcFlag

	lda	crcFlag		;crc or checksum?
	ora	a
	jz	sndCsum		;flag clear = checksum

	lda	crc16+1		;a=high byte of CRC
	call	sndByte		;send it
	lda	crc16		;a=low byte of crc
	jmp	sndSkip		;skip next instruction	

sndCsum	mov	a,e		;send the checksum byte

sndSkip	call	sndByte

;  All bytes sent. Wait for the response.

	call	rcvByte		;get the response character
	jz	sndFail		;timeout on response

	cpi	ACK		;ack received?
	jnz	sndFail		;no, send failed

	lda	blkNum		;increment block number
	inr	a
	sta	blkNum

	pop	b		;remove pushed hl, but don't clobber hl
	ret

; sndFail - ACK not received, decrement retry and try again.

sndFail	lxi	h,xmRetry	;point to retry counter
	dcr	m
	jz	xmFail		;retries used up, failed xmodem transfer

; If we've had 3 NAKs on the 1st packet and CRC is selected, assume
;   we took so long to send the 1st packet due to disk retries that
;   the receiver has since timed out and switched to checksum

	lda	crcFlag		;are we in CRC mode
	jz	clrRcv2		;no, ignore the rest of this

	lda	blkNum		;on block 1?
	dcr	a
	jnz	clrRcv2		;no, go on

	lda	xmRetry		;failed three times in a row on block 1?
	sui	XMTRIES-3
	jnz	clrRcv2		;no

	sta	crcFlag		;clear crcFlag to force checksum

;  clrRcv2 - wait for one second of line clear time and send packet again.

clrRcv2	call	rcvByte		;wait for 1 second of clear line
	jnz	clrRcv2

	pop	h		;restore pointer to the packet
	jmp	reSend		;re-send the packet

;  xmFail - Display failure message then restart program

xmFail	lxi	h,mXmdm		;xmodem failure message
	call	dispMsg

	lxi	sp,ourStk	;initialize stack pointer
	jmp	getDrv		;start over asking for drive

;-----------------------------------------------------------------------------
; calCrc - update the 16-bit CRC with one more byte. 
;    (Copied from M. Eberhard)
; On Entry:
;   a has the new byte
;   crc16 is current except this byte
; On Exit:
;   crc16 has been updated
;   Trashes a,bc
;-----------------------------------------------------------------------------
calCrc	push	d
	push	h
	lhld	crc16		;get CRC so far
	xra	h		;XOR into CRC top byte
	mov	h,a
	lxi	b,1021h		;bc=CRC16 polynomial
	mvi	d,8		;prepare to rotate 8 bits

; do 8 bit shift/divide by CRC polynomial

cRotLp	dad	h		;16-bit shift
	jnc	cClr		;skip if bit 15 was 0
	mov	a,h		;CRC=CRC xor 1021H
	xra	b
	mov	h,a
	mov	a,l
	xra	c
	mov	l,a
cClr	dcr	d
	jnz	cRotLp		;rotate 8 times

; save the updated CRC and exit

	shld	crc16		;save updated CRC
	pop	h
	pop	d
	ret

;-----------------------------------------------------------------------------
;  sndEot - send EOT character and wait for ACK response
;-----------------------------------------------------------------------------
sndEot	mvi	a,XMTRIES	;init retry counter
	sta	xmRetry

reEot	mvi	a,EOT		;send the EOT
	call	sndByte
	call	rcvByte		;wait for response
	jz	eotFail		;timeout

	cpi	ACK		;ack received?
	jnz	eotFail		;no, eot send failed

	ret			;otherwise, we're done.

; timeout waiting for ACK to EOT. Decrement retry counter and try again

eotFail	lxi	h,xmRetry	;point to retry counter
	dcr	m
	rz			;just give up - xfer was probably good

clrRcv3	call	rcvByte		;wait for 1 second of clear line
	jnz	clrRcv3
	jmp	reEot		;try again

;-----------------------------------------------------------------------------
; dispMsg - display the null-terminated message passed in hl on the
;    console device. Clobbers b, hl
;-----------------------------------------------------------------------------
dispMsg	mov	a,m		;get the next message byte
	ora	a		;null terminates
	rz

	mov	b,a		;conOut wants character in b
	call	conOut
	inx	h		;move to next byte
	jmp	dispMsg

;-----------------------------------------------------------------------------
; rcvCon - Receive a character from the console device, echo it, then
;   wait for a CR. Exits program if Ctrl-c typed. Returns with invalid
;   character (null) if BS or DEL pressed after 1st character
;   Returns character in a, clobbers b.
;-----------------------------------------------------------------------------
rcvCon	call	conIn		;check for input
	jz	rcvCon		;nothing

	ani	7fh
	cpi	CTRLC		;abort requested?
	jz	pgmExit		;yes

	cpi	CR		;return pressed?
	rz			;yes, don't echo it

	mov	b,a		;conOut needs character in b
	call	conOut		;echo it

; Wait for CR, then return 1st character typed

rcvCr	call	conIn		;check for input
	jz	rcvCr		;nothing

	ani	7fh
	cpi	CTRLC		;abort requested?
	jz	pgmExit		;yes

	cpi	DEL		;delete
	rz			;yes, return DEL character

	cpi	BS		;backspace?
	rz			;yes, return BS character

	cpi	CR		;return pressed?
	jnz	rcvCr		;no, keep waiting

	mov	a,b		;return 1st character typed
	ret

;-----------------------------------------------------------------------------
; sndByte - send the byte in a through the specified transfer port. 
;     Adds the byte to register e for checksum. Clobbers b.
;     XMODEM send routine assumes serOut returns with a containing
;     the character sent.
;-----------------------------------------------------------------------------
sndByte	mov	b,a		;b=byte to transmit
	add	e		;update checksum
	mov	e,a		;e=updated checksum
	lda	xfrPort		;a=port to use for transfer
	jmp	serOut		;send the character

;-----------------------------------------------------------------------------
; rcvByte - Receive a byte from specified transfer port with a one second
;     timeout. If a timeout occurs, zero is returned in A and the zero 
;     flag is true. Otherwise, the character is returned in A (could be
;     zero) and zero flag is false. ONESEC must be set based on processor
;     speed and the number of cycles in the serIn call + 59. 
;     Clobbers a, b and c.
;-----------------------------------------------------------------------------
rcvByte	lxi	b,ONESEC	;bc=cycles through this loop for 1s

rcvWait	lda	xfrPort		;(13) a=port to use for transfer
	call	serIn		;(17+cycles in serIn)look for a byte
	rnz			;(5)byte received

	dcx	b		;(5)otherwise, decrement timer
	mov	a,b		;(5)one second expire?
	ora	c		;(4)
	jnz	rcvWait		;(10)no, keep waiting

	ret			;return with timeout (zero true and in a)

;-----------------------------------------------------------------------------
; dspErr - display the current track and sector number which just had
;     a read error. If this is the first error on a track, the track
;     number is displayed first.
;
;  on entry:
;     e = sector number
;-----------------------------------------------------------------------------
dspErr	lda	trkErr		;test track error flag
	ora	a
	jnz	dspSec		;track already displayed, go display sector

	inr	a		;set track flag non-zero
	sta	trkErr

; First error on this track. Display "Track xx errors: "

	lxi	h,errTrk	;hl->where to put ascii decimal
	lda	trkNum		;a=track with error on it
	call	bin2dec		;track to ascii
	lxi	h,mTrkErr	;display the track error message
	call	dispMsg

; dspSec - display the sector number with an error

dspSec	lxi	h,errSec	;hl->where to put ascii sector
	mov	a,e		;a=sector where error occured
	call	bin2dec
	call	dispMsg		;display the error
	ret

;--------------------------------------------------------------
; bin2dec - Binary byte in A to 2 ASCII digits at (HL)
;   HL is preserved
;--------------------------------------------------------------
bin2dec	mvi	m,' '		;assume zero supression
	sui	10		;value less than 10?
	jc	do1s		;yes, leading blank
	mvi	m,'1'		;have one ten already

loop10	sui	10		;count 10s
	jc	do1s		;done with 10s, do 1s
	inr	m
	jmp	loop10

do1s	adi	'0'+10		;form ASCII 1s digit
	inx	h		;move to 1s position
	mov	m,a
	dcx	h		;restore hl
	ret

;--------------------------------------------------------------
; chkQuit - check for the user to request abort (ctrl-c). If
;    a character is present on the console port, read it and
;    see if ctrl-c. Clobbers A
;--------------------------------------------------------------
chkQuit	call	conIn		;check for console input
	rz

	ani	7fh
	cpi	CTRLC		;abort requested?
	rnz			;no

; Ctrl-C typed while program is running. Return to drive prompt.

	lxi	sp,ourStk	;initialize stack pointer
	jmp	getDrv		;start over asking for drive num

;--------------------------------------------------------------
; pgmExit - Exit to CP/M or to the monitor ROM based on the
;    CP/M flag
;--------------------------------------------------------------
pgmExit	lda	cpmFlag		;running under CP/M?
	ora	a
	jnz	cpmExit		;yes

; Exit to ROM monitor

	lxi	h,mExit		;display "exiting" message
	call	dispMsg
	jmp	MONITOR		;jump to ROM monitor entry point

; CP/M exit. If boot drive was used, prompt user to insert CP/M disk

cpmExit	lda	drvNum		;boot drive used?
	sui	MINDRV
	jnz	noDisk		;not 1, disk prompt not needed

	lxi	h,mCpm		;display "insert cp/m disk"	
	call	dispMsg
	call	rcvCon		;wait for a character

noDisk	mvi	a,MINDRV	;re-select drive A for CP/M 1.4
	sta	drvNum
	call	dSelDrv

	lxi	h,mExit		;display "exiting" message
	call	dispMsg
	jmp	CPMBOOT		;reboot CP/M

;--------------------------------------------------------------
; chkCpm - check if running under CP/M. CP/M flag is set true
;   (non-zero) if yes, cleared otherwise.
;--------------------------------------------------------------
; First, initialize entries for stand-alone

chkCpm	xra	a
	sta	cpmFlag		;clear CP/M flag
	mvi	a,MINDRV+'0'	;ascii for minimum drive number
	sta	mDrvMin		;store in the drive prompt message
	sta	baseDrv		;ascii 1st drive - baseDrv = 0
	mvi	a,MAXDRV+'0'	;ascii for max drive number
	sta	mDrvMax

; Determine if we're under CP/M or standalone. CP/M is assumed if
;   a jump instruction is present at the CP/M warm start location (0)
;   and five more jumps (e.g., a jump table) is present at the
;   jump-to destination.
		
	lda	WBOOT		;see if jump instruction present for CP/M
	cpi	JMPINST
	rnz			;no, not CP/M

; A jump instruction is present at the CP/M warm boot location (0),
;   now see if that jump points to five more jumps. If so, assume CP/M

	lxi	h,WBOOT+1	;point to lsb of jump address
	mov	e,m		;e=low byte of jump
	inx	h
	mov	d,m		;de=destination of jump
	mvi	b,5		;look for 5 more jumps (a jump table)

jmpTest	ldax	d		;a=opcode at jump destination
	sui	JMPINST		;another jump present?
	rnz			;no, not CP/M
	inx	d		;move to next jump
	inx	d
	inx	d
	dcr	b
	jnz	jmpTest

	dcr	a		;a=0ffh
	sta	cpmFlag		;CP/M flag to non-zero = true

; We're running under CP/M. Change drive prompt message to show drive
;    letters instead of drive numbers and change baseDrv to convert
;    an 'A' to the base drive number (MINDRV).

	mvi	a,'A'		;'A' in drive message instead of number
	sta	mDrvMin
	adi	MAXDRV-MINDRV	;max drive letter
	sta	mDrvMax
	mvi	a,'a'		;ascii 1st drive - baseDrv = 0
	sta	baseDrv
	ret

;------------------------------------------------------------------
; sizeRam - determine how much RAM we have for buffering tracks.
;   Sets the bufEnd variable which points to end address of 
;   the last possible track buffer + 1
;------------------------------------------------------------------
; If running under CP/M, use the BIOS pointer to determine the top
;    of available RAM. Otherwise, size RAM manually.

sizeRam	lhld	WBOOT+1		;get address of BIOS jump table+3
	dcx	h		
	dcx	h
	dcx	h		;hl->top of usable ram+1
	lda	cpmFlag		;running under CP/M?
	ora	a
	jnz	ramEnd		;yes, we have the end of RAM

;  Not under CP/M. Find the end of RAM manually.

	lxi	h,(trkBuf+0ffh) AND 0ff00h   ;next 256 byte boundary

ramLoop	mov	a,m		;a=current RAM content
	inr	m		;change RAM
	cmp	m		;did RAM change?
	mov	m,a		;restore RAM
	jz	ramEnd		;end of RAM found

	inr	h		;next page
	jnz	ramLoop

; ramEnd - end of RAM found. Now determine the end address + 1 of the
;   last track buffer that will fit in RAM. Store in bufEnd

ramEnd	xchg			;de=end of RAM + 1
	mvi	a,-((TRKLEN SHR 8) + 1) AND 0ffh
	cmp	d		;force de < (10000h - TRKLEN)
	jnc	topOk

	mov	d,a		;limit max address

topOk	lxi	h,trkBuf	;hl=start of track buffer
	lxi	b,TRKLEN	;bc=length of track in bytes

; Loop increasing hl by TRKLEN until hl > end of RAM.

bfEndLp	dad	b		;hl=hl+track length
	call	cmpHlDe		;compare hl-de
	jc	bfEndLp		;still more room, keep going

; Subtrack one track length from hl, this will be the end address + 1 of
;   the the last track buffer that will fit in RAM

	lxi	b,-TRKLEN	;subtract one track length
	dad	b		;hl = end address of last track + 1
	shld	bufEnd		;save as bufEnd
	ret

;--------------------------------------------------------------------
; cmHlDe - compare HL-DE. Carry set if HL<DE, carry clear if HL>=DE
;--------------------------------------------------------------------
cmpHlDe	mov	a,l		;compare HL-DE, do lsbs first
	sub	e
	mov	a,h		;do msbs
	sbb	d
	ret			;carry set HL<DE, clear HL>=DE

;--------------------------------------------------------------------
; cmDeHl - compare DE-HL. Carry set if DE<HL, carry clear if DE>=HL
;--------------------------------------------------------------------
cmpDeHl	mov	a,e		;compare DE-HL, do lsbs first
	sub	l
	mov	a,d		;do msbs
	sbb	h
	ret			;carry set DE<HL, clear DE>=HL

;--------------------------------------------------------------------
; subDeHl - HL=DE-HL
;--------------------------------------------------------------------
subDeHl	mov	a,e		;subtract DE-HL, do lsbs first
	sub	l
	mov	l,a		;lsb result in l
	mov	a,d		;do msbs
	sbb	h
	mov	h,a		;msb result in h	
	ret

;--------------------------------------------------------------------
; delayMs - delay number of MS specified in A. Clobbers B.
;    Be sure to set the ONEMS equate as required for the
;    target CPU.
;--------------------------------------------------------------------
delayMs	mvi	b,ONEMS		;loops for 1ms
	
dlyLoop	nop			;(4)
	dcr	b		;(5 or 4)
	jnz	dlyLoop		;(10)

	dcr	a		;decrement ms counter
	jnz	delayMs

	ret

;---------------------------------------------------------------------
; Message constants
;---------------------------------------------------------------------
mWelcom	db	cr,lf,lf
	db	'===== Floppy to PC Disk Image Transfer =====',cr,lf
	db	'      (Tarbell DD Controller, ver 1.0)',cr,lf,lf
	db	'Sends an image of a SSSD 8" floppy to a PC via an 88-2SIO'
	db	cr,lf
	db	'or 88-SIO serial port using the XMODEM protocol.',0

mDrive	db	cr,lf,lf,'Insert and specify source drive ('
mDrvMin	db	'x-'
mDrvMax	db	'x) or X to exit: ',0

mPort	db	cr,lf,lf
	db	'Specify the port to use for file transfer',cr,lf
	db	'  1) 88-2SIO port A (which is also the console)',cr,lf
	db	'  2) 88-2SIO port B',cr,lf
	db	'  3) 88-SIO',cr,lf
	db	'Enter 1-3 or X to exit: ',0

mStart	db	cr,lf,lf,'Start XMODEM receive operation on the PC now...',0

mDone	db	cr,lf,lf,'Transfer complete!',cr,lf,0

mXmdm	db	cr,lf,lf,'XMODEM communication failure',cr,lf,0

mNoTrk0	db	cr,lf,lf,'Seek to track 0 failed',cr,lf,0

mTrkErr	db	cr,lf,'Track '
errTrk	db	'xx failed sectors: ',0
errSec	db	'xx ',0

mExit	db	cr,lf,lf,'Exiting...',cr,lf,0

mCpm	db	cr,lf,lf
	db	'Insert CP/M disk into drive A, then press Return...',0


;****************************************************************************
;
;  Hardware specific console and serial I/O routines. 
;     The following four routines must be written to provide a common
;     interface to the hardware on which this program is running. The
;     port number specified for serIn and serOut matches the port number
;     input from the operator via the port menu.
;
;****************************************************************************

; 88-2SIO Serial Board Equates

s2aCtl	equ	010h		;1st port on 88-2SIO board - control register
s2aDat	equ	011h		;1st port on 88-2SIO board - data register
s2bCtl	equ	012h		;2nd port on 88-2SIO board - control register
s2bDat	equ	013h		;2nd port on 88-2SIO board - data register
s2Rdrf	equ	001h		;read data register full flag
s2Tdre	equ	002h		;transmit data register empty flag
s2Rst	equ	003h		;reset command
s28n1	equ	015h		;8N1 selection
s28n2	equ	011h		;8N2 selection

; 88-SIO Serial board Equates

sioCtl	equ	00h		;control port
sioDat	equ	01h		;data port
sioRdrf	equ	00000001b	;-RX Data register full
sioTdre	equ	10000000b	;-TX Data register empty

; The rcvByte subroutine above times a one second timeout with a code
;    loop that calls the hardware specific serIn routine below. ONESEC
;    must be set based on processor speed and the number of cycles in 
;    the serIn call + 59 cycles for the rcvByte code. 

ONESEC	equ	19231		;rcvByte loop count for 1 second

;----------------------------------------------------------------------------
; s2Init - reset and initialize 88-2SIO ports for 8N1
;----------------------------------------------------------------------------
s2Init	mvi	a,s2Rst		;reset and init 2nd 88-2SIO port
	out	s2bCtl
	mvi	a,s28n1		;transfer port as 8N1
	out	s2bCtl

; if not running under CP/M, reset and init 1st 88-2SIO port

	lda	cpmFlag		;running under CP/M?
	ora	a
	rnz			;yes, 2SIO already initialized

	mvi	a,s2Rst		;reset and init 1st 88-2SIO port
	out	s2aCtl
	mvi	a,s28n2		;configure console for 8N2 in case Teletype
	out	s2aCtl
	ret	

;----------------------------------------------------------------------------
; conIn - input character from console
;    inputs:
;    outputs: z true if no character present
;	      z false if character returned in a
;    clobbers none
;----------------------------------------------------------------------------
conIn	in	s2aCtl		;see if a new character is present
	ani	s2Rdrf
	rz			;no character, return zero status

	in	s2aDat		;return character and non-zero status
	ret	

;----------------------------------------------------------------------------
; conOut - output character to console
;    inputs: b = character to send
;    clobbers a
;----------------------------------------------------------------------------
conOut	in	s2aCtl		;wait for OK to transmit
	ani	s2Tdre
	jz	conOut
	mov	a,b		;a=character to transmit
	out	s2aDat		;send it
	ret

;----------------------------------------------------------------------------
; Hardware specific I/O
; serIn - input character from port specified in a
;       0 = 88-2SIO port A
;       1 = 88-2SIO port B
;       2 = 88-SIO
;    inputs: a = port to read from
;    outputs: z true if no character present
;	      z false if character returned in a
;    clobbers none
; 88-2SIO Port A: 53 cycles including return when no character present
; 88-2SIO Port B: 43 cycles including return when no character present
; 88-SIO: 57 cycles including return when no character present
;-----------------------------------------------------------------------------
serIn	dcr	a		;(5)3-way test
	jz	s2InB		;(10)a was 1: 88-2SIO port B
	jp	sioIn		;(10)a was 2: 88-SIO
				;    a was 0: 88-2SIO port A
; Input from 88-2SIO port A

s2InA	in	s2aCtl		;(10+1)see if a new character is present
	ani	s2Rdrf		;(7)
	rz			;(10)no character, return zero status
	in	s2aDat		;return character and non-zero status
	ret	
	
; Input from 88-2SIO port B

s2InB	in	s2bCtl		;(10+1)see if a new character is present
	ani	s2Rdrf		;(7)
	rz			;(10)no character, return zero status

	in	s2bDat		;return character and non-zero status
	ret	

; Input from 88-SIO

sioIn	in	sioCtl		;(10+1)see if a new character is present
	cma			;(4)invert Rx Data Ready flag
	ani	sioRdrf		;(7)
	rz			;(10)no character, return zero status

	in	sioDat		;return character and non-zero status
	ret	

;-----------------------------------------------------------------------------
; Hardware specific I/O
; serOut - output character to port specified in a
;       0 = 88-2SIO port A
;       1 = 88-2SIO port B
;       2 = 88-SIO
;    inputs: a = port to transmit through
;	     b = character to send
;    clobbers a
;-----------------------------------------------------------------------------
serOut	dcr	a		;3-way test
	jz	s2OutB		;a was 1: 88-2SIO port B
	jp	sioOut		;a was 2: 88-SIO
				;a was 0: 88-2SIO port A

; Send character through 88-2SIO port A

S2OutA	in	s2aCtl		;wait for OK to transmit
	ani	s2Tdre
	jz	S2OutA

	mov	a,b		;a=character to transmit
	out	s2aDat		;send it
	ret

; Send character through 88-2SIO port B

s2OutB	in	s2bCtl		;wait for OK to transmit
	ani	s2Tdre
	jz	s2OutB

	mov	a,b		;a=character to transmit
	out	s2bDat		;send it
	ret

; Send character through 88-SIO

sioOut	in	sioCtl		;wait for OK to transmit
	ani	sioTdre
	jnz	sioOut		;active-low flag

	mov	a,b		;a=character to transmit
	out	sioDat		;send it
	ret


;****************************************************************************
;
; Tarbell disk I/O routines (single density controller
;
;****************************************************************************

; Tarbell Disk Drive Controller Equates

FDCBASE	equ	0F8H		;controller base address
FDCCMD	equ	FDCBASE		;179X command register
FDCSTAT	equ	FDCBASE		;179X status register
FDCTRK	equ	FDCBASE+1	;179X track register
FDCSEC	equ	FDCBASE+2	;179X sector register
FDCDATA	equ	FDCBASE+3	;179X data in/out register
FDCWAIT	equ	FDCBASE+4	;FDC stall/wait port
FDCSEL	equ	FDCBASE+4	;FDC drive select port

STEP10	equ	2		;10ms step rate

; Commands for 179X.

cRESTOR	equ	000h+STEP10	;restore, no head load, no verify
cSEEK	equ	018h+STEP10	;seek, head load, no verify
cSTEPIN	equ	058h+STEP10	;step in, update track reg, head loaded
cREAD	equ	088h		;read, head assumed settled
cWRITE	equ	0A8h		;write, head assumed settled
cRESET	equ	0D0h		;reset 179X to idle
cWRTRK	equ	0F4h		;write track command

cWAITHD	equ	004h		;bit for read/write to wait for head settle

; Status bits from 179X

sNOTRDY	equ	80h		;1=not ready
sWRPROT	equ	40h		;1=write protected
sHDLOAD	equ	20h		;1=head is loaded
sSKERR	equ	10h		;1=seek error
sCRCERR	equ	08h		;1=CRC error
sTRACK0	equ	04h		;1=on track zero
sINDEX	equ	02h		;1=index detected
sBUSY	equ	01h		;1=179X busy

sSECERR	equ	10h		;1=sector not found
sWRTFLT	equ	20h		;1=write fault
sDLOST	equ	04h		;1=lost data 

; Combined status flags for status of a seek, read, write

fSEEK	equ	sSKERR+sCRCERR+sNOTRDY+sBUSY
fREAD	equ	sSECERR+sCRCERR+sDLOST+sNOTRDY+sBUSY
fWRITE	equ	fREAD+sWRPROT+sWRTFLT

;--------------------------------------------------------------
; dRead - Read sector on current track.
; On Entry:
;    Drive is selected, on proper track, head loaded
;    hl->sector buffer
;    e = sector number to read
; On Exit:
;    Z flag set = good, Z flag clear = error
;    clobbers h,l
;--------------------------------------------------------------
dRead	di			;disable interrupts
	mov	a,e		;give sector number to FDC
	out	FDCSEC

	lda	fWaitHd		;load head settle (E) flag
	ori	cREAD		;combine with read command
	out	FDCCMD

	xra	a		;no head settle wait after 1st read
	sta	fWaitHd

dRdLoop	in	FDCWAIT		;wait until byte available
	ora	a		;sector finished?
	jp	dRdDone		;yes

	in	FDCDATA		;store next byte in buffer
	mov	m,a

	inx	h		;bump memory pointer
	jmp	dRdLoop

dRdDone	in	FDCSTAT		;get status of the read
	ani	fREAD		;any of these bits is an error
	ei			;re-enable interrupts
	ret

	if	0		;verify and write not used
;--------------------------------------------------------------
; dVerify - Verify sector on current track. The track is
;    read to verify CRC, but not compared
; On Entry:
;    Drive is selected, on proper track, head loaded
;    e = sector number to verify
; On Exit:
;    Z flag set = good, Z flag clear = error
;    clobbers none
;--------------------------------------------------------------
dVerify	di			;disable interrupts
	mov	a,e		;give sector number to FDC
	out	FDCSEC

	lda	fWaitHd		;load head settle (E) flag
	ori	cREAD		;combine with read command
	out	FDCCMD

	xra	a		;no head settle wait after 1st read
	sta	fWaitHd

dVfLoop	in	FDCWAIT		;wait until byte available
	ora	a		;sector finished?
	jp	dVfDone		;yes

	in	FDCDATA		;get next byte
	nop			;waste some time
	nop

	jmp	dVfLoop

dVfDone	in	FDCSTAT		;get status of the read
	ani	fREAD		;any of these bits is an error
	ei			;re-enable interrupts
	ret

;--------------------------------------------------------------
; dWrite - Write a sector on current track
; On Entry:
;    Drive is selected, on proper track, head loaded
;    hl->buffer address
;    e = sector number to write
; On Exit:
;    Z flag set = good, Z flag clear = error
;   clobbers h,l
;--------------------------------------------------------------
dWrite	di			;disable interrupts
	mov	a,e		;give sector number to FDC
	out	FDCSEC

	lda	fWaitHd		;load head settle (E) flag
	ori	cWrite		;combine with write command
	out	FDCCMD

	xra	a		;no head settle wait after 1st write
	sta	fWaitHd

dWrLoop	in	FDCWAIT		;wait until ready for byte
	ora	a		;sector finished?
	jp	dWrDone		;yes

	mov	a,m		;a=next byte to write
	out	FDCDATA

	inx	h		;bump memory pointer
	jmp	dWrLoop

dWrDone	in	FDCSTAT		;get status of the write
	ani	fWRITE		;any of these bits is an error
	ei			;re-enable interrupts
	ret

;--------------------------------------------------------------
; dChkWP - check if disk is write protected. 
; On Entry:
;    disk already selected
; On Exit:
;    returns if disk is not protected. Otherwise, an error
;    message is displayed and the program started over.
; Clobbers none
;--------------------------------------------------------------
dChkWP	in	FDCSTAT
	ani	sWRPROT		;get write protect bit alone
	rz			;return if not protected

; Disk write protected. Display error and restart program.

	lxi	h,mWrtPrt	;otherwise, display error message
	jmp	errMsg		;display error and restart

	endif

;--------------------------------------------------------------
; dSeek - Seek track specified in L. Selects drive and loads
;    head. If the head was not already loaded, then the E bit
;    (wait for head settle one-shot) is set in fWaitHd for
;    OR'ing into the subsequent read/write command.
; On Entry:
;    l = desired track
; On Exit:
;    Z flag set = good, Z flag clear = error
; Clobbers none
;--------------------------------------------------------------
dSeek	call	dSelDrv		;make sure drive is selected

; See if head is currently loaded. Use the reset (interrupt)
;    command to ensure the status register is type I so it
;    includes the head status bit. If not loaded, set the E
;    bit (wait for head-settle one-shot) in fWaitHd which is
;    OR'd into the subsequent read/write command.

	mvi	a,cRESET	;reset command when idle forces
	out	FDCCMD		;   status to type I status
	nop			;delay

	in	FDCSTAT		;see if head is currently loaded
	ani	sHDLOAD
	mvi	a,cWAITHD	;E flag set for R/W commands
	jnz	doSeek		;head already loaded

	sta	fWaitHd		;otherwise, set E flag

doSeek	mov	a,l		;output track number to 179X
	out	FDCDATA

	mvi	a,cSEEK		;issue seek command
	out	FDCCMD
	in	FDCWAIT		;wait for seek to complete

	in	FDCSTAT		;did seek work?
	ani	fSEEK		;any of these bits is an error
	ret

;--------------------------------------------------------------
; dRestor - Selects drive, loads heads and restores to track 0.
;    If restore fails, message display and program restarted
;    at getDrv.
; On Entry:
;    drvNum = drive to be selected and restored to track zero
; On Exit:
;    drive selected and on track zero
; Clobbers none 
;--------------------------------------------------------------
dRestor	call	dSelDrv		;make sure drive is selected

	mvi	a,cRESTOR	;issue restore to track zero
	out	FDCCMD
	in	FDCWAIT		;and wait for restore to complete

	in	FDCSTAT		;verify restore worked
	ani	fSEEK		;isolate seek bits
	rz			;success

; restore failed

	lxi	h,mNoTrk0

errMsg	call	dispMsg
	lxi	sp,ourStk	;initialize stack pointer
	jmp	getDrv		;start over asking for drive num

;--------------------------------------------------------------
; dSelDrv - Select and wait for drive specified in drvNum 
;    to be ready.
; On Entry:
;    drvNum = drive to be selected
; On Exit:
;    drive selected and ready, 179X not busy
; Clobbers none
;--------------------------------------------------------------
dSelDrv	lda	drvNum		;a=desired drive
	add	a		;shift left 4 with zero fill
	add	a
	add	a
	add	a
	out	FDCSEL		;select the drive

; reset the 179X and wait for not busy

	mvi	a,cRESET	;ensure 179X is idle
	out	FDCCMD
	xthl			;waste some time
	xthl

; drive selected, 179X idle, wait for drive ready

dWtRdy	in	FDCSTAT
	rlc			;not ready bit in carry
	jc	dWtRdy		;wait for ready
	ret

;--------------------------------------------------------------
; dNxtSec - wait for next (any) sector. For the 179X, this
;    routine simply increments and wraps the sector number
;    passed in e, then falls into dWtSec to return bc with
;    the offset of the sector within the track buffer.
; On Entry:
;    Drive is selected, motor is running
;    e = most recent sector number
; On Exit:
;    e = next sector sector number
;    bc = byte offset of this sector in a track
;--------------------------------------------------------------
dNxtSec	inr	e		;move to next sector
	jz	dSec1		;in case uninitialized rolled to 0

	mov	a,e		;see if past end
	cpi	NUMSEC+1	;verify between 1 and 26
	jc	dWtSec		;good sector, compute bc

dSec1	mvi	e,1		;restart at sector 1
				;fall into dWtSec

;--------------------------------------------------------------
; dWtSec - wait for sector specified in e. For the 179X
;    controller, this routine simply returns the offset
;    of the sector within this track in bc.
; On Entry:
;    Drive is selected, motor is running
;    e = desired sector number (must be 1-26 for 179X)
; On Exit:
;    e = sector number
;    bc = byte offset of this sector in a track
;--------------------------------------------------------------
dWtSec	mov	a,e		;save the computed sector
	sta	lastSec

; compute bc=128*(sector-1)

	sui	1		;zero index and clear carry
	rar
	mov	b,a		;b=sector >> 1

	rar			;put lsbit into msbit	
	ani	80h
	mov	c,a		;bc=128*e
	ret

;**************************************************************************
; 
;  Data area
;
;**************************************************************************
; disk variables

drvNum	ds	1		;drive number to use
trkNum	ds	1		;track number to read
lastSec	ds	1		;last sector accessed on track
fWaitHd	ds	1		;E bit (wait head settle) flag
trkPtr	ds	2		;pointer into trkBuf at track boundaries
bufEnd	ds	2		;end address + 1 of last track spot in RAM

; retry logic variables

rdRtry	ds	1		;disk read retry counter
rtStep	ds	1		;current retry step
trkErr	ds	1		;non zero if error occured on track

; xmodem variables

xfrPort	ds	1		;pseudo port for file transfer
xmRetry	ds	1		;xmodem retry counter
blkNum	ds	1		;current xmodem block number
crcFlag	ds	1		;non zero if using CRC instead of checksum
crc16	ds	2		;crc-16 result
sndPtr	ds	2		;pointer for start of XMODEM send

; misc variables

cpmFlag	ds	1		;non-zero if running under CP/M
baseDrv	ds	1		;ascii 1st drive - baseDrv = 0
	ds	64		;stack space
ourStk	equ	$

; track buffer runs from here to the end of memory

	ds	PKTLEN		;space for pre-pended unsent data
trkBuf	equ	$

	end

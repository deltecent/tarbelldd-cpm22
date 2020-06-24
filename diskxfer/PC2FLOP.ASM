;******************************************************************************
;
;  PC2Flop - Transfer disk image from PC to floppy over serial port.
;		(for Tarbell dourble density controller)
;
;	This program writes a SSSD soft-sectored 8" floppy with a disk image
;	transmitted from a PC. The image is transmitted through a 2SIO at I/O
;	address 010h or 12h, or an SIO at address 0 using the XMODEM protocol.
;
;	The program talks directly to the Tarbell controller and does not
;	require CP/M or an OS to function.
;
;	Since this is a soft sectored controller, the destination disk must
;	have been formatted at some point. To allow this program to create
;	a new disk for a "cold" machine, it offers a format disk option. 
;
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
;	1.0	 06/24/20   Modify Tarbell SD PC2FLOP to support double
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
RDTRIES	equ	5		;number of read (verify) attempts
WRTRIES	equ	4		;number of write attempts

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

; CP/M Equates

WBOOT	equ	0		;warm boot jump location

; Misc equates

CR	equ	13		;ascii for carriage return
LF	equ	10		;ascii for line feed
DEL	equ	7fh		;ascii DEL
BS	equ	08h		;ascii backspace
CTRLC	equ	03		;ascii for control-c
JMPINST	equ	0c3h		;jump instruction opcode

	org	0100h	
;-----------------------------------------------------------------------------
;  Initialize for transfer
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

; Restore to track 0, verify drive is not write protected

	call	dRestor		;restore to track 0 (selects drive)
	call	dChkWP		;check write protect (aborts to getDrv)

; Prompt whether or not to format the disk

	lxi	h,mFormat	;display format prompt
	call	dispMsg
	call	rcvCon		;get byte
	ori	20h		;upper to lower case, nums not affected
	cpi	'y'		;format requested?
	cz	format		;yes, go format disk

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

; Prompt the user to insert the disk to write, initialize, then start
;   sending NAK to start the XMODEM reception.

	lxi	h,mStart	;display start file transfer prompt
	call	dispMsg

	xra	a		;init track we're reading to zero
	sta	trkNum
	sta	lastSec		;last sector accessed

	inr	a		;init xmodem block number to one
	sta	blkNum

	lxi	h,trkBuf	;trkBuf is initial starting point for
	shld	rcvPtr		;   XMODEM receive

	mvi	a,NAK		;send starting nak after purging input data
	call	purgSio

;-----------------------------------------------------------------------------
;  mainLp - Receive as many packets as will fit into RAM and then write
;      tracks to disk. Repeat until entire disk is written. 
;-----------------------------------------------------------------------------
mainLp	call	bufPkts		;buffer as many packets as possible
	xchg			;de=start of last packet received
	lxi	h,trkBuf	;hl=start of track buffer
	shld	trkPtr		;writing will start from here
	call	cmpDeHl		;compare last packet start - trkBuf
	jc	allDone		;nothing received but an EOT

; trkLoop - write tracks until all disk tracks have been written or all
;    the tracks in the buffer have been written.
	
trkLoop	call	wrtTrk		;write a track (hl returns->next track)

	lda	trkNum		;increment track number (preserve HL)
	inr	a
	sta	trkNum	
	cpi	NUMTRK		;done all tracks?
	jz	allDone		;yes

	xchg			;de=next track pointer
	lhld	rcvPtr		;hl=start of last packet received
	call	cmpHlDe		;compare rcvPtr-start of next track
	jnc	trkLoop		;another track is present

; All the buffered tracks have been written. Move any bytes left over
;    from the xmodem receive to the start of trkbuf. Adjust rcvPtr
;    to the end of that data which is where reception of the next
;    packet will begin.

	call	subHlDe		;hl=hl-de = left over byte count - PKTLEN
	mov	a,l		;a=left over count - PKTLEN
	adi	PKTLEN		;a=left over byte count
	mov	b,a		;b=left over byte count (bytes to move)
	lxi	h,trkBuf	;hl->start of trkBuf
	jz	mvDone		;no bytes to move, we're done
	
; Copy the leftover data to the start of trkBuf. The next XMODEM receive
;   sequence will start at the end of this copied data instead of at the
;   start of trkBuf.

moveLp	ldax	d		;move from end of trkBuf to start of trkBuf
	mov	m,a
	inx	h		;hl->starting bytes of trackbuf
	inx	d		;de->unwritten bytes from end of trkBuf		
	dcr	b
	jnz	moveLp

mvDone	shld	rcvPtr		;save address where to receive next packet

	mvi	a,ACK		;ACK the last packet or EOT
	call	sndByte

	jmp	mainLp		;go receive more packets

; allDone - The disk is completely written. ACK the final packet (or EOT),
;     display the "transfer complete" message and start the program over.

allDone	mvi	a,ACK		;ACK the final packet or EOT
	call	sndByte

	lxi	h,mDone		;hl->done message
	call	dispMsg
	jmp	getDrv		;start over asking for drive num

;-----------------------------------------------------------------------------
; bufPkts - Receive XMODEM packets until we fill all the track buffer
;   space available. Reception starts at the address pointed to by
;   rcvPtr. Reception is stopped when the last packet exactly
;   fills or "crosses" the end of the last track spot in RAM. rcvPtr is
;   updated on exit to point to the start of the last packet received.
;   The disk write routines use this pointer to know where data ends and
;   then update rcvPtr to start to where to begin receiving new packets.
;-----------------------------------------------------------------------------
bufPkts	call	rcvPkt		;receive a packet
	xchg			;de=current xmodem receive pointer
	cpi	EOT		;EOT received?
	jz	bufDone		;yes, buffering is done

	lhld	bufEnd		;hl=end of buffering space
	call	cmpDeHl		;compare current-end	
	jnc	bufDone		;past or at end, buffering is done

	mvi	a,ACK		;otherwise, ACK the packet
	call	sndByte
	xchg			;put xmodem rcv pointer back in HL
	jmp	bufPkts		;buffer some more

; bufDone - no more room for packets. Update rcvPtr to point to the 
;   start of the last packet received so the disk write routines know
;   where data ends.

bufDone	xchg			;hl=current xmodem receive pointer
	lxi	d,-PKTLEN
	dad	d		;hl=hl-PKTLEN = start of last rcv'd packet
	shld	rcvPtr		;save use by write tracks
	ret

;-----------------------------------------------------------------------------
; rcvPkt - receive an xmodem format 128 byte packet. HL points to the 128 byte
;    buffer to receive. HL is updated by 128 bytes after each succuessful
;    reception of a new 128 byte packet.
;-----------------------------------------------------------------------------
nakPkt	pop	h		;get HL back
	mvi	a,NAK
	call	purgSio		;purge receive for 1s then transmit NAK

;wait for SOH or EOT

rcvPkt	push	h		;save HL for retries
waitSoh	call	chkQuit		;check for user abort
	mvi	a,3		;3 second timeout for soh
	call	rcvByte		;receive character with timeout
	jz	nakPkt		;timeout

	cpi	SOH		;SOH received?
	jz	haveSoh

	cpi	EOT		;EOT to say we're done?
	jnz	waitSoh		;no, keep looking for SOH

	pop	h		;undo the entry push
	ret			;return with EOT

;  Have SOH, receive block number and not block number

haveSoh	mvi	a,1		;one second timeout once inside a packet
	call	rcvByte		;get the block number
	jz	nakPkt		;timeout, NAK and start over

	sta	rcvBlk		;save the received block number
	mvi	a,1		;one second timeout
	call	rcvByte		;get not block number
	jz	nakPkt		;timeout, NAK and start over

	sta	rcvNBlk		;save not block number

;  Receive the 128 byte block

	mvi	e,0		;init checksum
	mvi	d,pktLen	;d is byte counter
pktLoop	mvi	a,1		;one second timeout
	call	rcvByte		;get next data byte
	jz	nakPkt		;timeout

	mov	m,a		;store the character
	inx	h		;point to next byte
	add	e		;update the checksum
	mov	e,a
	dcr	d		;decrement bytes remaining
	jnz	pktLoop

;  Verify the checksum

	mvi	a,1		;one second timeout
	call	rcvByte		;get the checksum
	jz	nakPkt		;timeout

	cmp	e		;checksum match?
	jnz	nakPkt		;no, packet error

;  Checksum good. Verify block numbers

	lda	rcvNBlk		;verify rcvBlk = not (rcvNBlk)
	cma			;A should = block number now
	mov	b,a		;save in b
	lda	rcvBlk
	cmp	b		;compare rcvBlk = not(rcvNBlk)?
	jnz	nakPkt		;no, error

	lda	blkNum		;compare rcvBlk = expected blkNum
	cmp	b
	jnz	nakPkt		;nak if not the same (also nak's re-send)

	inr	a		;increment expected block number
	sta	blkNum
	pop	b		;get HL off stack, but don't clobber HL
	xra	a		;return a zero
	ret

;-----------------------------------------------------------------------------
; wrtTrk - write and verify NUMSEC sectors to the current track in trkBuf
;   as pointed to by trkPtr. After the track is written, trkPtr is updated
;   by the length of a track to point to the next track buffer. This
;   saved value is also returned in HL.
;-----------------------------------------------------------------------------
wrtTrk	lxi	h,trkNum	;get desired track from trkNum	
	mov	l,m		;and put into l
	call	dSeek		;seek to the track

	call	dChkWP		;check write protect

	mvi	a,WRTRIES	;init write retry counter
	sta	wrRetry

; To make sure the head is settled following the track step, yet still
;    minimize latency, add 5 to the last sector number accessed (and
;    wrap as needed). When this sector number is used in the call to
;    dNxtSec, a total delay of about 32ms has transpired since the step
;    was issued. This give 10ms for the step plus 22ms of head settle time.

	lda	lastSec		;last sector accessed
	adi	5		;bump by five sector times
	cpi	NUMSEC+1	;past 26?
	jc	noWrap

	sui	NUMSEC		;wrap to sector 1-n

noWrap	mov	e,a		;e=new "last" sector number

; rtryWrt - write a track and the retry entry point.

rtryWrt	mvi	d,NUMSEC	;d=count of sectors to write
	
; wrtLoop - write a full track starting after the sector in e.

wrtLoop	call	dNxtSec		;get next sector number and offset
	lhld	trkPtr		;hl->start of current track buffer
	dad	b		;bc has offset of sector within track
	call	dWrite		;write the sector
	jnz	wrtErr		;write failed

	dcr	d		;decrement sector count
	jnz	wrtLoop		;loop until all sectors written

; Verify the track just written

	mvi	d,NUMSEC	;d=count of sectors to verify

vfyLoop	call	chkQuit		;check for ctrl-c
	call	dNxtSec		;get next sector number and offset
	lhld	trkPtr		;hl->start of current track buffer
	dad	b		;bc has offset of sector within track
	call	dVerify		;verify the sector
	jnz	vfyRtry		;error, go to retry logic

vfyNext	dcr	d		;decrement sector count
	jnz	vfyLoop		;loop until all sectors verified

; Track verified, increment trkPtr to memory location for next track
;    and exit.

	lhld	trkPtr		;hl=current track pointer
	lxi	d,TRKLEN	;de=bytes in a track
	dad	d		;hl=start of next track in trkBuf
	shld	trkPtr
	ret

; vfyRtry - verify failed, retry reads followed by a re-write
;   of the track in needed.

vfyRtry	mvi	a,RDTRIES	;init retry counter
	sta	rdRetry

retryLp	call	chkQuit		;check for ctrl-c
	call	dWtSec		;wait for sector specified in e
	lhld	trkPtr		;hl->start of current track buffer
	dad	b		;bc has offset of sector within track
	call	dVerify		;verify the sector
	jz	vfyNext		;success, go verify next sector

; Re-verify failed. Decrement retry count and try again if not zero. Once
;   retry counter expires, do another write.

	lxi	h,rdRetry	;decrement the read retry counter
	dcr	m
	jnz	retryLp		;try again

; read re-tries expired, decrement the write retry count and re-write
;    if not expired

	lxi	h,wrRetry	;decrement the write retry counter
	dcr	m
	jnz	rtryWrt		;retry starting with the write

	jmp	vfyErr		;display the error and restart

;-----------------------------------------------------------------------------
; Disk write verify failure. Display the track and sector with the error. 
;    Restart the program.
;-----------------------------------------------------------------------------
wrtErr	ani	sSECERR		;sector not found error?
	jz	vfyErr		;no

	lxi	h,mNoSec	;'sector not found, format needed?'
	call	dispMsg

vfyErr	lxi	h,errTrk	;hl->where to put ascii decimal
	lda	trkNum		;a=track with error on it
	call	bin2dec		;track to ascii

	lxi	h,errSec	;hl->where to put ascii sector
	mov	a,e		;a=sector where error occured
	call	bin2dec

	lxi	h,mDskErr	;display the error message
	call	dispMsg
	lxi	sp,ourStk	;initialize stack pointer
	jmp	getDrv		;start over asking for drive num

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
; purgSio - wait for 1 second of idle time on receive line, then transmit the
;	character passed in A (usually ACK or NAK). Clobbers b
;-----------------------------------------------------------------------------
purgSio	push	a

purge	mvi	a,1		;1 second timeout
	call	rcvByte		;wait for 1 second without activity
	jnz	purge

	pop	a		;get back the character to send
				;fall through to sndByte
;-----------------------------------------------------------------------------
; sndByte - send the byte in a through the specified transfer port. 
;     Clobbers b. (assuming serOut clobbers only a).
;-----------------------------------------------------------------------------
sndByte	mov	b,a		;b=byte to transmit
	lda	xfrPort		;a=port to use for transfer
	jmp	serOut		;send the character

;-----------------------------------------------------------------------------
; rcvByte - Receive a byte from the specified transfer port. A wait timeout
;     in seconds is specified in a. If a timeout occurs, zero is returned in
;     a and the zero flag is true. Otherwise, the character is returned in a 
;     (could be zero) and the zero flag is false. ONESEC must be set based
;     on processor speed and the number of cycles in the serIn call + 59.
;     Clobbers a, b and c.
;-----------------------------------------------------------------------------
rcvByte	push	d		;save d, e
	mov	d,a		;save timeout in d

initSec	lxi	b,ONESEC	;one second timeout 104 cycles per loop

rcvWait	lda	xfrPort		;(13) a=port to use for transfer
	call	serIn		;(17+45) look for a byte
	jnz	haveChr		;(10) byte received

	dcx	b		;(5) otherwise, decrement timer
	mov	a,b		;(5) one second expire?
	ora	c		;(4)
	jnz	rcvWait		;(10) no, keep waiting

; one second timeout has occured. Decrement the seconds counter.

	dcr	d		;decrement seconds counter
	jnz	initSec		;initialize for another 1 second count
haveChr	pop	d		;restore d, e
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

; ramEnd - end of RAM found. Subtrack 256 bytes from this to make room
;   for xmodem packet overflow at the end. Determine the end address + 1
;   of the last track buffer that will fit in RAM. Store in bufEnd

ramEnd	xchg			;de=end of RAM + 1
	mvi	a,-((TRKLEN SHR 8) + 1) AND 0ffh
	cmp	d		;force de < (10000h - TRKLEN)
	jnc	topOk

	mov	d,a		;limit max address

topOk	dcr	d		;subtract 256 bytes from end of RAM
	lxi	h,trkBuf	;hl=start of track buffer
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
; subHlDe - HL=HL-DE
;--------------------------------------------------------------------
subHlDe	mov	a,l		;subtract HL-DE, do lsbs first
	sub	e
	mov	l,a		;lsb result in l
	mov	a,h		;do msbs
	sbb	d
	mov	h,a		;msb result in h	
	ret

;-----------------------------------------------------------------------------
;   Data Area
;-----------------------------------------------------------------------------
mWelcom	db	cr,lf,lf
	db 	'===== PC to Floppy Disk Image Transfer =====',cr,lf
	db	'      (Tarbell DD Controller, ver 1.0)',cr,lf,lf
	db	'Writes a SSSD 8" floppy with a disk image received via an'
	db	cr,lf
	db	'88-2SIO or 88-SIO serial port using the XMODEM protocol.',0

mDrive	db	cr,lf,lf,'Insert and specify destination drive ('
mDrvMin	db	'x-'
mDrvMax	db	'x) or X to exit: ',0

mPort	db	cr,lf,lf
	db	'Specify the port to use for file transfer',cr,lf
	db	'  1) 88-2SIO port A (which is also the console)',cr,lf
	db	'  2) 88-2SIO port B',cr,lf
	db	'  3) 88-SIO',cr,lf
	db	'Enter 1-3 or X to exit: ',0

mStart	db	cr,lf,lf
	db	'Start XMODEM send now...',0

mDone	db	cr,lf,lf,'Creation of new disk successful!',cr,lf,0

mNoTrk0	db	cr,lf,lf,'Seek to track 0 failed',cr,lf,0

mNoSec	db	cr,lf,lf,'Sector not found - disk not formatted?',0

mDskErr	db	cr,lf,lf,'Write failure on track '
errTrk	db	'xx, sector '
errSec	db	'xx. Disk creation aborted.',cr,lf,0

mWrtPrt	db	cr,lf,lf,'Disk is write protected',cr,lf,0

mExit	db	cr,lf,lf,'Exiting...',cr,lf,0

mCpm	db	cr,lf,lf
	db	'Insert CP/M disk into drive A, then press Return...',0

mFormat	db	cr,lf,lf,'Format the target disk? ',0

mFmting	db	cr,lf,'  Formatting SSSD',0

mFmtDon	db	cr,lf,'  Format complete',0

mFmtErr	db	cr,lf,lf,'Formatting failed',cr,lf,0


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
; Tarbell disk I/O routines (single density controller)
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

	if	0		;read not used
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

	endif

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
;    e = desired sector number (must be 1-26 for 179X in
;    single density mode)
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

;**************************************************************
;
; format - format disk routine taken from format.asm
;
;**************************************************************
format	lxi	h,mFmting	;'formatting...' message
	call	dispMsg

	mvi	l,0		;set track number to 0
	mvi	h,77		;set total tracks to 77

; nxtTrk - do the next track

nxtTrk	call	chkQuit		;see if abort requested
	
	mvi	d,1		;sector cnt to 0
	mvi	e,26		;set max # sectors -1 
	mvi	b,40		;gap 4 preindex 40 bytes of ff

	di			;disable interrupts
	mvi	a,cWRTRK	;load track write command
	out	FDCCMD		;issue track write

; write preindex fill

preInd	in	FDCWAIT		;wait for drq
	ora	a		;set flags
	jp	fmtFail		;jmp out if error

	mvi	a,0FFh		;load preindex fill
	out	FDCDATA		;write it on disk
	dcr	b		;count = count - 1
	jnz	preInd		;go back till b = 0

	mvi	b,6

preIn1	in	FDCWAIT
	ora	a
	jp	fmtFail

	xra	a
	out	FDCDATA
	dcr	b
	jnz	preIn1

; write address mark on track

	in	FDCWAIT		;wait for drq
	ora	a		;set flags
	jp	fmtFail		;jmp out if error

	mvi	a,0FCh		;load address mark
	out	FDCDATA		;write it on disk

; post index gap

postGap	mvi	b,26		;set # of bytes

postId	in	FDCWAIT		;wait for drq
	ora	a		;set flags
	jp	fmtFail		;jmp out if error

	mvi	a,0FFh		;load fill data
	out	FDCDATA		;write it on disk
	dcr	b		;count = count - 1
	jnz	postId		;if not 0 go back

; pre id section

	mvi	b,6		;get # of bytes

sector	in	FDCWAIT		;wait for drq
	ora	a		;set flags
	jp	fmtFail		;jmp out if error

	xra	a		;make a = 0
	out	FDCDATA		;write it on track
	dcr	b		;count = count - 1
	jnz	sector		;jmp back if not done

; write id address mark

	in	FDCWAIT		;wait for drq
	ora	a		;set flags
	jp	fmtFail		;if error jmp out

	mvi	a,0FEh		;get address mark
	out	FDCDATA		;write it on disk

; write track number on disk

	in	FDCWAIT		;wait for drq
	ora	a		;set flags
	jp	fmtFail		;jmp out if error

	mov	a,l		;get track number
	out	FDCDATA		;write it on disk

; write one byte of 00

	in	FDCWAIT		;wait for drq
	ora	a		;set flags
	jp	fmtFail		;jmp out if error

	xra	a		;set a to 0
	out	FDCDATA		;write it on disk

; write sector # on disk

	in	FDCWAIT		;wait for drq
	ora	a		;set flags
	jp	fmtFail		;jmp out if error

	mov	a,d		;get sector #
	out	FDCDATA		;write it on disk

; one more byte 0

	in	FDCWAIT		;wait for drq
	ora	a		;set flags
	jp	fmtFail		;jmp out if error

	xra	a		;set a to 00
	out	FDCDATA		;write it on disk
	inr	d		;bump sect. #

; write 2 crc's on this sector

	in	FDCWAIT		;wait for drq
	ora	a		;set flags
	jp	fmtFail		;jmp out if error

	mvi	a,0F7h		;get crc pattern
	out	FDCDATA		;write it on disk

; pre data 11 bytes FF, 6 bytes 00

	mvi	b,11		;set count
preDat	in	FDCWAIT		;wait for drq
	ora	a		;set flags
	jp	fmtFail		;jmp out if error

	mvi	a,0FFh		;set a to FF
	out	FDCDATA		;write it on disk
	dcr	b		;reduce count by 1
	jnz	preDat		;go back if not done

	mvi	b,6

preDa1	in	FDCWAIT
	ora	a
	jp	fmtFail

	xra	a 
	out	FDCDATA
	dcr	b
	jnz	preDa1

; data address mark

	in	FDCWAIT		;wait for drq
	ora	a		;set flags
	jp	fmtFail		;jmp out if error

	mvi	a,0FBh		;get data address mark
	out	FDCDATA		;write it on disk

; fill data field with E5

	mvi	b,128		;set field length
dFill	in	FDCWAIT		;wait for drq
	ora	a		;you know what
	jp	fmtFail		;happens here by now

	mvi	a,0E5h		;get fill byte
	out	FDCDATA		;write it on disk
	dcr	b		;drop 1 from count
	jnz	dFill		;do till 00

; write CRC's

	in	FDCWAIT		;wait till drq
	ora	a		;set flags
	jp	fmtFail		;jmp out if error

	mvi	a,0F7h		;get crc byte
	out	FDCDATA		;write it on disk

; end of sector fill

	dcr	e		;reduce sector count
	jz	endTrk		;if 0 do end of track rtn

datGap	in	FDCWAIT		;wait for drq
	ora	a		;set flags	
	jp	fmtFail		;jmp out if error

	mvi	a,0FFh		;get fill character
	out	FDCDATA		;write it on disk
	jmp	postGap		;go back for more

; endTrk - fill with FFh until command ends at index hole

endTrk	in	FDCWAIT		;wait for drq or intrq
	ora	a		;set flags
	jp	done		;jmp out if error

	mvi	a,0FFh		;load a with FFh
	out	FDCDATA		;write it on disk
	jmp	endTrk		;do until intrq

; done - check for error from the write track command. Wait for trim
;     erase delay in case the drive has tunnel erase heads, then
;     move to the next track.

done	in	FDCSTAT		;read status of write track command
	ani	0ffh		;test for any flag
	jnz	fmtFail		;if err go to err print rtn

	mvi	b,87		;delay 500us min (1ms at 2mhz)

trimDly	dcr	b		;(5)
	nop			;(4)
	nop			;(4)
	jnz	trimDly		;(10)


; decrement track counter, check for finish

	inr	l		;bump track #
	dcr	h		;trk count =count -1
	jnz	bmpTrk		;if not 0 then do more

	ei			;re-enable interrupts
	call	dRestor		;restore to track 0

	lxi	h,mFmtDon	;format complete message
	jmp	dispmsg		;display message and return

; bmpTrk - move to next track, jump back to nxtTrk to repeat

bmpTrk	ei			;re-enable interrupts
	mvi	a,cSTEPIN	;step in to next track
	out	FDCCMD
	in	FDCWAIT		;wait til done
				
	mvi	b,'.'		;display pacifier per track
	call	conout

	jmp	nxtTrk

; fmtFail

fmtFail lxi	h,mFmtErr	;format fail message
	jmp	errmsg		;display error and start over


;**************************************************************************
; 
;  Data area
;
;**************************************************************************
; Disk variables

drvNum	ds	1		;drive number to use
trkNum	ds	1		;track number to read
lastSec	ds	1		;last sector accessed on track
fWaitHd	ds	1		;E bit (wait head settle) flag
trkPtr	ds	2		;pointer into trkBuf (start of next track)
bufEnd	ds	2		;end address + 1 of last track spot in RAM

; Retry logic variables

rdRetry	ds	1		;disk read retry counter
wrRetry	ds	1		;disk write retry counter

; Xmodem variables

xfrPort	ds	1		;pseudo port for file transfer
blkNum	ds	1		;current xmodem block number
rcvBlk	ds	1		;block number received
rcvNBlk	ds	1		;"not" block number received
rcvPtr	ds	2		;pointer for start of XMODEM send

; Misc variables

cpmFlag	ds	1		;non-zero if running under CP/M
baseDrv	ds	1		;ascii 1st drive - baseDrv = 0
	ds	96		;stack space
ourStk	equ	$

; Track buffer runs from here to the end of memory

trkBuf	equ	$

	end


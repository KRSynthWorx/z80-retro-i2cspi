;--------------------------------------------------------------------------
; led_test.asm - routine to test the MAX7219 LED display driver 
;				 with up to 8 - 8x8 matrix displays
;--------------------------------------------------------------------------

; MAX7219 SPI LED driver control registers
DECODE_MODE:	EQU	0x09
INTENSITY:		EQU	0x0A
SCAN_LIMIT:		EQU	0x0B
SHUTDOWN:		EQU	0x0C
DISPLAY_TEST:	EQU	0x0F

; Display position bit masks
DISP_ALL:		EQU	0xFF
DISP_8:			EQU	0x80		; MSB (leftmost) display
DISP_7:			EQU 0x40
DISP_6:			EQU 0x20
DISP_5:			EQU	0x10
DISP_4:			EQU	0x08
DISP_3:			EQU 0x04
DISP_2:			EQU	0x02
DISP_1:			EQU	0x01		; LSB (rightmost) display

	ORG		0x1000

	CALL	DSPMSG
	DEFB	CR,LF,LF,'Z80-Retro! I2C/SPI Master Interface test routine',CR,LF
	DEFB	'Test MAX7219 SPI 8x8 matrix LED display drivers..',BIT7+'.'

	CALL	CRLF

	LD		A,CS1|MSB_LSB|MODE0	; CS1 active, MSB->LSB bit order
								; SPI MODE (CPOL = 0, CPHA = 0)
	CALL	SPI_INIT			; Initialize the SPI port with these values

;**************************************************************************
; REQUIRED - set the number [n] of 8x8 matrix displays chained in the 
;			 system, rightmost display is DISP_1, leftmost display is DISP_n
;**************************************************************************
	LD		A,0x04				; Set [n] number of displays in the system
	LD		(NUM_DISP),A		; Save it

; Required - insure no display is in test mode
	LD		A,DISPLAY_TEST
	LD		(MX_ADDR),A
	LD		A,0x00				; Normal mode
	LD		(MX_DATA),A
	LD		A,DISP_ALL
	CALL	MAX7219_CMD

; Required - set to no decoding when using the 8x8 matrix displays
	LD		A,DECODE_MODE
	LD		(MX_ADDR),A
	LD		A,0x00				; No decoding
	LD		(MX_DATA),A
	LD		A,DISP_ALL
	CALL	MAX7219_CMD

; Required - set a bit pattern for display intensity, range 0x00 - 0x0F
	LD		A,INTENSITY
	LD		(MX_ADDR),A
	LD		A,0x03				; 25% intensity
	LD		(MX_DATA),A
	LD		A,DISP_ALL
	CALL	MAX7219_CMD

; Required - set to the number of digits to display,
;	corresponds to rows using the 8x8 matrix displays
	LD		A,SCAN_LIMIT
	LD		(MX_ADDR),A
	LD		A,0x07				; All rows
	LD		(MX_DATA),A
	LD		A,DISP_ALL
	CALL	MAX7219_CMD	

	LD		H,0x01				; Initialize row counter
	XOR		A					; Column data 0 to erase
	LD		(MX_DATA),A

; Required - erase all rows of all displays with 0x00 values to
;	clear random startup values
.ERASE:
	LD		A,H					; Row number
	LD		(MX_ADDR),A
	LD		A,DISP_ALL
	CALL	MAX7219_CMD

	INC		H					; Adjust row counter
	LD		A,H
	CP		0x08+1				; Execute for 8 rows
	JR		NZ,.ERASE

; Required - set all displays to normal operation, ready for accessing
	LD		A,SHUTDOWN
	LD		(MX_ADDR),A
	LD		A,0x01				; Normal operation
	LD		(MX_DATA),A
	LD		A,DISP_ALL
	CALL	MAX7219_CMD

; Sample bit pattern to demonstrate LED addressing
	LD		A,(NUM_DISP)
	LD		B,A					; Number of displays -> B counter
	LD		A,0x01				; Bit 0	set

.BIT_LOOP:
	RLCA						; Rotate bit left once for each display configured
	DJNZ	.BIT_LOOP

	RRCA						; Adjust bit back right once to proper location
	LD		L,A					; Save bit mask in L

.DISPLAY:
	LD		H,0x08				; Initialize row counter

.ROW:
	LD		A,H					; Row8 (upper) - row1 (lower)
	LD		(MX_ADDR),A
	LD		A,01010101B			; Row bit pattern (LSB left column, MSB right column)
	LD		(MX_DATA),A
	LD		A,L					; Current display mask
	CALL	MAX7219_CMD

	LD		D,0x05				; 50ms delay
	CALL	DELAY_10MS

	LD		A,H					; Row8 (upper) - row1 (lower)
	LD		(MX_ADDR),A
	LD		A,00000000B			; Row bit pattern (LSB left column, MSB right column)
	LD		(MX_DATA),A
	LD		A,L					; Current display mask
	CALL	MAX7219_CMD

	LD		A,H					; Row8 (upper) - row1 (lower)
	LD		(MX_ADDR),A
	LD		A,10101010B			; Row bit pattern (LSB left column, MSB right column)
	LD		(MX_DATA),A
	LD		A,L					; Current display mask
	CALL	MAX7219_CMD

	LD		D,0x05				; 50ms delay
	CALL	DELAY_10MS

	LD		A,H					; Row8 (upper) - row1 (lower)
	LD		(MX_ADDR),A
	LD		A,00000000B			; Row bit pattern (LSB left column, MSB right column)
	LD		(MX_DATA),A
	LD		A,L					; Current display mask
	CALL	MAX7219_CMD

	DEC		H					; Adjust row counter
	LD		A,H
	OR		A					; Execute for 8 rows
	JR		NZ,.ROW

	LD		A,L					; Get current display bit
	RRCA						; Display bit -> carry
	LD		L,A
	JR		NC,.DISPLAY			; Do unit all displays processed

; Optional - set all displays to shutdown mode (low power)
	LD		A,SHUTDOWN
	LD		(MX_ADDR),A
	LD		A,0x00				; Shutdown operation
	LD		(MX_DATA),A
	LD		A,DISP_ALL
	CALL	MAX7219_CMD

.SUCCESS:
	CALL	DSPMSG
	DEFB	CR,LF,'Test complete',BIT7+'!'
	
	CALL	CRLF
	JP		START				; Return to monitor

;--------------------------------------------------------------------------
; DELAY_10MS
; 10ms second delay @ 10Mhz
;
; [n] = number of T-states, 1 T-state = 100ns or .1us @ 10Mhz
; Input: D = number of 10ms cycles to execute
; Return: none
; Destroys: A, BC, D
;--------------------------------------------------------------------------
DELAY_10MS:
	LD		BC,0x0F00			; [10] ~10ms delay @ 10Mhz

.DELAY_10MS_1:
	LD		A,B					; [4]
	OR		C					; [4] Check BC = 0
	DEC		BC					; [6] Adjust counter
	JR		NZ,.DELAY_10MS_1	; [7F/12T] Inner loop

	DEC		D					; [4]
	JR		NZ,DELAY_10MS		; [7F/12T] Outer loop
	RET							; [10]

;--------------------------------------------------------------------------
; MAX7219_CMD
; Send a command and value to one MAX7219 register
;
; Input: A = bit mask indicating which display(s) to update (DISP_8 - DISP_1)
;		 MX_ADDR = register address (command)
;		 MX_DATA = register data (value)
; Return: none
; Destroys: A, BC, DE
;--------------------------------------------------------------------------
MAX7219_CMD:
	PUSH	AF					; Protect bit mask in A
	CALL	SPI_CSx_TRUE 		; Assert CSx

	LD		A,(NUM_DISP)		; Total number of displays configured
	LD		B,A					; One loop iteration per display
	POP		AF

.CMD_BIT_LOOP:
	PUSH	BC					; Save counter
	RRCA						; Rotate LSB of A -> carry
	JP		C,.CMD_SEND			; Send command if carry set
	JP		NC,.CMD_SKIP		; Skip command if carry not set

.CMD_CONT:
	POP		BC					; Get counter
	DJNZ	.CMD_BIT_LOOP		; Do again for each bit in A
	JP		.CMD_EXIT			; Done with all bits

; Send data to the display if carry flag is set
.CMD_SEND:
	PUSH	AF					; Save bit mask in A & flags
	LD		A,(MX_ADDR)
	LD		C,A					; Copy address to C
	CALL	SPI_SEND_BYTE		; Send register address in C

	LD		A,(MX_DATA)
	LD		C,A					; Copy data to C
	CALL	SPI_SEND_BYTE		; Send register data in C
	POP		AF
	JP		.CMD_CONT

; Skip the display if carry flag is reset by sending a no-op to leave unchanged
.CMD_SKIP:
	PUSH	AF					; Save bit mask in A & flags
	LD		C,0x00				; No-op	
	CALL	SPI_SEND_BYTE		; Send register address in C
	CALL	SPI_SEND_BYTE		; Send register data in C
	POP		AF
	JP		.CMD_CONT

; Latch in last n bytes (NUM_DISP x 16) sent on rising edge of the
; MAX7219 LOAD (/CSx) line
.CMD_EXIT:
	CALL	SPI_CSx_FALSE 		; De-assert CSx
	RET

; Data area
MX_ADDR:	DEFB	0			; MAX7219 register address
MX_DATA:	DEFB	0			; MAX7219 data address
NUM_DISP:	DEFB	0			; Total number of displays configured

;--------------------------------------------------------------------------
;	Libraries
;--------------------------------------------------------------------------
include 'i2cspi_lib.asm'
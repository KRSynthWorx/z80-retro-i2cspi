;--------------------------------------------------------------------------
; led_test.asm - routine to test the MAX7219 LED display driver w/8x8 matrix display
;--------------------------------------------------------------------------

; MAX7219 SPI LED driver registers
DECODE_MODE:	EQU	0x09
INTENSITY:		EQU	0x0A
SCAN_LIMIT:		EQU	0x0B
SHUTDOWN:		EQU	0x0C
DISPLAY_TEST:	EQU	0x0F

	ORG		0x1000

	CALL	DSPMSG
	DEFB	CR,LF,LF,'Z80-Retro! I2C/SPI Master Interface test routine',CR,LF
	DEFB	'Test a MAX7219 SPI 8x8 matrix LED display driver..',BIT7+'.'

	CALL	CRLF

	LD		A,CS1|MSB_LSB|MODE0	; CS1 active, MSB->LSB bit order
								; SPI MODE (CPOL = 0, CPHA = 0)
	CALL	SPI_INIT			; Initialize the SPI port with these values

	LD		C,DISPLAY_TEST		; Display test register
	LD		A,0x01				; Test on
	CALL	MAX7219_CMD

	LD		D,0x64				; 1000ms delay
	CALL	DELAY_10MS

	LD		C,DISPLAY_TEST		; Display test register
	LD		A,0x00				; Test off
	CALL	MAX7219_CMD

	LD		C,DECODE_MODE		; Decode mode register
	LD		A,0x00				; No decoding
	CALL	MAX7219_CMD

	LD		C,INTENSITY			; Intensity register
	LD		A,0x03				; 25% intensity
	CALL	MAX7219_CMD

	LD		C,SCAN_LIMIT		; Scan limit register
	LD		A,0x07				; All rows
	CALL	MAX7219_CMD

	LD		H,0x01				; Initialize row counter

.ERASE:
	LD		C,H					; Row x register
	XOR		A					; Erase row
	CALL	MAX7219_CMD

	INC		H					; Adjust row counter
	LD		A,H
	CP		0x08+1				; Execute for 8 rows
	JR		NZ,.ERASE

	LD		C,SHUTDOWN			; Shutdown register
	LD		A,0x01				; Normal operation
	CALL	MAX7219_CMD

	LD		H,0x08				; Initialize row counter

.ROW:
	LD		E,0x01				; Initialize column bits

.COLUMN:
	PUSH	DE					; Save column
	LD		C,H					; Row x register
	LD		A,E					; Column bit to A
	CALL	MAX7219_CMD

	LD		D,0x0A				; 100ms delay
	CALL	DELAY_10MS

	POP		DE					; Restore column
	LD		A,E
	SLA		A					; Adjust column bits
	LD		E,A					; Save it
	OR		A					; Execute for 8 columns
	JR		NZ,.COLUMN

	LD		C,H					; Row x register
	CALL	MAX7219_CMD			; A = 0 from above to clear row

	DEC		H					; Adjust row counter
	LD		A,H
	OR		A					; Execute for 8 rows
	JR		NZ,.ROW

.SUCCESS:
	LD		C,SHUTDOWN			; Shutdown register
	XOR		A					; Shutdown mode
	CALL	MAX7219_CMD

	CALL	DSPMSG
	DEFB	CR,LF,'Test Complete!',CR,BIT7+LF

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
; Input: A = register data
;		 C = register address
; Return: none
; Destroys: B, DE
;--------------------------------------------------------------------------
MAX7219_CMD:
	PUSH	AF					; Save register data
	CALL	SPI_SEND_BYTE		; Send register address in C

	POP		AF					; Get register data
	LD		C,A					; Copy to C
	CALL	SPI_SEND_BYTE		; Send it

; Latch in last 16 bits sent on rising edge of MAX7219 LOAD (/CSx) line
	CALL	SPI_CSx_TRUE 		; Assert CS1
	CALL	SPI_CSx_FALSE 		; De-assert CS1
	RET

;--------------------------------------------------------------------------
;	Libraries
;--------------------------------------------------------------------------
include 'i2cspi_lib.asm'
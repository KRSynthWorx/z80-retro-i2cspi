;--------------------------------------------------------------------------
;	spi_test.asm - routine to test the SPI port on the I2C/SPI Master Interface
;--------------------------------------------------------------------------

	ORG		0x1000
	
	CALL	DSPMSG
	DEFB	CR,LF,LF,'Z80-Retro! I2C/SPI Master Interface test routine',CR,LF
	DEFB	'Read values from an ADXL345 digital accelerometer...',CR,BIT7+LF

	LD		A,CS1|MSB_LSB|MODE3	; CS1 active, MSB->LSB bit order
								; SPI MODE (CPOL = 1, CPHA = 1)
	CALL	SPI_INIT			; Initialize the SPI port with these values

	CALL	SPI_CSx_TRUE 		; Assert CS1
	LD		C,0x80				; DEVID register 0x00 with MSB read bit set
	CALL	SPI_SEND_BYTE		; Send address
	CALL	SPI_READ_BYTE		; Read ID value
	PUSH	AF					; Save it
	CALL	SPI_CSx_FALSE		; De-assert CS1

	POP		AF					; Get ID value back
	PUSH	AF					; Save ID again
	CP		0xE5				; Device ID 0xE5?
	JR		Z,.DEVICE_OK		; Continue
	
	CALL	DSPMSG
	DEFB	CR,LF,'No ADXL345 device found',CR,BIT7+LF

	POP		AF					; Clean-up stack
	JP		START				; Return to monitor
	
.DEVICE_OK:
	CALL	DSPMSG
	DEFB	CR,LF,'Device ID ',BIT7+'='
	
	POP		AF					; Get ID value back
	CALL	PT2					; Display it
	
; Perform a minimal setup of the ADXL45 chip
	CALL	SPI_CSx_TRUE 		; Assert CS1
	LD		C,0x31				; DATA_FORMAT register to send
	CALL	SPI_SEND_BYTE		; Send it

	LD		C,0x01				; '+/1 4G range' value to send
	CALL	SPI_SEND_BYTE		; Send it
	CALL	SPI_CSx_FALSE		; De-assert CS1
	
	CALL	SPI_CSx_TRUE 		; Assert CS1
	LD		C,0x2D				; POWER_CTL register to send
	CALL	SPI_SEND_BYTE		; Send it

	LD		C,0x08				; 'Measurement Mode' value to send
	CALL	SPI_SEND_BYTE		; Send it
	CALL	SPI_CSx_FALSE		; De-assert CS1

; Display to raw values of X, Y and Z
	CALL	DSPMSG
	DEFB	CR,LF,'Press any key to exit...',CR,LF
	DEFB	CR,LF,'Raw values from device',CR,LF
	DEFB	' X:    Y:    Z',BIT7+':'
	
	CALL	CRLF
	CALL	CRLF

.MAIN_LOOP:
	CALL	SPI_CSx_TRUE 		; Assert CS1

	LD		C,0xF2				; Register to begin read 0x32 w/MSB
								;	and Multi-Byte mode (0x40 MB) set
	CALL	SPI_SEND_BYTE		; Send it

	LD		HL,.VALUES			; Value buffer
	LD		B,6					; Read 6 bytes
	CALL 	SPI_READ_STREAM		; Read registers 0x32 - 0x37
	
	CALL	SPI_CSx_FALSE		; De-assert CS1
	
	LD		A,(.VALUES+1)		; Display X axis value
	CALL	PT2
	LD		A,(.VALUES)
	CALL	PT2
	CALL	SPCE
	CALL	SPCE
	
	LD		A,(.VALUES+3)		; Display Y axis value
	CALL	PT2
	LD		A,(.VALUES+2)
	CALL	PT2
	CALL	SPCE
	CALL	SPCE
	
	LD		A,(.VALUES+5)		; Display Z axis value
	CALL	PT2
	LD		A,(.VALUES+4)
	CALL	PT2
	CALL	CRLF				; New line
	
	IN		A,(ACTL)			; Any key pressed?
	AND		RDA
	JR		NZ,.SUCCESS			; Yes, exit
	
	LD		BC,0xA000			; Delay counter
	
.SHORT_DELAY:
	DEC		BC					; Adjust counter
	LD		A,B
	OR		C					; Check BC = 0
	JR		NZ,.SHORT_DELAY		; No?
	
	JR		.MAIN_LOOP			; Continue

.SUCCESS:
	IN		A,(ADTA)			; Flush keyboard buffer
	
	CALL	DSPMSG
	DEFB	CR,LF,'SPI test complete!',CR,BIT7+LF

	JP		START				; Return to monitor
	
; Local storage area
.VALUES:	DEFS	0x06		; Buffer to hold X,Y,Z values

;--------------------------------------------------------------------------
;	Libraries
;--------------------------------------------------------------------------
include 'i2cspi_lib.asm'
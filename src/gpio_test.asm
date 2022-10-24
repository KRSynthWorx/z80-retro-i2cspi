;--------------------------------------------------------------------------
; gpio_test.asm - routine to test a PCF8574 I2C 8-bit GPIO expander
;--------------------------------------------------------------------------

	ORG		0x1000

	CALL	I2C_INIT
	CALL	DSPMSG
	DEFB	CR,LF,LF,'Z80-Retro! I2C/SPI Master Interface test routine',CR,LF
	DEFB	'Write and read values in a PCF8574 I2C 8-bit GPIO expander...',CR,BIT7+LF

	LD		A,0x40			; PCF8574 device address
	CALL	GP_READ

	OR		A				; Check return code = 0
	JR		Z,.GP_CONT
	JP		.PT_ERROR

.GP_CONT:
	CALL	DSPMSG
	DEFB	CR,LF,'Current port value ',BIT7+'='

	LD		A,E				; Read data -> A
	CALL	PT2				; Display it

	CALL	DSPMSG
	DEFB	CR,LF,'Read test successful',BIT7+'!'

	CALL	DSPMSG
	DEFB	CR,LF,LF,'Enter byte to send to port *-',BIT7+'>'

	LD		C,2				; Get 2 hex digits -> E
	CALL	AHE0

	LD		A,0x40			; PCF8574 device address
	LD		D,E				; Byte to send to GPIO expander -> D
	CALL	GP_SEND

	OR		A				; Check return code = 0
	JR		Z,.SUCCESS
	JP		.PT_ERROR

.SUCCESS:
	CALL	DSPMSG
	DEFB	CR,LF,'Write test successful!',CR,BIT7+LF

	JP		START

; Display Error code
.PT_ERROR:
	PUSH	AF				; Save errorcode
	CALL	DSPMSG
	DEFB	CR,LF,'Error ',BIT7+'-'

	POP		AF				; Get errorcode
	CALL	PT2				; Print code
	
	JP		START

;--------------------------------------------------------------------------
; GP_SEND
; Send a byte of data to a PCF8574 8-bit GPIO expander
; (address range 0100xxxW)
;
; Input: A = PCF8574 7-bit address
;		 D = data to send
; Return: A = Error code
; Destroys: A, BC
;--------------------------------------------------------------------------
GP_SEND:
	PUSH	AF				; Save device address
	CALL	I2C_START

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.GP_SEND1

	POP		AF				; Clean-up stack
	LD		A,START_ERR		; Failed at start
	RET

; Send device address in write mode (bit 0 = 0)
.GP_SEND1:
	POP		AF				; Get back device address
	RLCA
	AND		01001110B
	OR		01000000B		; Form device address for reading
	CALL	I2C_SEND_BYTE	; Send byte in A

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.GP_SEND2

	LD		A,ADDR_ERR		; Failed at device address send
	RET

; Send data byte
.GP_SEND2:
	LD		A,D
	CALL	I2C_SEND_BYTE

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.GP_SEND3

	LD		A,READ_ERR		; Failed at data read
	RET

; Stop I2C communication
.GP_SEND3:
	CALL	I2C_STOP

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.GP_SEND4

	LD		A,STOP_ERR		; Failed at stop
	RET	

.GP_SEND4:
	XOR		A				; No error
	RET

;--------------------------------------------------------------------------
; GP_READ
; Read a byte of data from a PCF8574 8-bit GPIO expander
; (address range 0100xxxR)
;
; Input: A = PCF8574 7-bit address
; Return: A = Error code, E = data read
; Destroys: A, BC
;--------------------------------------------------------------------------
GP_READ:
	PUSH	AF				; Save device address
	CALL	I2C_START

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.GP_READ1

	POP		AF				; Clean-up stack
	LD		A,START_ERR		; Failed at start
	RET

; Send device address in read mode (bit 0 = 1)
.GP_READ1:
	POP		AF				; Get back device address
	RLCA
	AND		01001110B
	OR		01000001B		; Form device address for reading
	CALL	I2C_SEND_BYTE	; Send byte in A

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.GP_READ2

	LD		A,ADDR_ERR		; Failed at device address send
	RET

; Read data byte
.GP_READ2:
	SCF						; Set carry for NACK
	CALL	I2C_READ_BYTE
	LD		E,A				; Save data in E

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.GP_READ3

	LD		A,READ_ERR		; Failed at data read
	RET

; Stop I2C communication
.GP_READ3:
	CALL	I2C_STOP

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.GP_READ4

	LD		A,STOP_ERR		; Failed at stop
	RET	

.GP_READ4:
	XOR		A				; No error
	RET

;--------------------------------------------------------------------------
;	Libraries
;--------------------------------------------------------------------------
include 'i2cspi_lib.asm'
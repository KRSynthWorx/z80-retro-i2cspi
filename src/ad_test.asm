;--------------------------------------------------------------------------
; ad_test.asm - routine to test a PCF8591 I2C A/D-D/A converter
;--------------------------------------------------------------------------

	ORG		0x1000

	CALL	I2C_INIT
	CALL	DSPMSG
	DEFB	CR,LF,LF,'Z80-Retro! I2C/SPI Master Interface test routine',CR,LF
	DEFB	'Test a PCF8591 I2C A/D-D/A converter...',CR,LF,LF
	DEFB	'D/A test: Enter 8-bit value to send *-',BIT7+'>'

	LD		C,2				; Get 2 hex digits -> E
	CALL	AHE0
	LD		D,E				; Value -> D

	LD		A,0x48			; PCF8591 device address
	CALL	DA_SEND

	OR		A				; Check return code = 0
	JR		Z,.AD_CONT
	JP		.PT_ERROR	

.AD_CONT:
	CALL	DSPMSG
	DEFB	CR,LF,'D/A test successful!',CR,LF,LF
	DEFB	'A/D test: Enter A/D channel (0-3) to read *-',BIT7+'>'

	LD		C,1				; Get 1 hex digit -> E
	CALL	AHE0
	LD		D,E				; Channel -> D

	LD		A,0x48			; PCF8591 device address
	CALL	AD_READ

	OR		A				; Check return code = 0
	JR		Z,.SUCCESS
	JP		.PT_ERROR		

.SUCCESS:
	CALL	DSPMSG
	DEFB	CR,LF,'Channel value ',BIT7+'='

	LD		A,E				; Channel value -> A
	CALL	PT2				; Display it

	CALL	DSPMSG
	DEFB	CR,LF,'A/D test successful!',CR,BIT7+LF

	JP		START

; Display Error code
.PT_ERROR:
	PUSH	AF				; Save errorcode
	CALL	DSPMSG
	DEFB	CR,LF,LF,'Error ',BIT7+'-'

	POP		AF				; Get errorcode
	CALL	PT2				; Print code

	JP		START

;--------------------------------------------------------------------------
; DA_SEND
; Send a byte of data to a PCF8591 8-bit D/A converter
; (address range 1001xxxW)
;
; Input: A = PCF8591 7-bit address
;		 D = data byte to send
; Return: A = Error code
; Destroys: A, BC
;--------------------------------------------------------------------------
DA_SEND:
	PUSH	AF				; Save device address
	CALL	I2C_START

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.DA_SEND1

	POP		AF				; Clean-up stack
	LD		A,START_ERR		; Failed at start
	RET

; Send device address in write mode (bit 0 = 0)
.DA_SEND1:
	POP		AF				; Get back device address
	RLCA
	AND		10011110B
	OR		10010000B		; Form device address for writing
	CALL	I2C_SEND_BYTE	; Send byte in A

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.DA_SEND2

	LD		A,ADDR_ERR		; Failed at device address send
	RET

; Send control byte to enable D/A converter analog output
.DA_SEND2:
	LD		A,01000000B		; Enable analog output
	CALL	I2C_SEND_BYTE	; Send byte in A

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.DA_SEND3

	LD		A,WRITE_ERR		; Failed at PCF8591 control byte send
	RET

; Send data to D/A converter
.DA_SEND3:
	LD		A,D				; Data to send in A
	CALL	I2C_SEND_BYTE

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.DA_SEND4

	LD		A,WRITE_ERR		; Failed at data write
	RET

; Stop I2C communication
.DA_SEND4:
	CALL	I2C_STOP

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.DA_SEND5

	LD		A,STOP_ERR		; Failed at stop
	RET	

.DA_SEND5:
	XOR		A				; No error
	RET

;--------------------------------------------------------------------------
; AD_READ
; Read a byte of data from a PCF8591 8-bit A/D converter
; (address range 1001xxxR)
;
; Input: A = PCF8591 7-bit address
;		 D = A/D channel to read (0-3)
; Return: A = Error code, E = data read
; Destroys: A, BC
;--------------------------------------------------------------------------
AD_READ:
	PUSH	AF				; Save device address
	CALL	I2C_START

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.AD_READ1

	POP		AF				; Clean-up stack
	LD		A,START_ERR		; Failed at start
	RET

; Send device address in write mode (bit 0 = 0)
.AD_READ1:
	POP		AF				; Get back device address
	RLCA
	AND		10011110B
	OR		10010000B		; Form device address for writing
	PUSH	AF				; Save formed address for resend later
	CALL	I2C_SEND_BYTE	; Send byte in A

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.AD_READ2

	POP		AF				; Clean-up stack
	LD		A,ADDR_ERR		; Failed at device address send
	RET

; Send control byte
.AD_READ2:
	LD		A,D				; Get control byte A/D channel # in bits 1-0
	CALL	I2C_SEND_BYTE	; Send byte in A

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.AD_READ3

	LD		A,WRITE_ERR		; Failed at PCF8591 control byte send
	RET

; Perform repeated start
.AD_READ3:
	CALL	I2C_START

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.AD_READ4

	POP		AF				; Clean-up stack
	LD		A,START_ERR		; Failed at repeated start
	RET

; Resend device address, now in read mode (bit 0 = 1)
.AD_READ4:
	POP		AF				; Get back device address
	AND		11111110B
	OR		00000001B		; Set read bit 0
	CALL	I2C_SEND_BYTE	; Send byte in A

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.AD_READ5

	LD		A,ADDR_ERR		; Failed at address send
	RET

; Dummy read A/D channel to ignore previous reading
.AD_READ5:
	CALL	I2C_READ_BYTE

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.AD_READ6

	LD		A,READ_ERR		; Failed at data read
	RET

; Actual read of A/D channel
.AD_READ6:
	SCF						; Set carry for NACK
	CALL	I2C_READ_BYTE
	LD		E,A				; Save data in E

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.AD_READ7

	LD		A,READ_ERR		; Failed at data read
	RET

; Stop I2C communication
.AD_READ7:
	CALL	I2C_STOP

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.AD_READ8

	LD		A,STOP_ERR		; Failed at stop
	RET	

.AD_READ8:
	XOR		A				; No error
	RET

;--------------------------------------------------------------------------
;	Libraries
;--------------------------------------------------------------------------
include 'i2cspi_lib.asm'

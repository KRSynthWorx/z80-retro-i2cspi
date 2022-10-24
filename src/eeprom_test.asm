;--------------------------------------------------------------------------
; eeprom_test.asm - routine to test a 24C256 I2C EEPROM
;--------------------------------------------------------------------------

.PAGE_MAX:		EQU	0x40	; Max allowed bytes to write, 1 page (64D)
.EEPROM_MAX:	EQU	0x8000	; Max bytes in EEPROM (32,768D)

	ORG		0x1000

	CALL	I2C_INIT
	CALL	DSPMSG
	DEFB	CR,LF,LF,'Z80-Retro! I2C/SPI Master Interface test routine',CR,LF
	DEFB	'Write and read memory from a 24C256 I2C EEPROM...',CR,LF,LF
	DEFB	'Write test: <BBBB>Buffer address',CR,LF
	DEFB	'            <DDDD>EEPROM destination address',CR,LF
	DEFB	'            <CC>Count of bytes to copy (max 0x40)',CR,LF
	DEFB	'*-',BIT7+'>'

	CALL	TAHEX			; Get buffer address -> HL, EEPROM destination address -> DE
	PUSH	DE				; Save values in reverse order
	PUSH	HL

	LD		C,2				; Get 2 hex digits -> E
	CALL	AHE0
	LD		C,E				; Byte count -> C

	LD		A,0x50			; EEPROM I2C device address
	POP		DE				; DE = source buffer address
	POP		HL				; HL = EEPROM destination address
	CALL	EEPROM_WRITE

	OR		A				; Check return code = 0
	JR		Z,.READ_TEST
	JP		.PT_ERROR

.READ_TEST:
	CALL	DSPMSG
	DEFB	CR,LF,'Write successful!',CR,LF,LF
	DEFB	'Read test: <SSSS>EEPROM source address',CR,LF
	DEFB	'           <BBBB>Buffer destination address',CR,LF
	DEFB	'           <CCCC>Count of bytes to copy',CR,LF
	DEFB	'*-',BIT7+'>'

	CALL	TAHEX			; Get EEPROM source address -> HL, destination buffer address -> DE
	PUSH	HL				; Save values
	PUSH	DE

	CALL	AHEX			; Get 4 hex digits -> DE
	PUSH	DE				; Move them to BC
	POP		BC

	LD		A,0x50			; EEPROM I2C device address
	POP		DE				; DE = EEPROM source address
	POP		HL				; HL = destination buffer address
	CALL	EEPROM_READ

	OR		A				; Check return code = 0
	JR		Z,.SUCCESS
	JP		.PT_ERROR

.SUCCESS:
	CALL	DSPMSG
	DEFB	CR,LF,'Read successful!',CR,BIT7+LF

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
; EEPROM_WRITE (Page - max 64 bytes)
; Write bytes of data from a 24C256 I2C EEPROM (address range 1010xxxW)
;
; Input: A = EEPROM 7-bit address
;		 C = # of bytes to write (min 0x01 - max 0x40)
;		 DE = write data buffer address pointer
;		 HL = EEPROM write address (only A14 - A0 valid (15-bits = 32,767 bytes)
; Return: A = Error code
; Destroys: A, C
;--------------------------------------------------------------------------
EEPROM_WRITE:
	PUSH	BC				; Save byte count in C for later
	PUSH	AF				; Save device address
	CALL	I2C_START

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.EEPROM_WRITE1

	POP		AF				; Clean-up stack
	POP		BC
	LD		A,START_ERR		; Failed at start
	RET

; Send EEPROM device address in write mode (bit 0 = 0)
.EEPROM_WRITE1:
	POP		AF				; Get back device address
	RLCA
	AND		10101110B
	OR		10100000B		; Form device address for writing
	CALL	I2C_SEND_BYTE	; Send byte in A

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.EEPROM_WRITE2

	POP		BC				; Clean-up stack
	LD		A,ADDR_ERR		; Failed at device address send
	RET

; Send EEPROM write address
.EEPROM_WRITE2:
	LD		A,H				; Send MSB of EEPROM write address
	CALL	I2C_SEND_BYTE
	LD		A,L				; Send LSB of EEPROM write address
	CALL	I2C_SEND_BYTE

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.EEPROM_WRITE3

	POP		BC				; Clean-up stack
	LD		A,WRITE_ERR		; Failed at EEPROM write address send
	RET

; Now write EEPROM byte stream from write buffer
.EEPROM_WRITE3:
	POP		BC				; Get byte counter in C
	EX		DE,HL			; Write buffer address -> HL

	XOR		A				; Zero accumulator
	LD		B,A				; Limit byte counter to 64 bytes, 1 page
	OR		C				; Check if C = 0, clear carry
	JR		Z,.EEPROM_PAGE_MAX

	LD		A,C				; Get byte counter
	SLA		A				; Move bit-6 -> carry
	SLA		A
	JR		NC,.EEPROM_WRITE3A

.EEPROM_PAGE_MAX:
	LD		C,.PAGE_MAX		; Fix up byte counter

.EEPROM_WRITE3A:
	CALL	I2C_SEND_STREAM

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.EEPROM_WRITE4

	LD		A,WRITE_ERR		; Failed at data write
	RET

; Stop I2C communication
.EEPROM_WRITE4:
	CALL	I2C_STOP

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.EEPROM_WRITE5

	LD		A,STOP_ERR		; Failed at stop
	RET

.EEPROM_WRITE5:
	XOR		A				; No error
	RET

;--------------------------------------------------------------------------
; EEPROM_READ (Sequential)
; Read bytes of data from a 24C256 I2C EEPROM (address range 1010xxxR)
;
; Input: A = EEPROM 7-bit address
;		 BC = # of bytes to read (min 0x0001 - max 0x8000)
;		 DE = read data buffer address pointer
;		 HL = EEPROM read address (only A14 - A0 valid (15-bits = 32,767 bytes)
; Return: A = Error code
; Destroys: A, BC
;--------------------------------------------------------------------------
EEPROM_READ:
	PUSH	BC				; Save byte count for later
	PUSH	AF				; Save device address
	CALL	I2C_START

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.EEPROM_READ1

	POP		AF				; Clean-up stack
	POP		BC
	LD		A,START_ERR		; Failed at start
	RET

; Send EEPROM device address in write mode (bit 0 = 0)
.EEPROM_READ1:
	POP		AF				; Get back device address
	RLCA
	AND		10101110B
	OR		10100000B		; Form device address for writing
	PUSH	AF				; Save formed device address for resend later
	CALL	I2C_SEND_BYTE	; Send byte in A

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.EEPROM_READ2

	POP		AF				; Clean-up stack
	POP		BC
	LD		A,ADDR_ERR		; Failed at device address send
	RET	

; Send EEPROM read address
.EEPROM_READ2:
	LD		A,H				; Send MSB of EEPROM read address
	CALL	I2C_SEND_BYTE
	LD		A,L				; Send LSB of EEPROM read address
	CALL	I2C_SEND_BYTE

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.EEPROM_READ3

	POP		AF				; Clean-up stack
	POP		BC
	LD		A,WRITE_ERR		; Failed at EEPROM read address send
	RET

; Perform repeated start
.EEPROM_READ3:
	CALL	I2C_START

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.EEPROM_READ4

	POP		AF				; Clean-up stack
	POP		BC
	LD		A,START_ERR		; Failed at repeated start
	RET

; Resend EEPROM device address, now in read mode (bit 0 = 1)
.EEPROM_READ4:
	POP		AF				; Get back device address
	AND		11111110B
	OR		00000001B		; Set read bit 0
	CALL	I2C_SEND_BYTE	; Send device address in A

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.EEPROM_READ5

	POP		BC				; Clean-up stack
	LD		A,ADDR_ERR		; Failed at address send
	RET

; Now read EEPROM byte stream to read buffer
.EEPROM_READ5:
	POP		BC					; Get byte counter
	LD		A,B
	OR		C					; Check BC = 0
	JR		NZ,.EEPROM_READ5A	; OK, continue
	LD		BC,.PAGE_MAX		; Limit count to 64 bytes, 1 page

.EEPROM_READ5A:
	LD		A,B
	RLA							; Position MSB -> carry
	JR		NC,.EEPROM_READ5B	; OK, < 32k
	LD		BC,.EEPROM_MAX		; Limit count to 32k bytes, 512 pages

.EEPROM_READ5B:
	EX		DE,HL			; Read buffer address -> HL
	CALL	I2C_READ_STREAM

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.EEPROM_READ6

	LD		A,READ_ERR		; Failed at data read
	RET

; Stop I2C communication
.EEPROM_READ6:
	CALL	I2C_STOP

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Position error bit -> carry
	JR		NC,.EEPROM_READ7

	LD		A,STOP_ERR		; Failed at stop
	RET	

.EEPROM_READ7:
	XOR		A				; No error
	RET

;--------------------------------------------------------------------------
;	Libraries
;--------------------------------------------------------------------------
include 'i2cspi_lib.asm'
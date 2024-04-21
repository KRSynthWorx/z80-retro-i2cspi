;--------------------------------------------------------------------------
; oled_test.asm - routine to test the SSD1306 SPI 128x64 0.96" OLED display
; Kenny Maytum - KRSynthWorx - November 4th, 2022
;--------------------------------------------------------------------------

;--------------------------------------------------------------------------
; The display used in this test routine, configured for 4-wire SPI:
; https://www.buydisplay.com/yellow-blue-0-96-inch-oled-display-breakout-board-library-for-arduino
;
; The SSD1306 datasheet is here:
; https://www.buydisplay.com/download/ic/SSD1306.pdf
;
; These are also available on eBay and Amazon, just insure that they are
; the 7-pin version and are configured for 4-wire SPI.
;
; These SSD1306 displays are 3.3 vdc only but include a 5 vdc to 3.3 vdc
; voltage regulator so we can power them from the Z80-Retro! I2C/SPI
; interface board +5 vdc source. Care must be taken with the signal lines
; though. You can put together a simple resistor voltage divider as
; shown below. We don't need to read anything from the display (you can't
; in serial mode anyway), so we don't need any active level shifters.
;
; Z80-Retro! I2C/SPI
; Interface Board Pins
;         |
;         |
;                   ________                     ________
;       SCLK ->____|  2.7K  |_._________________|  4.7K  |_____ 
;                  |________| |                 |________|     |
;                             |                                |
;                   ________  |                  ________      |
;       MOSI ->____|  2.7K  |_|___._____________|  4.7K  |_____.
;                  |________| |   |             |________|     |
;                             |   |                            |
;                   ________  |   |              ________      |
;       /CS3 ->____|  2.7K  |_|___|___._________|  4.7K  |_____.
;                  |________| |   |   |         |________|     |
;                             |   |   |                        |
;                   ________  |   |   |          ________      |
;       /CS2 ->____|  2.7K  |_|___|___|___._____|  4.7K  |_____.
;                  |________| |   |   |   |     |________|     |
;                             |   |   |   |                    |
;                   ________  |   |   |   |      ________      |
;       /CS1 ->____|  2.7K  |_|___|___|___|___._|  4.7K  |_____.
;                  |________| |   |   |   |   | |________|     |
;        +5  ->___________    |   |   |   |   |                |
;                         |   |   |   |   |   |                |
;        GND ->_______.___|___|___|___|___|___|________________|
;                     |   |   |   |   |   |   |
;                _____|___|___|___|___|___|___|_____
;               |    GND +5  D0  D1  RES DC  CS     |
;               |                                   |
;               |          SSD1306 Display          |
;               |          0.96" SPI OLED           |
;               |           128x64 Pixels           |
;               |                                   |
;               |___________________________________|
;
; To help with performance, we use a spare (/CS2) line from the interface
; to toggle the Data/Command# line instead of configuring 3-wire SPI and
; sending the DC command in software on each command or data byte
; transferred. We also use a spare (/CS3) line to be able to remotely
; reset the display from the Z80-Retro! The MISO input line on the
; interface board is not used.
;--------------------------------------------------------------------------

; Misc equates
.SPI_DC:	EQU	0x20			; Display DC pin Data/Command# use SPI /CS2 output
.SPI_RES:	EQU	0x40			; Display RES pin Reset use SPI /CS3 output
.BUF_LEN:	EQU	128*8			; Size of screen character buffer

	ORG		0x1000

	CALL	DSPMSG
	DEFB	CR,LF,LF,'Z80-Retro! I2C/SPI Master Interface test routine',CR,LF
	DEFB	'Test a SSD1306 128x64 0.96" SPI OLED display..',BIT7+'.'

	CALL	CRLF
	CALL	CRLF
	LD		A,CS1|MSB_LSB|MODE0	; /CS1 active, MSB->LSB bit order
								; SPI MODE (CPOL = 0, CPHA = 0)
	CALL	SPI_INIT			; Initialize the SPI port with these values
	CALL	SSD1306_RESET		; Toggle RES pin

; Send a string of commands to initialize the display
	LD		C,0xA1				; Segment re-map direction, 0xA0 normal, 0xA1 reverse
	CALL	SSD1306_CMD

	LD		C,0xC8				; Common output scan direction 0xC0 - 0xC8
	CALL	SSD1306_CMD

	LD		C,0x81				; Contrast level byte one 0x81
	CALL	SSD1306_CMD

	LD		C,0x7F				; Contrast level byte two 0x00 - 0xFF
	CALL	SSD1306_CMD

	LD		C,0xA6				; 0xA6 normal display, 0xA7 reverse display
	CALL	SSD1306_CMD

	LD		C,0x8D				; Enable charge pump regulator byte one 0x8D
	CALL	SSD1306_CMD

	LD		C,0x14				; Enable charge pump regulator byte two 0x14
	CALL	SSD1306_CMD

	LD		C,0xAF				; 0xAE display off (sleep), 0xAF display on
	CALL	SSD1306_CMD

	LD		C,0x20				; Memory address mode byte one 0x20
	CALL	SSD1306_CMD

	LD		C,0x00				; Memory address mode byte two 0x00 = horizontal
	CALL	SSD1306_CMD

; Clear the entire screen
	CALL	SSD1306_CLEAR

	CALL	DSPMSG				; Status message on main console
	DEFB	'-> Displaying 1st screen on SSD1306 now..',BIT7+'.'
	
; Display static text on SSD1306 defined just past the function call
	CALL	DSP_TXT
	DEFB	'Static text...',CR,LF,LF				; Extra LF for a blank line
	DEFB	' !"#$%&',0x27,'()*+,-./01234',CR,LF	; 0x27 = '
	DEFB	'56789:;<=>?@ABCDEFGHI',CR,LF
	DEFB	'JKLMNOPQRSTUVWXYZ[',0x5C,']^',CR,LF	; 0x5C = '\'
	DEFB	'_`abcdefghijklmnopqrs',CR,LF
	DEFB	'tuvwxyz{|}~',0x7F,CR,LF,LF				; 0x7F = DEL, last LF causes wrap to top
	DEFB	'2.5 sec delay...',CR,BIT7+LF			; <-- Terminate string with MSB set

	CALL	DSPMSG				; Status message on main console
	DEFB	CR,LF,'-> 2.5 second delay on SSD1306 now..',BIT7+'.'
	
	LD		D,0xFF				; 2550ms delay
	CALL	DELAY_10MS
	CALL	SSD1306_CLEAR
	
	CALL	DSPMSG				; Status message on main console
	DEFB	CR,LF,'-> Displaying 2nd screen on SSD1306 now..',BIT7+'.'

; Display buffer text on SSD1306 pointed to by HL
	LD		HL,.TXT_BUF
	CALL	DSP_BUF

.SUCCESS:
	CALL	DSPMSG				; Status message on main console
	DEFB	CR,LF,LF,'Test complete',BIT7+'!'

	CALL	CRLF
	JP		START				; Return to monitor

; Sample text buffer
.TXT_BUF:	DEFB	'From a buffer...',CR,LF,LF		; Extra LF for a blank line
			DEFB	'Greetings from the',CR,LF
			DEFB	'Z80-Retro! SBC',CR,LF,LF		; Extra LF for a blank line
			DEFB	'* * * * * * * * * * *',CR,LF
			DEFB	'Thank you John Winans',CR,LF
			DEFB	'* * * * * * * * * * ',BIT7+'*'	; <-- Terminate buffer with MSB set

;-------------------------------------------------------------------------
; DSP_TXT
; Displays a static text string defined just past the call to this function
; Includes a 100ms delay to slow the display of characters
;
; Input: Gets address of string from stack. EOL = MSB (bit 7) set
; Return: none
; Destroys: A, BC, DE, HL	
;--------------------------------------------------------------------------
DSP_TXT:
	POP		HL					; Get address of string

.TXT_LOOP:
	LD		A,(HL)				; Get character
	PUSH	HL					; Protect HL
	CALL	DSP_CHAR			; Display character
	POP		HL
	OR		(HL)				; MSB set? (EOL marker)
	INC		HL					; Point to next character

; Delay for visual effect
	PUSH	AF					; Protect flags
	LD		D,0x0A				; 100ms delay to slow message display
	CALL	DELAY_10MS
	POP		AF					; Get back overflow (P) flag, set?

	JP		P,.TXT_LOOP			; No, keep looping
	JP		(HL)				; Return past the string

;-------------------------------------------------------------------------
; DSP_BUF
; Displays text from a buffer
; Includes a 100ms delay to slow the display of characters
;
; Input: HL = address of buffer, EOL = MSB (bit 7) set
; Return: none
; Destroys: A, BC, DE, HL	
;--------------------------------------------------------------------------
DSP_BUF:
	LD		A,(HL)				; Get character
	PUSH	HL					; Protect HL
	CALL	DSP_CHAR			; Display character
	POP		HL
	OR		(HL)				; MSB set? (EOL marker)
	INC		HL					; Point to next character

; Delay for visual effect
	PUSH	AF					; Protect flags
	LD		D,0x0A				; 100ms delay to slow message display
	CALL	DELAY_10MS
	POP		AF					; Get back overflow (P) flag, set?

	JP		P,DSP_BUF			; No, keep looping
	RET

;--------------------------------------------------------------------------
; DSP_CHAR
; Displays one ASCII character. Also process any CR or LF codes
;
; Input: A = ASCII character to display
; Return: none
; Destroys: A, BC, DE, HL	
;--------------------------------------------------------------------------
DSP_CHAR:
	AND		0x7F				; Get rid of MSB (EOL marker)
	CP		CR
	JR		Z,.DSP_CR			; Carriage return?

	CP		LF
	JR		Z,.DSP_LF			; Line feed?

	PUSH	AF					; Save character
	LD		A,(COLUMN)			; Get current pixel column
	CP		0x7E				; Allow only 21 character columns (126 pixels)
	JR		NZ,.DSP_CONT

	POP		AF					; Clean-up stack and exit
	RET

.DSP_CR:
	XOR		A
	LD		(COLUMN),A			; Zero X coordinate
	CALL	SSD1306_SETXY		; Move invisible cursor
	RET

.DSP_LF:
	LD		HL,LINE				; Get address of Y coordinate
	INC		(HL)				; Add one character line
	CALL	SSD1306_SETXY		; Move invisible cursor
	RET

.DSP_CONT:
	POP		AF					; Character to display -> A
	LD		HL,.ASC_FONT		; ASCII font table
	LD		DE,0x0005			; Index font row size = 5 columns
	SUB		' '					; Adjust ASCII value to table row
	JR		Z,.FONT_LOOP		; First row in font table then skip index

	LD		B,A					; Font row counter

.INDEX_LOOP:
	ADD		HL,DE				; Skip 5 bytes in font table (1 row)
	DJNZ	.INDEX_LOOP			;	until at correct row

.FONT_LOOP:
	CALL	SPI_CSx_TRUE		; Assert /CS1 for multiple data writes
	LD		B,E					; Font table column counter

.FONT_LOOP1:
	PUSH	BC					; Save counter
	LD		A,(HL)				; Get character font data
	INC		HL					; Advance font table column pointer
	LD		C,A					; Data -> C
	CALL	SSD1306_DATA		; Display pixel column is automatically
								;	incremented but we still adjust and
								;	keep track of it in COLUMN below

	POP		BC					; Get counter
	DJNZ	.FONT_LOOP1			; Loop till end of row

	LD		C,0x00				; Last byte of font always zero for kerning
	CALL	SSD1306_DATA
	CALL	SPI_CSx_FALSE		; De-assert /CS1, done with data writes

	LD		A,(COLUMN)			; COLUMN -> A
	LD		B,0x06				; Advance 6 pixel columns
	ADD		A,B
	LD		(COLUMN),A			; Save it
	CALL	SSD1306_SETXY
	RET

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
; SSD1306_RESET
; Toggle the SSD1306 display RES pin (/CS3 using our interface board)
; Call this function after SPI_INIT is called
;
; Input: none	 
; Return: none
; Destroys: A
;--------------------------------------------------------------------------
SSD1306_RESET:
	LD		A,(PORT_CACHE)		; Get current port data
	AND		~.SPI_RES			; Turn off RES pin (/CS3)
	OUT		(PRN_DAT),A

	OR		.SPI_RES			; Turn on RES pin (/CS3)
	OUT		(PRN_DAT),A			; No need to save in cache, no changes
	RET

;--------------------------------------------------------------------------
; SSD1306_CMD
; Send one command byte
; This will leave SPI_DC = 0
;
; Input: C = command byte
; Return: none
; Destroys: A, B, DE
;--------------------------------------------------------------------------
SSD1306_CMD:
	LD		A,(PORT_CACHE)		; Get current PRN_DAT value
	AND		~.SPI_DC			; Set SPI_DC = 0
	LD		(PORT_CACHE),A		; Save copy in cache
	OUT		(PRN_DAT),A			; Send SPI_DC out port

	CALL	SPI_CSx_TRUE
	CALL	SPI_SEND_BYTE		; Send byte in C
	CALL	SPI_CSx_FALSE
	RET

;--------------------------------------------------------------------------
; SSD1306_DATA
; Send one data byte. SPI_CSx_TRUE must have been called first and
; SPI_CSx_FALSE must be called when done transferring data. This allows
; multiple data bytes to be sent without toggling the /CSx line on every call
; This will leave SPI_DC = 1
;
; Input: C = data byte
; Return: none
; Destroys: A, B, DE
;--------------------------------------------------------------------------
SSD1306_DATA:
	LD		A,(PORT_CACHE)		; Get current PRN_DAT value
	OR		.SPI_DC				; Set SPI_DC = 1
	LD		(PORT_CACHE),A		; Save copy in cache
	OUT		(PRN_DAT),A			; Send SPI_DC out port

	CALL	SPI_SEND_BYTE		; Send byte in C
	RET

;--------------------------------------------------------------------------
; SSD1306_CLEAR
; Clear the entire display and move invisible text cursor to 0,0
; 
; Input: none
; Return: none
; Destroys: A, BC, DE
;--------------------------------------------------------------------------
SSD1306_CLEAR:
	LD		C,0x021				; Set column start and end address, byte one 0x21
	CALL	SSD1306_CMD

	LD		C,0x00				; Column address start, byte two 0x00 - 0x7F
	CALL	SSD1306_CMD

	LD		C,0x7F				; Column address end, byte three 0x00 - 0x7F
	CALL	SSD1306_CMD

	LD		C,0x22				; Set row start and end address, byte one 0x22
	CALL	SSD1306_CMD

	LD		C,0x00				; Row address start, byte two 0x00 - 0x07
	CALL	SSD1306_CMD

	LD		C,0x07				; Row address end, byte three 0x00 - 0x07
	CALL	SSD1306_CMD

	CALL	SPI_CSx_TRUE		; Assert CS1 for multiple data writes
	LD		BC,.BUF_LEN			; Number of bytes to clear

.CLEAR_LOOP:
	PUSH	BC					; Save counter
	LD		C,0x00				; Zero to clear pixel
	CALL	SSD1306_DATA
	POP		BC					; Get counter
	DEC		BC					; Adjust counter
	LD		A,B
	OR		C					; Check BC = 0
	JR		NZ,.CLEAR_LOOP		; Continue looping

	CALL	SPI_CSx_FALSE		; De-assert CS1, done with data writes

	XOR		A					; Set COLUMN & LINE to 0
	LD		(COLUMN), A
	LD		(LINE),A
	CALL	SSD1306_SETXY
	RET

;--------------------------------------------------------------------------
; SSD1306_SETXY
; Move invisible text cursor to an X, Y coordinate
; 0,0 = upper left, 7,127 = lower right
; Updates COLUMN and LINE if out of bounds
;
; Input: COLUMN = X coordinate
;		 LINE = Y coordinate
; Return: none
; Destroys: A, BC, DE
;--------------------------------------------------------------------------
SSD1306_SETXY:
	LD		C,0x21				; Set column start and end address, byte one 0x21
	CALL	SSD1306_CMD

	LD		A,(COLUMN)			; COLUMN -> A
	AND		0x7F				; Limit to 127d
	LD		(COLUMN),A			; Save it
	LD		C,A					; Copy COLUMN -> C, byte two
	CALL	SSD1306_CMD

	LD		C,0x7F				; Set column end address, byte three
	CALL	SSD1306_CMD

	LD		C,0x22				; Set row start and end address, byte one 0x22
	CALL	SSD1306_CMD

	LD		A,(LINE)
	AND		0x07				; Limit to 7d
	LD		(LINE),A			; Save it
	LD		C,A					; Copy LINE -> C, byte two
	CALL	SSD1306_CMD

	LD		C,0x07				; Set row end address, byte three
	CALL	SSD1306_CMD	
	RET

; Data area
LINE:		DEFB	0x00		; Current character line (X) (0 - 7d)
COLUMN:		DEFB	0x00		; Current pixel column (Y) (0 - 127d)

;--------------------------------------------------------------------------
; ASCII font data - supports ASCII values 0x20 - 0x7F
; Bit patterns for 5x7 font. Each array column element defines one 7 pixel
;	column of the displays possible 128x64 pixel field
;
; Examples:  0x7F  0x5F  0x60
;        _
; Bit = |0|   x     x
;        _
;       |1|   x     x
;        _
;       |2|   x     x
;        _
;       |3|   x     x
;        _
;       |4|   x     x
;        _
;       |5|   x           x
;        _
;       |6|   x     x     x
;--------------------------------------------------------------------------
.ASC_FONT:	DEFB	0x00,0x00,0x00,0x00,0x00	; 0x20 (space)
			DEFB	0x00,0x00,0x5f,0x00,0x00	; 0x21 !
			DEFB	0x00,0x07,0x00,0x07,0x00	; 0x22 "
			DEFB	0x14,0x7f,0x14,0x7f,0x14	; 0x23 #
			DEFB	0x24,0x2a,0x7f,0x2a,0x12	; 0x24 $
			DEFB	0x23,0x13,0x08,0x64,0x62	; 0x25 %
			DEFB	0x36,0x49,0x55,0x22,0x50	; 0x26 &
			DEFB	0x00,0x05,0x03,0x00,0x00	; 0x27 '
			DEFB	0x00,0x1c,0x22,0x41,0x00	; 0x28 (
			DEFB	0x00,0x41,0x22,0x1c,0x00	; 0x29 )
			DEFB	0x14,0x08,0x3e,0x08,0x14	; 0x2a *
			DEFB	0x08,0x08,0x3e,0x08,0x08	; 0x2b +
			DEFB	0x00,0x50,0x30,0x00,0x00	; 0x2c ,
			DEFB	0x08,0x08,0x08,0x08,0x08	; 0x2d -
			DEFB	0x00,0x60,0x60,0x00,0x00	; 0x2e .
			DEFB	0x20,0x10,0x08,0x04,0x02	; 0x2f /
			DEFB	0x3e,0x51,0x49,0x45,0x3e	; 0x30 0
			DEFB	0x00,0x42,0x7f,0x40,0x00	; 0x31 1
			DEFB	0x42,0x61,0x51,0x49,0x46	; 0x32 2
			DEFB	0x21,0x41,0x45,0x4b,0x31	; 0x33 3
			DEFB	0x18,0x14,0x12,0x7f,0x10	; 0x34 4
			DEFB	0x27,0x45,0x45,0x45,0x39	; 0x35 5
			DEFB	0x3c,0x4a,0x49,0x49,0x30	; 0x36 6
			DEFB	0x01,0x71,0x09,0x05,0x03	; 0x37 7
			DEFB	0x36,0x49,0x49,0x49,0x36	; 0x38 8
			DEFB	0x06,0x49,0x49,0x29,0x1e	; 0x39 9
			DEFB	0x00,0x36,0x36,0x00,0x00	; 0x3a :
			DEFB	0x00,0x56,0x36,0x00,0x00	; 0x3b ;
			DEFB	0x08,0x14,0x22,0x41,0x00	; 0x3c <
			DEFB	0x14,0x14,0x14,0x14,0x14	; 0x3d =
			DEFB	0x00,0x41,0x22,0x14,0x08	; 0x3e >
			DEFB	0x02,0x01,0x51,0x09,0x06	; 0x3f ?
			DEFB	0x32,0x49,0x79,0x41,0x3e	; 0x40 @
			DEFB	0x7e,0x11,0x11,0x11,0x7e	; 0x41 A
			DEFB	0x7f,0x49,0x49,0x49,0x36	; 0x42 B
			DEFB	0x3e,0x41,0x41,0x41,0x22	; 0x43 C
			DEFB	0x7f,0x41,0x41,0x22,0x1c	; 0x44 D
			DEFB	0x7f,0x49,0x49,0x49,0x41	; 0x45 E
			DEFB	0x7f,0x09,0x09,0x09,0x01	; 0x46 F
			DEFB	0x3e,0x41,0x49,0x49,0x7a	; 0x47 G
			DEFB	0x7f,0x08,0x08,0x08,0x7f	; 0x48 H
			DEFB	0x00,0x41,0x7f,0x41,0x00	; 0x49 I
			DEFB	0x20,0x40,0x41,0x3f,0x01	; 0x4a J
			DEFB	0x7f,0x08,0x14,0x22,0x41	; 0x4b K
			DEFB	0x7f,0x40,0x40,0x40,0x40	; 0x4c L
			DEFB	0x7f,0x02,0x0c,0x02,0x7f	; 0x4d M
			DEFB	0x7f,0x04,0x08,0x10,0x7f	; 0x4e N
			DEFB	0x3e,0x41,0x41,0x41,0x3e	; 0x4f O
			DEFB	0x7f,0x09,0x09,0x09,0x06	; 0x50 P
			DEFB	0x3e,0x41,0x51,0x21,0x5e	; 0x51 Q
			DEFB	0x7f,0x09,0x19,0x29,0x46	; 0x52 R
			DEFB	0x46,0x49,0x49,0x49,0x31	; 0x53 S
			DEFB	0x01,0x01,0x7f,0x01,0x01	; 0x54 T
			DEFB	0x3f,0x40,0x40,0x40,0x3f	; 0x55 U
			DEFB	0x1f,0x20,0x40,0x20,0x1f	; 0x56 V
			DEFB	0x3f,0x40,0x38,0x40,0x3f	; 0x57 W
			DEFB	0x63,0x14,0x08,0x14,0x63	; 0x58 X
			DEFB	0x07,0x08,0x70,0x08,0x07	; 0x59 Y
			DEFB	0x61,0x51,0x49,0x45,0x43	; 0x5a Z
			DEFB	0x00,0x7f,0x41,0x41,0x00	; 0x5b [
			DEFB	0x02,0x04,0x08,0x10,0x20	; 0x5c backslash
			DEFB	0x00,0x41,0x41,0x7f,0x00	; 0x5d ]
			DEFB	0x04,0x02,0x01,0x02,0x04	; 0x5e ^
			DEFB	0x40,0x40,0x40,0x40,0x40	; 0x5f _
			DEFB	0x00,0x01,0x02,0x04,0x00	; 0x60 `
			DEFB	0x20,0x54,0x54,0x54,0x78	; 0x61 a
			DEFB	0x7f,0x48,0x44,0x44,0x38	; 0x62 b
			DEFB	0x38,0x44,0x44,0x44,0x20	; 0x63 c
			DEFB	0x38,0x44,0x44,0x48,0x7f	; 0x64 d
			DEFB	0x38,0x54,0x54,0x54,0x18	; 0x65 e
			DEFB	0x08,0x7e,0x09,0x01,0x02	; 0x66 f
			DEFB	0x0c,0x52,0x52,0x52,0x3e	; 0x67 g
			DEFB	0x7f,0x08,0x04,0x04,0x78	; 0x68 h
			DEFB	0x00,0x44,0x7d,0x40,0x00	; 0x69 i
			DEFB	0x20,0x40,0x44,0x3d,0x00	; 0x6a j
			DEFB	0x7f,0x10,0x28,0x44,0x00	; 0x6b k
			DEFB	0x00,0x41,0x7f,0x40,0x00	; 0x6c l
			DEFB	0x7c,0x04,0x18,0x04,0x78	; 0x6d m
			DEFB	0x7c,0x08,0x04,0x04,0x78	; 0x6e n
			DEFB	0x38,0x44,0x44,0x44,0x38	; 0x6f o
			DEFB	0x7c,0x14,0x14,0x14,0x08	; 0x70 p
			DEFB	0x08,0x14,0x14,0x18,0x7c	; 0x71 q
			DEFB	0x7c,0x08,0x04,0x04,0x08	; 0x72 r
			DEFB	0x48,0x54,0x54,0x54,0x20	; 0x73 s
			DEFB	0x04,0x3f,0x44,0x40,0x20	; 0x74 t
			DEFB	0x3c,0x40,0x40,0x20,0x7c	; 0x75 u
			DEFB	0x1c,0x20,0x40,0x20,0x1c	; 0x76 v
			DEFB	0x3c,0x40,0x30,0x40,0x3c	; 0x77 w
			DEFB	0x44,0x28,0x10,0x28,0x44	; 0x78 x
			DEFB	0x0c,0x50,0x50,0x50,0x3c	; 0x79 y
			DEFB	0x44,0x64,0x54,0x4c,0x44	; 0x7a z
			DEFB	0x00,0x08,0x36,0x41,0x00	; 0x7b {
			DEFB	0x00,0x00,0x7f,0x00,0x00	; 0x7c |
			DEFB	0x00,0x41,0x36,0x08,0x00	; 0x7d }
			DEFB	0x10,0x08,0x08,0x10,0x08	; 0x7e ~
			DEFB	0x78,0x46,0x41,0x46,0x78	; 0x7f DEL

;--------------------------------------------------------------------------
;	Libraries
;--------------------------------------------------------------------------
include 'i2cspi_lib.asm'
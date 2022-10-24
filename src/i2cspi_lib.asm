;***********************************************************************************************************************
;
;						Z 8 0 - R E T R O !  I 2 C / S P I  B I T - B A N G  L I B R A R Y
;
;***********************************************************************************************************************
;	i2cspi_lib.asm v1.0 - an I2C/SPI master library for the <jb> Z80 Retro! SBC
;	Kenny Maytum - KRSynthWorx - October 24th, 2022
;***********************************************************************************************************************

;***********************************************************************************************************************
;								I 2 C / S P I  L I B R A R Y  L I C E N S E S
;***********************************************************************************************************************
;
;	This I2C library...
;
;	Copyright (C) 2022 Kenny Maytum - https://github.com/KRSynthWorx/z80-i2cspi
;
;	This library is free software; you can redistribute it and/or
;	modify it under the terms of the GNU Lesser General Public
;	License as published by the Free Software Foundation; either
;	version 2.1 of the License, or (at your option) any later version.
;
;	This library is distributed in the hope that it will be useful,
;	but WITHOUT ANY WARRANTY; without even the implied warranty of
;	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
;	Lesser General Public License for more details.
;
;	You should have received a copy of the GNU Lesser General Public
;	License along with this library; if not, write to the Free Software
;	Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
;	02110-1301 USA
;
;	https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html
;
;-----------------------------------------------------------------------------------------------------------------------
;
;	Portions of the SPI library algorithm provided by John Winans ...
;
;	Copyright (C) 2021,2022 John Winans - https://github.com/johnwinans/2063-Z80-cpm
;
;	This library is free software; you can redistribute it and/or
;	modify it under the terms of the GNU Lesser General Public
;	License as published by the Free Software Foundation; either
;	version 2.1 of the License, or (at your option) any later version.
;
;	This library is distributed in the hope that it will be useful,
;	but WITHOUT ANY WARRANTY; without even the implied warranty of
;	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
;	Lesser General Public License for more details.
;
;	You should have received a copy of the GNU Lesser General Public
;	License along with this library; if not, write to the Free Software
;	Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
;	02110-1301 USA
;
;	https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html
;
;-----------------------------------------------------------------------------------------------------------------------
;
;	Portions of the I2C bit-bang algorithm provided by K. S. Jiang ...
;
;	The MIT License
;
;	Copyright (C) 2018 siyujiang81 - https://github.com/ksjiang/bb85
;
;	Permission is hereby granted, free of charge, to any person obtaining a copy
;	of this software and associated documentation files (the "Software"), to deal
;	in the Software without restriction, including without limitation the rights
;	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;	copies of the Software, and to permit persons to whom the Software is
;	furnished to do so, subject to the following conditions:
;
;	The above copyright notice and this permission notice shall be included in all
;	copies or substantial portions of the Software.
;
;	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;	SOFTWARE.
;
;	https://mit-license.org/
;
;***********************************************************************************************************************

;***********************************************************************************************************************
;										A C K N O W L E D G E M E N T S
;***********************************************************************************************************************
;
;	Many thanks to John Winans and his Z80-Retro! SBC projects.
;
;	Z80-Retro! project:	https://github.com/johnwinans/2063-Z80
;	FLASH programmer:	https://github.com/johnwinans/2065-Z80-programmer
;	CP/M BIOS project:	https://github.com/johnwinans/2063-Z80-cpm
;
;	John's Basement <jb> YouTube Channel:
;	https://www.youtube.com/c/JohnsBasement
;
;***********************************************************************************************************************

;***********************************************************************************************************************
;
;							I 2 C  =  I N T E R - I N T E G R A T E D  C I R C U I T
;
;								I 2 C  P R O T O C A L  D E S C R I P T I O N
;
;***********************************************************************************************************************
; • Information provided by Texas Instruments Application Report SLVA704 - June 2015
; • Additional documentation from https://i2c-bus.org & https://www.kernel.org/doc/Documentation/i2c/busses/i2c-parport
;
; General I2C Operation:
; The I2C bus is a standard bidirectional interface that uses a controller, known as the master, to
; communicate with slave devices. A slave may not transmit data unless it has been addressed by the
; master. Each device on the I2C bus has a specific device address to differentiate between other devices
; that are on the same I2C bus. Many slave devices will require configuration upon startup to set the
; behavior of the device. This is typically done when the master accesses the slave's internal register maps,
; which have unique register addresses. A device can have one or multiple registers where data is stored,
; written, or read.
;
; Clock Generation:
; The SCL clock is always generated by the I2C master. The specification requires minimum periods for the low
; and high phases of the clock signal. Hence, the actual clock rate may be lower than the nominal clock rate
; e.g. in I2C buses with large rise times due to high capacitances.
;
; Clock Stretching:
; I2C devices can slow down communication by stretching SCL: During an SCL low phase, any I2C device on the
; bus may additionally hold down SCL to prevent it from rising again, enabling it to slow down the SCL clock
; rate or to stop I2C communication for a while. This is also referred to as clock synchronization.
;
; NOTE: The I2C specification does not specify any timeout conditions for clock stretching, i.e. any device
; can hold down SCL as long as it likes.
;
; Arbitration:
; Several I2C multi-masters can be connected to the same I2C bus and operate concurrently. By constantly
; monitoring SDA and SCL for START and STOP conditions, they can determine whether the bus is currently idle
; or not. If the bus is busy, masters delay pending I2C transfers until a STOP condition indicates that the bus
; is free again. However, it may happen that two masters start a transfer at the same time. During the transfer,
; the masters constantly monitor SDA and SCL. If one of them detects that SDA is low when it should actually be
; high, it assumes that another master is active and immediately stops its transfer. This process is called
; arbitration.
;
; Hardware:
; The physical I2C interface consists of the serial clock (SCL) and serial data (SDA) lines. Both SDA and
; SCL lines must be connected to VCC through a pull-up resistor. These lines are buffered with open drain/collector
; devices. The size of the pull-up resistor is determined by the amount of capacitance on the I2C lines 
; (for further details, refer to Texas Instruments I2C Pull-up Resistor Calculation (SLVA689) Application Report.
; Data transfer may be initiated only when the bus is idle. A bus is considered idle if both SDA and SCL lines are
; high after a STOP condition.
;
; I2C Device                                                  Z80-Retro!
; Bus            _____________________________ (+5 vdc)       Printer Port
;                |    |            |    |
;               ---  ---          ---  ---
;               | |  | |          | |  | |
;               |R|  |R|          |R|  |R|
;               | |  | |          | |  | |
;               ---  ---          ---  ---
;                |    |            |    |
;                |    |      |\    |    |
; SCL  <---------x--------x--| o---x----------------------->  Pin 13 - Status
;                     |   |  |/         |
;                     |   |             |
;                     |   |   /|        |
;                     |   ---o |-------------x-------------<  Pin 3 - D1
;                     |       \|        |    |
;                     |                 |    |
;                     |                 |    |
;                     |      |\         |    |
; SDA  <>-------------x---x--| o--------x------------------>  Pin 15 - Error
;                         |  |/              |
;                         |                  |
;                         |   /|             |
;                         ---o |------------------x--------<  Pin 2 - D0
;                             \|             |    |
;                                            |    |
;                                           ---  ---
;                                           | |  | |
;                                           |R|  |R|
;                                           | |  | |
;                                           ---  ---
;                                            |    |
;                                           GND  GND
;
; Simplified Interface Circuit Diagram (74HC05 Open Drain Inverting Hex Buffer)
;
; The general procedure for a master to access a slave device is the following:
; 1. Suppose a master wants to send data to a slave:
;	• Master-transmitter sends a START condition and addresses the slave-receiver
;	• Master-transmitter sends data to slave-receiver
;	• Master-transmitter terminates the transfer with a STOP condition
;
; 2. If a master wants to receive/read data from a slave:
;	• Master-receiver sends a START condition and addresses the slave-transmitter
;	• Master-receiver sends the requested register to read to slave-transmitter
;	• Master-receiver receives data from the slave-transmitter
;	• Master-receiver terminates the transfer with a STOP condition
;
; START and STOP conditions:
; I2C communication with a device is initiated by the master sending a START condition and terminated
; by the master sending a STOP condition. A high-to-low transition on the SDA line while the SCL is high
; defines a START condition. A low-to-high transition on the SDA line while the SCL is high defines a STOP
; condition.
;
;      :   :                           :   :
;     _:___:     ___           ___     :___:_
; SCL  :   :\___/   \__ ... __/   \___/:   :
;      :   :                           :   :
;     _:_  :   _______       _______   :  _:_
; SDA  : \_:__/_______X ... X_______\__:_/ :
;      :   :                           :   :
;      : ^ :  ^                     ^  : ^ :
;        |     \___________________/     |
;      START       Data Transfer        STOP
;    Condition                        Condition
;
; Repeated START Condition:
; A repeated START condition is similar to a START condition and is used in place of a back-to-back STOP
; then START condition. It looks identical to a START condition, but differs from a START condition
; because it happens before a STOP condition (when the bus is not idle). This is useful for when the master
; wishes to start a new communication, but does not wish to let the bus go idle with the STOP condition,
; which has the chance of the master losing control of the bus to another master (in multi-master
; environments).
;
; Data Validity and Byte Format:
; One data bit is transferred during each clock pulse of the SCL. One byte is comprised of eight bits on the
; SDA line. A byte may either be a device address, register address, or data written to or read from a slave.
; Data is transferred Most Significant Bit (MSB) first. Any number of data bytes can be transferred from the
; master to slave between the START and STOP conditions. Data on the SDA line must remain stable
; during the high phase of the clock period, as changes in the data line when the SCL is high are
; interpreted as control commands (START or STOP as described above).
;
;         _____________ SDA line stable while SCL line is high ______________
;        /                                                                   \
;         ___     ___     ___     ___     ___     ___     ___     ___     ___
; SCL ___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \_
;        : 1 :   : 0 :   : 1 :   : 0 :   : 1 :   : 0 :   : 1 :   : 0 :   :ACK:
;        :   :   :   :   :   :   :   :   :   :   :   :   :   :   :   :   :   :
;       _:___:_  :   :  _:___:_  :   :  _:___:_  :   :  _:___:_  :   :   :   :
; SDA _/ :   : \_:___:_/ :   : \_:___:_/ :   : \_:___:_/ :   : \_:___:___:___:_
;        :   :   :   :   :   :   :   :   :   :   :   :   :   :   :   :   :   :
;        :   :   :   :   :   :   :   :   :   :   :   :   :   :   :   :   :   :
;          ^       ^       ^       ^       ^       ^       ^       ^       ^
;          |       |       |       |       |       |       |       |       |
;         MSB     BIT     BIT     BIT     BIT     BIT     BIT     LSB     ACK
;        \__________________________________________________________/
;                    Example: Byte 1010 1010 (0xAA) - ACK
;
; Acknowledge (ACK) and Not-Acknowledge (NACK):
; Each byte of data (including the address byte) is followed by one ACK bit from the receiver. The ACK bit
; allows the receiver to communicate to the transmitter that the byte was successfully received and another
; byte may be sent.
;
; Before the receiver can send an ACK, the transmitter must release the SDA line. To send an ACK bit, the
; receiver shall pull down the SDA line during the low phase of the ACK/NACK-related clock period (period 9),
; so that the SDA line is stable low during the high phase of the ACK/NACK-related clock period. Setup and
; hold times must be taken into account.
;
; When the SDA line remains high during the ACK/NACK-related clock period, this is interpreted as a
; NACK. There are several conditions that lead to the generation of a NACK:
; 1. The receiver is unable to receive or transmit because it is performing some real-time function and is
;    not ready to start communication with the master.
; 2. During the transfer, the receiver gets data or commands that it does not understand.
; 3. During the transfer, the receiver cannot receive any more data bytes.
; 4. A master-receiver is done reading data and indicates this to the slave through a NACK.
;
;         ___     ___     ___     ___     ___     ___     ___     ___     ___     _____
; SCL ___/ 1 \___/ 2 \___/ 3 \___/ 4 \___/ 5 \___/ 6 \___/ 7 \___/ 8 \___/ 9 \___/
;        :   :   :   :   :   :   :   :   :   :   :   :   :   :   :   :   :   :   :   :
;        :   :   :   :   :   :   :   :   :   :   :   :   :   :   :   :   :   :   :   :
;       _:___:_  :   :  _:___:_  :   :  _:___:_  :   :  _:___:_  :   :  _:___:_  :  _:_
; SDA _/ :   : \_:___:_/ :   : \_:___:_/ :   : \_:___:_/ :   : \_:___:_/ :   : \_:_/ :
;        :   :   :   :   :   :   :   :   :   :   :   :   :   :   :   :   :   :   :   :
;        :   :   :   :   :   :   :   :   :   :   :   :   :   :   :   :   :   :   :   :
;          ^       ^       ^       ^       ^       ^       ^       ^       ^       ^
;          |       |       |       |       |       |       |       |       |       |
;         MSB      |       |       |       |       |       |      LSB      |      STOP
;         D7      D6      D5      D4      D3      D2      D1      D0      NACK  Condition
;        \___________________________________________________________/
;                 Example: Data Byte 1010 1010 (0xAA) - NACK
;
; I2C Data:
; Data must be sent and received to or from the slave devices, but the way that this is accomplished is by
; reading or writing to or from registers in the slave device. Registers are locations in the slave's
; memory which contain information, whether it be the configuration information, or some sampled data to
; send back to the master. The master must write information into these registers in order to instruct the
; slave device to perform a task.
;
; While it is common to have registers in I2C slaves, please note that not all slave devices will have
; registers. Some devices are simple and contain only 1 register, which may be written directly to by
; sending the register data immediately after the slave address, instead of addressing a register. An
; example of a single-register device would be an 8-bit I2C switch, which is controlled via I2C commands.
; Since it has 1 bit to enable or disable a channel, there is only 1 register needed, and the master merely
; writes the register data after the slave address, skipping the register number.
;
; Writing to a Slave on the I2C Bus:
; To write on the I2C bus, the master will send a START condition on the bus with the slave's address, as well
; as the last bit (the R/W bit) set to 0, which signifies a write. After the slave sends the acknowledge bit, the
; master will then send the register address of the register it wishes to write to. The slave will acknowledge
; again, letting the master know it is ready. After this, the master will start sending the register data to the
; slave, until the master has sent all the data it needs to (sometimes this is only a single byte), and the
; master will terminate the transmission with a STOP condition.
;
; NOTE: Slave controls SDL line during ACK, Master controls SDL line at all other times.
;
;     7-Bit Slave Address_       8-Bit Register Address_    _ 8-Bit Register Data _
;    /                    \     /                       \  /                       \
;  -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
; |ST|6 |5 |4 |3 |2 |1 |0 |W |AK|7 |6 |5 |4 |3 |2 |1 |0 |AK|7 |6 |5 |4 |3 |2 |1 |0 |AK|SP|
;  -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
;  ^                       ^  ^                          ^                          ^  ^
;  |                       |  |                          |                          |  |
; START                 R/W=0 ACK                       ACK                       ACK STOP
;
;                   Example: I2C Write to One Register in a Slave Device
;
; Reading from a Slave on the I2C Bus:
; Reading from a slave is very similar to writing, but with some extra steps. In order to read from a slave,
; the master must first instruct the slave which register it wishes to read from. This is done by the master
; starting off the transmission in a similar fashion as the write, by sending the address with the R/W bit
; equal to 0 (signifying a write), followed by the register address it wishes to read from. Once the slave
; acknowledges this register address, the master will send a START condition again, followed by the slave
; address with the R/W bit set to 1 (signifying a read). This time, the slave will acknowledge the read
; request, and the master releases the SDA bus, but will continue supplying the clock to the slave. During
; this part of the transaction, the master will become the master-receiver, and the slave will become the
; slave-transmitter.
;
; The master will continue sending out the clock pulses, but will release the SDA line, so that the slave can
; transmit data. At the end of every byte of data, the master will send an ACK to the slave, letting the slave
; know that it is ready for more data. Once the master has received the number of bytes it is expecting, it
; will send a NACK, signaling to the slave to halt communications and release the bus. The master will
; follow this up with a STOP condition.
;
; NOTE: Slave controls SDA line during ACK and D0-D7, Master controls SDL line at all other times.
;
;     7-Bit Slave Address_       8-Bit Register Address_       7-Bit Slave Address_       _ 8-Bit Register Data _
;    /                    \     /                       \     /                    \     /                       \
;  -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
; |ST|6 |5 |4 |3 |2 |1 |0 |W |AK|7 |6 |5 |4 |3 |2 |1 |0 |AK|RS|6 |5 |4 |3 |2 |1 |0 |R |AK|D7|D6|D5|D4|D3|D2|D1|D0|NK|SP|
;  -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
;  ^                       ^  ^                          ^  ^                       ^  ^                          ^  ^
;  |                       |  |                          |  |                       |  |                          |  |
; START                 R/W=0 ACK                       ACK Repeated             R/W=1 ACK                     NACK STOP
;                                                           START
;
;                             Example: I2C Read from One Register in a Slave Device
;
;***********************************************************************************************************************

;***********************************************************************************************************************
;
;										U S I N G  T H I S  L I B R A R Y
;
;***********************************************************************************************************************
;
;	Set editor for tabstops = 4
;	You can also set Github tabstops to 4 permanently from the upper right
;	hand corner->profile icon dropdown->Settings->Appearance->Tab size preference
;
;	Build using included Makefile
;	make					; Build all examples included with this library
;	make ad_test.hex		; Build only ad_test.asm
;	make eeprom_test.hex	; Build only eeprom_test.asm
;	make gpio_test.hex		; Build only gpio_test.asm
;	make spi_test.hex		; Build only spi_test.asm
;	make clean				; Remove all built items
;
;	To use this library in your own programs, put the following line at the end of your source file:
;
;		include 'i2cspi.asm'
;
;	The Makefile requires the srec_cat utility to convert .bin files to .hex files. It is available
;	as part of the srecord package of utilities and can be installed on Linux using:
;
;		sudo apt-get install srecord
;
;
;	All of the included example programs are assembled at ORG 0x1000. The Z80asm v1.8 assembler does
;	not output the .hex files required by the monitor for uploading code. The Makefile uses the srec_cat
;	utility to convert .bin files to .hex files. An offset address is used by srec_cat to indicate the
;	origin location of the .bin file output by z80asm. By default this offset is set to 0x1000 to match
;	the assembled ORG 0x1000 in the examples. If you change the ORG directive location, you need to also
;	change the offset in the Makefile. Comments in the Makefile indicate where to make this change.
;
;	The symbol table retromon.sym file is required to build this library and by default is located in
;	the z80-retro-monitor/src/ folder and output during the build of retromon.asm. You can modify the
;	included Makefile if your retromon.sym file is located in another location. Comments in the Makefile
;	show where to make this change.
;
;	The included example test programs illustrate the necessary flow to initialize and use this library.
;	You can use them as templates for more advanced operations and writing new routines for other I2C and
;	SPI devices.

;	The I2C portion of the library uses extensive error checking of all I2C communications. After an error
;	occurs, the error status variable I2C_STAT is updated and control is returned back to the calling function.
;	If you wish to include error checking in your programs, you should check this variable after each I2C
;	library function call. Bit patterns are provided below in the I2C_STAT EQU statements showing the various
;	error bits. These are all in bit fields so bit masks are provided to isolate each possible error.
;
;	After checking the I2C_STAT variable and seeing an error bit set, you can assign an Error code of your
;	choosing or use the pre-defined EQU ones in the Error code equate section below. All of the I2C example
;	programs use this method of error checking. See these example programs included for more information.
;
;	Because the SPI protocol is much simpler and more generic, no error checking is provided. It is up to
;	the programmer to check the datasheets of the devices being used and decide on the best method of error
;	checking if required.
;
;	Additionally the I2C and SPI ports are independent of each other and know about each others use of the
;	common PRN_DAT output port on the Z80-Retro! You can initialize and use both types of ports concurrently.
;
;	Thank you for your interest in this project!
;	Kenny Maytum - KRSynthWorx
;
;***********************************************************************************************************************

; NOTE: Labels prefixed with a '.' denote local symbols in scope for only THIS file

include 'retromon.sym'			; Include symbols from the monitor in control of the system

; I2C/SPI bit-assignment equates
.SDA:				EQU	0x01	; PRN_DAT [bit 0] I2C Data
.SCL:				EQU	0x02	; PRN_DAT [bit 1] I2C Clock
.MOSI:				EQU	0x04	; PRN_DAT [bit 2] SPI Master-out Slave-in
.SCLK:				EQU 0x08	; PRN_DAT [bit 3] SPI Clock
CS1:				EQU	0x10	; PRN_DAT [bit 4] SPI /CS1
CS2:				EQU	0x20	; PRN_DAT [bit 5] SPI /CS2
CS3:				EQU	0x40	; PRN_DAT [bit 6] SPI /CS3
CS4:				EQU	0x80	; PRN_DAT [bit 7] SPI /CS4
.MISO:				EQU 0x04	; GPIO_IN [bit 2] SPI Master-in Slave-out

MODE0:				EQU	0x00	; SPI_INIT [none] MODE 0
MODE1:				EQU	0x01	; SPI_INIT [bit 0] MODE 1
MODE2:				EQU 0x02	; SPI_INIT [bit 1] MODE 2
MODE3:				EQU 0x03	; SPI_INIT [bit 0&1] MODE 3
MSB_LSB:			EQU	0x00	; SPI_INIT [none] bit order MSB first, LSB last
LSB_MSB:			EQU 0x04	; SPI_INIT [bit 2] bit order LSB first, MSB last

; I2C_STAT variable options: (format EEExxxxx, EEE -> error bits, x -> none)
NO_ERR:				EQU	0x1F	; 00011111B error bits -> 000:no error
TIMEOUT:			EQU	0x80	; 10000000B error bits -> 100:timeout
TIMEOUT_MASK:		EQU	0x9F	; 10011111B error bits -> 100:timeout mask
ARBLOST:			EQU	0xA0	; 10100000B error bits -> 101:arbitration lost
ARBLOST_MASK:		EQU	0xBF	; 10111111B error bits -> 101:arbitration lost mask
NACK:				EQU	0xC0	; 11000000B	error bits -> 110:not-acknowledge
NACK_MASK:			EQU	0xDF	; 11011111B error bits -> 110:not-acknowledge mask

; Error code equates:
START_ERR:			EQU	10000000B	; Failed at START (0x80)
ADDR_ERR:			EQU 10000001B	; Failed at device address send (0x81)
WRITE_ERR:			EQU 10000010B	; Failed at data write (0x82)
READ_ERR:			EQU	10000011B	; Failed at data read (0x83)
STOP_ERR:			EQU	10000100B	; Failed at STOP (0x84)

; Misc equates
.TRUE:				EQU	0x01
.STD_DELAY:			EQU	0x01	; 4.5us @ 10Mhz CPU clock
.WD_TIMEOUT:		EQU	0x8000	; Max retries before timeout

;**************************************************************************
;
;					I 2 C  P O R T  S U B R O U T I N E S
;
;**************************************************************************

;--------------------------------------------------------------------------
; DELAY
; General-purpose delay
;
; Input: none
; Return: none
;
; Timing info:
; Total T-states: 45 w/false DELAY1, 50 w/true DELAY1,
;	includes +17 for function call
; One loop = 45 T-states
; Additional loops = 16 T-states each
; Loops = 1 for 4.5us delay, +1.6us per each additional loop
; [n] = number of T-states, 1 T-state = 100ns or .1us @ 10Mhz
; Destroys: A
;--------------------------------------------------------------------------
DELAY:
	LD		A,.STD_DELAY	; [7] Get count

.DELAY1:
	DEC		A				; [4] Loop counter
	JR		NZ,.DELAY1		; [7F/12T]
	RET						; [10]

;--------------------------------------------------------------------------
; I2C_INIT
; Initialize I2C status variables and the Z80-Retro! PRN_DAT port
;
; Input: none
; Return: none
; Destroys: A
;--------------------------------------------------------------------------
I2C_INIT:
	LD		A,(PORT_CACHE)	; Get current port data
	AND		0+~(.SDA|.SCL)	; Clear SDA & SCL
	LD		(PORT_CACHE),A	; Save copy back in cache
	OUT		(PRN_DAT),A		; Out to port

	XOR		A				; Zero accumulator, clear carry
	LD		(I2C_RUNNING),A	; Set I2C_RUNNING to false
	CALL	ACTIVE_LED		; Turn off ACTIVE LED
	RET

;--------------------------------------------------------------------------
; ACTIVE_LED
; Sets the ACTIVE LED on the I2C/SPI interface board on or off
; NOTE: The LED is connected to the Z80-Retro! /PRN_STB GPIO output
;		(active low) so it is initialized ON during boot of the
;		Retro Monitor to prevent a connected printer from activating
;
; Input: C flag = reset to turn LED off else LED on
; Return: none
; Destroys: A
;--------------------------------------------------------------------------
ACTIVE_LED:
	LD		A,(GPIO_OUT_CACHE)	; Get main GPIO port cache value
	JP		C,.LED_ON

	AND		~GPIO_OUT_PRN_STB	; Mask off LED bit

.LED_EXIT:
	LD		(GPIO_OUT_CACHE),A	; Save copy in cache
	OUT		(GPIO_OUT),A		; Out to port
	RET

.LED_ON:
	OR		GPIO_OUT_PRN_STB	; Set LED bit
	JP		.LED_EXIT

;--------------------------------------------------------------------------
; I2C_CLEAR_SCL
; Pull the I2C bus CLK line low
;
; Input: none
; Return: none
; Destroys: A
;--------------------------------------------------------------------------
.I2C_CLEAR_SCL:
	LD		A,(PORT_CACHE)	; Get current port data
	OR		.SCL			; Pull CLK low by setting A[1] = 1
	LD		(PORT_CACHE),A	; Save copy in cache
	OUT		(PRN_DAT),A
	RET

;--------------------------------------------------------------------------
; I2C_SET_SCL
; Release the I2C bus CLK line
;
; Input: none
; Return: none
; Destroys: A
;--------------------------------------------------------------------------
.I2C_SET_SCL:
	LD		A,(PORT_CACHE)	; Get current port data
	AND		~.SCL			; Release CLK by resetting A[1] = 0
	LD		(PORT_CACHE),A	; Save copy in cache
	OUT		(PRN_DAT),A
	RET

;--------------------------------------------------------------------------
; I2C_CLEAR_SDA
; Pull the I2C bus DATA line low
;
; Input: none
; Return: none
; Destroys: A
;--------------------------------------------------------------------------
.I2C_CLEAR_SDA:
	LD		A,(PORT_CACHE)	; Get current port data
	OR		.SDA			; Pull DATA low by setting A[0] = 1
	LD		(PORT_CACHE),A	; Save copy in cache
	OUT		(PRN_DAT),A
	RET

;--------------------------------------------------------------------------
; I2C_SET_SDA
; Release the I2C bus DATA line
;
; Input: none
; Return: none
; Destroys: A
;--------------------------------------------------------------------------
.I2C_SET_SDA:
	LD		A,(PORT_CACHE)	; Get current port data
	AND		~.SDA			; Release DATA by resetting A[0] = 0
	LD		(PORT_CACHE),A	; Save copy in cache
	OUT		(PRN_DAT),A
	RET

;--------------------------------------------------------------------------
; I2C_READ_SCL
; Sample the I2C bus CLK line
;
; Input: none
; Return: C flag = CLK
; Destroys: A
;--------------------------------------------------------------------------
.I2C_READ_SCL:
	IN		A,(GPIO_IN)
	XOR		.SCL			; Complement SCL from inverting buffer
	RRA
	RRA						; Move CLK bit to carry flag
	JP		C,.I2C_READ_SCL1

	AND		A				; If CLK = 0, clear carry flag and return
	RET

.I2C_READ_SCL1:
	SCF						; Else set carry flag and return
	RET

;--------------------------------------------------------------------------
; I2C_READ_SDA
; Sample the I2C bus DATA line
;
; Input: none
; Return: C flag = DATA
; Destroys: A
;--------------------------------------------------------------------------
.I2C_READ_SDA:
	IN		A,(GPIO_IN)
	XOR		.SDA			; Complement SDA from inverting buffer
	RRA						; Move DATA bit to carry flag
	JP		C,.I2C_READ_SDA1

	AND		A				; If DATA = 0, clear carry flag and return
	RET

.I2C_READ_SDA1:
	SCF						; Else set carry flag and return
	RET

;--------------------------------------------------------------------------
; I2C_ACTION_OK
; The action was successful
;
; Input: none
; Return: A = passed through return value
;		  Reset bits in I2C_STAT[7-5] = 000
; Destroys: none
;--------------------------------------------------------------------------
.I2C_ACTION_OK:
	PUSH	AF				; Save calling routine return value and flags

	LD		A,(I2C_STAT)	; Get current I2C_STAT
	AND		NO_ERR			; Reset bits I2C_STAT[7-5] = 000:no error
	LD		(I2C_STAT),A	; Save back to I2C_STAT

	POP		AF				; Restore return value and flags
	RET

;--------------------------------------------------------------------------
; I2C_TIMEOUT_ERR
; ERR:timeout
; Exit communication and return to calling procedure
;
; Input: none
; Return: set bits in I2C_STAT[7-5] = 100
; Destroys: A
;--------------------------------------------------------------------------
.I2C_TIMEOUT_ERR:
	CALL	.I2C_SET_SCL
	CALL	.I2C_SET_SDA
	LD		A,(I2C_STAT)	; Get current I2C_STAT
	AND		TIMEOUT_MASK
	OR		TIMEOUT			; Mask and set bits I2C_STAT[7-5] = 100:timeout
	LD		(I2C_STAT),A	; Save back in I2C_STAT

	XOR		A				; Zero accumulator, clear carry for LED
	LD		(I2C_RUNNING),A	; Communication has ended
	CALL	ACTIVE_LED		; Turn off ACTIVE LED
	RET

;--------------------------------------------------------------------------
; I2C_ARBLOST_ERR
; ERR:arblost
; Exit communication and return to calling procedure
;
; Input: none
; Return: set bits in I2C_STAT[7-5] = 101
; Destroys: A
;--------------------------------------------------------------------------
.I2C_ARBLOST_ERR:
	CALL	.I2C_SET_SCL
	CALL	.I2C_SET_SDA
	LD		A,(I2C_STAT)	; Get current I2C_STAT
	AND		ARBLOST_MASK
	OR		ARBLOST			; Mask and set bits I2C_STAT[7-5] = 101:arblost
	LD		(I2C_STAT),A	; Save back in I2C_STAT

	XOR		A				; Zero accumulator, clear carry for LED
	LD		(I2C_RUNNING),A	; Communication has ended
	CALL	ACTIVE_LED		; Turn off ACTIVE LED
	RET

;--------------------------------------------------------------------------
; I2C_NACK_ERR
; ERR:nack
; Exit communication and return to calling procedure
;
; Input: none
; Return: set bits in I2C_STAT[7-5] = 110
; Destroys: A
;--------------------------------------------------------------------------
.I2C_NACK_ERR:
	CALL	.I2C_SET_SCL
	CALL	.I2C_SET_SDA
	LD		A,(I2C_STAT)	; Get current I2C_STAT
	AND		NACK_MASK
	OR		NACK			; Mask and set bits I2C_STAT[7-5] = 110:nack
	LD		(I2C_STAT),A	; Save back in I2C_STAT

	XOR		A				; Zero accumulator, clear carry for LED
	LD		(I2C_RUNNING),A	; Communication has ended
	CALL	ACTIVE_LED		; Turn off ACTIVE LED
	RET

;--------------------------------------------------------------------------
; I2C_START
; Initiate I2C communication with a START condition
;
; Input: none
; Return: none
; Destroys: A, BC
;--------------------------------------------------------------------------
I2C_START:	
	LD		A,(I2C_START)
	OR		A
	JR		Z,.I2C_START3		; Check if communication is running

	CALL	.I2C_SET_SDA
	CALL	DELAY
	CALL	.I2C_SET_SCL
	LD		BC,.WD_TIMEOUT		; Timeout timer

.I2C_START1:					; Implement clock-stretching
	CALL	.I2C_READ_SCL
	JP		C,.I2C_START2

	DEC		BC
	LD		A,B
	OR		C					; Check for BC = 0
	JP		NZ,.I2C_START1

	JP		.I2C_TIMEOUT_ERR	; Timeout error

.I2C_START2:
	CALL	DELAY

.I2C_START3:
	CALL	.I2C_READ_SDA
	JP		C,.I2C_START4

	JP		.I2C_ARBLOST_ERR	; Arbitration lost error

.I2C_START4:
	CALL	.I2C_CLEAR_SDA
	CALL	DELAY
	CALL	.I2C_CLEAR_SCL
	LD		A,.TRUE
	LD		(I2C_RUNNING),A		; Communication is running

	SCF							; Set carry
	CALL	ACTIVE_LED			; Turn on ACTIVE LED
	JP		.I2C_ACTION_OK

;--------------------------------------------------------------------------
; I2C_STOP
; Stop I2C communication with a STOP condition
;
; Input: none
; Return: none
; Destroys: A, BC
;--------------------------------------------------------------------------
I2C_STOP:
	AND		A					; Clear carry for LED
	CALL	ACTIVE_LED			; Turn off ACTIVE LED
	CALL	.I2C_CLEAR_SDA
	CALL	DELAY
	CALL	.I2C_SET_SCL
	LD		BC,.WD_TIMEOUT		; Timeout timer

.I2C_STOP1:						; Implement clock-stretching
	CALL	.I2C_READ_SCL
	JP		C,.I2C_STOP2

	DEC		BC
	LD		A,B
	OR		C					; Check for BC = 0
	JP		NZ,.I2C_STOP1

	JP		.I2C_TIMEOUT_ERR	; Timeout error

.I2C_STOP2:
	CALL	DELAY
	CALL	.I2C_SET_SDA
	CALL	DELAY
	CALL	.I2C_READ_SDA
	JP		C,.I2C_STOP3

	JP		.I2C_ARBLOST_ERR	; Arbitration lost error

.I2C_STOP3:
	XOR		A					; Zero accumulator
	LD		(I2C_RUNNING),A		; Communication has ended

	JP		.I2C_ACTION_OK

;--------------------------------------------------------------------------
; I2C_SEND_BIT
; Send a bit over the I2C bus
;
; Input: C flag = BIT to send
; Return: none
; Destroys: A, BC
;--------------------------------------------------------------------------
I2C_SEND_BIT:
	PUSH	AF					; Save carry flag, will be checked later
	JP		NC,.I2C_SEND_BIT1

	CALL	.I2C_SET_SDA		; Send a 1
	JP		.I2C_SEND_BIT2

.I2C_SEND_BIT1:
	CALL	.I2C_CLEAR_SDA		; Send a 0

.I2C_SEND_BIT2:
	CALL	DELAY
	CALL	.I2C_SET_SCL
	CALL	DELAY

	LD		BC,.WD_TIMEOUT		; Timeout timer

.I2C_SEND_BIT3:					; Implement clock-stretching
	CALL	.I2C_READ_SCL		; Read bit -> carry
	JP		C,.I2C_SEND_BIT4

	DEC		BC
	LD		A,B
	OR		C					; Check if BC = 0
	JP		NZ,.I2C_SEND_BIT3

	POP		AF					; Clean-up stack
	JP		.I2C_TIMEOUT_ERR	; Timeout error

.I2C_SEND_BIT4:
	POP		AF					; Restore carry flag to check arbitration lost
	JP		NC,.I2C_SEND_BIT5

	CALL	.I2C_READ_SDA
	JP		C,.I2C_SEND_BIT5

	JP		.I2C_ARBLOST_ERR	; Arbitration lost error

.I2C_SEND_BIT5:
	CALL	.I2C_CLEAR_SCL
	RET

;--------------------------------------------------------------------------
; I2C_READ_BIT
; Read a bit on the I2C bus
;
; Input: none
; Return: C flag = BIT reading
; Destroys: none
;--------------------------------------------------------------------------
I2C_READ_BIT:
	PUSH	AF					; Protect AF
	PUSH	BC					; Protect BC

	CALL	.I2C_SET_SDA
	CALL	DELAY
	CALL	.I2C_SET_SCL

	LD		BC,.WD_TIMEOUT		; Timeout timer

.I2C_READ_BIT1:					; Implement clock-stretching
	CALL	.I2C_READ_SCL		; Read bit -> carry
	JP		C,.I2C_READ_BIT2

	DEC		BC
	LD		A,B
	OR		C					; Check if BC = 0
	JP		NZ,.I2C_READ_BIT1

	POP		BC					; Clean-up stack
	POP		AF
	JP		.I2C_TIMEOUT_ERR	; Timeout error

.I2C_READ_BIT2:
	CALL	DELAY
	CALL	.I2C_READ_SDA		; Read bit -> carry
	PUSH	AF					; Save carry
	CALL	.I2C_CLEAR_SCL
	POP		AF					; Read bit -> carry
	POP		BC					; Restore BC
	JP		C,.I2C_READ_BIT3

	POP		AF					; Clean-up stack

	AND		A					; Clear carry and return
	JP		.I2C_ACTION_OK

.I2C_READ_BIT3:
	POP		AF					; Restore AF
	SCF							; Set carry and return
	JP		.I2C_ACTION_OK

;--------------------------------------------------------------------------
; I2C_SEND_BYTE
; Send a byte to the I2C bus
;
; Input: A = data byte to send
; Return: none
; Destroys: A, BC
;--------------------------------------------------------------------------
I2C_SEND_BYTE:
	LD		C,0x08			; Bit counter

.I2C_SEND_BYTE1:
	RLA						; Position bit to send, MSB -> carry
	LD		B,A				; Save byte
	PUSH	BC				; Save byte and counter
	CALL	I2C_SEND_BIT	; Send bit

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Error bit -> carry
	JP		NC,.I2C_SEND_BYTE2

	POP		BC				; Clean-up stack
	RET						; Bit-level error, communication stopped and return

.I2C_SEND_BYTE2:
	POP		BC				; Retrieve byte and counter
	LD		A,B				; Restore byte
	DEC		C				; Adjust bit counter
	JP		NZ,.I2C_SEND_BYTE1

	CALL	I2C_READ_BIT	; Byte send complete, check for ACK
	JP		NC,.I2C_SEND_BYTE3

	JP		.I2C_NACK_ERR	; NACK error if carry set

.I2C_SEND_BYTE3:
	JP		.I2C_ACTION_OK

;--------------------------------------------------------------------------
; I2C_READ_BYTE
; Read a byte from the I2C bus
;
; Input: C flag = reset -> ACK, set -> NACK
; Return: A = 8-bit data
; Destroys: A, BC
;--------------------------------------------------------------------------
I2C_READ_BYTE:
	PUSH	AF				; Save carry flag for later

	LD		C,0x08			; Bit counter
	XOR		A				; Clear accumulator

.I2C_READ_BYTE1:
	PUSH	BC				; Save counter

	CALL	I2C_READ_BIT	; Read bit -> carry
	RLA						; Position carry to LSB
	LD		B,A				; Save byte so far

	LD		A,(I2C_STAT)	; Get I2C_STAT
	RLA						; Error bit -> carry
	JP		NC,.I2C_READ_BYTE2

	POP		BC				; Clean-up stack
	POP		AF
	RET						; Bit-level error, communication stopped and return

.I2C_READ_BYTE2:
	LD		A,B				; Restore byte so far
	POP		BC				; Retrieve byte and counter
	DEC		C				; Adjust bit counter
	JP		NZ,.I2C_READ_BYTE1

	LD		B,A				; Save completed byte

	POP		AF				; Restore carry flag
	PUSH	BC				; Save byte
	CALL	I2C_SEND_BIT	; Carry -> bit to send

	POP		BC
	LD		A,B				; Restore completed byte for return in A

	JP		.I2C_ACTION_OK

;--------------------------------------------------------------------------
; I2C_SEND_STREAM
; Send a byte stream to the I2C bus
;
; Input: BC = # bytes to send
;		 HL = byte stream pointer
; Return: none
; Destroys: A, BC, HL
;--------------------------------------------------------------------------
I2C_SEND_STREAM:
	LD		A,(HL)				; Byte to send

	PUSH	BC					; Protect BC
	CALL	I2C_SEND_BYTE
	POP		BC

	LD		A,(I2C_STAT)		; Get I2C_STAT
	RLA							; Position error bit -> carry
	JP		C,.I2C_SEND_STREAM1	; Exit

	INC		HL					; Advance byte pointer
	DEC		BC
	LD		A,B
	OR		C					; Check BC = 0
	JR		NZ,I2C_SEND_STREAM

.I2C_SEND_STREAM1:
	RET

;--------------------------------------------------------------------------
; I2C_READ_STREAM
; Read a byte stream from the I2C bus
;
; Input: BC = # of bytes to read
;		 HL = byte stream pointer
; Return: none
; Destroys: A, BC, HL
;--------------------------------------------------------------------------
I2C_READ_STREAM:
	DEC		BC					; Adjust byte counter
	LD		A,B
	OR		C					; Check BC = 0, clear carry - > send ACK
	JP		Z,.I2C_READ_STREAM1

	PUSH 	BC					; Save byte counter
	CALL	I2C_READ_BYTE		; Byte read -> A
	LD		B,A					; Save received data before error check

	LD		A,(I2C_STAT)		; Get I2C_STAT
	RLA							; Position error bit -> carry
	JP		C,.I2C_READ_STREAM2	; Error

	LD		(HL),B				; Save byte in stream
	INC		HL					; Advance byte pointer
	POP		BC					; Restore byte counter
	JP		I2C_READ_STREAM

.I2C_READ_STREAM1:
	SCF							; Set carry -> send NACK
	CALL	I2C_READ_BYTE
	LD		(HL),A				; No need to error check last operation

.I2C_READ_STREAM2:
	RET		NC					; Return if no error

	POP		BC					; Clean-up stack if carry set (error)
	RET

;**************************************************************************
;
;		S P I  =  S E R I A L  P E R I P H E R A L  I N T E R F A C E
;
;					S P I  P O R T  S U B R O U T I N E S
;
;**************************************************************************

;**************************************************************************
; A 4-wire SPI library for use with SPI modes 0 - 3. MSB first - LSB last
; or LSB first - MSB last bit directions are supported. 4 chip select lines
; CS1 - CS4 are supported.
;
; MODE 0: (Clock Polarity - CPOL = 0, Clock Phase - CPHA = 0)
; SCLK idle state = low
; Data changes on falling SCLK edge & sampled on rising SCLK edge:
;        __                                             ___
; /CSx     \______________________ ... ________________/      Host --> Device
;                 __    __    __   ... _    __    __
; SCLK   ________/  \__/  \__/  \__     \__/  \__/  \______   Host --> Device
;        _____ _____ _____ _____ _     _ _____ _____ ______
; MOSI        \_____X_____X_____X_ ... _X_____X_____/         Host --> Device
;        _____ _____ _____ _____ _     _ _____ _____ ______
; MISO        \_____X_____X_____X_ ... _X_____X_____/         Host <-- Device
;
;
; MODE 1: (CPOL = 0, CPHA = 1)
; SCLK idle state = low
; Data changes on rising SCLK edge & sampled on falling SCLK edge:
;        __                                             ___
; /CSx     \______________________ ... ________________/      Host --> Device
;              __    __    __    _ ...   __    __    __
; SCLK   _____/  \__/  \__/  \__/      _/  \__/  \__/  \___   Host --> Device
;        _____ _____ _____ _____ _     _ _____ _____ ______
; MOSI        \_____X_____X_____X_ ... _X_____X_____/         Host --> Device
;        _____ _____ _____ _____ _     _ _____ _____ ______
; MISO        \_____X_____X_____X_ ... _X_____X_____/         Host <-- Device
;
;
; MODE 2: (CPOL = 1, CPHA = 0)
; SCLK idle state = high
; Data changes on rising SCLK edge & sampled on falling SCLK edge:
;        __                                             ___
; /CSx     \______________________ ... ________________/      Host --> Device
;        ________    __    __    _ ...   __    __    ______
; SCLK           \__/  \__/  \__/      _/  \__/  \__/         Host --> Device
;        _____ _____ _____ _____ _     _ _____ _____ ______
; MOSI        \_____X_____X_____X_ ... _X_____X_____/         Host --> Device
;        _____ _____ _____ _____ _     _ _____ _____ ______
; MISO        \_____X_____X_____X_ ... _X_____X_____/         Host <-- Device
;
;
; MODE 3: (CPOL = 1, CPHA = 1)
; SCLK idle state = high
; Data changes on falling SCLK edge & sampled on rising SCLK edge:
;        __                                             ___
; /CSx     \______________________ ... ________________/      Host --> Device
;        _____    __    __    __   ... _    __    __    ___
; SCLK        \__/  \__/  \__/  \__     \__/  \__/  \__/      Host --> Device
;        _____ _____ _____ _____ _     _ _____ _____ ______
; MOSI        \_____X_____X_____X_ ... _X_____X_____/         Host --> Device
;        _____ _____ _____ _____ _     _ _____ _____ ______
; MISO        \_____X_____X_____X_ ... _X_____X_____/         Host <-- Device

;
;**************************************************************************

;--------------------------------------------------------------------------
; SPI_INIT
; Initialize the SPI MODE, bit transfer order (MSB->LSB) or (LSB->MSB),
; and the Z80-Retro! PRN_DAT port
; This will leave: MODE 0 & 1 SCLK = 0
;				   MODE 2 & 3 SCLK = 1
;				   MOSI = 1, CS1 - CS4 = 1
;
;     Bit ->   7   6   5   4   3   2   1   0
;             --- --- --- --- --- --- --- ---
; Input: A = |CS4|CS3|CS2|CS1| x | D | M | M |
;             --- --- --- --- --- --- --- ---
;            [M] bit 0 & 1 = SPI MODE (0 - 3)
;            [D] bit 2 = 0 MSB->LSB bit direction
;            [D] bit 2 = 1 LSB->MSB bit direction
;            [x] bit 3 = not used
;            [CSx] bits 4 - 7 = CS1 - CS4 bit mask
; Return: none
; Destroys: A, B, HL
;--------------------------------------------------------------------------
SPI_INIT:
	LD		B,A					; Save a copy of config byte
	AND		0xF0				; Get high nibble only
	LD		(SPI_CSx),A			; Save desired chip select line
	LD		A,B					; Restore config byte

; Setup opcode and operands for MSB->LSB or LSB->MSB bit direction
;	in SPI_SEND_BYTE and SPI_READ_BYTE routines depending on bit 2 of A
	BIT		2,A					; Check MSB->LSB bit direction (bit 2 reset)
	JR		NZ,.INIT_LSB_MSB	; LSB->MSB bit direction selected

; MSB->LSB bit direction selected
	LD		HL,.SEND_ORDER		; Set bit start order at SEND_ORDER to 0x01 (10000000B)
	LD		(HL),0x80			; Operand for LD E,xx set to 0x80

	LD		HL,.SEND_SHIFT		; Set operand for SRL at SEND_SHIFT to E
	LD		(HL),0x3B			; E operand code

	LD		HL,.READ_ROT1		; Set RLCA opcode at READ_ROT1
	LD		(HL),0x07			; RLCA opcode

	LD		HL,.READ_ROT2		; Set RRCA opcode at READ_ROT2
	LD		(HL),0x0F			; RRCA opcode

	JR		.INIT_MODE

; LSB->MSB bit direction selected
.INIT_LSB_MSB:
	LD		HL,.SEND_ORDER		; Set bit start order at SEND_ORDER to 0x01 (00000001B)
	LD		(HL),0x01			; Operand for LD E,xx set to 0x01

	LD		HL,.SEND_SHIFT		; Set operand for SLA at SEND_SHIFT to E
	LD		(HL),0x23			; E operand code
	
	LD		HL,.READ_ROT1		; Set RRCA opcode at READ_ROT1
	LD		(HL),0x0F			; RRCA opcode

	LD		HL,.READ_ROT2		; Set opcode to NOP at READ_ROT2
	LD		(HL),0x00			; NOP opcode

; Setup clock mask opcodes and operands in SPI_SEND_BYTE and SPI_READ_BYTE
;	routines depending on the selected SPI MODE
.INIT_MODE:	
	AND		0x03				; Allow MODE bits 0 - 1 only
	LD		(SPI_MODE),A		; Save SPI MODE
	OR		A
	JR		Z,.INIT_MODE0_3		; MODE 0

	CP		0x03
	JR		Z,.INIT_MODE0_3		; MODE 3

; MODE 1 & 2 if we end up here
	LD		HL,.SEND_LE			; Leading clock edge SCLK = 1
	LD		(HL),0xF6			; OR opcode
	INC		HL					; Advance address pointer
	LD		(HL),.SCLK			; OR operand SCLK = 1

	LD		HL,.READ_LE			; Do the same for READ_LE
	LD		(HL),0xF6
	INC		HL
	LD		(HL),.SCLK

	LD		HL,.SEND_TE			; Trailing clock edge SCLK = 0
	LD		(HL),0xE6			; AND opcode
	INC		HL					; Advance byte pointer
	LD		(HL),~.SCLK			; AND operand SCLK = 0

	LD		HL,.READ_TE			; So the same for READ_TE
	LD		(HL),0xE6
	INC		HL
	LD		(HL),~.SCLK

	CP		0x02
	JR		Z,.INIT_MODE2_EXIT	; MODE 2 only

	LD		HL,.SEND_EXIT		; Exit clock state SCLK = 0
	LD		(HL),0xE6			; AND opcode
	INC		HL					; Advance byte pointer
	LD		(HL),~.SCLK			; AND operand SCLK = 0

	LD		HL,.READ_EXIT		; Do the same for READ_EXIT
	LD		(HL),0xE6
	INC		HL
	LD		(HL),~.SCLK

	JR		.INIT_CLOCK_POL

.INIT_MODE2_EXIT:
	LD		HL,.SEND_EXIT		; Exit clock SCLK = 1
	LD		(HL),0xF6			; OR opcode
	INC		HL					; Advance byte pointer
	LD		(HL),.SCLK			; OR operand SCLK = 1

	LD		HL,.READ_EXIT		; Do the same for READ_EXIT
	LD		(HL),0xF6
	INC		HL
	LD		(HL),.SCLK

	JR		.INIT_CLOCK_POL

.INIT_MODE0_3:
	LD		HL,.SEND_LE			; Leading clock edge SCLK = 0
	LD		(HL),0xE6			; AND opcode
	INC		HL					; Advance byte pointer
	LD		(HL),~.SCLK			; AND operand SCLK = 0

	LD		HL,.READ_LE			; Do the same for READ_LE
	LD		(HL),0xE6
	INC		HL
	LD		(HL),~.SCLK

	LD		HL,.SEND_TE			; Trailing clock edge SCLK = 1
	LD		(HL),0xF6			; OR opcode
	INC		HL					; Advance byte pointer
	LD		(HL),.SCLK			; OR operand SCLK = 1

	LD		HL,.READ_TE			; Do the same for READ_TE
	LD		(HL),0xF6
	INC		HL
	LD		(HL),.SCLK

	CP		0x03
	JR		Z,.INIT_MODE3_EXIT	; MODE 3 only

	LD		HL,.SEND_EXIT		; Exit clock state SCLK = 0
	LD		(HL),0xE6			; AND opcode
	INC		HL					; Advance address pointer
	LD		(HL),~.SCLK			; AND operand SCLK = 0

	LD		HL,.READ_EXIT		; Do the same for READ_EXIT
	LD		(HL),0xE6
	INC		HL
	LD		(HL),~.SCLK

	JR		.INIT_CLOCK_POL

.INIT_MODE3_EXIT:
	LD		HL,.SEND_EXIT		; Exit clock state SCLK = 1
	LD		(HL),0xF6			; OR opcode
	INC		HL					; Advance byte pointer
	LD		(HL),.SCLK			; OR operand SCLK = 1

	LD		HL,.READ_EXIT		; Do the same for READ_EXIT
	LD		(HL),0xF6
	INC		HL
	LD		(HL),.SCLK

; Setup clock polarity (CPOL) depending on the selected SPI MODE
.INIT_CLOCK_POL:
	AND		0x02					; Check MODE 2 or 3 (bit 1 set)
	LD		A,(PORT_CACHE)			; Get current port data
	JR		NZ,.INIT_MODE2_3		; MODE 2 or 3 

	AND		~.SCLK					; SCLK = 0
	JR		.INIT_EXIT

.INIT_MODE2_3:
	OR		.SCLK					; SCLK = 1

.INIT_EXIT:
	OR		.MOSI|CS1|CS2|CS3|CS4	; MOSI = 1, /CS1 - /CS4 = 1, clear carry for LED
	LD		(PORT_CACHE),A			; Save copy in cache
	OUT		(PRN_DAT),A				; Send bits

	CALL	ACTIVE_LED				; Turn off ACTIVE LED
	RET

;--------------------------------------------------------------------------
; SPI_SEND_BYTE
; Send 8 bits to the SPI port and discard the received data. It is assumed
; that the PORT_CACHE value matches the current state of the PRN_DAT output
; port and that /CSx is low from a previous call to SPI_CSx_TRUE
; This will leave: MODE 0 & 1 SCLK = 0
;				   MODE 2 & 3 SCLK = 1
;				   MOSI = the LSB of the byte written
;
; Input: C = byte to send
; Return: none
; Destroys: A, B, DE
;--------------------------------------------------------------------------
SPI_SEND_BYTE:
	LD		A,(PORT_CACHE)		; Get current PRN_DAT value
	AND		~.MOSI				; MOSI = 0 to start

; Leading clock edge - MODE 0 & 3 SCLK = 0, MODE 1 & 2 SCLK = 1
.SEND_LE:
;	AND		~.SCLK				; SCLK = 0
;	OR		.SCLK				; SCLK = 1
	DEFW	0x0000				; Space for AND/OR opcode & SCLK operand
								;	filled in by SPI_INIT routine
	LD		D,A					; Save in D for reuse
	LD		B,8					; Setup to run .SPI_WRITE1 8 times

	DEFB	0x1E				; Opcode for LD E,xx
.SEND_ORDER:
;	LD		E,0x80				; Bit start, 10000000B for MSB->LSB (0x1E,0x80)
;	LD		E,0x01				; Bit start, 00000001B for LSB->MSB (0x1E,0x01)
	DEFB	0x00				; Space for LD E,xx operand
								;	filled in by SPI_INIT routine

; Send one of the 8 bits for each clock period
.SPI_SEND1:
	LD		A,E					; Get current bit mask
	AND		C					; Check if bit in C is a 1
	LD		A,D					; A = PRN_DAT value w/SCLK & MOSI = 0
	JP		Z,.LO_BIT			; Send a 0
	OR		.MOSI				; Prepare to transmit a 1

.LO_BIT:
	OUT		(PRN_DAT),A			; Set data value & SCLK leading edge

; Trailing clock edge - MODE 0 & 3 SCLK = 1, MODE 1 & 2 SCLK = 0
.SEND_TE:
;	AND		~.SCLK				; SCLK = 0
;	OR		.SCLK				; SCLK = 1
	DEFW	0x0000				; Space for AND/OR opcode & SCLK operand
								;	filled in by SPI_INIT routine
	OUT		(PRN_DAT),A			; Set SCLK trailing edge

	DEFB	0xCB				; Opcode prefix for SRL/SLA instruction
.SEND_SHIFT:
;	SRL		E					; SRL E adjust bit MSB->LSB (SRL E 0xCB,0x3B)
;	SLA		E					; SLA E adjust bit LSB->MSB (SLA E 0xCB,0x23)
	DEFB 0x00					; Space for E operand
								;	filled in by SPI_INIT routine

	DJNZ	.SPI_SEND1			; Continue until all 8 bits are sent

; Exit clock state - MODE 0 & 1 SCLK = 0, MODE 2 & 3 SCLK = 1
.SEND_EXIT:
;	AND		~.SCLK				; SCLK = 0
;	OR		.SCLK				; SCLK = 1
	DEFW	0x0000				; Space for AND/OR opcode & SCLK operand
								;	filled in by SPI_INIT routine
	LD		(PORT_CACHE),A		; Save copy in cache
	OUT		(PRN_DAT),A			; Set SCLK exit state
	RET

;--------------------------------------------------------------------------
; SPI_READ_BYTE
; Read 8 bits from the SPI port. It is assumed that the PORT_CACHE value
; matches the current state of the PRN_DAT output port and that /CSx is low
; from a previous call to SPI_CSx_TRUE
; This will leave: MODE 0 & 1 SCLK = 0
;				   MODE 2 & 3 SCLK = 1
;				   MOSI = 1
;
; Input: none
; Return: A = byte read
; Destroys: A, B, DE
;--------------------------------------------------------------------------
SPI_READ_BYTE:
	LD		A,(PORT_CACHE)	; Get current PRN_DAT value
	OR		.MOSI			; MOSI = 1

; Leading clock edge - MODE 0 & 3 SCLK = 0, MODE 1 & 2 SCLK = 1
.READ_LE:
;	AND		~.SCLK			; SCLK = 0
;	OR		.SCLK			; SCLK = 1
	DEFW	0x0000			; Space for AND/OR opcode & SCLK operand
							;	filled in by SPI_INIT routine
	LD		D,A				; Save in D for reuse
	LD		B,8				; Setup to run .SPI_READ1 8 times
	LD		E,0				; Prepare to accumulate the bits into E

; Read one of the 8 bits for each clock period
.SPI_READ1:
	LD		A,D
	OUT		(PRN_DAT),A		; Set data value & CLK clock leading edge

; Trailing clock edge - MODE 0 & 3 SCLK = 1, MODE 1 & 2 SCLK = 0
.READ_TE:
;	AND		~.SCLK			; SCLK = 0
;	OR		.SCLK			; SCLK = 1
	DEFW	0x0000			; Space for AND/OR opcode & SCLK operand
							;	filled in by SPI_INIT routine
	LD		(PORT_CACHE),A	; Save copy in cache
	OUT		(PRN_DAT),A		; SCLK trailing edge

	IN		A,(GPIO_IN)		; Read MISO
	AND		.MISO			; Strip all but MISO (bit 2 of PRN_DAT port)
	OR		E				; Accumulate the current MISO value

.READ_ROT1:
;	RLCA					; Rotate all bits left for next cycle MSB->LSB (RLCA 0x07)
;	RRCA					; Rotate all bits right for next cycle LSB->MSB (RRCA 0x0F)
	DEFB	0x00			; Space for RLCA or RRCA opcode
							;	filled in by SPI_INIT routine
	LD		E,A				; Save a copy of the running value in A and E
	DJNZ	.SPI_READ1		; Continue until all 8 bits are read

	RRCA					; Rotate all bits to proper location
	RRCA					; Twice for LSB->MSB

.READ_ROT2:
;	RRCA					; Three times for MSB->LSB bit direction (RRCA 0x0F)
;	NOP						; NOP for LSB->MSB bit direction (NOP 0x00)
	DEFB	0x00			; Space for RRCA or NOP opcode
							;	filled in by SPI_INIT routine
	LD		E,A				; Save back in E

; Exit clock state - MODE 0 & 1 SCLK = 0, MODE 2 & 3 SCLK = 1
	LD		A,(PORT_CACHE)	; Get current PRN_DAT value

.READ_EXIT:
;	AND		~.SCLK			; SCLK = 0
;	OR		.SCLK			; SCLK = 1
	DEFW	0x0000			; Space for AND/OR opcode & SCLK operand
							;	filled in by SPI_INIT routine
	LD		(PORT_CACHE),A	; Save copy in cache
	OUT		(PRN_DAT),A		; Set SCLK exit state
	LD		A,E				; Final value will be in A
	RET

;--------------------------------------------------------------------------
; SPI_CSx_TRUE
; Assert the select line initialized in SPI_INIT (set it low)
; This will leave: /CSx = 0, MOSI = 1
;				   MODE 0 & 1 SCLK = 0
;				   MODE 2 & 3 SCLK = 1
;
; Input: none
; Return: none
; Destroys: A, B
;--------------------------------------------------------------------------
SPI_CSx_TRUE:
	LD		A,(SPI_CSx)			; Get current SPI chip select line
	CPL							; One's complement of /CSx bit mask for use in AND
	LD		B,A					; Save in B

; Make sure SCLK is low in MODE 0 & 1 or high in MODE 2 & 3 before enabling /CSx
	LD		A,(SPI_MODE)		; Get current SPI MODE
	AND		0x02				; Check MODE 2 or 3 (bit 1 set)
	LD		A,(PORT_CACHE)		; Get current port data
	JR		NZ,.TRUE_MODE2_3	; MODE 2 or 3

	AND		~.SCLK				; SCLK = 0
	OR		.MOSI				; MOSI = 1
	JR		.TRUE1

.TRUE_MODE2_3:
	OR		.SCLK|.MOSI			; MOSI & SCLK = 1

; Enable it
.TRUE1:
	OUT		(PRN_DAT),A			; Send MOSI & SCLK
	AND		B					; /CSx = 0
	LD		(PORT_CACHE),A		; Save current state in the cache
	OUT		(PRN_DAT),A			; Send /CSx

	SCF							; Set carry
	CALL	ACTIVE_LED			; Turn on ACTIVE LED
	RET

;--------------------------------------------------------------------------
; SPI_CSx_FALSE
; De-assert the select line initialized in SPI_INIT (set it high)
; This will leave: /CSx = 1, MOSI = 1
;				   MODE 0 & 1 SCLK = 0
;				   MODE 2 & 3 SCLK = 1
;
; Input: A = none
; Return: none
; Destroys: A, B
;--------------------------------------------------------------------------
SPI_CSx_FALSE:
	LD		A,(SPI_CSx)			; Get current SPI chip select line
	LD		B,A					; Save bit in B

; Make sure SCLK is low in MODE 0 & 1 or high in MODE 2 & 3 before disabling /CSx
	LD		A,(SPI_MODE)		; Get current SPI MODE
	AND		0x02				; Check MODE 2 or 3 (bit 1 set)
	LD		A,(PORT_CACHE)		; Get current port data
	JR		NZ,.FALSE_MODE2_3	; MODE 2 or 3

	AND		~.SCLK				; SCLK = 0
	OR		.MOSI				; MOSI = 1
	JR		.FALSE1

.FALSE_MODE2_3:
	OR		.MOSI|.SCLK			; MOSI & SCLK = 1

; Disable it
.FALSE1:
	OUT		(PRN_DAT),A			; Send MOSI & SCLK
	OR		B					; /CSx = 1, clear carry for LED
	LD		(PORT_CACHE),A
	OUT		(PRN_DAT),A

	CALL	ACTIVE_LED			; Turn off ACTIVE LED
	RET

;--------------------------------------------------------------------------
; SPI_SEND_STREAM
; Send a stream of bytes to the SPI port
;
; Input: HL = address of bytes to write
;        B = byte count
; Return: none
; Destroys: A, BC, DE, HL
;--------------------------------------------------------------------------
SPI_SEND_STREAM:
	PUSH	BC				; Save counter
	LD		C,(HL)			; Get next byte to send
	CALL	SPI_SEND_BYTE	; Send it
	INC		HL				; Point to the next byte

	POP		BC				; Get back counter
	DJNZ	SPI_SEND_STREAM	; Count the byte & continue if not done
	RET

;--------------------------------------------------------------------------
; SPI_READ_STREAM
; Read a stream of bytes from the SPI port
;
; Input: HL = address of buffer to receive bytes
;        B = byte count
; Return: none
; Destroys: A, B, DE, HL
;--------------------------------------------------------------------------
SPI_READ_STREAM:
	PUSH	BC				; Save counter
	CALL	SPI_READ_BYTE	; Read byte
	LD		(HL),A			; Save byte read to buffer
	INC		HL				; Point to the next byte

	POP		BC				; Get back counter
	DJNZ	SPI_READ_STREAM	; Count the byte & continue if not done
	RET

;**************************************************************************
;
;					E N D  O F  S U B R O U T I N E S
;
;**************************************************************************

; Data storage area
I2C_STAT:		DEFB	0	; EEExxxxx, EEE -> error bits, x -> none
I2C_RUNNING:	DEFB	0	; Boolean for communications running
SPI_MODE:		DEFB	0	; Currently selected SPI mode (0-3)
SPI_CSx:		DEFB	0	; Bit mask for selected SPI chip select line
PORT_CACHE:		DEFB	0	; Copy of PRN_DAT port

	END
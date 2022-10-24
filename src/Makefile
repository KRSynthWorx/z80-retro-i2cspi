# Makefile for building test routines for the Z80-Retro! SBC I2C/SPI library

# Modify this path if necessary to point to the retromon.sym symbol table
ASM_FLAGS=-I../../z80-retro-monitor/src/

# Modify this hex value to define the starting address for the .bin to .hex conversion
# It should match the value of the ORG directive in the associated .asm file
HEX_OFFSET=0x1000

all: ad_test.hex eeprom_test.hex gpio_test.hex spi_test.hex

ad_test.hex: ad_test.asm i2cspi_lib.asm
	z80asm -i ad_test.asm -o ad_test.bin --list=ad_test.lst $(ASM_FLAGS)
	srec_cat ad_test.bin -binary -offset $(HEX_OFFSET) -o ad_test.hex -intel

eeprom_test.hex: eeprom_test.asm  i2cspi_lib.asm
	z80asm -I -i eeprom_test.asm -o eeprom_test.bin --list=eeprom_test.lst $(ASM_FLAGS)
	srec_cat eeprom_test.bin -binary -offset $(HEX_OFFSET) -o eeprom_test.hex -intel

gpio_test.hex: gpio_test.asm  i2cspi_lib.asm
	z80asm -i gpio_test.asm -o gpio_test.bin --list=gpio_test.lst $(ASM_FLAGS)
	srec_cat gpio_test.bin -binary -offset $(HEX_OFFSET) -o gpio_test.hex -intel
	
spi_test.hex: spi_test.asm  i2cspi_lib.asm
	z80asm -i spi_test.asm -o spi_test.bin --list=spi_test.lst $(ASM_FLAGS)
	srec_cat spi_test.bin -binary -offset $(HEX_OFFSET) -o spi_test.hex -intel
	
clean:
	rm -f *.lst *.bin *.hex


CC=avr-gcc
CFLAGS=-DF_CPU=16000000UL -mmcu=atmega328 -Wall -Os -g -Wno-unused-function # -DDEBUG
OBJCOPY=avr-objcopy
SIZE=avr-size
DUDE=avrdude

all:	main.hex size

main.hex:	main.elf
	$(OBJCOPY) -O ihex -R .eeprom $< $@

eeprom.hex:	main.elf
	$(OBJCOPY) -O ihex -j .eeprom $< $@

main.elf:	main.c
	$(CC) $(CFLAGS) -o $@ $^

clean:
	rm -f main.elf main.hex *~

size:	main.elf
	$(SIZE) $<

flash:	main.hex
	$(DUDE) -V -c arduino -b 57600 -P /dev/ttyUSB0 -p atmega328p -vv -U flash:w:main.hex || exit 1

main.c:

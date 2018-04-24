/*
 * SNES2JOY
 *
 * Connect SNES controller to DB9 Atari joystick port
 *
 * Copyright (C) 2017 by Ivo van Poorten
 * All rights reserved.
 *
 * License to be determined.
 *
 */

/* Hardware:
 *      Arduino Nano V3 (ATmega328 16MHz, 32kB Flash, 1kB ROM, 2kB RAM)
 */

#include <avr/io.h>
#include <util/delay.h>
#include <stdio.h>

/* ------------------------------------------------------------------------- */

#define SNES_CLK    0x20
#define SNES_LATCH  0x10
#define SNES_DATA   0x08

#define BUTTON_B        0x0001
#define BUTTON_Y        0x0002
#define BUTTON_SELECT   0x0004
#define BUTTON_START    0x0008

#define BUTTON_UP       0x0010
#define BUTTON_DOWN     0x0020
#define BUTTON_LEFT     0x0040
#define BUTTON_RIGHT    0x0080

#define BUTTON_A        0x0100
#define BUTTON_X        0x0200
#define BUTTON_L        0x0400
#define BUTTON_R        0x0800

/* ------------------------------------------------------------------------- */

static void hw_usart_init(unsigned int ubrr) {
    UBRR0H = ubrr>>8;
    UBRR0L = ubrr;
    UCSR0B = 0;                             // disable all
    UCSR0B = _BV(RXEN0)  | _BV(TXEN0);      // enable RX and TX
    UCSR0C = _BV(UCSZ01) | _BV(UCSZ00);     // 8N1
//    UCSR0A = _BV(U2X0);                     // Double Speed
}

static void hw_usart_tx_byte(uint8_t byte) {
    while(!(UCSR0A & _BV(UDRE0))) ;         // wait for port ready to write
    UDR0 = byte;
}

static uint8_t hw_usart_rx_byte(void) {
    while(!(UCSR0A & _BV(RXC0))) ;          // wait for byte received
    return UDR0;
}

static void hw_usart_tx_block(const void *const buf, uint16_t len) {
    const uint8_t *b = buf;
    while (len--)
        hw_usart_tx_byte(*b++);
}

static void hw_usart_rx_block(void *const buf, uint16_t len) {
    uint8_t *b = buf;
    while (len--)
        *b++ = hw_usart_rx_byte();
}

static void hw_usart_tx_string(char *s) {
    while(*s) hw_usart_tx_byte(*s++);
}

/* ------------------------------------------------------------------------- */

static void snes_init(void) {
    DDRC  |=  SNES_CLK;         // PC5 output
    DDRC  |=  SNES_LATCH;       // PC4 output
    DDRC  &= ~SNES_DATA;        // PC3 input

    PORTC |=  SNES_CLK;         // CLK High
    PORTC &= ~SNES_LATCH;       // LATCH Low
    PORTC |=  SNES_DATA;        // Pull-up DATA
}

// Takes a total time of 210 us

#define LATCH 12
#define CLOCK 6

static uint16_t snes_retrieve_word(void) {
    uint16_t result = 0;
    int i;

    PORTC |= SNES_LATCH;        // LATCH High
    _delay_us(LATCH);
    PORTC &= ~SNES_LATCH;       // LATCH Low
    _delay_us(LATCH/2);

    for (i=0; i<16; i++) {
        PORTC &= ~SNES_CLK;     // CLK Low
        _delay_us(CLOCK);

        result >>= 1;
        result |= (PINC & SNES_DATA) ? 0x8000 : 0;

        PORTC |= SNES_CLK;      // CLK High
        _delay_us(CLOCK);
    }

    return result|0xf000;       // non-existing buttons are never pressed
}

/* ------------------------------------------------------------------------- */

static void joy_init(void) {
    DDRB  |= 0x1f;
    PORTB |= 0x1f;
}

/* ------------------------------------------------------------------------- */

// Compatibility Mode:
// -------------------
//
// D-Pad maps to Up/Down/Left/Right
//
// (L) and (R) on top map to Up and Down
//
// All other buttons map to Fire
//
// POTA can have eight different values depending on Select/Y/B
// POTB can have eight different values depending on X/A/Start
// 
// For single buttons, POTA and POTB do not need to be callibrated
// For multiple button combinations it probably does (needs testing on a lot
// of different machines to see if we could do without)


// Endless Stream Mode:
// --------------------
//
// Trigger clocked stream of nibbles
//
// TRIG High    --> joystick port reads Up/Down/Left/Right
// TRIG Low     --> joystick port reads B/Y/A/X
//
// High and Low periods are approximately 210 us (0.21 ms)
//
// POTA and POTB go down (i.e. lower than 228) on Select and Start respectively
// No callibration needed


// Button hold during power-up or after Device Reset:
//
// None         Compatibility Mode
// A            Compatibility Mode, but only A triggers Fire
// B            Endless Stream Mode, Trigger clocked

/* ------------------------------------------------------------------------- */

int main(void) {
    uint16_t w0, w1, mask = 0x0f0f;
    uint8_t mode;

#ifdef DEBUG
    hw_usart_init(103);          // 9600 baud, debug console
#endif

    snes_init();
    joy_init();

    switch (~snes_retrieve_word() & (BUTTON_B | BUTTON_Y | BUTTON_A)) {
    case BUTTON_B:
        mode = 2;
        DDRC  |= 2;         // enable extended mode LED
        PORTC |= 2;
        break;
    case BUTTON_A:
        mask = BUTTON_A;
    default:                // fall-through!
        mode = 1;
        DDRC  |= 1;         // enable compatibility mode LED
        PORTC |= 1;
        break;
    }

    while(1) {
        w0 = snes_retrieve_word();      // bit is zero when pressed

#ifdef DEBUG
    {
        char tmp[256];
        sprintf(tmp, "%4x\n\r", w0);
        hw_usart_tx_string(tmp);
    }
#endif
        // map L to UP and R to DOWN (handy for diagonal jump games)
        if (!(w0 & BUTTON_L)) {
            w0 |= BUTTON_L;
            w0 &= ~BUTTON_UP;
        }
        if (!(w0 & BUTTON_R)) {
            w0 |= BUTTON_R;
            w0 &= ~BUTTON_DOWN;
        }

        w1 = ~w0;                       // bit is one when pressed

        switch (mode) {

        case 1:
            // copy directional bits and add trigger bit according to mask
            PORTB = ((w0>>4) & 0x0f) | (!(w1 & mask) ? 0x10 : 0);

            // PORTD, output 1 for 1, input/tri-state for 0 --> dir == output
            // 7   6   5   4   3   2   1   0
            // X   A  Sta Sel  Y   B   -   -
            DDRD = PORTD = ((w1&0x0f) | ((w1>>4)&0x30)) << 2;
            break;

        case 2:
            // copy directional bits with trigger high
            PORTB = ((w0>>4) & 0x0f) | 0x10;
            _delay_us(210);

            // copy BYAX with trigger low
            PORTB = (w0 & 0x03) | ((w0>>6) & 0x0c);
            // continue loop will take 210 us again

            DDRD = PORTD = ( (w1 & BUTTON_SELECT) ? 0x1c : 0x00) |
                           ( (w1 & BUTTON_START)  ? 0xe0 : 0x00);
            break;
        }
    }

    return 0;
}

/* ------------------------------------------------------------------------- */


/*
 *
 * Odyssey 2 MCU
 *
 * Copyright (C) 2020 Davide Gerhard IV3CVE
 *
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 */


#ifndef SSD1306_H
#define	SSD1306_H

#ifdef	__cplusplus
extern "C" {
#endif

#include <string.h>
#include "16F1827.h"
#include "i2c.h"

  //#include "font8x5.h"
#include "font8x8.h"

  // enable extra functions
#define EXTRA 1

  // SSD1306 Display Type
  //#define SSD1306_128_64
#define SSD1306_128_32
  //#define SSD1306_96_16

#if defined SSD1306_128_64
#define SSD1306_WIDTH                  128
#define SSD1306_HEIGHT                 64
#endif
#if defined SSD1306_128_32
#define SSD1306_WIDTH                  128
#define SSD1306_HEIGHT                 32
#endif
#if defined SSD1306_96_16
#define SSD1306_WIDTH                  96
#define SSD1306_HEIGHT                 16
#endif

  // display address
#define SSD1364_ADDRESS                  0x78

  // SSD1306 registers
#define SSD1306_COMMAND                  0x00
#define SSD1306_DATA                     0x40

  // command macros
#define SSD1306_SETCONTRAST              0x81
#define SSD1306_DISPLAYALLON_RESUME      0xA4
#define SSD1306_DISPLAYALLON             0xA5
#define SSD1306_NORMALDISPLAY            0xA6
#define SSD1306_INVERTDISPLAY            0xA7
#define SSD1306_DISPLAYOFF               0xAE
#define SSD1306_DISPLAYON                0xAF
#define SSD1306_SETDISPLAYOFFSET         0xD3
#define SSD1306_SETCOMPINS               0xDA
#define SSD1306_SETVCOMDETECT            0xDB
#define SSD1306_SETDISPLAYCLOCKDIV       0xD5
#define SSD1306_SETPRECHARGE             0xD9
#define SSD1306_SETMULTIPLEX             0xA8
#define SSD1306_SETLOWCOLUMN             0x00
#define SSD1306_SETHIGHCOLUMN            0x10
#define SSD1306_SETSTARTLINE             0x40
#define SSD1306_PAGESTART                0xB0
#define SSD1306_MEMORYMODE               0x20
#define SSD1306_COLUMNADDR               0x21
#define SSD1306_PAGEADDR                 0x22
#define SSD1306_COMSCANINC               0xC0
#define SSD1306_COMSCANDEC               0xC8
#define SSD1306_SEGREMAP                 0xA0
#define SSD1306_CHARGEPUMP               0x8D
#define SSD1306_NOP                      0xE3
#define SSD1306_DEACTIVATE_SCROLL        0x2E

  // maintain the display status
  // 0 = OFF
  // 1 = ON
  uint8_t ssd1306_display_status = 0;

  // custom symbols
#define DEG			0x5C
#define ARROW_L		0x7E
#define ARROW_R 	0x7F

  // scroll delays from smaller value (fast) to higher value (slow)
#define SCROLL_DELAY_1	7	// 2 frames
#define SCROLL_DELAY_2	4	// 3 frames
#define SCROLL_DELAY_3	5	// 4 frames
#define SCROLL_DELAY_4	0	// 5 frames
#define SCROLL_DELAY_5	1	// 64 frames
#define SCROLL_DELAY_6	2	// 128 frames
#define SCROLL_DELAY_7	3	// 256 frames
  // scroll direction
#define SCROLL_RIGHT	0x26
#define SCROLL_LEFT		0x27

  // current value of X
  unsigned char curX=0;
  // current value of Y
  unsigned char curY=0;

  void ssd1306_command(uint8_t c);
  void ssd1306_data(uint8_t d);
  void ssd1306_init(void);
  void ssd1306_power(uint8_t s);
  void ssd1306_goto(unsigned char x, unsigned char y);
  void ssd1306_clear(void);
  void ssd1306_clear_row(unsigned char row);
  void ssd1306_putch(char c);
  void ssd1306_puts(char *s);
  void ssd1306_puts_center(char *s, uint8_t y);
  void ssd1306_putun(unsigned int c);
  void ssd1306_putsn(signed int c);
  void ssd1306_plot(unsigned char x, unsigned char y);
  void ssd1306_scrollh(char direction, char delay, char rowstart, char rowend);
  void ssd1306_stop_scroll(void);
#if EXTRA
  void ssd1306_bitmap(const unsigned char *bitmap, unsigned char x, unsigned char y);
  void ssd1306_icon(const unsigned char *icon);
  void ssd1306_line(int8_t x_start, int8_t y_start, int8_t x_end, int8_t y_end);
  void ssd1306_circle(int8_t x0, int8_t y0, uint8_t r);
#endif

#ifdef	__cplusplus
}
#endif

#endif	/* SSD1306_H */

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

/*
 * NOTE
 *
 * This is an SSD1306 version without the frame buffer since we
 * don't have enough memory to maintain the structure during the running
 *
 */


#include "ssd1306.h"

/**
 * @brief send an i2c command
 *
 * @param c: command to send
 */
void
ssd1306_command(uint8_t c) {
  i2c_master_start(); //Start condition
  i2c_master_write(SSD1364_ADDRESS); //7 bit address + Write
  i2c_master_write(SSD1306_COMMAND); // send that the following is a command
  i2c_master_write(c); //Write data
  i2c_master_stop();
}

/**
 * @brief send an i2c data
 *
 * @param d: data to send
 */
void
ssd1306_data(uint8_t d) {
  i2c_master_start(); //Start condition
  i2c_master_write(SSD1364_ADDRESS); //7 bit address + Write
  i2c_master_write(SSD1306_DATA); // send that the following is data
  i2c_master_write(d); //Write data
  i2c_master_stop();
}

/**
 * @brief initialize the display
 */
void
ssd1306_init() {
  i2c_master_init();

  // speedup the process
  i2c_master_start(); //Start condition
  i2c_master_write(SSD1364_ADDRESS); //7 bit address + Write
  i2c_master_write(SSD1306_COMMAND); // send that the following is data

  i2c_master_write(SSD1306_DISPLAYOFF);
  i2c_master_write(SSD1306_SETDISPLAYCLOCKDIV);
  i2c_master_write(0x80);
  i2c_master_write(SSD1306_SETMULTIPLEX);
  i2c_master_write(SSD1306_HEIGHT - 1);
  i2c_master_write(SSD1306_SETDISPLAYOFFSET);
  i2c_master_write(0x00); // no offset
  i2c_master_write(SSD1306_SETSTARTLINE | 0x0);
  i2c_master_write(SSD1306_CHARGEPUMP);
  i2c_master_write(0x14); // 0x10 external 0x14 internal
  i2c_master_write(SSD1306_MEMORYMODE);
  // 00b, Horizontal Addressing Mode (like ks0108)
  // 01b, Vertical Addressing Mode
  // 10b, Page Addressing Mode (RESET)
  i2c_master_write(0x00);

  // set segment remap (column address 127 mapped to SEG0)
  i2c_master_write(SSD1306_SEGREMAP | 0x01);
  i2c_master_write(SSD1306_COMSCANDEC);
#if defined SSD1306_128_32
  i2c_master_write(SSD1306_SETCOMPINS);
  i2c_master_write(0x02);
  i2c_master_write(SSD1306_SETCONTRAST);
  i2c_master_write(0x8F);
#elif defined SSD1306_128_64
  i2c_master_write(SSD1306_SETCOMPINS);
  i2c_master_write(0x12);
  i2c_master_write(SSD1306_SETCONTRAST);
  i2c_master_write(0xCF);
#endif

  // Setup column start and end address
  i2c_master_write(SSD1306_COLUMNADDR);
  i2c_master_write(0x00);
  i2c_master_write(SSD1306_WIDTH - 1);

  // Setup page start and end address
  i2c_master_write(SSD1306_PAGEADDR);
  i2c_master_write(0x00);
  i2c_master_write(SSD1306_HEIGHT / 8 - 1);

  i2c_master_write(SSD1306_SETPRECHARGE);
  i2c_master_write(0xF1); //0x22 external 0xF1 internal
  i2c_master_write(SSD1306_SETVCOMDETECT);
  i2c_master_write(0x40);

  i2c_master_write(SSD1306_DISPLAYALLON_RESUME);
  i2c_master_write(SSD1306_NORMALDISPLAY);
  i2c_master_write(SSD1306_DEACTIVATE_SCROLL);

  i2c_master_stop();

  ssd1306_clear();
  ssd1306_power(1);
}

/**
 * @brief power on/off the display
 *
 * @param s: status to change 1=ON 0=OFF
 */
void
ssd1306_power(uint8_t s) {
  if (s && !ssd1306_display_status) {
    ssd1306_command(SSD1306_DISPLAYON);
    ssd1306_display_status = 1;
  } else if (!s && ssd1306_display_status) {
    ssd1306_command(SSD1306_DISPLAYOFF);
    ssd1306_display_status = 0;
  }
}

/**
 * @brief where to write the next pixel
 *
 * @param x: value must be between 0 and SSD1306_WIDTH-1 (column)
 * @param y: value must be between 0 and (SSD1306_HEIGHT/8)-1 page, not really the row
 */
void
ssd1306_goto(unsigned char x, unsigned char y) {
  // speedup the process
  i2c_master_start(); //Start condition
  i2c_master_write(SSD1364_ADDRESS); //7 bit address + Write
  i2c_master_write(SSD1306_COMMAND); // send that the following is data
  i2c_master_write(0x00 | (x & 0x0F)); // column start address - x low nibble
  i2c_master_write(0x10 | ((x & 0xF0) >> 4)); // column start address - x high nibble
  i2c_master_write(0xB0 | (y & ((SSD1306_HEIGHT / 8) - 1))); // set display ram start page to value y
  i2c_master_stop();
  curX = x;
  curY = y;
}

/**
 * @brief clear the whole screen
 */
void
ssd1306_clear(void) {
  ssd1306_goto(0, 0);
  int i;
  // speedup the process
  i2c_master_start(); //Start condition
  i2c_master_write(SSD1364_ADDRESS); //7 bit address + Write
  i2c_master_write(SSD1306_DATA); // send that the following is data
  for (i = 0; i < (SSD1306_WIDTH * (SSD1306_HEIGHT >> 3)); ++i)
    i2c_master_write(0); //empty the column
  i2c_master_stop();
}

/**
 * @brief clear a single row
 *
 * @param row: which row to clear
 */
void
ssd1306_clear_row(unsigned char row) {
  ssd1306_goto(0, row);
  uint8_t i;
  // speedup the process
  i2c_master_start(); //Start condition
  i2c_master_write(SSD1364_ADDRESS); //7 bit address + Write
  i2c_master_write(SSD1306_DATA); // send that the following is data
  for (i = 0; i < SSD1306_WIDTH; i++)
    i2c_master_write(0); //empty the column
  i2c_master_stop();
}

/**
 * @brief print one char to the display
 *
 * @param c: character to print
 */
void
ssd1306_putch(char c) {
  // index in the font array
  unsigned int u;
  uint8_t i;

  // ascii chars out of limits becomes '?'
  if ((c < FONT_START) || (c > FONT_END)) {
    c = '?';
  }
  u = c - FONT_START;
  u *= FONT_WIDTH;

  for (i = 0; i < FONT_WIDTH; i++)
    ssd1306_data(ASCII[u + i]);

  curX += FONT_WIDTH;
  if (curX > (SSD1306_WIDTH - 1)) {
    curX = curX - SSD1306_WIDTH;
    curY++;
    if (curY > (SSD1306_HEIGHT - 1)) {
      curY = 0;
    }
  }
}

/**
 * @brief print a full string to the display
 * @param s: string to print
 */
void
ssd1306_puts(char *s) {
  while (*s) {
    ssd1306_putch(*s++);
  }
}

/**
 * @brief print a string on the display center
 *
 * @param s: string to print
 * @param y: vertical coordinate
 */
void
ssd1306_puts_center(char *s, uint8_t y) {
  ssd1306_goto(0, y);
  // calculate the length of the string
  char len = 0;
  char *t;
  t = s;
  while (*s) {
    s++;
    len++;
  }
  char v; // width of a single char
  v = FONT_WIDTH;
  if (v == 5) {
    v++;
  }
  // division by 2
  char u = (SSD1306_WIDTH - (len * v)) >> 1;
  char h = u;
  while (h--) {
    ssd1306_data(0x00);
  }
  ssd1306_puts(t);
  while (u--) {
    ssd1306_data(0x00);
  }
  curX = 0;
  curY = y + 1;
}

/**
 * @brief print an unsigned integer to the display
 *
 * @param c: integer to print
 */
void
ssd1306_putun(unsigned int c) {
  unsigned char t, i, w;
  unsigned int k;
  w = 0;
  for (i = 4; i >= 1; i--) {
    switch (i) {
    case 4:
      k = 10000;
      break;
    case 3:
      k = 1000;
      break;
    case 2:
      k = 100;
      break;
    case 1:
      k = 10;
      break;
    }
    t = c / k;
    if ((w) || (t != 0)) {
      ssd1306_putch(t + 0x30);
      w = 1;
    }
    c -= (t * k);
  }
  ssd1306_putch(c + 0x30);
}

/**
 * @brief print a signed integer
 *
 * @param c: signed integer
 */
void
ssd1306_putsn(signed int c) {
  if (c < 0) {
    ssd1306_putch('-');
    c *= (-1);
  }
  ssd1306_putun(c);
}

// draw a spot

/**
 * @brief draw a pixel in the display
 *
 * @param x: x coordinate
 * @param y: y coordinate
 */
void
ssd1306_plot(unsigned char x, unsigned char y) {
  // y/8 = page
  ssd1306_goto(x, y >> 3);
  // y%8 = bit
  ssd1306_data(1 << (y % 8));
  curX = x++;
  curY = y >> 3;
}

/**
 * @brief scroll a text horizontally
 *
 * @param direction: in which direction; use SCROLL_RIGHT or SCROLL_LEFT
 * @param delay: delay between scroll; use SCROLL_DELAY_*
 * @param rowstart: from which row
 * @param rowend: to which row
 */
void
ssd1306_scrollh(char direction, char delay, char rowstart, char rowend) {
  // horizontal scroll
  ssd1306_command(direction);
  // dummy byte
  ssd1306_command(0x00);
  // start page
  ssd1306_command(rowstart);
  // delay value
  ssd1306_command(delay);
  // end page
  ssd1306_command(rowend);
  // dummy byte
  ssd1306_command(0x00);
  // dummy byte
  ssd1306_command(0xFF);
  // start scroll
  ssd1306_command(0x2F);
}

/**
 * @brief stop the current scroll
 */
void
ssd1306_stop_scroll(void) {
  ssd1306_command(SSD1306_DEACTIVATE_SCROLL);
}

#if EXTRA

/**
 * @brief: draw a bitmap to the display
 *
 * the height must be divisible by 8
 *
 * @param bitmap: the bitmap to draw
 * @param x: x point
 * @param y: y point
 */
void
ssd1306_bitmap(const unsigned char *bitmap, unsigned char x, unsigned char y) {
  /*
    bitmap[0] = width, in pixel
    bitmap[1] = height, in pixel
  */
  unsigned char wi, hi;
  unsigned int col = 0;
  // division by 8
  unsigned char height = bitmap[1] >> 3;
  if ((bitmap[1] % 8) > 0) {
    height += 1;
  }

  // row scan
  for (hi = 0; hi < height; hi++) {
    ssd1306_goto(x, y);
    // column scan
    for (wi = 0; wi < bitmap[0]; wi++) {
      ssd1306_data(bitmap[2 + col]);
      col++;
    }
    y += 1;
  }
  curX = x + bitmap[0];
  curY = y + height;
  ssd1306_command(SSD1306_NOP);
}

/**
 * @brief draw an icon to the display
 *
 * the icon must be 8 pixels high
 *
 * @param icon: icon to print
 */
void
ssd1306_icon(const unsigned char *icon) {
  /*
    height: 8 pixel
    width: icon[0]
  */
  unsigned char wi;
  for (wi = 0; wi < icon[0]; wi++) {
    ssd1306_data(icon[1 + wi]);
  }
  curX += icon[0];
  if (curX > (SSD1306_WIDTH - 1)) {
    curX -= SSD1306_WIDTH;
    curY++;
    if (curY > (SSD1306_HEIGHT - 1)) {
      curY = 0;
    }
  }
  ssd1306_command(SSD1306_NOP);
}

/**
 * @brief draw a line on the display
 *
 * use the Bresenham line algorithm
 *
 * @param x_start: x coordinate of start point. Valid values: 0..127
 * @param y_start: x coordinate of start point. Valid values: 0..63
 * @param x_end: x coordinate of end point. Valid values: 0..127
 * @param y_end: y coordinate of end point. Valid values: 0..63
 */
void
ssd1306_line(int8_t x_start, int8_t y_start, int8_t x_end, int8_t y_end) {
  int16_t x, y, addx, addy, dx, dy;
  int32_t P;
  int16_t i;
  dx = abs((int16_t) (x_end - x_start));
  dy = abs((int16_t) (y_end - y_start));
  x = x_start;
  y = y_start;

  if (x_start > x_end)
    addx = -1;
  else
    addx = 1;

  if (y_start > y_end)
    addy = -1;
  else
    addy = 1;

  if (dx >= dy) {
    P = 2 * dy - dx;

    for (i = 0; i <= dx; ++i) {
      ssd1306_plot(x, y);
      if (P < 0) {
        P += 2 * dy;
        x += addx;
      } else {
        P += 2 * dy - 2 * dx;
        x += addx;
        y += addy;
      }
    }
  } else {
    P = 2 * dx - dy;
    for (i = 0; i <= dy; ++i) {
      ssd1306_plot(x, y);

      if (P < 0) {
        P += 2 * dx;
        y += addy;
      } else {
        P += 2 * dx - 2 * dy;
        x += addx;
        y += addy;
      }
    }
  }
}

/**
 * @brief draw a circle on the display on OLED.
 *
 * use the midpoint circle algorithm
 *
 * @param x_center: x coordinate of the circle center. Valid values: 0..127
 * @param y_center: y coordinate of the circle center. Valid values: 0..63
 * @param radius: radius of the circle.
 */
void
ssd1306_circle(int8_t x0, int8_t y0, uint8_t r) {
  int8_t f = 1 - r;
  int8_t ddF_x = 1;
  int8_t ddF_y = -2 * r;
  int8_t x = 0;
  int8_t y = r;

  ssd1306_plot(x0, y0 + r);
  ssd1306_plot(x0, y0 - r);
  ssd1306_plot(x0 + r, y0);
  ssd1306_plot(x0 - r, y0);

  while (x < y) {
    if (f >= 0) {
      y--;
      ddF_y += 2;
      f += ddF_y;
    }
    x++;
    ddF_x += 2;
    f += ddF_x;

    ssd1306_plot(x0 + x, y0 + y);
    ssd1306_plot(x0 - x, y0 + y);
    ssd1306_plot(x0 + x, y0 - y);
    ssd1306_plot(x0 - x, y0 - y);
    ssd1306_plot(x0 + y, y0 + x);
    ssd1306_plot(x0 - y, y0 + x);
    ssd1306_plot(x0 + y, y0 - x);
    ssd1306_plot(x0 - y, y0 - x);
  }
}
#endif

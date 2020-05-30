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

#ifndef I2C_H
#define	I2C_H

#include "16F1827.h"

#ifdef	__cplusplus
extern "C" {
#endif

  void i2c_master_init(void);
  void i2c_master_wait(void);
  void i2c_master_start(void);
  void i2c_master_repeated_start(void);
  void i2c_master_stop(void);
  void i2c_master_write(unsigned char d);
  unsigned char i2c_master_read(unsigned char ack);
  void i2c_master_send_ack();
  void i2c_master_send_nack();

#ifdef	__cplusplus
}
#endif

#endif	/* I2C_H */

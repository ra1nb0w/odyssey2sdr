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

#include "i2c.h"

/**
 * @brief initialize the i2c hardware interface
 */
void
i2c_master_init() {

  // configure pins for I2C on MSSP1
  // RB1 = SDA
  // RB4 = SCL
  RB1_SetDigitalMode();
  RB4_SetDigitalMode();
  RB1_SetDigitalInput();
  RB4_SetDigitalInput();
  RB1_SetPullup();
  RB4_SetPullup();

  // more information at
  // https://ww1.microchip.com/downloads/en/DeviceDoc/41391D.pdf#277

  // BF RCinprocess_TXcomplete; UA dontupdate; SMP endsample_disable; P stopbit_notdetected;
  // S startbit_notdetected; R_nW write_noTX; CKE tx_on_idle_to_active; D_nA lastbyte_address;
  // otherwise use 0x00
  SSP1STAT = 0x80;
  SSP1STATbits.SMP = 1; // 1 = Slew rate control disabled for standard speed mode (100 kHz and 1 MHz)
  SSP1STATbits.CKE = 1; // 1 = Enable input logic so that thresholds are compliant with SMbus specification

  // SSPEN enabled; WCOL no_collision; SSPOV no_overflow; CKP lo_hold; SSPM I2CMaster_FOSC/4_SSPxADD;
  // otherwise use 0x08
  SSP1CON1 = 0x24;
  SSP1CON1bits.SSPEN = 1; // 1 = Enables the serial port and configures the SDAx and SCLx pins as the source of the serial port pins(3)
  SSP1CON1bits.SSPM = 0b1000; // 1000 = I2C Master mode, clock = FOSC / (4 * (SSPxADD+1))(4)

  // no conf
  SSP1CON2 = 0x00;

  // BOEN disabled; AHEN disabled; SBCDE disabled; SDAHT 300nshold; ACKTIM ackseq; DHEN disabled; PCIE disabled; SCIE disabled;
  // otherwise use 0x00
  SSP1CON3 = 0x08;
  SSP1CON3bits.SDAHT = 1; // 1 = Minimum of 300 ns hold time on SDAx after the falling edge of SCLx
  SSP1CON3bits.AHEN = 0; // 0 = Address holding is disabled
  SSP1CON3bits.DHEN = 0; // 0 = Data holding is disabled

  // i2c speed see page 278
  // 0x13 for 400KHz or 0x4F for 100KHz with 32MHz clock
  SSP1ADD = 0x13;

  // SSPBUF 0x0;
  SSP1BUF = 0x00;

  // SSPMSK 0x0;
  SSP1MSK = 0x00;

  // enable MSSP port
  SSP1CON1bits.SSPEN = 1;

  // wait slave devices
  __delay_ms(100);
}

/**
 * @brief write a byte in the i2c channel
 *
 * @param d data to write
 */
void
i2c_master_write(unsigned char d) {
  // clear SSP interrupt bit
  PIR1bits.SSP1IF = 0;
  // send data
  SSP1BUF = d;
  // Wait for interrupt flag to go high indicating transmission is complete
  while (!PIR1bits.SSP1IF);
}

/**
 * @brief read a byte from the i2c channel
 *
 * @return the data read
 */
unsigned char
i2c_read_byte() {
  // clear SSP interrupt bit
  PIR1bits.SSP1IF = 0;
  // set the receive enable bit to initiate a read of 8 bits
  SSP1CON2bits.RCEN = 1;
  // wait for interrupt flag to go high indicating transmission is complete
  while (!PIR1bits.SSP1IF);
  // data is now in the SSPBUF so return that value
  return (SSP1BUF);
}

/**
 * @brief set the start condition
 */
void
i2c_master_start() {
  // clear SSP interrupt bit
  PIR1bits.SSP1IF = 0;
  // send start bit
  SSP1CON2bits.SEN = 1;
  // wait for the SSPIF bit to go back high before we load the data buffer
  while (!PIR1bits.SSP1IF);
}

/**
 * @brief set the restart condition
 */
void
i2c_master_repeated_start(void) {
  // clear SSP interrupt bit
  PIR1bits.SSP1IF = 0;
  // send restart bit
  SSP1CON2bits.RSEN = 1;
  // wait for the SSPIF bit to go back high before we load the data buffer
  while (!PIR1bits.SSP1IF);
}

/**
 * @brief set the stop condition
 */
void i2c_master_stop() {
  // clear SSP interrupt bit
  PIR1bits.SSP1IF = 0;
  // send stop bit
  SSP1CON2bits.PEN = 1;
  // wait for interrupt flag to go high indicating transmission is complete
  while (!PIR1bits.SSP1IF);
}

/**
 * @brief send an acknowledge
 */
void
i2c_master_send_ack() {
  // clear SSP interrupt bit
  PIR1bits.SSP1IF = 0;
  // clear the Acknowledge Data Bit - this means we are sending an Acknowledge or 'ACK'
  SSP1CON2bits.ACKDT = 0;
  // set the ACK enable bit to initiate transmission of the ACK bit
  SSP1CON2bits.ACKEN = 1;
  // wait for interrupt flag to go high indicating transmission is complete
  while (!PIR1bits.SSP1IF);
}

/**
 * @brief send a not acknowledge
 */
void
i2c_master_send_nack() {
  // clear SSP interrupt bit
  PIR1bits.SSP1IF = 0;
  // set the Acknowledge Data Bit- this means we are sending a No-Ack or 'NAK'
  SSP1CON2bits.ACKDT = 1;
  // set the ACK enable bit to initiate transmission of the ACK bit
  SSP1CON2bits.ACKEN = 1;
  // wait for interrupt flag to go high indicating transmission is complete
  while (!PIR1bits.SSP1IF);
}

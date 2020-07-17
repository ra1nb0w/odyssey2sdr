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

#ifndef FPGA_H
#define	FPGA_H

#include "16F1827.h"
#include "version.h"

#ifdef	__cplusplus
extern "C" {
#endif

  // IP address
#define FPGA_IP_ADDRESS_LENGTH 16
  char fpga_ip_address[FPGA_IP_ADDRESS_LENGTH+1] = {0};

  // bootloader version
#define FPGA_VERSION_LENGTH 8
  char fpga_version [FPGA_VERSION_LENGTH+1] = {0};
  // used to write the text in the
  // right position of the array
  uint8_t fpga_version_pos = 0;

  // slot position
  uint8_t fpga_boot_slot = 1;

  /* status bit mask
   *
   * | BIT | function                             |
   * |-----+--------------------------------------|
   * |   7 | not used                             |
   * |   6 | not used                             |
   * |   5 | not used                             |
   * |   4 | not used                             |
   * |   3 | not used                             |
   * |   2 | auto power on           (0=OFF 1=ON) |
   * |   1 | power amplifier enabled (0=OFF 1=ON) |
   * |   0 | audio amplifier enabled (0=OFF 1=ON) |
   */
  uint8_t fpga_status = 0;

  // the fpga request the status
  bool fpga_request_status = false;

  // the fpga requested the auto power on
  bool fpga_request_poweron = false;

  // trigger changes on main when something is received
  bool fpga_value_changed = false;

  // structure that define the stage
  // in which the FPGA is
  typedef enum {
    FPGA_RESERVED, // reserved
    FPGA_BOOTING,
    FPGA_BOOTLOADER,
    FPGA_RADIO,
    FPGA_PTT,
    FPGA_CRC_ERROR
  } fpga_stage_t;

  // define in which stage we are
  // see README for more information
  fpga_stage_t fpga_stage = 0;

  // alert main that we have a new stage
  bool fpga_stage_changed = false;

  // save the TX SWR value
  // since we receive two byte we use char and
  // during printing we convert to the right value
#define FPGA_SWR_LENGTH 2
  char fpga_swr[FPGA_SWR_LENGTH] = {0};
  bool fpga_swr_changed = false;

  // variable of the command that we
  // are waiting to acknowledge
  // if 0 there is no command in the
  // ACK waiting list
  // if !0 contains the command that we
  // want to acknowledge
  uint8_t fpga_cmd_to_ack = 0;

  // variable used to receive the bytes after the command
  uint8_t fpga_rx_cmd_next_bytes = 0;

  // which command is receiving more bytes
  uint8_t fpga_rx_cmd_wait = 0x00;

  // baud rate shared with FPGA
  // not tested with higher value
  // probably we need to use ASM
#define FPGA_UART_BAUDRATE 19200

  // value of interrupt period
#define FPGA_UART_INTERRUPT_PERIOD (1000000/FPGA_UART_BAUDRATE)

  // how many bits for each transfer
#define FPGA_UART_TRANSFER_BITS 8

  // acknowledgment command
#define FPGA_CMD_ACK 0x10

  // stage command
#define FPGA_CMD_STAGE 0x20

  // version command
#define FPGA_CMD_VERSION 0x30

  // IP command
#define FPGA_CMD_IP 0x40

  // status command
#define FPGA_CMD_STATUS 0x50

  // auto power on command
#define FPGA_CMD_POWERON 0x60

  // swr value
#define FPGA_CMD_SWR 0x70

  // temporary structure used during TX
  char fpga_tx_data = 0x00;
  uint8_t fpga_tx_pos = 0;

  // temporary position to move between bits
  uint8_t fpga_rx_pos = 0;

  // maximum bytes that we can receive without overwriting
  // the circular queue
#define FPGA_UART_RX_QUEUE_MAX 32
  // circular queue to receive multiple bytes
  char fpga_rx_queue[FPGA_UART_RX_QUEUE_MAX] = {0};
  // position used during read
  uint8_t fpga_rx_read_pos = 0;
  // position used during write new byte
  uint8_t fpga_rx_write_pos = 0;
  // flag to alert on queue overwrite; 1=overwrite; 0=good data
  uint8_t fpga_rx_queue_rewrite = 0;

  // address used to store in eeprom the configuration
#define FPGA_EEPROM_STATUS_ADDR 0x00
#define FPGA_EEPROM_SLOT_ADDR 0x01

  void fpga_init(void);
  void fpga_deinit(void);
  inline void uart_tx_bit(void);
  void uart_tx_byte(const char d);
  void uart_tx_bytes(const char *array, const uint8_t length);
  inline void uart_rx_bit(void);
  inline void uart_rx(void);
  void fpga_check_command(void);
  void fpga_send_status(void);
  void fpga_send_poweron(void);
  void fpga_write_eeprom(void);
  void fpga_read_eeprom(void);
  void fpga_update_status(void);

#ifdef	__cplusplus
}
#endif

#endif	/* FPGA_H */

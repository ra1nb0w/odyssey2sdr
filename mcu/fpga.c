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
 * This library implements software UART, aka bit-banging, to communicate with the FPGA.
 * To avoid issue with delay drift, since you sum the error each time, we use interrupt timers
 * for both RX and TX and in the RX path we use Interrupt On Change to get the
 * start bit. It should also work in full duplex, at reasonable speed, but it is not tested.
 *
 *
 * PROTOCOL: see README.org
 *
 */

/*
 * TODO:
 *  - for some strange reason the last data bit in TX is 3/4 usec shorter (at 9600)
 *    it doesn't hurt too much but it is strange :)
 *  - manage receiving error per each byte
 *  - manage overwriting of the RX circular queue (should be not needed for the moment)
 */

#include "fpga.h"

/**
 * @brief initialize the UART channel used to communicate with the FPGA
 *
 * RB6 is used for the TX to FPGA (RX on this one)
 * RB7 is used for the RX to FPGA (TX on this one)
 *
 * Timer4 is used during receive
 * Timer6 is used during transmit
 */
void
fpga_init(void) {
  // set the TX port
  IO_RB6_FPGA_TX_SetDigitalMode();
  IO_RB6_FPGA_TX_SetDigitalOutput();
  IO_RB6_FPGA_TX_SetHigh();
  IO_RB6_FPGA_TX_WPU = 1;

  // set the RX port
  IO_RB7_FPGA_RX_SetDigitalMode();
  IO_RB7_FPGA_RX_SetDigitalInput();
  IO_RB7_FPGA_RX_WPU = 1;

  // enable Interrupt on Change bit
  INTCONbits.IOCIE = 1;
  // we use interrupt on negative edge change
  // to detect the receiving start bit
  IOCBNbits.IOCBN7 = 1;

  // TIMER 4 for RX
  // we use post-scaller sets at 1:8
  T4CON |= 56;
  // no pre-scaller
  T4CONbits.T4CKPS1 = 0;
  T4CONbits.T4CKPS0 = 0;
  // Timer6 interrupt period calculated from baud rate
  PR4 = (uint8_t) FPGA_UART_INTERRUPT_PERIOD;
  // Enable Timer 6 interrupt
  PIE3bits.TMR4IE = 1;
  // Disable the Timer 6 by default
  T4CONbits.TMR4ON = 0;

  // TIMER 6 for TX
  // we use post-scaller sets at 1:8
  T6CON |= 56;
  // no pre-scaller
  T6CONbits.T6CKPS1 = 0;
  T6CONbits.T6CKPS0 = 0;
  // Timer6 interrupt period calculated from baud rate
  PR6 = (uint8_t) FPGA_UART_INTERRUPT_PERIOD;
  // Enable Timer 6 interrupt
  PIE3bits.TMR6IE = 1;
  // Disable the Timer 6 by default
  T6CONbits.TMR6ON = 0;
}

/**
 * @brief de-initialize the FPGA UART
 */
void
fpga_deinit(void)
{
  // disable Interrupt On Change
  IOCBNbits.IOCBN7 = 0;
  // disable Timers 4 and 6
  T4CONbits.TMR4ON = 0;
  T6CONbits.TMR6ON = 0;

  // reset helper variables
  fpga_boot_slot = 0;
  fpga_status = 0;
  fpga_stage = 0;
  fpga_version[0] = 0;
  fpga_ip_address[0] = 0;
  fpga_stage_changed = false;
  fpga_value_changed = false;
  fpga_request_status = false;
  fpga_request_poweron = false;
}

/**
 * @brief receive a single bit from the UART
 *
 * this function is driven by Timer4 and at each interrupt
 * its gets the bit near the middle of the period.
 * At the end it re-enables the Interrupt On Change to eventually
 * receive another byte.
 */
inline void
uart_rx_bit(void)
{
  if (fpga_rx_pos < FPGA_UART_TRANSFER_BITS)
    {
      // store the bit
      fpga_rx_queue[fpga_rx_write_pos] |= IO_RB7_FPGA_RX_GetValue() << fpga_rx_pos;

      // go to the next bit
      fpga_rx_pos++;
    }
  // we should receive a stop bit
  else if (fpga_rx_pos == FPGA_UART_TRANSFER_BITS)
    {
      // if it is not a stop bit (high)
      // we erase the data value received
      if (!IO_RB7_FPGA_RX_GetValue())
        fpga_rx_queue[fpga_rx_write_pos] = 0x00;

      // move on (not used just to differentiate the state)
      fpga_rx_pos++;

      // stop the timer
      T4CONbits.TMR4ON = 0;

      // move to the next location in the circular queue
      fpga_rx_write_pos = (fpga_rx_write_pos+1) % FPGA_UART_RX_QUEUE_MAX;

      // re-enable the interrupt on change
      IOCBNbits.IOCBN7 = 1;
    }
}

/**
 * @brief receive a single byte; driven by Interrupt On Change
 */
inline void
uart_rx(void)
{
  // we have detected a start bit; from now on we use the
  // Timer 4 interrupt to drive the read
  IOCBNbits.IOCBN7 = 0;

  // initialize the pointer
  fpga_rx_pos = 0;
  // initialize the data
  fpga_rx_queue[fpga_rx_write_pos] = 0x00;

  // since we have a range to receive we use a quick and dirty
  // way to center in the middle of the bit
  // minus 4 usec to compensate the instructions delay
  __delay_us((FPGA_UART_INTERRUPT_PERIOD/2)-4);

  // confirm that it is a start bit
  if (IO_RB7_FPGA_RX_GetValue())
    {
      // re-enable the interrupt on change
      IOCBNbits.IOCBN7 = 1;
      return;
    }

  // then enable the interrupt that will read the bits
  T4CONbits.TMR4ON = 1;
}

/**
 * @brief transmit a single bit using Timer6
 *
 * this function transmit one data bit and the stop bit
 * the data is got from fpga_tx_data and we use the
 * counter fpga_tx_pos to understand where we hare.
 * this should be called from uart_trasmit_start which
 * sets the starting value, the start bit and the Timer6
 */
inline void
uart_tx_bit(void)
{
  // we have bits to send
  if (fpga_tx_pos < FPGA_UART_TRANSFER_BITS)
    {
      // optimize the change
      if((fpga_tx_data>>fpga_tx_pos)&0x1)
        IO_RB6_FPGA_TX_SetHigh();
      else
        IO_RB6_FPGA_TX_SetLow();

      // got to the next bit
      fpga_tx_pos++;
    }
  // we have sent all bits so send the stop bit
  else if (fpga_tx_pos == FPGA_UART_TRANSFER_BITS)
    {
      // stop bit
      IO_RB6_FPGA_TX_SetHigh();

      // another delay to close the transmission
      fpga_tx_pos++;
    }
  else
    {
      // we have done
      T6CONbits.TMR6ON = 0;
    }
}

/**
 * @brief send a single byte to UART
 *
 * @param d byte to send
 */
void
uart_tx_byte(const char d)
{
  // check if we are already transmitting
  // so we BLOCK here the next transmitting data
  // until the previous one is finished
  while(T6CONbits.TMR6ON) {}

  // set the starting value
  fpga_tx_pos = 0;
  fpga_tx_data = d;

  // start bit to high
  IO_RB6_FPGA_TX_SetLow();
  // start the timer6
  T6CONbits.TMR6ON = 1;
}

/**
 * @brief send a stream of byte to UART
 *
 * @param array char array to send
 * @param length length of the array to send; generally sizeof(array)
 */
void
uart_tx_bytes(const char *array,
              const uint8_t length)
{
  uint8_t i;

  // cycle through the array
  // the transmission is automatically blocked by
  // while() in uart_transmit()
  for(i=0; i < length; i++)
    uart_tx_byte(*(array+i));
}

/**
 * @brief read the received buffer and check for commands
 */
void
fpga_check_command(void)
{
  // read byte until we have reached the write position
  while (fpga_rx_read_pos != fpga_rx_write_pos)
    {
      // we have pending bytes?
      if (fpga_rx_cmd_next_bytes != 0)
        {
          // check which command belongs these bytes
          switch(fpga_rx_cmd_wait)
            {
            case FPGA_CMD_VERSION:
              // the bytes arrive is this sense "000003.0"
              // therefore we get only the good text
              if (fpga_rx_queue[fpga_rx_read_pos] != 0x00) {
                fpga_version[fpga_version_pos] = fpga_rx_queue[fpga_rx_read_pos];
                fpga_version_pos++;
              }
              break;

            case FPGA_CMD_IP:
              fpga_ip_address[FPGA_IP_ADDRESS_LENGTH-fpga_rx_cmd_next_bytes] = fpga_rx_queue[fpga_rx_read_pos];
              break;

              // if the bytes are not correlated to a command
              // exit from this check
            default:
              fpga_rx_cmd_next_bytes = 1;
              break;
            }
          fpga_rx_cmd_next_bytes--;

          // if it is the last we can alert the main that we have changed the value
          if (fpga_rx_cmd_next_bytes == 0)
            fpga_value_changed = true;
        }
      else {
        // check the command
        switch(fpga_rx_queue[fpga_rx_read_pos] >> 4)
          {
            // reserved command or not valid
          case 0:
            break;

            // acknowledge command
          case 1:
            // check if there is a command to acknowledge
            // and if the command is the same
            if (!fpga_cmd_to_ack &&
                (fpga_rx_queue[fpga_rx_read_pos] & 0x0F) == fpga_cmd_to_ack >> 4)
              fpga_cmd_to_ack = 0x00;
            break;

            // stage command
          case 2:
            // check in which stage we are
            // we use a switch to ensure the good data and eventually
            // to implement other functions
            switch(fpga_rx_queue[fpga_rx_read_pos] & 0x0F)
              {
                // reserved
              case 0:
                fpga_stage = FPGA_RESERVED;
                break;

                // booting
              case 1:
                fpga_stage = FPGA_BOOTING;
                break;

                // bootloader
              case 2:
                fpga_stage = FPGA_BOOTLOADER;
                break;

                // radio
              case 3:
                fpga_stage = FPGA_RADIO;
                break;

                // PTT
              case 4:
                fpga_stage = FPGA_PTT;
                break;

                // firmware CRC ERROR
              case 5:
                fpga_stage = FPGA_CRC_ERROR;
                break;

                // default stage
              default:
                fpga_stage = FPGA_RESERVED;
                break;
              }
            fpga_stage_changed = true;
            break;

            // fpga firmware version
          case 3:
            // we don't care about which type is at the moment
            // only that it is not invalid or MCU
            if ((fpga_rx_queue[fpga_rx_read_pos] & 0x0F) != 0 &&
                (fpga_rx_queue[fpga_rx_read_pos] & 0x0F) != 1)
              {
                // clear version string
                cla(fpga_version, sizeof(fpga_version));
                // we need to get the following 8 bytes
                fpga_rx_cmd_next_bytes = FPGA_VERSION_LENGTH;
                // save the command to correlate the next bytes
                fpga_rx_cmd_wait = FPGA_CMD_VERSION;
                // reset the counter
                fpga_version_pos = 0;
              }
            break;

            // IP address
          case 4:
            // clear the IP array
            cla(fpga_ip_address, sizeof(fpga_ip_address));

            // we need to get the following 16 bytes
            fpga_rx_cmd_next_bytes = FPGA_IP_ADDRESS_LENGTH;
            // save the command to correlate the next bytes
            fpga_rx_cmd_wait = FPGA_CMD_IP;
            break;

            // status
          case 5:

            // we have a request therefore send the status
            // is blocking but fast enough to not care
            if (fpga_rx_queue[fpga_rx_read_pos] == FPGA_CMD_STATUS)
              {
                fpga_request_status = true;
                break;
              }

            // get a valid slot
            if ((fpga_rx_queue[fpga_rx_read_pos] & 0x0C) != 0)
              fpga_boot_slot = (fpga_rx_queue[fpga_rx_read_pos] & 0x0C) >> 2;

            // get the 1W power amplifier status
            if (rbi(fpga_rx_queue[fpga_rx_read_pos], 1))
              sbi(fpga_status, 1);
            else
              cbi(fpga_status, 1);

            // get the audio amplifier status
            if (rbi(fpga_rx_queue[fpga_rx_read_pos], 0))
              sbi(fpga_status, 0);
            else
              cbi(fpga_status, 0);

            // write to eeprom the new values
            fpga_write_eeprom();

            // we have changed the values
            fpga_value_changed = true;
            break;

            // auto power on
          case 6:

            if (fpga_rx_queue[fpga_rx_read_pos] == FPGA_CMD_POWERON)
              {
                fpga_request_poweron = true;
                break;
              }

            if (fpga_rx_queue[fpga_rx_read_pos] == (FPGA_CMD_POWERON | 0x01))
              sbi(fpga_status, 2);
            else
              cbi(fpga_status, 2);

            // write the new value to eeprom
            fpga_write_eeprom();
            break;

            // if the command is invalid don't do anything
          default:
            break;
          }
      }

      // move on in the circular queue
      fpga_rx_read_pos = (fpga_rx_read_pos + 1) % FPGA_UART_RX_QUEUE_MAX;
    }
}

/**
 * @brief send the status to the FPGA
 *
 * before calling this function we need to check
 * that fpga_cmd_to_ack must be 0 to ensure
 * that there is not other commands on the fly
 */
void
fpga_send_status(void)
{
  // send the status byte
  uart_tx_byte(FPGA_CMD_STATUS | fpga_boot_slot << 2 | rbi(fpga_status,1) << 1 | rbi(fpga_status,0));
}

/**
 * @brief send the MCU software version to FPGA
 */
void
fpga_send_mcu_version(void)
{
  // we send the MCU version
  uart_tx_byte(FPGA_CMD_VERSION | 1);
  uart_tx_bytes(mcu_version, 8);
}

/**
 * @brief send the power on value to FPGA
 */
void
fpga_send_poweron(void)
{
  // send the auto power on byte
  uart_tx_byte(FPGA_CMD_POWERON | (rbi(fpga_status,2) ? 0x01 : 0x02));
}

/**
 * @brief write configuration to eeprom
 */
void
fpga_write_eeprom(void)
{
  EEPROM_WRITE(FPGA_EEPROM_STATUS_ADDR, fpga_status);
  EEPROM_WRITE(FPGA_EEPROM_SLOT_ADDR, fpga_boot_slot);
}

/**
 * @brief read configuration from eeprom
 */
void
fpga_read_eeprom(void)
{
  // wait for end-of-write before EEPROM_READ
  while(WR) {}
  fpga_status = EEPROM_READ(FPGA_EEPROM_STATUS_ADDR);
  fpga_boot_slot = EEPROM_READ(FPGA_EEPROM_SLOT_ADDR);

  // check to be sure that a good value is generated
  if (fpga_boot_slot < 1 || fpga_boot_slot > 3) {
    fpga_boot_slot = 1;
    fpga_write_eeprom();
  }
}

/**
 * @brief update the status to eeprom and to fpga
 */
void
fpga_update_status(void)
{
  fpga_write_eeprom();
  fpga_send_status();
}

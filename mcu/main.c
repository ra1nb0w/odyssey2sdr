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

/**
 * DEVICE: PIC16F1827
 *
 * standard: C99
 * compiler: XC8 2.20
 *
 *
 * Pin connections:
 *
 * RA0  empty
 * RA1  empty
 * RA2  1W Power Amplifier 1 = ON; 0 = OFF (enabled only during PTT)
 * RA3  MIC FST permit power on (like physical button)
 * RA4  empty
 * RA5  MCLR
 * RA6  Audio Amplifier 1 = OFF; 0 = ON
 * RA7  MIC UP (pull-up) --> NO Interrupt on Change available
 * RB0  Power on button (pull-up) pressed when 0
 * RB1  i2c SDA display
 * RB2  TPS62140 enable line (board 5V) 1 = ON; 0 = OFF
 * RB3  MIC DOWN (pull-up)
 * RB4  i2c SCL display
 * RB5  FPGA J22 (not used)
 * RB6  FPGA L22 (UART TX to FPGA) and CLK programmer
 * RB7  FPGA L21 (UART RX from FPGA) and DAT programmer
 *
 * FPGA K21 (MCU_RES) not connected to MCU
 *
 *
 * Interrupt:
 * - Interrupt on Change on RB7 (UART RX) for detect the start bit
 * - interrupt of timers 4 and 6 to manage UART RX/TX timing
 *
 *
 * Timer:
 * - TMR4  used by UART RX to manage next bit delay
 * - TMR6  used by UART TX to manage next bit delay
 *
 *
 * Functionalities:
 * - power up/down the main board with button and MIC FST
 * - display the status/IP/slot to the display
 * - bi-directional communication with the FPGA
 * - store all configurations except IP and MAC on local EEPROM
 *   this was done for two reasons:
 *     - we need to save locally the auto power on value
 *     - to avoid modification/rewriting of the FPGA EEPROM code
 *
 *
 * During BOOT:
 * - change the slot with a short pression of MIC UP/DOWN during boot
 *
 *
 * At any time:
 * - enable or disable the PA with a long press of MIC DOWN
 * - enable or disable the audio amplifier with a long press of MIC UP
 *
 * Notes:
 *
 *
 */

#include "16F1827.h"
#include "i2c.h"
#include "ssd1306.h"
#include "fpga.h"
#include "version.h"

// main while delay in ms
#define FUNCTIONAL_DELAY 100

// 1 second to be a valid press (in msec)
#define BUTTON_PRESS_TIME 1000
// button counter
uint8_t btn_count_time = 0;

// text used on the screen
#define TEXT_STANDBY         "STANDBY"
#define TEXT_FPGA_ERROR      "FPGA ERROR"
#define TEXT_FPGA_CRC_ERROR  "CRC ERROR"
#define TEXT_SDR             "ODYSSEY 2"
#define TEXT_BOOTLOADER      "BL: "
#define TEXT_MCU_VERSION     "MCU: "
#define TEXT_BOOTING         "BOOTING"
//#define TEXT_IP_ADDRESS      "IP:"
#define TEXT_IP_ADDRESS      " "
#define TEXT_TRANSMITTING    "ON AIR"
#define TEXT_BOOT_SLOT       "SLOT: "
#define TEXT_PA              "PA: "
#define TEXT_AA              "AA: "
#define TEXT_ENABLED         "ON"
#define TEXT_DISABLED        "OFF"
#define TEXT_SWR             "SWR: "

// after 60 second the display will be off
#define STANDBY_TIMEOUT 60000
// counter to power off the display
uint16_t standby_display_count = 0;
uint16_t display_count = 0;

// how much we need to press to be a valid command
#define BUTTON_LONG_PRESS 1500
#define BUTTON_SHORT_PRESS 200

// how much we show the message on the display
#define SCREEN_MESSAGE_TIMEOUT 3000

// counter to check the MIC down button
uint16_t mic_down_count = 0;
// counter to check the MIC up button
uint16_t mic_up_count = 0;

// declare which slot are the minimum to boot
#define BOOT_SLOT_MIN 1
// declare which slot are the maxim to boot
#define BOOT_SLOT_MAX 3

// screen status
typedef enum {
  EMPTY, // empty status
  STANDBY, // stand by
  BOOTING, // booting
  BOOTLOADER, // bootloader
  SDR, // fpga enabled
  TRANSMITTING, // during transmission
  PA_MSG, // show the power amplifier status
  AA_MSG, // show the audio amplifier status
  FPGA_ERROR, // the FPGA not boot correctly
  CRC_ERROR  // the FPGA has encountered a CRC error during firmware load
} screen_status_t;

// track the in which status is living the display
screen_status_t screen_status = EMPTY;
screen_status_t prev_screen_status = EMPTY;
screen_status_t change_screen_status = EMPTY;
// permit to redraw the same screen
// useful in bootloader when value change
bool screen_redraw = 0;

// standby circle range
uint8_t display_circle = 3;

// counter used to check FPGA after the boot
uint16_t count_from_boot = 0;
// 2 second to be a valid press (in msec)
#define FPGA_ERROR_TIME 3000

// initialize the eeprom during programming
// see fpga.h for the address and the meaning
__EEPROM_DATA(0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00);

/**
 * @brief function called when interrupt is received
 */
void
__interrupt() interrupt_handler(void) {

  // check if we need to transmit
  if (PIE3bits.TMR6IE && PIR3bits.TMR6IF)
    {
      uart_tx_bit();
      // reset the interrupt
      PIR3bits.TMR6IF=0;
    }

  // check if we need to receive
  if (PIE3bits.TMR4IE && PIR3bits.TMR4IF)
    {
      uart_rx_bit();
      // reset the interrupt
      PIR3bits.TMR4IF=0;
    }

  // evaluate only Interrupt on Change interrupts
  // to check all Flags use INTCONbits.IOCIF (remember to clear after)
  if (INTCONbits.IOCIE == 1) {
    // check if we have received an interrupt from FPGA RX
    if (IOCBFbits.IOCBF7 == 1) {
      uart_rx();
      // reset the interrupt
      IOCBFbits.IOCBF7 = 0;
    }
  }
}

/**
 * @brief print the header (bootloader/mcu version) in the bootloader screen
 */
void
write_boot_header(void) {
  ssd1306_puts(TEXT_BOOTLOADER);
  ssd1306_puts(fpga_version);
  ssd1306_puts(" " TEXT_MCU_VERSION);
  ssd1306_puts((char *) mcu_version);
}

/**
 * @brief print the slot in the bootloader screen
 */
void
write_boot_slot(void) {
  ssd1306_goto(0, 2);
  ssd1306_puts(TEXT_BOOT_SLOT);
  ssd1306_putun(fpga_boot_slot);
}

/**
 * @brief print the amplifiers status in the bootloader screen
 */
void
write_boot_amplifiers(void) {
  ssd1306_goto(0, 3);
  ssd1306_puts(bit_is_set(fpga_status, 1) ? "PA: " TEXT_ENABLED : "PA: " TEXT_DISABLED);
  ssd1306_puts("  ");
  ssd1306_puts(bit_is_set(fpga_status, 0) ? "AA: " TEXT_ENABLED : "AA: " TEXT_DISABLED);
}

/**
 * @brief print the swr value during PTT
 */
void
write_swr(void) {
  ssd1306_goto(0, 3);
  ssd1306_puts(TEXT_SWR);
  ssd1306_puts(fpga_swr);
}

/**
 * @brief print the IP in the bootloader screen
 */
void
write_boot_ip(void) {
  ssd1306_goto(0, 1);
  // not enough space to print this and the full IPv4
  ssd1306_puts(TEXT_IP_ADDRESS);
  int i;
  // print the IP address with dots (note: not IPv6 compliant)
  for (i=0; i < strlen(fpga_ip_address); i++) {
    if (i!=0)
      ssd1306_putch('.');
    ssd1306_putun(fpga_ip_address[i]);
  }
}

/**
 * @brief enable or disable the audio amplifier based on the status value
 */
void
set_audio_amplifier(void) {
  IO_RA6_AUDIO_AMPL_LAT = ~rbi(fpga_status, 0);
}

/**
 * @brief enable or disable the 1W RF amplifier based on the status value
 *
 * generally it is used during PTT status since we don't like that the RF
 * amplifier is always enabled
 *
 * @param c 1 if we are entering in the PTT otherwise 0
 */
void
set_rf_amplifier(bool c) {
  if(c && bit_is_set(fpga_status, 1))
    IO_RA2_1W_PA_SetHigh();
  else
    IO_RA2_1W_PA_SetLow();
}

/**
 * @brief initialize the FPGA UART and power on the board
 */
void
start_fpga(void) {
  IO_RB2_BOARD_PWR_SetHigh();

  // read configuration from eeprom
  fpga_read_eeprom();

  // initialize the audio amplifier value
  set_audio_amplifier();

  // initialize the communication with FPGA
  fpga_init();

  // delay a bit before use FPGA
  __delay_ms(FUNCTIONAL_DELAY*5);

  // draw immediately the screen
  prev_screen_status = screen_status;
  screen_status = BOOTING;

  // start the counter
  count_from_boot = 0;
}

/**
 * @brief stop the UART and power off the board
 */
void
stop_fpga(void) {
  // write configuration to eeprom before
  // clear local values
  fpga_write_eeprom();
  fpga_deinit();
  IO_RB2_BOARD_PWR_SetLow();
  // move the screen to STANDBY
  prev_screen_status = screen_status;
  screen_status = STANDBY;
}

/**
 * @brief nothing to say :)
 */
void
main(void) {

  // initialize the MCU
  mcu_init();

  // read the eeprom configuration
  fpga_read_eeprom();

  // initialize the display and move to STANDBY screen
  ssd1306_init();
  screen_status = STANDBY;

  // check if we need to start the FPGA
  // without any button
  // useful with a remote controllable
  // power supply
  if (rbi(fpga_status, 2)) {
    start_fpga();
  }

  while (1) {

    // power off the display after a while when in stand-by mode
    if (screen_status == STANDBY && ssd1306_display_status) {
      if (standby_display_count == STANDBY_TIMEOUT / FUNCTIONAL_DELAY &&
          (IO_RB0_BTN_ON_GetValue() || IO_RA3_MIC_FST_GetValue())) {
        ssd1306_power(0);
      } else {
        standby_display_count++;
#if EXTRA
        // display a small animated circle during standby
        display_circle++;
        display_circle %= 8;
        ssd1306_circle(SSD1306_WIDTH / 2, SSD1306_HEIGHT / 3, display_circle);
#endif
      }
    }

    // check if we are in operating mode
    if (IO_RB2_BOARD_PWR_GetValue()) {

      // check if have received commands from FPGA
      fpga_check_command();

      // send the status after an fpga request
      if (fpga_request_status) {
        fpga_request_status = false;
        fpga_send_status();
      }

      // send the auto power on after an fpga request
      if (fpga_request_poweron) {
        fpga_request_poweron = false;
        fpga_send_poweron();
      }

      if (fpga_value_changed) {
        // reset the value
        fpga_value_changed = false;

        // se the new value of audio amplifier
        set_audio_amplifier();

        // we need to redraw the bootloader
        if (screen_status == BOOTLOADER) {
          screen_redraw = 1;
        }
      }

      if (fpga_swr_changed) {
        // reset the value
        fpga_swr_changed = false;
        // print on screen the SWR value
        write_swr();
      }

      // now we need to check if the FPGA changed the stage
      // or if we haven't received anything from FPGA after an amount of time
      if (fpga_stage_changed ||
          (screen_status == BOOTING && count_from_boot == (BUTTON_PRESS_TIME/FUNCTIONAL_DELAY) && fpga_ip_address[0] == 0)) {
        fpga_stage_changed = false;
        prev_screen_status = screen_status;
        switch(fpga_stage)
          {
            // if there is not message we display the error
          case FPGA_RESERVED:
            screen_status = FPGA_ERROR;
            break;

          case FPGA_BOOTING:
            screen_status = BOOTING;
            break;

          case FPGA_BOOTLOADER:
            screen_status = BOOTLOADER;
            break;

          case FPGA_RADIO:
            // always power of the RF amplifier
            set_rf_amplifier(false);
            screen_status = SDR;
            break;

          case FPGA_PTT:
            // check if we need to unable the RF amplifier
            set_rf_amplifier(true);
            screen_status = TRANSMITTING;
            break;

          case FPGA_CRC_ERROR:
            screen_status = CRC_ERROR;
            break;
          }
      }

      // but not transmitting or in error
      if (screen_status != TRANSMITTING && screen_status != FPGA_ERROR) {

        // check if we are pressing the MIC down button
        if (!IO_RB3_MIC_DOWN_GetValue()) {
          mic_down_count++;
          // enable or disable the power amplifier during PTT with a long press of MIC DOWN
          if ((mic_down_count >= BUTTON_LONG_PRESS / FUNCTIONAL_DELAY) &&
              screen_status != PA_MSG) {
            // update the fpga status
            fbi(fpga_status, 1);
            fpga_update_status();
            prev_screen_status = screen_status;
            screen_status = PA_MSG;
          }
}// the button is not pressed and check if was pressed
              else if (mic_down_count > 0) {
                // if a short press decrement the boot slot value; available only at bootloader
                if ((mic_down_count < BUTTON_LONG_PRESS / FUNCTIONAL_DELAY) &&
                    (mic_down_count >= BUTTON_SHORT_PRESS / FUNCTIONAL_DELAY) &&
                    screen_status == BOOTLOADER) {
                  if (fpga_boot_slot > BOOT_SLOT_MIN) {
                    // decrement the slot
                    fpga_boot_slot--;
                    fpga_update_status();
                    // update the screen value
                    write_boot_slot();
                  }
                }
                // reset the counter
                mic_down_count = 0;
              }

              // check if we are pressing the MIC up button
              if (!IO_RA7_MIC_UP_GetValue()) {
                mic_up_count++;
                // enable or disable the audio amplifier with a long press of MIC up
                if ((mic_up_count >= BUTTON_LONG_PRESS / FUNCTIONAL_DELAY) &&
                    screen_status != AA_MSG) {
                  // update the fpga status
                  fbi(fpga_status, 0);
                  fpga_update_status();
                  // enable/disable the audio amplifier
                  set_audio_amplifier();
                  prev_screen_status = screen_status;
                  screen_status = AA_MSG;
                }
              }// the button is not pressed and check if was pressed
              else if (mic_up_count > 0) {
                // if a short press decrement the boot slot value
                if ((mic_up_count < BUTTON_LONG_PRESS / FUNCTIONAL_DELAY) &&
                    (mic_up_count >= BUTTON_SHORT_PRESS / FUNCTIONAL_DELAY) &&
                    screen_status == BOOTLOADER) {
                  if (fpga_boot_slot < BOOT_SLOT_MAX) {
                    // increment the slot
                    fpga_boot_slot++;
                    fpga_update_status();
                    // update the screen value
                    write_boot_slot();
                  }
                }
                // reset the counter
                mic_up_count = 0;
              }
            }
    }

      // check if the Power ON or MIC FST buttons are pressed
      // unfortunately, we can't move to ISR since we need to check RA3
      // and therefore if we use SLEEP() we can't use the MIC to power on
      if (!IO_RB0_BTN_ON_GetValue() || !IO_RA3_MIC_FST_GetValue()) {
        if (btn_count_time == BUTTON_PRESS_TIME / FUNCTIONAL_DELAY) {

          // the UART must be initialized here because the external pull-ups
          // are powered by the main board power supply; in this way we avoid
          // un-requested spikes

          // power off the UART channel with FPGA and the board
          if(IO_RB2_BOARD_PWR_GetValue())
            {
              stop_fpga();
            }
          // power on the board and init the UART
          else
            {
              start_fpga();
            }

          // reset the counter
          btn_count_time = 0;
        } else {
          btn_count_time++;
          // with short press power on the display
          if (!ssd1306_display_status) {
            ssd1306_power(1);
            standby_display_count = 0;
          }
        }
      }
      // if released without action reset the counter
      else if (btn_count_time > 0)
        btn_count_time = 0;

      // manage the display screen only when changes occur
      if ((change_screen_status != screen_status) || screen_redraw) {
        change_screen_status = screen_status;
        screen_redraw = 0;
        ssd1306_clear();
        ssd1306_power(1);
        // check in which status we are
        switch (screen_status) {
        case EMPTY:
          break;
        case STANDBY:
          ssd1306_puts_center(TEXT_STANDBY, (SSD1306_HEIGHT / 8) - 1);
          standby_display_count = 0;
          break;
        case BOOTING:
          ssd1306_puts_center(TEXT_BOOTING, (SSD1306_HEIGHT / 16) - 1);
          break;
        case BOOTLOADER:
          write_boot_header();
          write_boot_ip();
          write_boot_slot();
          write_boot_amplifiers();
          break;
        case SDR:
          ssd1306_puts_center(TEXT_SDR, (SSD1306_HEIGHT / 16) - 1);
          break;
        case TRANSMITTING:
          ssd1306_puts_center(TEXT_TRANSMITTING, 1);
          ssd1306_puts_center(fpga_version, 2);
          break;
        case PA_MSG:
          ssd1306_puts_center(bit_is_set(fpga_status, 1) ?
                              TEXT_PA TEXT_ENABLED : TEXT_PA TEXT_DISABLED,
                              (SSD1306_HEIGHT / 16) - 1);
          display_count = 0;
          break;
        case AA_MSG:
          ssd1306_puts_center(bit_is_set(fpga_status, 0) ?
                              TEXT_AA TEXT_ENABLED : TEXT_AA TEXT_DISABLED,
                              (SSD1306_HEIGHT / 16) - 1);
          display_count = 0;
          break;
        case FPGA_ERROR:
          ssd1306_puts_center(TEXT_FPGA_ERROR, (SSD1306_HEIGHT / 16) - 1);
          break;
        case CRC_ERROR:
          ssd1306_puts_center(TEXT_FPGA_CRC_ERROR, (SSD1306_HEIGHT / 16) - 1);
          break;
        }
      }

      // check if we are printing a message on the display
      if (screen_status == PA_MSG || screen_status == AA_MSG) {
        // if the timeout is reached we change the display to the previous one
        if (display_count == SCREEN_MESSAGE_TIMEOUT / FUNCTIONAL_DELAY) {
          screen_status = prev_screen_status;
          change_screen_status = EMPTY;
          display_count = 0;
        } else {
          display_count++;
        }
      }

      // standard functional delay
      __delay_ms(FUNCTIONAL_DELAY);
      count_from_boot++;
  }
}

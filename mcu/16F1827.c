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

#include "16F1827.h"

/**
 * @brief initialize the microcontroller
 */
void
mcu_init(void) {

  // initialize the oscillator 8MHz x4 = 32MHz PLL if enabled
  // SCS FOSC; SPLLEN disabled; IRCF 8MHz_HF;
  OSCCON = 0x70;
  // TUN 0;
  OSCTUNE = 0x00;
  // SBOREN disabled;
  BORCON = 0x00;
  // Wait for PLL to stabilize
  while (PLLR == 0) {}

  // WDTPS 1:65536; SWDTEN OFF;
  WDTCON = 0x16;

  // PIN initialization
  // read https://ww1.microchip.com/downloads/en/DeviceDoc/41391D.pdf#117
  // LAT* output latch
  LATA = 0x48;
  LATB = 0x01;
  // TRIS* data direction register
  TRISA = 0xBB;
  TRISB = 0xFB;
  // ANSEL* analog select
  ANSELA = 0x00;
  ANSELB = 0x00;
  // WPU* weak pull-up
  WPUA = 0x00;
  WPUB = 0x00;
  // alternate pin function control
  APFCON0 = 0x00;
  APFCON1 = 0x00;

  // Fixed voltage reference (FVR)
  // FVR output voltage for DAC = 4.096V
  FVRCONbits.CDAFVR = 0b11;
  // FVR enable
  FVRCONbits.FVREN = 1;

  // use RA2 (1W power amplifier power on) as ADC with
  // the voltage reference as backend to have a stable
  // voltage to drive the ST PD85004
#ifdef PA_BIAS_4096
  TRISAbits.TRISA2 = 1;
  ANSELAbits.ANSA2 = 1;
  DACCON1 = 0x00;
  // use FVR as source voltage for DAC
  DACCON0bits.DACPSS=0b10;
  // enable LPS
  DACCON0bits.DACLPS=0;
  // enable DAC to output on RA2
  DACCON0bits.DACOE=1;
  // DAC negative voltage is Vss
  DACCON0bits.DACNSS = 0;
  // turn on the DAC
  DACCON0bits.DACEN=0;
#endif

  // enable weak pull-ups globally
  OPTION_REGbits.nWPUEN = 0;

  // enable/disable global interrupt
  INTCONbits.GIE = 1;

  // enable/disable peripheral interrupt
  INTCONbits.PEIE = 1;
}

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


#ifndef _16F1827_H
#define	_16F1827_H

#ifdef	__cplusplus
extern "C" {
#endif

  // 32MHz frequency
#define _XTAL_FREQ 32000000

  // CONFIG
#pragma config FOSC = INTOSC    // Oscillator Selection->INTOSC oscillator: I/O function on CLKIN pin
#pragma config WDTE = OFF       // Watchdog Timer Enable->WDT disabled
#pragma config PWRTE = OFF      // Power-up Timer Enable->PWRT disabled
#pragma config MCLRE = ON       // MCLR Pin Function Select->MCLR/VPP pin function is MCLR
#pragma config CP = OFF         // Flash Program Memory Code Protection->Program memory code protection is disabled
#pragma config CPD = OFF        // Data Memory Code Protection->Data memory code protection is disabled
#pragma config BOREN = OFF      // Brown-out Reset Enable->Brown-out Reset enabled
#pragma config CLKOUTEN = OFF   // Clock Out Enable->CLKOUT function is disabled. I/O or oscillator function on the CLKOUT pin
#pragma config IESO = OFF       // Internal/External Switchover->Internal/External Switchover mode is enabled
#pragma config FCMEN = OFF      // Fail-Safe Clock Monitor Enable->Fail-Safe Clock Monitor is enabled
#pragma config WRT = OFF        // Flash Memory Self-Write Protection->Write protection off
#pragma config PLLEN = ON       // PLL Enable->4x PLL enabled
#pragma config STVREN = ON      // Stack Overflow/Underflow Reset Enable->Stack Overflow or Underflow will cause a Reset
#pragma config BORV = LO        // Brown-out Reset Voltage Selection->Brown-out Reset Voltage (Vbor), low trip point selected.
#pragma config LVP = ON         // Low-Voltage Programming Enable->Low-voltage programming enabled

  //XC8 Standard Include
#include <xc.h>
#include <stdio.h>
#include <stdlib.h>

  //Other Includes
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <math.h>
#include <conio.h>

  /*** PIN facilities ***/
#define INPUT   1
#define OUTPUT  0

#define HIGH    1
#define LOW     0

#define ANALOG      1
#define DIGITAL     0

#define PULL_UP_ENABLED      1
#define PULL_UP_DISABLED     0

  // get/set IO_RA2_1W_PA aliases
#define IO_RA2_1W_PA_TRIS                 TRISAbits.TRISA2
#define IO_RA2_1W_PA_LAT                  LATAbits.LATA2
#define IO_RA2_1W_PA_PORT                 PORTAbits.RA2
#define IO_RA2_1W_PA_ANS                  ANSELAbits.ANSA2
#define IO_RA2_1W_PA_SetHigh()            do { LATAbits.LATA2 = 1; } while(0)
#define IO_RA2_1W_PA_SetLow()             do { LATAbits.LATA2 = 0; } while(0)
#define IO_RA2_1W_PA_Toggle()             do { LATAbits.LATA2 = ~LATAbits.LATA2; } while(0)
#define IO_RA2_1W_PA_GetValue()           PORTAbits.RA2
#define IO_RA2_1W_PA_SetDigitalInput()    do { TRISAbits.TRISA2 = 1; } while(0)
#define IO_RA2_1W_PA_SetDigitalOutput()   do { TRISAbits.TRISA2 = 0; } while(0)
#define IO_RA2_1W_PA_SetAnalogMode()      do { ANSELAbits.ANSA2 = 1; } while(0)
#define IO_RA2_1W_PA_SetDigitalMode()     do { ANSELAbits.ANSA2 = 0; } while(0)

// get/set IO_RA3_MIC_FST aliases
#define IO_RA3_MIC_FST_TRIS                 TRISAbits.TRISA3
#define IO_RA3_MIC_FST_LAT                  LATAbits.LATA3
#define IO_RA3_MIC_FST_PORT                 PORTAbits.RA3
#define IO_RA3_MIC_FST_ANS                  ANSELAbits.ANSA3
#define IO_RA3_MIC_FST_SetHigh()            do { LATAbits.LATA3 = 1; } while(0)
#define IO_RA3_MIC_FST_SetLow()             do { LATAbits.LATA3 = 0; } while(0)
#define IO_RA3_MIC_FST_Toggle()             do { LATAbits.LATA3 = ~LATAbits.LATA3; } while(0)
#define IO_RA3_MIC_FST_GetValue()           PORTAbits.RA3
#define IO_RA3_MIC_FST_SetDigitalInput()    do { TRISAbits.TRISA3 = 1; } while(0)
#define IO_RA3_MIC_FST_SetDigitalOutput()   do { TRISAbits.TRISA3 = 0; } while(0)
#define IO_RA3_MIC_FST_SetAnalogMode()      do { ANSELAbits.ANSA3 = 1; } while(0)
#define IO_RA3_MIC_FST_SetDigitalMode()     do { ANSELAbits.ANSA3 = 0; } while(0)

// get/set IO_RA6_AUDIO_AMPL aliases
#define IO_RA6_AUDIO_AMPL_TRIS                 TRISAbits.TRISA6
#define IO_RA6_AUDIO_AMPL_LAT                  LATAbits.LATA6
#define IO_RA6_AUDIO_AMPL_PORT                 PORTAbits.RA6
#define IO_RA6_AUDIO_AMPL_SetHigh()            do { LATAbits.LATA6 = 1; } while(0)
#define IO_RA6_AUDIO_AMPL_SetLow()             do { LATAbits.LATA6 = 0; } while(0)
#define IO_RA6_AUDIO_AMPL_Toggle()             do { LATAbits.LATA6 = ~LATAbits.LATA6; } while(0)
#define IO_RA6_AUDIO_AMPL_GetValue()           PORTAbits.RA6
#define IO_RA6_AUDIO_AMPL_SetDigitalInput()    do { TRISAbits.TRISA6 = 1; } while(0)
#define IO_RA6_AUDIO_AMPL_SetDigitalOutput()   do { TRISAbits.TRISA6 = 0; } while(0)

// get/set IO_RA7_MIC_UP aliases
#define IO_RA7_MIC_UP_TRIS                 TRISAbits.TRISA7
#define IO_RA7_MIC_UP_LAT                  LATAbits.LATA7
#define IO_RA7_MIC_UP_PORT                 PORTAbits.RA7
#define IO_RA7_MIC_UP_SetHigh()            do { LATAbits.LATA7 = 1; } while(0)
#define IO_RA7_MIC_UP_SetLow()             do { LATAbits.LATA7 = 0; } while(0)
#define IO_RA7_MIC_UP_Toggle()             do { LATAbits.LATA7 = ~LATAbits.LATA7; } while(0)
#define IO_RA7_MIC_UP_GetValue()           PORTAbits.RA7
#define IO_RA7_MIC_UP_SetDigitalInput()    do { TRISAbits.TRISA7 = 1; } while(0)
#define IO_RA7_MIC_UP_SetDigitalOutput()   do { TRISAbits.TRISA7 = 0; } while(0)

// get/set IO_RB0_BTN_ON aliases
#define IO_RB0_BTN_ON_TRIS                 TRISBbits.TRISB0
#define IO_RB0_BTN_ON_LAT                  LATBbits.LATB0
#define IO_RB0_BTN_ON_PORT                 PORTBbits.RB0
#define IO_RB0_BTN_ON_WPU                  WPUBbits.WPUB0
#define IO_RB0_BTN_ON_SetHigh()            do { LATBbits.LATB0 = 1; } while(0)
#define IO_RB0_BTN_ON_SetLow()             do { LATBbits.LATB0 = 0; } while(0)
#define IO_RB0_BTN_ON_Toggle()             do { LATBbits.LATB0 = ~LATBbits.LATB0; } while(0)
#define IO_RB0_BTN_ON_GetValue()           PORTBbits.RB0
#define IO_RB0_BTN_ON_SetDigitalInput()    do { TRISBbits.TRISB0 = 1; } while(0)
#define IO_RB0_BTN_ON_SetDigitalOutput()   do { TRISBbits.TRISB0 = 0; } while(0)
#define IO_RB0_BTN_ON_SetPullup()          do { WPUBbits.WPUB0 = 1; } while(0)
#define IO_RB0_BTN_ON_ResetPullup()        do { WPUBbits.WPUB0 = 0; } while(0)

// get/set RB1 i2c SDA
#define RB1_SetHigh()            do { LATBbits.LATB1 = 1; } while(0)
#define RB1_SetLow()             do { LATBbits.LATB1 = 0; } while(0)
#define RB1_Toggle()             do { LATBbits.LATB1 = ~LATBbits.LATB1; } while(0)
#define RB1_GetValue()              PORTBbits.RB1
#define RB1_SetDigitalInput()    do { TRISBbits.TRISB1 = 1; } while(0)
#define RB1_SetDigitalOutput()   do { TRISBbits.TRISB1 = 0; } while(0)
#define RB1_SetPullup()             do { WPUBbits.WPUB1 = 1; } while(0)
#define RB1_ResetPullup()           do { WPUBbits.WPUB1 = 0; } while(0)
#define RB1_SetAnalogMode()         do { ANSELBbits.ANSB1 = 1; } while(0)
#define RB1_SetDigitalMode()        do { ANSELBbits.ANSB1 = 0; } while(0)

// get/set IO_RB2_BOARD_PWR aliases
#define IO_RB2_BOARD_PWR_TRIS                 TRISBbits.TRISB2
#define IO_RB2_BOARD_PWR_LAT                  LATBbits.LATB2
#define IO_RB2_BOARD_PWR_PORT                 PORTBbits.RB2
#define IO_RB2_BOARD_PWR_WPU                  WPUBbits.WPUB2
#define IO_RB2_BOARD_PWR_ANS                  ANSELBbits.ANSB2
#define IO_RB2_BOARD_PWR_SetHigh()            do { LATBbits.LATB2 = 1; } while(0)
#define IO_RB2_BOARD_PWR_SetLow()             do { LATBbits.LATB2 = 0; } while(0)
#define IO_RB2_BOARD_PWR_Toggle()             do { LATBbits.LATB2 = ~LATBbits.LATB2; } while(0)
#define IO_RB2_BOARD_PWR_GetValue()           PORTBbits.RB2
#define IO_RB2_BOARD_PWR_SetDigitalInput()    do { TRISBbits.TRISB2 = 1; } while(0)
#define IO_RB2_BOARD_PWR_SetDigitalOutput()   do { TRISBbits.TRISB2 = 0; } while(0)
#define IO_RB2_BOARD_PWR_SetPullup()          do { WPUBbits.WPUB2 = 1; } while(0)
#define IO_RB2_BOARD_PWR_ResetPullup()        do { WPUBbits.WPUB2 = 0; } while(0)
#define IO_RB2_BOARD_PWR_SetAnalogMode()      do { ANSELBbits.ANSB2 = 1; } while(0)
#define IO_RB2_BOARD_PWR_SetDigitalMode()     do { ANSELBbits.ANSB2 = 0; } while(0)

// get/set IO_RB3_MIC_DOWN aliases
#define IO_RB3_MIC_DOWN_TRIS                 TRISBbits.TRISB3
#define IO_RB3_MIC_DOWN_LAT                  LATBbits.LATB3
#define IO_RB3_MIC_DOWN_PORT                 PORTBbits.RB3
#define IO_RB3_MIC_DOWN_WPU                  WPUBbits.WPUB3
#define IO_RB3_MIC_DOWN_ANS                  ANSELBbits.ANSB3
#define IO_RB3_MIC_DOWN_SetHigh()            do { LATBbits.LATB3 = 1; } while(0)
#define IO_RB3_MIC_DOWN_SetLow()             do { LATBbits.LATB3 = 0; } while(0)
#define IO_RB3_MIC_DOWN_Toggle()             do { LATBbits.LATB3 = ~LATBbits.LATB3; } while(0)
#define IO_RB3_MIC_DOWN_GetValue()           PORTBbits.RB3
#define IO_RB3_MIC_DOWN_SetDigitalInput()    do { TRISBbits.TRISB3 = 1; } while(0)
#define IO_RB3_MIC_DOWN_SetDigitalOutput()   do { TRISBbits.TRISB3 = 0; } while(0)
#define IO_RB3_MIC_DOWN_SetPullup()          do { WPUBbits.WPUB3 = 1; } while(0)
#define IO_RB3_MIC_DOWN_ResetPullup()        do { WPUBbits.WPUB3 = 0; } while(0)
#define IO_RB3_MIC_DOWN_SetAnalogMode()      do { ANSELBbits.ANSB3 = 1; } while(0)
#define IO_RB3_MIC_DOWN_SetDigitalMode()     do { ANSELBbits.ANSB3 = 0; } while(0)

// get/set RB4 i2c SCL
#define RB4_SetHigh()            do { LATBbits.LATB4 = 1; } while(0)
#define RB4_SetLow()             do { LATBbits.LATB4 = 0; } while(0)
#define RB4_Toggle()             do { LATBbits.LATB4 = ~LATBbits.LATB4; } while(0)
#define RB4_GetValue()              PORTBbits.RB4
#define RB4_SetDigitalInput()    do { TRISBbits.TRISB4 = 1; } while(0)
#define RB4_SetDigitalOutput()   do { TRISBbits.TRISB4 = 0; } while(0)
#define RB4_SetPullup()             do { WPUBbits.WPUB4 = 1; } while(0)
#define RB4_ResetPullup()           do { WPUBbits.WPUB4 = 0; } while(0)
#define RB4_SetAnalogMode()         do { ANSELBbits.ANSB4 = 1; } while(0)
#define RB4_SetDigitalMode()        do { ANSELBbits.ANSB4 = 0; } while(0)

// get/set IO_RB5_FPGA_CLK aliases
#define IO_RB5_FPGA_CLK_TRIS                 TRISBbits.TRISB5
#define IO_RB5_FPGA_CLK_LAT                  LATBbits.LATB5
#define IO_RB5_FPGA_CLK_PORT                 PORTBbits.RB5
#define IO_RB5_FPGA_CLK_WPU                  WPUBbits.WPUB5
#define IO_RB5_FPGA_CLK_ANS                  ANSELBbits.ANSB5
#define IO_RB5_FPGA_CLK_SetHigh()            do { LATBbits.LATB5 = 1; } while(0)
#define IO_RB5_FPGA_CLK_SetLow()             do { LATBbits.LATB5 = 0; } while(0)
#define IO_RB5_FPGA_CLK_Toggle()             do { LATBbits.LATB5 = ~LATBbits.LATB5; } while(0)
#define IO_RB5_FPGA_CLK_GetValue()           PORTBbits.RB5
#define IO_RB5_FPGA_CLK_SetDigitalInput()    do { TRISBbits.TRISB5 = 1; } while(0)
#define IO_RB5_FPGA_CLK_SetDigitalOutput()   do { TRISBbits.TRISB5 = 0; } while(0)
#define IO_RB5_FPGA_CLK_SetPullup()          do { WPUBbits.WPUB5 = 1; } while(0)
#define IO_RB5_FPGA_CLK_ResetPullup()        do { WPUBbits.WPUB5 = 0; } while(0)
#define IO_RB5_FPGA_CLK_SetAnalogMode()      do { ANSELBbits.ANSB5 = 1; } while(0)
#define IO_RB5_FPGA_CLK_SetDigitalMode()     do { ANSELBbits.ANSB5 = 0; } while(0)

// get/set IO_RB6_FPGA_MISO aliases
#define IO_RB6_FPGA_TX_TRIS                 TRISBbits.TRISB6
#define IO_RB6_FPGA_TX_LAT                  LATBbits.LATB6
#define IO_RB6_FPGA_TX_PORT                 PORTBbits.RB6
#define IO_RB6_FPGA_TX_WPU                  WPUBbits.WPUB6
#define IO_RB6_FPGA_TX_ANS                  ANSELBbits.ANSB6
#define IO_RB6_FPGA_TX_SetHigh()            do { LATBbits.LATB6 = 1; } while(0)
#define IO_RB6_FPGA_TX_SetLow()             do { LATBbits.LATB6 = 0; } while(0)
#define IO_RB6_FPGA_TX_Toggle()             do { LATBbits.LATB6 = ~LATBbits.LATB6; } while(0)
#define IO_RB6_FPGA_TX_GetValue()           PORTBbits.RB6
#define IO_RB6_FPGA_TX_SetDigitalInput()    do { TRISBbits.TRISB6 = 1; } while(0)
#define IO_RB6_FPGA_TX_SetDigitalOutput()   do { TRISBbits.TRISB6 = 0; } while(0)
#define IO_RB6_FPGA_TX_SetPullup()          do { WPUBbits.WPUB6 = 1; } while(0)
#define IO_RB6_FPGA_TX_ResetPullup()        do { WPUBbits.WPUB6 = 0; } while(0)
#define IO_RB6_FPGA_TX_SetAnalogMode()      do { ANSELBbits.ANSB6 = 1; } while(0)
#define IO_RB6_FPGA_TX_SetDigitalMode()     do { ANSELBbits.ANSB6 = 0; } while(0)

// get/set IO_RB7_FPGA_RX aliases
#define IO_RB7_FPGA_RX_TRIS                 TRISBbits.TRISB7
#define IO_RB7_FPGA_RX_LAT                  LATBbits.LATB7
#define IO_RB7_FPGA_RX_PORT                 PORTBbits.RB7
#define IO_RB7_FPGA_RX_WPU                  WPUBbits.WPUB7
#define IO_RB7_FPGA_RX_ANS                  ANSELBbits.ANSB7
#define IO_RB7_FPGA_RX_SetHigh()            do { LATBbits.LATB7 = 1; } while(0)
#define IO_RB7_FPGA_RX_SetLow()             do { LATBbits.LATB7 = 0; } while(0)
#define IO_RB7_FPGA_RX_Toggle()             do { LATBbits.LATB7 = ~LATBbits.LATB7; } while(0)
#define IO_RB7_FPGA_RX_GetValue()           PORTBbits.RB7
#define IO_RB7_FPGA_RX_SetDigitalInput()    do { TRISBbits.TRISB7 = 1; } while(0)
#define IO_RB7_FPGA_RX_SetDigitalOutput()   do { TRISBbits.TRISB7 = 0; } while(0)
#define IO_RB7_FPGA_RX_SetPullup()          do { WPUBbits.WPUB7 = 1; } while(0)
#define IO_RB7_FPGA_RX_ResetPullup()        do { WPUBbits.WPUB7 = 0; } while(0)
#define IO_RB7_FPGA_RX_SetAnalogMode()      do { ANSELBbits.ANSB7 = 1; } while(0)
#define IO_RB7_FPGA_RX_SetDigitalMode()     do { ANSELBbits.ANSB7 = 0; } while(0)

// Bit Operation macros
#define sbi(b,n) ((b) |=   (1<<(n)))        // Set bit number n in byte b
#define cbi(b,n) ((b) &= (~(1<<(n))))       // Clear bit number n in byte b
#define rbi(b,n) ((b) &    (1<<(n)))        // Read bit number n in byte b
#define fbi(b,n) ((b) ^=   (1<<(n)))        // Flip bit number n in byte b
#define bit_is_set(b,n)   (b & (1<<n))      // Test if bit number n in byte b is set
#define bit_is_clear(b,n) (!(b & (1<<n)))   // Test if bit number n in byte b is clear

// clear array
#define cla(a,l)       do { uint8_t i=0; do { a[i] = 0; i++; } while (i<=l); } while(0)

// functions
void mcu_init(void);

#ifdef	__cplusplus
}
#endif

#endif	/* _16F1827_H */

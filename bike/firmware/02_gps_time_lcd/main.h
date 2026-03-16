#ifndef __MAIN_H__
#define __MAIN_H__

#include <reg52.h>

typedef unsigned char u8;
typedef unsigned int u16;
typedef unsigned long u32;
typedef signed char s8;

#ifndef SYS_FOSC_HZ
#define SYS_FOSC_HZ 11059200UL
#endif

#ifndef GPS_BAUD
#define GPS_BAUD 9600UL
#endif

#ifndef GPS_TIMEZONE_OFFSET
#define GPS_TIMEZONE_OFFSET 8
#endif

#define LCD_DATA P0
sbit LCD_RW = P2^5;
sbit LCD_RS = P2^6;
sbit LCD_EN = P2^7;
sbit GPS_RX_PIN = P2^1;
sbit GPS_TX_PIN = P2^2;

#endif

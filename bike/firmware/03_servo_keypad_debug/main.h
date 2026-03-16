#ifndef __MAIN_H__
#define __MAIN_H__

#include <reg52.h>

typedef unsigned char u8;
typedef unsigned int u16;
typedef unsigned long u32;
typedef signed char s8;

#define LCD_DATA P0
sbit LCD_RW = P2^5;
sbit LCD_RS = P2^6;
sbit LCD_EN = P2^7;

sbit SERVO_PIN = P2^0;

#endif

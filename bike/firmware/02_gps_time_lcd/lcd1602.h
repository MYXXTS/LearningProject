#ifndef __LCD1602_H__
#define __LCD1602_H__

#include "main.h"

void LCD_Init(void);
void LCD_Clear(void);
void LCD_SetCursor(u8 col, u8 row);
void LCD_WriteChar(char ch);
void LCD_WriteString(u8 col, u8 row, char *s);
void LCD_WritePadded(u8 col, u8 row, char *s, u8 width);

#endif

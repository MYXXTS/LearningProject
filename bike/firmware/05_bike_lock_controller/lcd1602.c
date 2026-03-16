#include "lcd1602.h"
#include "delay.h"
#include <intrins.h>

static void lcd_enable_pulse(void)
{
    LCD_EN = 0;
    _nop_();
    LCD_EN = 1;
    _nop_();
    _nop_();
    LCD_EN = 0;
}

static void lcd_write_cmd(u8 cmd)
{
    LCD_RS = 0;
    LCD_RW = 0;
    LCD_DATA = cmd;
    lcd_enable_pulse();
    delay_ms(2);
}

static void lcd_write_data(u8 dat)
{
    LCD_RS = 1;
    LCD_RW = 0;
    LCD_DATA = dat;
    lcd_enable_pulse();
    delay_ms(2);
}

void LCD_Init(void)
{
    LCD_RS = 0;
    LCD_RW = 0;
    LCD_EN = 0;

    delay_ms(20);
    lcd_write_cmd(0x38);
    delay_ms(5);
    lcd_write_cmd(0x38);
    delay_ms(1);
    lcd_write_cmd(0x38);
    lcd_write_cmd(0x0C);
    lcd_write_cmd(0x06);
    lcd_write_cmd(0x01);
    delay_ms(5);
}

void LCD_Clear(void)
{
    lcd_write_cmd(0x01);
    delay_ms(5);
}

void LCD_SetCursor(u8 col, u8 row)
{
    if (row == 0) {
        lcd_write_cmd((u8)(0x80 + col));
    } else {
        lcd_write_cmd((u8)(0xC0 + col));
    }
}

void LCD_WriteChar(char ch)
{
    lcd_write_data((u8)ch);
}

void LCD_WriteString(u8 col, u8 row, char *s)
{
    LCD_SetCursor(col, row);
    while (*s) {
        lcd_write_data((u8)*s++);
    }
}

void LCD_WritePadded(u8 col, u8 row, char *s, u8 width)
{
    u8 used = 0;

    LCD_SetCursor(col, row);
    while (*s && used < width) {
        lcd_write_data((u8)*s++);
        used++;
    }

    while (used < width) {
        lcd_write_data(' ');
        used++;
    }
}

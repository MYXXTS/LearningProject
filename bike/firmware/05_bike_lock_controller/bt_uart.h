#ifndef __BT_UART_H__
#define __BT_UART_H__

#include "main.h"

void BT_Uart_Init(void);
bit BT_ReadFrame(char *out, u8 max_len, u8 *out_len);
void BT_SendByte(u8 dat);
void BT_SendText(char *text);

#endif

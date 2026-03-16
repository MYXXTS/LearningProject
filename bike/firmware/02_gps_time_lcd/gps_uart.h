#ifndef __GPS_UART_H__
#define __GPS_UART_H__

#include "main.h"

#define GPS_LINE_MAX 96

typedef struct {
    u16 year;
    u8 month;
    u8 day;
    u8 hour;
    u8 minute;
    u8 second;
    u8 has_date;
    u8 has_time;
    char source[4];
} gps_time_t;

void GPS_UART_Init(void);
bit GPS_ReadLine(char *out, u8 max_len);
void GPS_ClearTime(gps_time_t *time_data);
bit GPS_ApplySentence(char *line, gps_time_t *time_data);

#endif

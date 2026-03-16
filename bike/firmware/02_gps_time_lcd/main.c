#include "main.h"
#include "delay.h"
#include "lcd1602.h"
#include "gps_uart.h"

static gps_time_t xdata gps_time_state;
static char xdata gps_line[GPS_LINE_MAX];
static u8 wait_spinner = 0;

static char hex_digit(u8 value)
{
    value &= 0x0F;
    if (value < 10U) {
        return (char)('0' + value);
    }
    return (char)('A' + (value - 10U));
}

static void format_date(char *out, gps_time_t *time_data)
{
    if (!time_data->has_date) {
        out[0] = 'D';
        out[1] = 'A';
        out[2] = 'T';
        out[3] = 'E';
        out[4] = ' ';
        out[5] = 'U';
        out[6] = 'N';
        out[7] = 'K';
        out[8] = 'N';
        out[9] = 'O';
        out[10] = 'W';
        out[11] = 'N';
        out[12] = '\0';
        return;
    }

    out[0] = (char)('0' + (time_data->year / 1000U) % 10U);
    out[1] = (char)('0' + (time_data->year / 100U) % 10U);
    out[2] = (char)('0' + (time_data->year / 10U) % 10U);
    out[3] = (char)('0' + time_data->year % 10U);
    out[4] = '-';
    out[5] = (char)('0' + (time_data->month / 10U));
    out[6] = (char)('0' + (time_data->month % 10U));
    out[7] = '-';
    out[8] = (char)('0' + (time_data->day / 10U));
    out[9] = (char)('0' + (time_data->day % 10U));
    out[10] = '\0';
}

static void format_time_line(char *out, gps_time_t *time_data)
{
    out[0] = (char)('0' + (time_data->hour / 10U));
    out[1] = (char)('0' + (time_data->hour % 10U));
    out[2] = ':';
    out[3] = (char)('0' + (time_data->minute / 10U));
    out[4] = (char)('0' + (time_data->minute % 10U));
    out[5] = ':';
    out[6] = (char)('0' + (time_data->second / 10U));
    out[7] = (char)('0' + (time_data->second % 10U));
    out[8] = ' ';
    out[9] = time_data->source[0];
    out[10] = time_data->source[1];
    out[11] = time_data->source[2];
    out[12] = '+';
    out[13] = hex_digit((u8)GPS_TIMEZONE_OFFSET);
    out[14] = '\0';
}

static void show_wait_screen(void)
{
    static char spinner_text[5] = "|/-\\";
    char line2[17];

    LCD_WritePadded(0, 0, "WAIT ZDA/GGA", 16);

    line2[0] = 'U';
    line2[1] = 'A';
    line2[2] = 'R';
    line2[3] = 'T';
    line2[4] = ' ';
    line2[5] = '9';
    line2[6] = '6';
    line2[7] = '0';
    line2[8] = '0';
    line2[9] = ' ';
    line2[10] = 'P';
    line2[11] = '2';
    line2[12] = '.';
    line2[13] = '1';
    line2[14] = spinner_text[wait_spinner & 0x03U];
    line2[15] = '\0';

    LCD_WritePadded(0, 1, line2, 16);
    wait_spinner++;
}

static void show_time_screen(gps_time_t *time_data)
{
    char line1[17];
    char line2[17];

    format_date(line1, time_data);
    format_time_line(line2, time_data);

    LCD_WritePadded(0, 0, line1, 16);
    LCD_WritePadded(0, 1, line2, 16);
}

void main(void)
{
    bit have_time = 0;
    u16 idle_count = 0;

    delay_ms(100);
    LCD_Init();
    GPS_UART_Init();
    GPS_ClearTime(&gps_time_state);

    LCD_Clear();
    LCD_WritePadded(0, 0, "GPS TIME DEBUG", 16);
    LCD_WritePadded(0, 1, "INIT SOFT...", 16);
    delay_ms(800);
    show_wait_screen();

    while (1) {
        if (GPS_ReadLine(gps_line, sizeof(gps_line))) {
            if (GPS_ApplySentence(gps_line, &gps_time_state)) {
                have_time = gps_time_state.has_time;
                show_time_screen(&gps_time_state);
            }
            idle_count = 0;
        } else {
            idle_count++;
            if (!have_time && idle_count >= 60000U) {
                show_wait_screen();
                idle_count = 0;
            }
        }
    }
}

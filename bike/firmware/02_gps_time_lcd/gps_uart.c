#include "gps_uart.h"

#define GPS_SOFTUART_HALFBIT_TH 0xFF
#define GPS_SOFTUART_HALFBIT_TL 0xD0
#define GPS_SOFTUART_FULLBIT_TH 0xFF
#define GPS_SOFTUART_FULLBIT_TL 0xA0
#define GPS_SOFTUART_START_TIMEOUT 40000U

static char xdata gps_rx_line[GPS_LINE_MAX];
static char xdata gps_ready_line[GPS_LINE_MAX];
static u8 gps_rx_len = 0;
static bit gps_line_ready = 0;
static bit gps_overflow = 0;

static void gps_copy_line_to_ready(void);

static void gps_timer1_wait(u8 th_value, u8 tl_value)
{
    TR1 = 0;
    TF1 = 0;
    TH1 = th_value;
    TL1 = tl_value;
    TR1 = 1;
    while (!TF1) {
        ;
    }
    TR1 = 0;
    TF1 = 0;
}

static void gps_wait_half_bit(void)
{
    gps_timer1_wait(GPS_SOFTUART_HALFBIT_TH, GPS_SOFTUART_HALFBIT_TL);
}

static void gps_wait_full_bit(void)
{
    gps_timer1_wait(GPS_SOFTUART_FULLBIT_TH, GPS_SOFTUART_FULLBIT_TL);
}

static bit gps_receive_byte(u8 *out_byte, u16 timeout_loops)
{
    u8 i;
    u8 rx_value = 0;

    while (timeout_loops > 0U) {
        if (GPS_RX_PIN == 0) {
            gps_wait_half_bit();
            if (GPS_RX_PIN != 0) {
                timeout_loops--;
                continue;
            }

            for (i = 0; i < 8U; i++) {
                gps_wait_full_bit();
                if (GPS_RX_PIN) {
                    rx_value |= (u8)(1U << i);
                }
            }

            gps_wait_full_bit();
            *out_byte = rx_value;
            return 1;
        }

        timeout_loops--;
    }

    return 0;
}

static void gps_push_rx_byte(u8 rx_byte)
{
    if (rx_byte == '$') {
        gps_rx_len = 0;
        gps_overflow = 0;
    }

    if (!gps_overflow) {
        if (gps_rx_len < (GPS_LINE_MAX - 1U)) {
            gps_rx_line[gps_rx_len++] = (char)rx_byte;
            gps_rx_line[gps_rx_len] = '\0';
        } else {
            gps_overflow = 1;
        }
    }

    if (rx_byte == '\n') {
        if (!gps_overflow && gps_rx_len > 6U) {
            gps_copy_line_to_ready();
            gps_line_ready = 1;
        }
        gps_rx_len = 0;
        gps_overflow = 0;
    }
}

static void gps_copy_text(char *dst, const char *src, u8 max_len)
{
    u8 i = 0;

    if (max_len == 0) {
        return;
    }

    while (src[i] != '\0' && i < (u8)(max_len - 1)) {
        dst[i] = src[i];
        i++;
    }
    dst[i] = '\0';
}

static void gps_copy_line_to_ready(void)
{
    u8 i = 0;

    while (i < (GPS_LINE_MAX - 1) && gps_rx_line[i] != '\0') {
        gps_ready_line[i] = gps_rx_line[i];
        i++;
    }
    gps_ready_line[i] = '\0';
}

static bit gps_sentence_is(char *line, char c1, char c2, char c3)
{
    if (line[0] == '\0' ||
        line[1] == '\0' ||
        line[2] == '\0' ||
        line[3] == '\0' ||
        line[4] == '\0' ||
        line[5] == '\0') {
        return 0;
    }

    return (line[0] == '$' &&
            line[3] == c1 &&
            line[4] == c2 &&
            line[5] == c3);
}

static bit gps_get_field(char *line, u8 field_index, char *out, u8 max_len)
{
    char *p = line;
    u8 current = 0;
    u8 i = 0;

    if (max_len == 0) {
        return 0;
    }

    if (*p == '$') {
        p++;
    }

    while (1) {
        if (current == field_index) {
            while (*p != '\0' &&
                   *p != ',' &&
                   *p != '*' &&
                   *p != '\r' &&
                   *p != '\n' &&
                   i < (u8)(max_len - 1)) {
                out[i++] = *p++;
            }
            out[i] = '\0';
            return (i > 0);
        }

        while (*p != '\0' &&
               *p != ',' &&
               *p != '*' &&
               *p != '\r' &&
               *p != '\n') {
            p++;
        }

        if (*p != ',') {
            break;
        }

        p++;
        current++;
    }

    out[0] = '\0';
    return 0;
}

static u8 gps_is_digit(char ch)
{
    return (ch >= '0' && ch <= '9');
}

static u8 gps_parse_u8_2(char *text, u8 *value)
{
    if (!gps_is_digit(text[0]) || !gps_is_digit(text[1])) {
        return 0;
    }

    *value = (u8)((text[0] - '0') * 10 + (text[1] - '0'));
    return 1;
}

static u8 gps_parse_u16_4(char *text, u16 *value)
{
    u16 v = 0;
    u8 i;

    for (i = 0; i < 4; i++) {
        if (!gps_is_digit(text[i])) {
            return 0;
        }
        v = (u16)(v * 10 + (u16)(text[i] - '0'));
    }

    *value = v;
    return 1;
}

static u8 gps_parse_time_field(char *text, gps_time_t *time_data)
{
    if (!gps_is_digit(text[0]) ||
        !gps_is_digit(text[1]) ||
        !gps_is_digit(text[2]) ||
        !gps_is_digit(text[3]) ||
        !gps_is_digit(text[4]) ||
        !gps_is_digit(text[5])) {
        return 0;
    }

    time_data->hour = (u8)((text[0] - '0') * 10 + (text[1] - '0'));
    time_data->minute = (u8)((text[2] - '0') * 10 + (text[3] - '0'));
    time_data->second = (u8)((text[4] - '0') * 10 + (text[5] - '0'));
    time_data->has_time = 1;
    return 1;
}

static bit gps_is_leap_year(u16 year)
{
    return (((year % 4U) == 0U) && ((year % 100U) != 0U)) || ((year % 400U) == 0U);
}

static u8 gps_days_in_month(u8 month, u16 year)
{
    switch (month) {
        case 1:
        case 3:
        case 5:
        case 7:
        case 8:
        case 10:
        case 12:
            return 31;

        case 4:
        case 6:
        case 9:
        case 11:
            return 30;

        case 2:
            return gps_is_leap_year(year) ? 29 : 28;

        default:
            return 31;
    }
}

static void gps_increment_day(gps_time_t *time_data)
{
    u8 max_day;

    if (!time_data->has_date) {
        return;
    }

    max_day = gps_days_in_month(time_data->month, time_data->year);
    time_data->day++;

    if (time_data->day > max_day) {
        time_data->day = 1;
        time_data->month++;
        if (time_data->month > 12) {
            time_data->month = 1;
            time_data->year++;
        }
    }
}

static void gps_decrement_day(gps_time_t *time_data)
{
    if (!time_data->has_date) {
        return;
    }

    if (time_data->day > 1) {
        time_data->day--;
        return;
    }

    if (time_data->month > 1) {
        time_data->month--;
    } else {
        time_data->month = 12;
        time_data->year--;
    }

    time_data->day = gps_days_in_month(time_data->month, time_data->year);
}

static void gps_apply_timezone(gps_time_t *time_data, s8 offset_hours)
{
    int hour_value;

    if (!time_data->has_time) {
        return;
    }

    hour_value = (int)time_data->hour + (int)offset_hours;

    while (hour_value >= 24) {
        hour_value -= 24;
        gps_increment_day(time_data);
    }

    while (hour_value < 0) {
        hour_value += 24;
        gps_decrement_day(time_data);
    }

    time_data->hour = (u8)hour_value;
}

void GPS_UART_Init(void)
{
    TMOD = (TMOD & 0x0F) | 0x10;
    TR1 = 0;
    TF1 = 0;
    TH1 = GPS_SOFTUART_FULLBIT_TH;
    TL1 = GPS_SOFTUART_FULLBIT_TL;
    GPS_TX_PIN = 1;

    gps_rx_len = 0;
    gps_line_ready = 0;
    gps_overflow = 0;
    gps_rx_line[0] = '\0';
    gps_ready_line[0] = '\0';
}

bit GPS_ReadLine(char *out, u8 max_len)
{
    u8 rx_byte;
    bit has_line;

    if (max_len == 0) {
        return 0;
    }

    has_line = gps_line_ready;
    if (has_line) {
        gps_copy_text(out, gps_ready_line, max_len);
        gps_line_ready = 0;
        return 1;
    }

    while (!gps_line_ready) {
        if (!gps_receive_byte(&rx_byte, GPS_SOFTUART_START_TIMEOUT)) {
            out[0] = '\0';
            return 0;
        }
        gps_push_rx_byte(rx_byte);
    }

    gps_copy_text(out, gps_ready_line, max_len);
    gps_line_ready = 0;
    return 1;
}

void GPS_ClearTime(gps_time_t *time_data)
{
    time_data->year = 0;
    time_data->month = 0;
    time_data->day = 0;
    time_data->hour = 0;
    time_data->minute = 0;
    time_data->second = 0;
    time_data->has_date = 0;
    time_data->has_time = 0;
    time_data->source[0] = '-';
    time_data->source[1] = '-';
    time_data->source[2] = '-';
    time_data->source[3] = '\0';
}

bit GPS_ApplySentence(char *line, gps_time_t *time_data)
{
    char field[16];
    gps_time_t temp;
    u8 day;
    u8 month;
    u16 year;

    if (gps_sentence_is(line, 'Z', 'D', 'A')) {
        GPS_ClearTime(&temp);

        if (!gps_get_field(line, 1, field, sizeof(field))) {
            return 0;
        }
        if (!gps_parse_time_field(field, &temp)) {
            return 0;
        }

        if (!gps_get_field(line, 2, field, sizeof(field)) || !gps_parse_u8_2(field, &day)) {
            return 0;
        }
        if (!gps_get_field(line, 3, field, sizeof(field)) || !gps_parse_u8_2(field, &month)) {
            return 0;
        }
        if (!gps_get_field(line, 4, field, sizeof(field)) || !gps_parse_u16_4(field, &year)) {
            return 0;
        }

        temp.day = day;
        temp.month = month;
        temp.year = year;
        temp.has_date = 1;
        temp.source[0] = 'Z';
        temp.source[1] = 'D';
        temp.source[2] = 'A';
        temp.source[3] = '\0';
        gps_apply_timezone(&temp, (s8)GPS_TIMEZONE_OFFSET);

        time_data->year = temp.year;
        time_data->month = temp.month;
        time_data->day = temp.day;
        time_data->hour = temp.hour;
        time_data->minute = temp.minute;
        time_data->second = temp.second;
        time_data->has_date = temp.has_date;
        time_data->has_time = temp.has_time;
        gps_copy_text(time_data->source, temp.source, sizeof(time_data->source));
        return 1;
    }

    if (gps_sentence_is(line, 'G', 'G', 'A')) {
        GPS_ClearTime(&temp);

        if (!gps_get_field(line, 1, field, sizeof(field))) {
            return 0;
        }
        if (!gps_parse_time_field(field, &temp)) {
            return 0;
        }

        temp.source[0] = 'G';
        temp.source[1] = 'G';
        temp.source[2] = 'A';
        temp.source[3] = '\0';
        gps_apply_timezone(&temp, (s8)GPS_TIMEZONE_OFFSET);

        time_data->hour = temp.hour;
        time_data->minute = temp.minute;
        time_data->second = temp.second;
        time_data->has_time = 1;
        gps_copy_text(time_data->source, temp.source, sizeof(time_data->source));
        return 1;
    }

    return 0;
}

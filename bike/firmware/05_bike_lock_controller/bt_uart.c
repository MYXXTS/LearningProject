#include "bt_uart.h"

static char xdata bt_rx_line[BT_FRAME_MAX];
static char xdata bt_ready_line[BT_FRAME_MAX];
static volatile u8 bt_rx_len = 0;
static volatile bit bt_line_ready = 0;
static volatile bit bt_overflow = 0;

static char bt_upper_char(char ch)
{
    if (ch >= 'a' && ch <= 'z') {
        return (char)(ch - ('a' - 'A'));
    }
    return ch;
}

static void bt_reset_rx(void)
{
    bt_rx_len = 0;
    bt_overflow = 0;
    bt_rx_line[0] = '\0';
}

static void bt_publish_rx(void)
{
    u8 i;

    if (bt_overflow || bt_rx_len == 0U) {
        bt_reset_rx();
        return;
    }

    for (i = 0; i < bt_rx_len; i++) {
        bt_ready_line[i] = bt_rx_line[i];
    }
    bt_ready_line[bt_rx_len] = '\0';
    bt_line_ready = 1;
    bt_reset_rx();
}

static void bt_copy_ready_line(char *out, u8 max_len)
{
    u8 i = 0;

    if (max_len == 0U) {
        return;
    }

    while (i < (u8)(max_len - 1U) && bt_ready_line[i] != '\0') {
        out[i] = bt_ready_line[i];
        i++;
    }
    out[i] = '\0';
}

void BT_Uart_Init(void)
{
    PCON = 0x00;
    SCON = 0x50;
    TMOD = (TMOD & 0x0F) | 0x20;
    TH1 = 0xFD;
    TL1 = 0xFD;
    TR1 = 1;
    TI = 0;
    RI = 0;
    ES = 1;

    bt_reset_rx();
    bt_ready_line[0] = '\0';
    bt_line_ready = 0;

    EA = 1;
}

bit BT_ReadFrame(char *out, u8 max_len, u8 *out_len)
{
    bit has_frame;
    u8 i = 0;

    if (max_len == 0U) {
        return 0;
    }

    EA = 0;
    has_frame = bt_line_ready;
    if (has_frame) {
        bt_copy_ready_line(out, max_len);
        while (i < (u8)(max_len - 1U) && out[i] != '\0') {
            i++;
        }
        bt_line_ready = 0;
    }
    EA = 1;

    if (!has_frame) {
        out[0] = '\0';
        i = 0;
    }

    if (out_len != 0) {
        *out_len = i;
    }

    return has_frame;
}

void BT_SendByte(u8 dat)
{
    bit es_backup;

    es_backup = ES;
    ES = 0;
    TI = 0;
    SBUF = dat;
    while (!TI) {
        ;
    }
    TI = 0;
    ES = es_backup;
}

void BT_SendText(char *text)
{
    while (*text != '\0') {
        BT_SendByte((u8)*text++);
    }
}

static bit bt_is_immediate_frame(void)
{
    char c0;

    if (bt_rx_len == 1U) {
        c0 = bt_upper_char(bt_rx_line[0]);
        return (c0 == 'U' || c0 == 'L' || c0 == 'S');
    }

    if (bt_rx_len == 3U) {
        c0 = bt_upper_char(bt_rx_line[0]);
        return (c0 == 'P' &&
                bt_rx_line[1] == ',' &&
                bt_rx_line[2] >= '0' &&
                bt_rx_line[2] <= '9');
    }

    return 0;
}

void BT_Uart_ISR(void) interrupt 4
{
    char rx;

    if (TI) {
        TI = 0;
    }

    if (!RI) {
        return;
    }

    RI = 0;
    rx = (char)SBUF;

    if (bt_line_ready) {
        return;
    }

    if (rx == '\r' || rx == '\n') {
        bt_publish_rx();
        return;
    }

    if (bt_overflow) {
        return;
    }

    if (bt_rx_len < (BT_FRAME_MAX - 1U)) {
        bt_rx_line[bt_rx_len++] = rx;
        bt_rx_line[bt_rx_len] = '\0';
        if (bt_is_immediate_frame()) {
            bt_publish_rx();
        }
    } else {
        bt_overflow = 1;
    }
}

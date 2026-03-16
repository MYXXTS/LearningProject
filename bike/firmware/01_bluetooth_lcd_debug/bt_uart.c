#include "bt_uart.h"

#define BT_T0_1MS_TH 0xFC
#define BT_T0_1MS_TL 0x66
#define BT_FRAME_IDLE_MS 30U

static volatile u16 bt_ms_tick = 0;
static volatile u16 bt_last_rx_ms = 0;
static volatile bit bt_frame_ready = 0;
static volatile u8 bt_rx_len = 0;
static char xdata bt_rx_buffer[BT_FRAME_MAX];

static void bt_timer0_reload(void)
{
    TH0 = BT_T0_1MS_TH;
    TL0 = BT_T0_1MS_TL;
}

static bit bt_is_printable(u8 ch)
{
    return (ch >= 0x20U && ch <= 0x7EU);
}

static void bt_reset_frame(void)
{
    bt_rx_len = 0;
    bt_frame_ready = 0;
    bt_rx_buffer[0] = '\0';
}

void BT_Uart_Init(void)
{
    TMOD = 0x21;
    PCON = 0x00;

    SCON = 0x50;
    TH1 = 0xFD;
    TL1 = 0xFD;
    TR1 = 1;
    TI = 0;
    RI = 0;
    ES = 1;

    bt_timer0_reload();
    TF0 = 0;
    ET0 = 1;
    TR0 = 1;

    bt_ms_tick = 0;
    bt_last_rx_ms = 0;
    bt_reset_frame();

    EA = 1;
}

bit BT_ReadFrame(char *out, u8 max_len, u8 *out_len)
{
    u8 i;
    u8 copy_len;
    u16 now_ms;
    bit ready = 0;

    if (max_len == 0) {
        return 0;
    }

    out[0] = '\0';
    if (out_len != 0) {
        *out_len = 0;
    }

    EA = 0;
    now_ms = bt_ms_tick;
    if (bt_frame_ready) {
        ready = 1;
    } else if (bt_rx_len > 0U &&
               (u16)(now_ms - bt_last_rx_ms) >= BT_FRAME_IDLE_MS) {
        ready = 1;
    }

    if (!ready) {
        EA = 1;
        return 0;
    }

    copy_len = bt_rx_len;
    if (copy_len >= max_len) {
        copy_len = (u8)(max_len - 1U);
    }

    for (i = 0; i < copy_len; i++) {
        out[i] = bt_rx_buffer[i];
    }
    out[copy_len] = '\0';

    if (out_len != 0) {
        *out_len = copy_len;
    }

    bt_reset_frame();
    EA = 1;
    return 1;
}

void BT_Timer0_ISR(void) interrupt 1
{
    bt_timer0_reload();
    bt_ms_tick++;
}

void BT_Uart_ISR(void) interrupt 4
{
    u8 rx_byte;

    if (TI) {
        TI = 0;
    }

    if (!RI) {
        return;
    }

    RI = 0;
    rx_byte = SBUF;
    bt_last_rx_ms = bt_ms_tick;

    if (rx_byte == '\n') {
        bt_frame_ready = 1;
        return;
    }

    if (rx_byte == '\r') {
        return;
    }

    if (!bt_is_printable(rx_byte)) {
        return;
    }

    if (bt_rx_len < (BT_FRAME_MAX - 1U)) {
        bt_rx_buffer[bt_rx_len++] = (char)rx_byte;
        bt_rx_buffer[bt_rx_len] = '\0';
    } else {
        bt_frame_ready = 1;
    }
}

#include "main.h"
#include "delay.h"
#include "lcd1602.h"
#include "bt_uart.h"

static char xdata bt_text[BT_FRAME_MAX];
static char xdata scroll_line[17];
static u8 bt_text_len = 0;
static u8 scroll_offset = 0;
static u16 scroll_divider = 0;
static bit have_frame = 0;

static void fill_spaces(char *text, u8 width)
{
    u8 i;

    for (i = 0; i < width; i++) {
        text[i] = ' ';
    }
    text[width] = '\0';
}

static void build_status_line(char *line, u8 len_value)
{
    fill_spaces(line, 16);
    line[0] = 'B';
    line[1] = 'T';
    line[2] = ' ';
    line[3] = 'L';
    line[4] = 'E';
    line[5] = 'N';
    line[6] = '=';
    line[7] = (char)('0' + (len_value / 10U));
    line[8] = (char)('0' + (len_value % 10U));
    line[10] = 'A';
    line[11] = 'S';
    line[12] = 'C';
    line[13] = 'I';
    line[14] = 'I';
}

static void build_scroll_line(char *line)
{
    u8 i;
    u8 virtual_len;
    u8 index;

    fill_spaces(line, 16);

    if (!have_frame || bt_text_len == 0) {
        line[0] = 'N';
        line[1] = 'O';
        line[2] = ' ';
        line[3] = 'D';
        line[4] = 'A';
        line[5] = 'T';
        line[6] = 'A';
        return;
    }

    if (bt_text_len <= 16U) {
        for (i = 0; i < bt_text_len; i++) {
            line[i] = bt_text[i];
        }
        return;
    }

    virtual_len = (u8)(bt_text_len + 3U);
    for (i = 0; i < 16U; i++) {
        index = (u8)(scroll_offset + i);
        while (index >= virtual_len) {
            index = (u8)(index - virtual_len);
        }

        if (index < bt_text_len) {
            line[i] = bt_text[index];
        } else {
            line[i] = ' ';
        }
    }
}

static void show_wait_screen(void)
{
    LCD_WritePadded(0, 0, "BT WAITING", 16);
    LCD_WritePadded(0, 1, "HC-06 ASCII RX", 16);
}

static void show_text_screen(void)
{
    char line1[17];

    build_status_line(line1, bt_text_len);
    build_scroll_line(scroll_line);
    LCD_WritePadded(0, 0, line1, 16);
    LCD_WritePadded(0, 1, scroll_line, 16);
}

void main(void)
{
    delay_ms(100);
    LCD_Init();
    BT_Uart_Init();

    LCD_Clear();
    LCD_WritePadded(0, 0, "BT LCD DEBUG", 16);
    LCD_WritePadded(0, 1, "INIT UART...", 16);
    delay_ms(800);
    show_wait_screen();

    while (1) {
        if (BT_ReadFrame(bt_text, sizeof(bt_text), &bt_text_len)) {
            have_frame = 1;
            scroll_offset = 0;
            scroll_divider = 0;
            show_text_screen();
            continue;
        }

        if (!have_frame) {
            continue;
        }

        if (bt_text_len > 16U) {
            scroll_divider++;
            if (scroll_divider >= 20000U) {
                scroll_divider = 0;
                scroll_offset++;
                if (scroll_offset >= (u8)(bt_text_len + 3U)) {
                    scroll_offset = 0;
                }
                show_text_screen();
            }
        }
    }
}

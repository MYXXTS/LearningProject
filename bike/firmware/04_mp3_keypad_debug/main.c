#include "main.h"
#include "delay.h"
#include "lcd1602.h"
#include "keypad.h"
#include "mp3_uart.h"

static void show_action(char *text)
{
    LCD_WritePadded(0, 0, "MP3 DEBUG", 16);
    LCD_WritePadded(0, 1, text, 16);
}

static void show_track_action(char *prefix, u8 track_no)
{
    char line2[17];

    line2[0] = prefix[0];
    line2[1] = prefix[1];
    line2[2] = prefix[2];
    line2[3] = prefix[3];
    line2[4] = ' ';
    line2[5] = '0';
    line2[6] = '0';
    line2[7] = '0';
    line2[8] = '\0';

    line2[5] = (char)('0' + (track_no / 100U));
    line2[6] = (char)('0' + ((track_no / 10U) % 10U));
    line2[7] = (char)('0' + (track_no % 10U));

    LCD_WritePadded(0, 0, "MP3 DEBUG", 16);
    LCD_WritePadded(0, 1, line2, 16);
}

void main(void)
{
    u8 key_value;

    delay_ms(100);
    LCD_Init();
    LCD_Clear();
    LCD_WritePadded(0, 0, "MP3 DEBUG", 16);
    LCD_WritePadded(0, 1, "INIT TF CARD...", 16);
    MP3_Init();
    delay_ms(200);
    show_action("READY");

    while (1) {
        key_value = Keypad_Scan();

        if (key_value == KEY_S1) {
            MP3_Play();
            show_action("PLAY");
        } else if (key_value == KEY_S2) {
            MP3_Pause();
            show_action("PAUSE");
        } else if (key_value == KEY_S3) {
            MP3_Prev();
            show_action("PREV");
        } else if (key_value == KEY_S4) {
            MP3_Next();
            show_action("NEXT");
        } else if (key_value == KEY_S5) {
            MP3_PlayTrack(1U);
            show_track_action("PLAY", 1U);
        } else if (key_value == KEY_S6) {
            MP3_PlayTrack(2U);
            show_track_action("PLAY", 2U);
        } else if (key_value == KEY_S7) {
            MP3_PlayTrack(3U);
            show_track_action("PLAY", 3U);
        } else if (key_value == KEY_S8) {
            MP3_PlayTrack(4U);
            show_track_action("PLAY", 4U);
        } else if (key_value == KEY_S9) {
            MP3_PlayTrack(5U);
            show_track_action("PLAY", 5U);
        }
    }
}

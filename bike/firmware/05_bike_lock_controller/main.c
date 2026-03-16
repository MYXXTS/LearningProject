#include "main.h"
#include "delay.h"
#include "lcd1602.h"
#include "bt_uart.h"
#include "servo.h"
#include "mp3_uart.h"

typedef enum {
    BIKE_STATE_LOCKED = 0,
    BIKE_STATE_UNLOCKED = 1
} bike_state_t;

static bike_state_t bike_state = BIKE_STATE_LOCKED;
static bit bike_busy = 0;
static char xdata rx_frame[BT_FRAME_MAX];
static char xdata last_action[17];

static char upper_char(char ch)
{
    if (ch >= 'a' && ch <= 'z') {
        return (char)(ch - ('a' - 'A'));
    }
    return ch;
}

static void text_copy_16(char *dst, char *src)
{
    u8 i = 0;

    while (i < 16U && src[i] != '\0') {
        dst[i] = src[i];
        i++;
    }

    while (i < 16U) {
        dst[i] = ' ';
        i++;
    }
    dst[16] = '\0';
}

static bit text_equals(char *left, char *right)
{
    while (*left != '\0' && *right != '\0') {
        if (upper_char(*left) != upper_char(*right)) {
            return 0;
        }
        left++;
        right++;
    }

    return (*left == '\0' && *right == '\0');
}

static void set_last_action(char *text)
{
    text_copy_16(last_action, text);
}

static void refresh_lcd(void)
{
    if (bike_busy) {
        LCD_WritePadded(0, 0, "STATE: BUSY", 16);
    } else if (bike_state == BIKE_STATE_LOCKED) {
        LCD_WritePadded(0, 0, "STATE: LOCKED", 16);
    } else {
        LCD_WritePadded(0, 0, "STATE: RIDING", 16);
    }

    LCD_WritePadded(0, 1, last_action, 16);
}

static void send_status_response(void)
{
    if (bike_state == BIKE_STATE_LOCKED) {
        BT_SendText("S,0\n");
        set_last_action("LAST: S 0");
    } else {
        BT_SendText("S,1\n");
        set_last_action("LAST: S 1");
    }
    refresh_lcd();
}

static void send_busy_response(char cmd)
{
    if (cmd == 'U') {
        BT_SendText("U,BUSY\n");
        set_last_action("LAST: U BUSY");
    } else if (cmd == 'L') {
        BT_SendText("L,BUSY\n");
        set_last_action("LAST: L BUSY");
    } else if (cmd == 'P') {
        BT_SendText("P,BUSY\n");
        set_last_action("LAST: P BUSY");
    }
    refresh_lcd();
}

static bit parse_play_track(char *line, u8 *track_no)
{
    if (upper_char(line[0]) != 'P' || line[1] != ',') {
        return 0;
    }

    if (line[2] < '0' || line[2] > '9' || line[3] != '\0') {
        return 0;
    }

    *track_no = (u8)(line[2] - '0');
    return 1;
}

static void service_busy_input(void)
{
    u8 rx_len;
    u8 busy_track;

    if (!BT_ReadFrame(rx_frame, sizeof(rx_frame), &rx_len)) {
        return;
    }

    if (text_equals(rx_frame, "S")) {
        send_status_response();
        return;
    }

    if (text_equals(rx_frame, "U")) {
        send_busy_response('U');
        return;
    }

    if (text_equals(rx_frame, "L")) {
        send_busy_response('L');
        return;
    }

    if (parse_play_track(rx_frame, &busy_track)) {
        send_busy_response('P');
        return;
    }
}

static void busy_wait_ms(u16 total_ms)
{
    u16 elapsed = 0;

    while (elapsed < total_ms) {
        delay_ms(10);
        elapsed += 10U;
        service_busy_input();
    }
}

static void handle_unlock(void)
{
    if (bike_state == BIKE_STATE_UNLOCKED) {
        MP3_PlayTrack(2U);
        BT_SendText("U,ALREADY\n");
        set_last_action("LAST: U ALREADY");
        refresh_lcd();
        return;
    }

    bike_busy = 1;
    set_last_action("LAST: U RUN");
    refresh_lcd();

    Servo_SetLevel(SERVO_UNLOCK_LEVEL);
    MP3_PlayTrack(1U);
    busy_wait_ms(800U);

    bike_state = BIKE_STATE_UNLOCKED;
    bike_busy = 0;
    BT_SendText("U,OK\n");
    set_last_action("LAST: U OK");
    refresh_lcd();
}

static void handle_lock(void)
{
    if (bike_state == BIKE_STATE_LOCKED) {
        MP3_PlayTrack(4U);
        BT_SendText("L,ALREADY\n");
        set_last_action("LAST: L ALREADY");
        refresh_lcd();
        return;
    }

    bike_busy = 1;
    set_last_action("LAST: L RUN");
    refresh_lcd();

    Servo_SetLevel(SERVO_LOCK_LEVEL);
    MP3_PlayTrack(3U);
    busy_wait_ms(800U);

    bike_state = BIKE_STATE_LOCKED;
    bike_busy = 0;
    BT_SendText("L,OK\n");
    set_last_action("LAST: L OK");
    refresh_lcd();
}

static void handle_play_track(void)
{
    u8 track_no;

    if (!parse_play_track(rx_frame, &track_no)) {
        BT_SendText("P,BAD\n");
        set_last_action("LAST: P BAD");
        refresh_lcd();
        return;
    }

    if (bike_busy) {
        send_busy_response('P');
        return;
    }

    if (track_no < 1U || track_no > 5U) {
        BT_SendText("P,BAD\n");
        set_last_action("LAST: P BAD");
        refresh_lcd();
        return;
    }

    if (track_no == 1U) {
        set_last_action("LAST: P1");
    } else if (track_no == 2U) {
        set_last_action("LAST: P2");
    } else if (track_no == 3U) {
        set_last_action("LAST: P3");
    } else if (track_no == 4U) {
        set_last_action("LAST: P4");
    } else {
        set_last_action("LAST: P5");
    }

    refresh_lcd();
    MP3_PlayTrack((u16)track_no);
    BT_SendText("P,OK\n");
}

static void send_bad_command_response(void)
{
    BT_SendText("E,BAD\n");
    set_last_action("LAST: BAD CMD");
    refresh_lcd();
}

static void handle_frame(void)
{
    u8 rx_len = 0;

    if (!BT_ReadFrame(rx_frame, sizeof(rx_frame), &rx_len)) {
        return;
    }

    if (rx_len == 0U) {
        return;
    }

    if (text_equals(rx_frame, "S")) {
        send_status_response();
        return;
    }

    if (text_equals(rx_frame, "U")) {
        if (bike_busy) {
            send_busy_response('U');
        } else {
            handle_unlock();
        }
        return;
    }

    if (text_equals(rx_frame, "L")) {
        if (bike_busy) {
            send_busy_response('L');
        } else {
            handle_lock();
        }
        return;
    }

    if (rx_frame[0] == 'P') {
        handle_play_track();
        return;
    }

    if (upper_char(rx_frame[0]) == 'P') {
        handle_play_track();
        return;
    }

    send_bad_command_response();
}

void main(void)
{
    delay_ms(100);
    LCD_Init();
    Servo_Init();
    BT_Uart_Init();
    MP3_Init();

    Servo_SetLevel(SERVO_LOCK_LEVEL);
    bike_state = BIKE_STATE_LOCKED;
    bike_busy = 0;

    LCD_Clear();
    LCD_WritePadded(0, 0, "BIKE LOCK INIT", 16);
    LCD_WritePadded(0, 1, "BT+SERVO+MP3", 16);
    delay_ms(1000);

    set_last_action("LAST: READY");
    refresh_lcd();

    while (1) {
        handle_frame();
    }
}

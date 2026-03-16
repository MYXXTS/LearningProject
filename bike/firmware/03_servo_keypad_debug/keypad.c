#include "keypad.h"
#include "delay.h"

static u8 keypad_read_raw(void)
{
    u8 row_state;
    u8 key_value = KEY_NONE;

    P1 = 0xF7;
    delay_ms(1);
    row_state = P1 & 0xF0;
    if ((row_state & 0x80U) == 0U) key_value = KEY_S1;
    else if ((row_state & 0x40U) == 0U) key_value = KEY_S5;
    else if ((row_state & 0x20U) == 0U) key_value = KEY_S9;
    else if ((row_state & 0x10U) == 0U) key_value = KEY_S13;
    if (key_value != KEY_NONE) {
        P1 = 0xFF;
        return key_value;
    }

    P1 = 0xFB;
    delay_ms(1);
    row_state = P1 & 0xF0;
    if ((row_state & 0x80U) == 0U) key_value = KEY_S2;
    else if ((row_state & 0x40U) == 0U) key_value = KEY_S6;
    else if ((row_state & 0x20U) == 0U) key_value = KEY_S10;
    else if ((row_state & 0x10U) == 0U) key_value = KEY_S14;
    if (key_value != KEY_NONE) {
        P1 = 0xFF;
        return key_value;
    }

    P1 = 0xFD;
    delay_ms(1);
    row_state = P1 & 0xF0;
    if ((row_state & 0x80U) == 0U) key_value = KEY_S3;
    else if ((row_state & 0x40U) == 0U) key_value = KEY_S7;
    else if ((row_state & 0x20U) == 0U) key_value = KEY_S11;
    else if ((row_state & 0x10U) == 0U) key_value = KEY_S15;
    if (key_value != KEY_NONE) {
        P1 = 0xFF;
        return key_value;
    }

    P1 = 0xFE;
    delay_ms(1);
    row_state = P1 & 0xF0;
    if ((row_state & 0x80U) == 0U) key_value = KEY_S4;
    else if ((row_state & 0x40U) == 0U) key_value = KEY_S8;
    else if ((row_state & 0x20U) == 0U) key_value = KEY_S12;
    else if ((row_state & 0x10U) == 0U) key_value = KEY_S16;

    P1 = 0xFF;
    return key_value;
}

u8 Keypad_Scan(void)
{
    static bit key_locked = 0;
    u8 key_value;

    if (key_locked) {
        if (keypad_read_raw() == KEY_NONE) {
            key_locked = 0;
        }
        return KEY_NONE;
    }

    key_value = keypad_read_raw();
    if (key_value == KEY_NONE) {
        return KEY_NONE;
    }

    delay_ms(20);
    if (key_value == keypad_read_raw()) {
        key_locked = 1;
        return key_value;
    }

    return KEY_NONE;
}

#include "main.h"
#include "delay.h"
#include "lcd1602.h"
#include "keypad.h"
#include "servo.h"

static void show_angle(u8 angle)
{
    char line2[17];

    line2[0] = 'A';
    line2[1] = 'N';
    line2[2] = 'G';
    line2[3] = 'L';
    line2[4] = 'E';
    line2[5] = '=';
    line2[6] = (char)('0' + (angle / 100U));
    line2[7] = (char)('0' + ((angle / 10U) % 10U));
    line2[8] = (char)('0' + (angle % 10U));
    line2[9] = ' ';
    line2[10] = 'D';
    line2[11] = 'E';
    line2[12] = 'G';
    line2[13] = '\0';

    LCD_WritePadded(0, 0, "SERVO DEBUG", 16);
    LCD_WritePadded(0, 1, line2, 16);
}

void main(void)
{
    u8 servo_level = SERVO_CENTER_LEVEL;
    u8 angle = Servo_LevelToDegrees(SERVO_CENTER_LEVEL);
    u8 key_value;

    delay_ms(100);
    LCD_Init();
    Servo_Init();
    Servo_SetLevel(servo_level);

    LCD_Clear();
    LCD_WritePadded(0, 0, "S1- S6+ S11C", 16);
    LCD_WritePadded(0, 1, "SERVO INIT...", 16);
    delay_ms(800);
    show_angle(angle);

    while (1) {
        key_value = Keypad_Scan();

        if (key_value == KEY_S1) {
            if (servo_level > SERVO_LEVEL_MIN) {
                servo_level--;
            }
        } else if (key_value == KEY_S6) {
            if (servo_level < SERVO_LEVEL_MAX) {
                servo_level++;
            }
        } else if (key_value == KEY_S11) {
            servo_level = SERVO_CENTER_LEVEL;
        } else {
            continue;
        }

        Servo_SetLevel(servo_level);
        angle = Servo_LevelToDegrees(servo_level);
        show_angle(angle);
    }
}

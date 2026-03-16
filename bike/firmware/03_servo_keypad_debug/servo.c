#include "servo.h"

#define SERVO_T0_100US_TH 0xFF
#define SERVO_T0_100US_TL 0xA4

static u8 servo_level = SERVO_CENTER_LEVEL;
static u16 servo_tick_index = 0;

u8 Servo_LevelToDegrees(u8 level)
{
    u16 degrees;

    if (level <= SERVO_LEVEL_MIN) {
        return 0U;
    }

    if (level >= SERVO_LEVEL_MAX) {
        return 177U;
    }

    degrees = ((u16)(level - SERVO_LEVEL_MIN) * 100U + 4U) / 9U;
    return (u8)degrees;
}

void Servo_Init(void)
{
    SERVO_PIN = 0;
    servo_tick_index = 0;
    servo_level = SERVO_CENTER_LEVEL;

    TMOD = (TMOD & 0xF0) | 0x01;
    TH0 = SERVO_T0_100US_TH;
    TL0 = SERVO_T0_100US_TL;
    TF0 = 0;
    ET0 = 1;
    EA = 1;
    TR0 = 1;
}

void Servo_SetLevel(u8 level)
{
    if (level < SERVO_LEVEL_MIN) {
        level = SERVO_LEVEL_MIN;
    }

    if (level > SERVO_LEVEL_MAX) {
        level = SERVO_LEVEL_MAX;
    }

    EA = 0;
    servo_level = level;
    EA = 1;
}

void Servo_Timer0_ISR(void) interrupt 1
{
    TH0 = SERVO_T0_100US_TH;
    TL0 = SERVO_T0_100US_TL;

    if (servo_tick_index < servo_level) {
        SERVO_PIN = 1;
    } else {
        SERVO_PIN = 0;
    }

    servo_tick_index++;
    if (servo_tick_index >= SERVO_PWM_PERIOD_TICKS) {
        servo_tick_index = 0;
    }
}

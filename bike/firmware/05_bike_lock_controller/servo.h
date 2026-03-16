#ifndef __SERVO_H__
#define __SERVO_H__

#include "main.h"

/*
 * Match the reference demo:
 * timer tick = 100us, PWM level = 4..20, center level = 12.
 */
#define SERVO_PWM_PERIOD_TICKS 160U
#define SERVO_LEVEL_MIN 4U
#define SERVO_CENTER_LEVEL 12U
#define SERVO_LEVEL_MAX 20U
#define SERVO_LOCK_LEVEL SERVO_LEVEL_MIN
#define SERVO_UNLOCK_LEVEL SERVO_LEVEL_MAX

void Servo_Init(void);
void Servo_SetLevel(u8 level);
u8 Servo_LevelToDegrees(u8 level);

#endif

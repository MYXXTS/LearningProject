# 03_servo_keypad_debug

SG90 servo debug project for `STC89C52RC`.

## Pins

- `P0.0-P0.7`: LCD1602A data bus
- `P2.5`: LCD `RW`
- `P2.6`: LCD `RS`
- `P2.7`: LCD `EN`
- `P2.0`: SG90 PWM output
- `P1.0-P1.3`: keypad columns
- `P1.4-P1.7`: keypad rows

## Keys

- `s1`: angle `-10`
- `s6`: angle `+10`
- `s11`: center to `90`

## Behavior

- Timer0 generates a `20ms` servo PWM period.
- PWM control now follows the reference demo directly: `100us` timer tick, level range `4..20`.
- `s11` returns to reference center level `12`, which is about `89` degrees on the demo module.
- LCD shows the current target angle.

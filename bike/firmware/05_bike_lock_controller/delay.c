#include "delay.h"

void delay_ms(u16 ms)
{
    u16 i;

    while (ms--) {
        for (i = 0; i < 114; i++) {
            ;
        }
    }
}

#include "mp3_uart.h"
#include "delay.h"

#define MP3_T1_BIT_RELOAD 0xA0

static volatile bit mp3_tx_busy = 0;
static volatile u16 mp3_tx_shift = 0;
static volatile u8 mp3_tx_bits_left = 0;

static void mp3_send_byte(u8 value)
{
    while (mp3_tx_busy) {
        ;
    }

    mp3_tx_shift = (u16)value;
    mp3_tx_shift |= 0x0300U;
    mp3_tx_bits_left = 10U;
    mp3_tx_busy = 1;

    MP3_TX_PIN = 0;
    TF1 = 0;
    TR1 = 1;

    while (mp3_tx_busy) {
        ;
    }
}

static void mp3_send_command(u8 cmd, u16 param)
{
    u8 buffer[8];
    u8 i;

    buffer[0] = 0x7E;
    buffer[1] = 0xFF;
    buffer[2] = 0x06;
    buffer[3] = cmd;
    buffer[4] = 0x00;
    buffer[5] = (u8)(param >> 8);
    buffer[6] = (u8)(param & 0x00FFU);
    buffer[7] = 0xEF;

    for (i = 0; i < 8U; i++) {
        mp3_send_byte(buffer[i]);
    }

    delay_ms(100);
}

static void mp3_uart_init(void)
{
    MP3_TX_PIN = 1;
    TMOD = (TMOD & 0x0F) | 0x20;
    TH1 = MP3_T1_BIT_RELOAD;
    TL1 = MP3_T1_BIT_RELOAD;
    TF1 = 0;
    TR1 = 0;
    ET1 = 1;
    EA = 1;
}

void MP3_Init(void)
{
    mp3_uart_init();

    delay_ms(500);
    MP3_SetVolume(MP3_DEFAULT_VOLUME);
    delay_ms(500);
    MP3_SetVolume(MP3_DEFAULT_VOLUME);
    delay_ms(500);
    mp3_send_command(0x09, 0x0002U);
    delay_ms(500);
}

void MP3_SetVolume(u8 volume)
{
    if (volume > 30U) {
        volume = 30U;
    }
    mp3_send_command(0x06, (u16)volume);
}

void MP3_Play(void)
{
    mp3_send_command(0x0D, 0x0000U);
}

void MP3_Pause(void)
{
    mp3_send_command(0x0E, 0x0000U);
}

void MP3_Prev(void)
{
    mp3_send_command(0x02, 0x0000U);
}

void MP3_Next(void)
{
    mp3_send_command(0x01, 0x0000U);
}

void MP3_PlayTrack(u16 track_no)
{
    mp3_send_command(0x03, track_no);
}

void MP3_Timer1_ISR(void) interrupt 3
{
    TF1 = 0;

    if (!mp3_tx_busy) {
        MP3_TX_PIN = 1;
        TR1 = 0;
        return;
    }

    if (mp3_tx_bits_left > 0U) {
        if ((mp3_tx_shift & 0x0001U) != 0U) {
            MP3_TX_PIN = 1;
        } else {
            MP3_TX_PIN = 0;
        }
        mp3_tx_shift >>= 1;
        mp3_tx_bits_left--;
        return;
    }

    MP3_TX_PIN = 1;
    TR1 = 0;
    mp3_tx_busy = 0;
}

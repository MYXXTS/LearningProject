#include "mp3_uart.h"
#include "delay.h"

#define MP3_T2_BIT_RELOAD_HIGH 0xFF
#define MP3_T2_BIT_RELOAD_LOW 0xA0

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

    TH2 = RCAP2H;
    TL2 = RCAP2L;
    TF2 = 0;
    MP3_TX_PIN = 0;
    TR2 = 1;

    while (mp3_tx_busy) {
        ;
    }
}

static void mp3_send_command(u8 cmd, u16 param)
{
    u8 buffer[8];
    u8 i;
    bit ea_backup;
    bit es_backup;
    bit et0_backup;
    bit et2_backup;
    bit tr0_backup;

    buffer[0] = 0x7E;
    buffer[1] = 0xFF;
    buffer[2] = 0x06;
    buffer[3] = cmd;
    buffer[4] = 0x00;
    buffer[5] = (u8)(param >> 8);
    buffer[6] = (u8)(param & 0x00FFU);
    buffer[7] = 0xEF;

    ea_backup = EA;
    es_backup = ES;
    et0_backup = ET0;
    et2_backup = ET2;
    tr0_backup = TR0;

    ES = 0;
    ET0 = 0;
    TR0 = 0;
    ET2 = 1;
    EA = 1;

    for (i = 0; i < 8U; i++) {
        mp3_send_byte(buffer[i]);
    }

    TR2 = 0;
    TF2 = 0;
    MP3_TX_PIN = 1;

    TF0 = 0;
    TR0 = tr0_backup;
    ET2 = et2_backup;
    ET0 = et0_backup;
    ES = es_backup;
    EA = ea_backup;

    delay_ms(120);
}

void MP3_Init(void)
{
    MP3_TX_PIN = 1;
    T2CON = 0x00;
    RCAP2H = MP3_T2_BIT_RELOAD_HIGH;
    RCAP2L = MP3_T2_BIT_RELOAD_LOW;
    TH2 = MP3_T2_BIT_RELOAD_HIGH;
    TL2 = MP3_T2_BIT_RELOAD_LOW;
    TF2 = 0;
    TR2 = 0;
    ET2 = 1;
    EA = 1;

    delay_ms(500);
    MP3_SetVolume(MP3_DEFAULT_VOLUME);
    delay_ms(500);
    MP3_SetVolume(MP3_DEFAULT_VOLUME);
    delay_ms(500);
    mp3_send_command(0x09, 0x0002U);
    delay_ms(300);
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

void MP3_Timer2_ISR(void) interrupt 5
{
    TF2 = 0;

    if (!mp3_tx_busy) {
        MP3_TX_PIN = 1;
        TR2 = 0;
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
    TR2 = 0;
    mp3_tx_busy = 0;
}

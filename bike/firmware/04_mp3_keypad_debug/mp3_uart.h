#ifndef __MP3_UART_H__
#define __MP3_UART_H__

#include "main.h"

/* MP3 module volume range: 0-30 */
#define MP3_DEFAULT_VOLUME 26

void MP3_Init(void);
void MP3_SetVolume(u8 volume);
void MP3_Play(void);
void MP3_Pause(void);
void MP3_Prev(void);
void MP3_Next(void);
void MP3_PlayTrack(u16 track_no);

#endif

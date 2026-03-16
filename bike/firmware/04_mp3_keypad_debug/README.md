# 04_mp3_keypad_debug

MP3-TF-16P debug project for `STC89C52RC`.

## Pins

- `P0.0-P0.7`: LCD1602A data bus
- `P2.5`: LCD `RW`
- `P2.6`: LCD `RS`
- `P2.7`: LCD `EN`
- `P2.3`: MP3 software UART `TXD` (`MCU -> MP3 RXD`)
- `P1.0-P1.3`: keypad columns
- `P1.4-P1.7`: keypad rows

## Keys

- `s1`: play
- `s2`: pause
- `s3`: previous track
- `s4`: next track
- `s5-s9`: direct play `001-005`

## Behavior

- Uses `P2.3` software UART transmit only.
- Keeps the command format and startup rhythm close to the working reference flow.
- LCD shows the latest action.

# 01_bluetooth_lcd_debug

HC-06 ASCII receive debug project for `STC89C52RC`.

## Pins

- `P0.0-P0.7`: LCD1602A data bus
- `P2.5`: LCD `RW`
- `P2.6`: LCD `RS`
- `P2.7`: LCD `EN`
- `P3.0`: Bluetooth `RXD` (`HC-06 TXD -> MCU RXD`)
- `P3.1`: Bluetooth `TXD` (`MCU TXD -> HC-06 RXD`)

## Behavior

- Initializes HC-06 hardware UART at `9600 8N1`.
- Receives printable ASCII text from a phone serial debug app.
- A frame ends on `\n`, receive buffer full, or about `30ms` of line idle.
- LCD line 1 shows the latest frame length.
- LCD line 2 shows the latest text. If longer than 16 characters, it scrolls automatically.

## Notes

- Send ASCII text only. `\r` is ignored; `\n` ends a frame.
- The latest frame replaces the previous frame.

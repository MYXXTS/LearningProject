# 02_gps_time_lcd

GPS time debug project for `STC89C52RC`.

## Pins

- `P0.0-P0.7`: LCD1602A data bus
- `P2.5`: LCD `RW`
- `P2.6`: LCD `RS`
- `P2.7`: LCD `EN`
- `P2.1`: GPS `RXD` (`ATGM336H/ATGM332D TXD -> MCU`)
- `P2.2`: GPS `TXD` (optional, software UART idle high)

## Behavior

- Uses software UART at `9600 8N1`.
- Parses GPS NMEA sentences.
- Prefers `ZDA` for full date and time.
- Falls back to `GGA` for time only if no `ZDA` date is available.
- Displays local time as `UTC+8`.

## LCD

- Line 1: `YYYY-MM-DD` or `DATE UNKNOWN`
- Line 2: `HH:MM:SS ZDA+8` or `HH:MM:SS GGA+8`

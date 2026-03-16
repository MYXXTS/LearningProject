# Bike Lock Android App

Android 12+ Flutter app for the bike lock simulator.

## Features

- Scan bike QR code or paste QR text and extract the HC-06 MAC address
- Connect to the paired HC-06 module through Android Bluetooth Classic RFCOMM
- Unlock, lock, query state, and trigger prompt tracks
- Get phone time and location on the app side
- Configure circle and polygon geofences through coordinate forms
- Persist ride history, active ride session, and debug overrides
- Provide a debug page for mock locations and test prompt playback

## Android Only

This project intentionally keeps only:

- `android/`
- `lib/`
- Flutter root config files

Other platform directories are removed to keep the project clean.

## Notes

- Pair HC-06 in Android system Bluetooth settings first
- GPS and time are handled by the app, not by the MCU
- Geofence rejection uses track `005`
- Fee is calculated as `0.5 RMB/minute` by elapsed time only

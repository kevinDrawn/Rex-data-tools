# Sync input support

UART payload: 370 bytes; complete frame: 374 bytes; header: AA 55 72 01.
The last ten payload bytes (offsets 360-369) hold P0.05 levels, 0=Low,
1=High, sampled at 1 kHz alongside EXO data. Both console logger and live
viewer accept this format. Old 360-byte payloads are rejected.

CSV adds sync_state as its last column. Each 1 kHz state is repeated for
its two corresponding 2 kHz EMG rows. The viewer displays sync_state in
a separate Sync input panel as a step plot, enabled by default, for both
live reception and CSV replay. Legacy CSV files remain readable.

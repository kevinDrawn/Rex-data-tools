# UART angle scaling

The receiver expects signed int16 angles in radians multiplied by 10000
for qL, qR, and qMirror. CSV and live-view angles are converted to degrees
using `(raw / 10000.0f) * (180.0f / pi)`.

The wire layout and torque/EMG scaling are unchanged. Sender and receiver
must use the same angle scale; the packet has no scale-version identifier.
Older firmware using radians multiplied by 100 is not compatible with this
receiver conversion. Existing CSV files already contain degrees and remain
readable without conversion or modification.

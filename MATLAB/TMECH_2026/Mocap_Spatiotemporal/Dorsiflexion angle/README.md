# Event-aligned ankle-angle extraction

Source `exp_data.mat`: variable `exp_data`, 6 x 4 struct array.
Rows: #5, #6, #7, #8, #11, #12.
Columns: IE = intact_Exo shoe; IR = intact_Rex; LE = lido_Exo shoe; LR = lido_Rex.

Relevant fields:
- int_data.t: complete Hall timestamp vector, nominal 500 Hz.
- int_data.left.angle / right.angle: stored ankle angles, deg.
- int_data.t_interval: one [start end] row per recording interval.
- phase_data.events.left.mocap.t_IC / t_TO: video-labelled event timestamps.
- phase_data.events.right.mocap.t_IC / t_TO: right-side equivalents.
- phase_data.events.t_bias: scalar or per-recording vector, preserved as provenance.
- phase_data.left/right.mocap/exo: existing cycle-normalized waveforms (101 phase points).
- phase_data.results: previously computed waveform and spatiotemporal summaries.
- meta / similarity / work: existing derived summaries.

The stored event timestamps overlap the Hall analysis intervals and agree with
existing event-normalized angle traces. They are therefore used directly;
t_bias is not added a second time. EVENT_TIME_OFFSET_SECONDS is an explicit
additional scalar offset, default 0, if further alignment is independently verified.

Run exec_event_dorsiflexion.m from its active MATLAB editor tab.
RAT_ID / CONDITION / ANGLE_SIDE choose the plotted record.
All 24 extracted results remain in eventAngleData (same 6 x 4 layout).
Each result contains Segments with Time_s, Angle_deg, StanceState, Events,
and complete TO-to-next-IC SwingIntervals. Disjoint intervals are never joined.
IC-inclusive to TO-exclusive is stance=1; TO-inclusive to IC-exclusive is swing=0.
The leading phase is inferred from the next event; no-event intervals remain NaN.
Leading/trailing open phases are plotted but not counted as complete swings.
Plots use a separate panel and optional zero time per recording interval.
Absolute source times and original Hall angle values are retained in the results.
No neutral-angle or dorsiflexion direction conversion is assumed.
SAVE_RESULTS=true saves extracted data and the selected FIG/PNG to OUTPUT_DIRECTORY.

#define _CRT_SECURE_NO_WARNINGS
#undef NDEBUG
#include "csv_writer.h"
#include "frame_parser.h"
#include "torque_preview.h"
#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdio>
#include <sstream>

int main() {
    static_assert(REX_TMECH_FRAME_LEN == 174);
    std::vector<uint8_t> frame(REX_TMECH_FRAME_LEN);
    frame[0] = 0xaa;
    frame[1] = 0x55;
    frame[2] = 0xaa;
    for (std::size_t channel = 0; channel < 8; ++channel) {
        for (std::size_t sample = 0; sample < 10; ++sample) {
            const auto off = 4 + 2 * (10 * channel + sample);
            const auto wire = static_cast<uint16_t>(1000 * static_cast<int>(channel) -
                7500 + 100 * static_cast<int>(sample));
            frame[off] = static_cast<uint8_t>(wire);
            frame[off + 1] = static_cast<uint8_t>(wire >> 8);
        }
    }
    for (std::size_t i = 0; i < 10; ++i) frame[164 + i] = static_cast<uint8_t>(i % 2);

    rex::FrameParser tmech(REX_LOG_TMECH), legacy;
    std::vector<RexBatch> decoded;
    std::vector<uint8_t> emg(FRAME_LEN);
    emg[0] = HDR0; emg[1] = HDR1;
    emg[2] = PAYLOAD_LEN & 0xff; emg[3] = PAYLOAD_LEN >> 8;
    // A header-like sequence inside an EMG frame must not be mistaken for a TMECH batch.
    std::copy(frame.begin(), frame.end(), emg.begin() + 5);
    for (auto byte : emg) tmech.feed(&byte, 1, decoded);
    assert(decoded.empty() && tmech.bad_headers() == 1);
    legacy.feed(frame.data(), frame.size(), decoded);
    assert(decoded.empty() && legacy.bad_headers() == 1);
    for (auto byte : frame) tmech.feed(&byte, 1, decoded);
    assert(decoded.size() == 1);
    const auto& batch = decoded.front();
    assert(batch.qL[9] == -6600 && batch.qR[9] == -5600 && batch.qMirror[9] == -4600);
    assert(batch.torque_axis[9] == -3600 && batch.torque_can_L[9] == -2600 && batch.torque_can_R[9] == -1600);
    assert(batch.q_nominal[0] == -1500 && batch.q_nominal[9] == -600);
    assert(batch.q_compensation[0] == -500 && batch.q_compensation[9] == 400);
    assert(batch.sync_state[0] == 0 && batch.sync_state[9] == 1);

    static CsvWriter writer;
    assert(csv_writer_attach_format(&writer, std::tmpfile(), REX_LOG_TMECH));
    for (std::size_t i = 0; i < LOG_BATCH_EXO; ++i)
        assert(csv_writer_write_sample(&writer, &batch, i, static_cast<double>(i), 0.0));
    assert(!csv_writer_write_sample(&writer, &batch, LOG_BATCH_EXO, 0, 0));
    assert(csv_writer_flush(&writer));
    std::rewind(writer.file);
    std::stringstream csv_text;
    char line[256];
    while (std::fgets(line, sizeof(line), writer.file)) csv_text << line;
    assert(csv_writer_close(&writer));
    const auto saved = rex::read_csv(csv_text, "TMECH");
    auto raw = rex::make_live_data(REX_LOG_TMECH);
    rex::append_live_batch(raw, batch, 0, REX_LOG_TMECH);
    assert(saved.seconds.size() == 10 && saved.channels.size() == 11);
    assert(raw.seconds.size() == 10 && raw.channels.size() == 9);
    for (std::size_t i = 0; i < raw.seconds.size(); ++i) {
        assert(std::abs(saved.seconds[i] - raw.seconds[i]) < 1e-12);
        for (std::size_t c = 0; c < raw.channels.size(); ++c) {
            assert(saved.channels[c + 2].name == raw.channels[c].name);
            assert(std::abs(saved.channels[c + 2].values[i] - raw.channels[c].values[i]) < 1e-6);
        }
    }

    // The three sliders change independent preview channels and leave the raw series intact.
    auto step = rex::make_live_data(REX_LOG_TMECH);
    step.seconds = {0.0, 0.001, 0.002, 0.012};
    for (auto& channel : step.channels) channel.values = {0.0, 1.0, 1.0, 1.0};
    rex::TorquePreviewSettings settings;
    settings[0] = {6, 100};
    settings[1] = {40, 200};
    settings[2] = {20, 0};
    const auto preview = rex::make_torque_preview(step, settings);
    const auto& left = preview.channels[0].values;
    const auto& right = preview.channels[1].values;
    const auto& axial = preview.channels[2].values;
    assert(left[1] > 0.0 && right[1] > 2.0 * left[1]);
    assert(left.back() == 1.0 && right.back() == 2.0 && axial.back() == 0.0);
    assert(step.channels[3].values[1] == 1.0 && step.channels[4].values[1] == 1.0);
}

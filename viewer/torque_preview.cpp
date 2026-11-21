#include "torque_preview.h"
#include <algorithm>
#include <cmath>

namespace rex {
std::size_t torque_preview_index(const std::string& name) {
    const auto found = std::find(TorquePreviewChannels.begin(), TorquePreviewChannels.end(), name);
    return static_cast<std::size_t>(found - TorquePreviewChannels.begin());
}

LogData make_torque_preview(const LogData& raw, const TorquePreviewSettings& settings) {
    constexpr double period = REX_TMECH_SAMPLE_PERIOD_US / 1000000.0;
    constexpr double two_pi = 6.283185307179586;
    LogData preview;
    preview.seconds = raw.seconds;
    for (std::size_t c = 0; c < TorquePreviewChannels.size(); ++c) {
        const auto name = TorquePreviewChannels[c];
        auto& result = preview.channels.emplace_back(Channel{name, SignalGroup::Torque, {}});
        const auto source = std::find_if(raw.channels.begin(), raw.channels.end(),
            [name](const Channel& channel) { return channel.name == name; });
        if (source == raw.channels.end() || source->values.empty() ||
            source->values.size() != raw.seconds.size()) continue;

        const double cutoff = settings[c].cutoff_half_hz * 0.5;
        const double gain = settings[c].gain_percent / 100.0;
        const double alpha = -std::expm1(-two_pi * cutoff * period);
        result.values.reserve(source->values.size());
        double filtered = source->values.front();
        result.values.push_back(filtered * gain);
        for (std::size_t i = 1; i < source->values.size(); ++i) {
            const double value = source->values[i];
            // Restart at a display-queue gap where the intervening samples are unavailable.
            if (raw.seconds[i] - raw.seconds[i - 1] > 1.5 * period) filtered = value;
            else filtered += alpha * (value - filtered);
            result.values.push_back(filtered * gain);
        }
    }
    return preview;
}
}

#pragma once
#include "log_data.h"
#include <array>

namespace rex {
inline constexpr std::array<const char*, 3> TorquePreviewChannels{
    "Torque_CAN_L", "Torque_CAN_R", "Torque_axis"
};

struct TorquePreviewSetting {
    int cutoff_half_hz = 20;
    int gain_percent = 100;
};

using TorquePreviewSettings = std::array<TorquePreviewSetting, TorquePreviewChannels.size()>;

std::size_t torque_preview_index(const std::string& name);
LogData make_torque_preview(const LogData& raw, const TorquePreviewSettings& settings);
}

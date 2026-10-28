#ifndef REX_LOG_DATA_H
#define REX_LOG_DATA_H

#include <cstddef>
#include <filesystem>
#include <istream>
#include <string>
#include <vector>
#include "rex_protocol.h"

namespace rex {
enum class SignalGroup { Angle, Torque, Emg, Other };
struct Channel {
    std::string name;
    SignalGroup group = SignalGroup::Other;
    std::vector<double> values;
};
struct LogData {
    std::string name;
    std::vector<double> seconds;
    std::vector<Channel> channels;
};
/* 메모리 사용량에 상한을 두고 잘못된 CSV는 행 번호와 함께 거부합니다. */
LogData read_csv(std::istream& input, const std::string& name);
LogData load_csv(const std::filesystem::path& path);
LogData make_demo();
LogData make_live_data();
void append_live_batch(LogData& data, const RexBatch& batch, uint64_t first_sample);
struct PlotPoints { std::vector<double> x, y; };
/* 화면 구간의 피크를 보존하면서 가로 픽셀 수에 맞춰 점 수를 제한합니다. */
PlotPoints visible_points(const LogData& data, std::size_t channel,
                          double start, double end, std::size_t pixels);
}
#endif

#include "log_data.h"
#include "rex_protocol.h"
#include "rex_units.h"
#include <algorithm>
#include <cmath>
#include <fstream>
#include <iterator>
#include <limits>
#include <locale>
#include <set>
#include <sstream>
#include <stdexcept>

namespace rex {
namespace {
constexpr std::size_t MaxRows = 2000000;
constexpr std::size_t MaxChannels = 64;
constexpr std::size_t MaxNumericBytes = 256 * 1024 * 1024;

std::string trim(std::string text) {
    auto first = text.find_first_not_of(" \t\r");
    if (first == std::string::npos) return {};
    return text.substr(first, text.find_last_not_of(" \t\r") - first + 1);
}
std::vector<std::string> split(const std::string& line) {
    // 현재 로거의 단순 숫자 CSV를 지원합니다. 따옴표 필드는 명시적으로 거부합니다.
    if (line.find('"') != std::string::npos)
        throw std::runtime_error("Quoted fields are not supported.");
    std::vector<std::string> result;
    std::size_t begin = 0;
    do {
        auto end = line.find(',', begin);
        result.push_back(trim(line.substr(begin, end - begin)));
        if (end == std::string::npos) break;
        begin = end + 1;
    } while (true);
    return result;
}
double number(const std::string& text) {
    std::istringstream parser(text);
    parser.imbue(std::locale::classic());
    double value;
    if (!(parser >> value)) throw std::runtime_error("A non-numeric value was found.");
    parser >> std::ws;
    if (!parser.eof() || !std::isfinite(value))
        throw std::runtime_error("Only finite numbers are allowed.");
    return value;
}
SignalGroup group_of(const std::string& name) {
    if (name == "sync_state") return SignalGroup::Sync;
    if (name.find("EMG") != std::string::npos) return SignalGroup::Emg;
    if (name.find("Torque") != std::string::npos || name == "q_compensation") return SignalGroup::Torque;
    if (name.find("_deg") != std::string::npos) return SignalGroup::Angle;
    return SignalGroup::Other;
}
}

LogData read_csv(std::istream& input, const std::string& name) {
    std::string line;
    if (!std::getline(input, line)) throw std::runtime_error("The file is empty.");
    if (line.compare(0, 3, "\xef\xbb\xbf") == 0) line.erase(0, 3);
    auto header = split(line);
    if (header.size() < 2 || header.size() > MaxChannels + 1)
        throw std::runtime_error("Expected 2-65 columns including time.");
    std::set<std::string> unique;
    std::size_t time_column = header.size();
    LogData data;
    data.name = name;
    for (std::size_t i = 0; i < header.size(); ++i) {
        if (header[i].empty() || !unique.insert(header[i]).second)
            throw std::runtime_error("Column names are empty or duplicated.");
        if (header[i] == "time_ms") time_column = i;
        else data.channels.push_back({header[i], group_of(header[i]), {}});
    }
    if (time_column == header.size()) throw std::runtime_error("The time_ms column is required.");
    const auto max_rows = std::min(MaxRows, MaxNumericBytes / (header.size() * sizeof(double)));
    std::size_t row = 1;
    while (std::getline(input, line)) {
        ++row;
        if (trim(line).empty()) continue;
        try {
            if (data.seconds.size() >= max_rows)
                throw std::runtime_error("Import limit exceeded (2 million rows or 256 MiB of numeric data).");
            auto fields = split(line);
            if (fields.size() != header.size()) throw std::runtime_error("Column count mismatch.");
            std::vector<double> values;
            for (const auto& field : fields) values.push_back(number(field));
            const double t = values[time_column] / 1000.0;
            if (!data.seconds.empty() && t <= data.seconds.back())
                throw std::runtime_error("time_ms must be strictly increasing.");
            data.seconds.push_back(t);
            std::size_t c = 0;
            for (std::size_t i = 0; i < values.size(); ++i)
                if (i != time_column) data.channels[c++].values.push_back(values[i]);
        } catch (const std::exception& e) {
            throw std::runtime_error(std::to_string(row) + ": row error: " + e.what());
        }
    }
    if (input.bad()) throw std::runtime_error("File read failed.");
    if (data.seconds.empty()) throw std::runtime_error("No data rows found.");
    return data;
}

LogData load_csv(const std::filesystem::path& path) {
    std::ifstream input(path);
    if (!input) throw std::runtime_error("Could not open the file.");
    return read_csv(input, path.filename().u8string());
}

LogData make_demo(RexLogFormat format) {
    LogData data = make_live_data(format);
    data.name = "Demo data (not a measurement)";
    const auto period_us = rex_sample_period_us(format);
    const std::size_t count = 60 * 1000000 / period_us;
    for (std::size_t i = 0; i < count; ++i) {
        const double t = i * (period_us / 1000000.0);
        data.seconds.push_back(t);
        for (std::size_t c = 0; c < data.channels.size(); ++c) {
            const double phase = c * 0.7;
            double y;
            if (data.channels[c].group == SignalGroup::Sync) y = std::fmod(t, 2.0) >= 1.0 ? 1.0 : 0.0;
            else if (data.channels[c].group == SignalGroup::Angle) y = 30 * std::sin(t * 4 + phase);
            else if (data.channels[c].group == SignalGroup::Torque) {
                y = 0.7 * std::sin(t * 4 + phase);
                if (format == REX_LOG_TMECH && c < 6) y += 0.15 * std::sin(t * 240 + phase);
            }
            else {
                const double envelope = std::pow(std::max(0.0, std::sin(t * 4 + phase)), 4);
                y = envelope * (100000 * std::sin(t * 700 + phase) +
                                35000 * std::sin(t * 1130 + phase));
            }
            data.channels[c].values.push_back(y);
        }
    }
    return data;
}

LogData make_live_data(RexLogFormat format) {
    LogData data;
    data.name = "Live MCU data";
    const char* names[] = {"L_deg", "R_deg", "M_deg", "Torque_axis", "Torque_CAN_L", "Torque_CAN_R"};
    for (auto name : names) data.channels.push_back({name, group_of(name), {}});
    if (format == REX_LOG_TMECH) {
        data.channels.push_back({"q_nominal_deg", SignalGroup::Angle, {}});
        data.channels.push_back({"q_compensation", SignalGroup::Torque, {}});
    } else {
        for (auto name : {"L_TB_EMG", "L_GT_EMG", "R_TB_EMG", "R_GT_EMG"})
            data.channels.push_back({name, SignalGroup::Emg, {}});
    }
    data.channels.push_back({"sync_state", SignalGroup::Sync, {}});
    return data;
}

void append_live_batch(LogData& data, const RexBatch& batch, uint64_t first_sample, RexLogFormat format) {
    const bool tmech = format == REX_LOG_TMECH;
    if (data.channels.size() != (tmech ? 9u : 11u))
        throw std::runtime_error("Live data channel count mismatch.");
    const auto period_us = rex_sample_period_us(format);
    for (std::size_t i = 0; i < rex_samples_per_batch(format); ++i) {
        const auto j = tmech ? i : i / REX_EMG_PER_EXO;
        data.seconds.push_back((first_sample + i) * (period_us / 1000000.0));
        const double values[] = {rex_angle_degrees(batch.qL[j]), rex_angle_degrees(batch.qR[j]),
            rex_angle_degrees(batch.qMirror[j]), rex_torque_value(batch.torque_axis[j]),
            rex_torque_value(batch.torque_can_L[j]), rex_torque_value(batch.torque_can_R[j])};
        for (std::size_t c = 0; c < std::size(values); ++c)
            data.channels[c].values.push_back(values[c]);
        const auto first_extra = std::size(values);
        if (tmech) {
            data.channels[first_extra].values.push_back(rex_angle_degrees(batch.q_nominal[j]));
            data.channels[first_extra + 1].values.push_back(rex_torque_value(batch.q_compensation[j]));
        } else {
            for (std::size_t c = 0; c < LOG_EMG_CHANNEL; ++c)
                data.channels[first_extra + c].values.push_back(batch.emg[c][i]);
        }
        data.channels.back().values.push_back(batch.sync_state[j]);
    }
    // 최근 60초만 화면에 유지합니다. 전체 기록은 CSV에서 별도로 보존됩니다.
    const std::size_t capacity = 60 * 1000000 / period_us;
    if (data.seconds.size() > capacity) {
        auto remove = data.seconds.size() - capacity;
        data.seconds.erase(data.seconds.begin(), data.seconds.begin() + remove);
        for (auto& channel : data.channels)
            channel.values.erase(channel.values.begin(), channel.values.begin() + remove);
    }
}

PlotPoints visible_points(const LogData& data, std::size_t channel,
                          double start, double end, std::size_t pixels) {
    PlotPoints points;
    if (channel >= data.channels.size() || !(end > start) || data.seconds.empty()) return points;
    const auto& x = data.seconds;
    const auto& y = data.channels[channel].values;
    if (y.size() != x.size()) return points;
    auto lo = std::lower_bound(x.begin(), x.end(), start);
    auto hi = std::upper_bound(x.begin(), x.end(), end);
    if (lo != x.begin()) --lo;
    if (hi != x.end()) ++hi;
    const auto first = static_cast<std::size_t>(lo - x.begin());
    const auto last = static_cast<std::size_t>(hi - x.begin());
    pixels = std::clamp<std::size_t>(pixels, 1, 8192);
    auto add = [&](std::size_t i) { points.x.push_back(x[i]); points.y.push_back(y[i]); };
    if (last - first <= pixels * 4) {
        for (auto i = first; i < last; ++i) add(i);
        return points;
    }
    // 원래 시간 순서대로 각 구간의 양 끝과 최솟값·최댓값을 보존합니다.
    const std::size_t bucket = (last - first + pixels - 1) / pixels;
    for (auto begin = first; begin < last; begin += bucket) {
        auto finish = std::min(begin + bucket, last);
        auto mm = std::minmax_element(y.begin() + begin, y.begin() + finish);
        std::size_t indices[] = {begin, static_cast<std::size_t>(mm.first - y.begin()),
            static_cast<std::size_t>(mm.second - y.begin()), finish - 1};
        std::sort(std::begin(indices), std::end(indices));
        auto unique_end = std::unique(std::begin(indices), std::end(indices));
        for (auto it = std::begin(indices); it != unique_end; ++it) add(*it);
    }
    return points;
}
}

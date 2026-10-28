#include "log_data.h"
#include "rex_protocol.h"
#include "rex_units.h"
#include <algorithm>
#include <cmath>
#include <fstream>
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
        throw std::runtime_error("따옴표 필드는 지원하지 않습니다.");
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
    if (!(parser >> value)) throw std::runtime_error("숫자가 아닌 값이 있습니다.");
    parser >> std::ws;
    if (!parser.eof() || !std::isfinite(value))
        throw std::runtime_error("유한한 숫자만 허용됩니다.");
    return value;
}
SignalGroup group_of(const std::string& name) {
    if (name.find("EMG") != std::string::npos) return SignalGroup::Emg;
    if (name.find("Torque") != std::string::npos) return SignalGroup::Torque;
    if (name.find("_deg") != std::string::npos) return SignalGroup::Angle;
    return SignalGroup::Other;
}
}

LogData read_csv(std::istream& input, const std::string& name) {
    std::string line;
    if (!std::getline(input, line)) throw std::runtime_error("빈 파일입니다.");
    if (line.compare(0, 3, "\xef\xbb\xbf") == 0) line.erase(0, 3);
    auto header = split(line);
    if (header.size() < 2 || header.size() > MaxChannels + 1)
        throw std::runtime_error("열 개수는 시간 포함 2~65개여야 합니다.");
    std::set<std::string> unique;
    std::size_t time_column = header.size();
    LogData data;
    data.name = name;
    for (std::size_t i = 0; i < header.size(); ++i) {
        if (header[i].empty() || !unique.insert(header[i]).second)
            throw std::runtime_error("열 이름이 비었거나 중복되었습니다.");
        if (header[i] == "time_ms") time_column = i;
        else data.channels.push_back({header[i], group_of(header[i]), {}});
    }
    if (time_column == header.size()) throw std::runtime_error("time_ms 열이 필요합니다.");
    const auto max_rows = std::min(MaxRows, MaxNumericBytes / (header.size() * sizeof(double)));
    std::size_t row = 1;
    while (std::getline(input, line)) {
        ++row;
        if (trim(line).empty()) continue;
        try {
            if (data.seconds.size() >= max_rows)
                throw std::runtime_error("불러오기 한도(200만 행 또는 숫자 데이터 256 MiB)를 넘었습니다.");
            auto fields = split(line);
            if (fields.size() != header.size()) throw std::runtime_error("열 개수가 맞지 않습니다.");
            std::vector<double> values;
            for (const auto& field : fields) values.push_back(number(field));
            const double t = values[time_column] / 1000.0;
            if (!data.seconds.empty() && t <= data.seconds.back())
                throw std::runtime_error("time_ms는 중복 없이 증가해야 합니다.");
            data.seconds.push_back(t);
            std::size_t c = 0;
            for (std::size_t i = 0; i < values.size(); ++i)
                if (i != time_column) data.channels[c++].values.push_back(values[i]);
        } catch (const std::exception& e) {
            throw std::runtime_error(std::to_string(row) + "행: " + e.what());
        }
    }
    if (input.bad()) throw std::runtime_error("파일 읽기에 실패했습니다.");
    if (data.seconds.empty()) throw std::runtime_error("데이터 행이 없습니다.");
    return data;
}

LogData load_csv(const std::filesystem::path& path) {
    std::ifstream input(path);
    if (!input) throw std::runtime_error("파일을 열 수 없습니다.");
    return read_csv(input, path.filename().u8string());
}

LogData make_demo() {
    LogData data = make_live_data();
    data.name = "샘플 데이터 (실제 측정 아님)";
    const std::size_t count = 60 * 1000000 / REX_EMG_SAMPLE_PERIOD_US;
    for (std::size_t i = 0; i < count; ++i) {
        const double t = i * (REX_EMG_SAMPLE_PERIOD_US / 1000000.0);
        data.seconds.push_back(t);
        for (std::size_t c = 0; c < data.channels.size(); ++c) {
            const double phase = c * 0.7;
            double y;
            if (c < 3) y = 30 * std::sin(t * 4 + phase);
            else if (c < 6) y = 0.7 * std::sin(t * 4 + phase);
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

LogData make_live_data() {
    LogData data;
    data.name = "MCU 실시간 수신";
    const char* names[] = {"L_deg", "R_deg", "M_deg", "Torque_axis", "Torque_CAN_L",
        "Torque_CAN_R", "L_TB_EMG", "L_GT_EMG", "R_TB_EMG", "R_GT_EMG"};
    for (auto name : names) data.channels.push_back({name, group_of(name), {}});
    return data;
}

void append_live_batch(LogData& data, const RexBatch& batch, uint64_t first_sample) {
    if (data.channels.size() != 10) throw std::runtime_error("실시간 데이터 채널 수가 맞지 않습니다.");
    for (std::size_t i = 0; i < LOG_BATCH_EMG; ++i) {
        auto j = i / REX_EMG_PER_EXO;
        data.seconds.push_back((first_sample + i) * (REX_EMG_SAMPLE_PERIOD_US / 1000000.0));
        double values[] = {rex_angle_degrees(batch.qL[j]), rex_angle_degrees(batch.qR[j]),
            rex_angle_degrees(batch.qMirror[j]), rex_torque_value(batch.torque_axis[j]),
            rex_torque_value(batch.torque_can_L[j]), rex_torque_value(batch.torque_can_R[j]),
            double(batch.emg[REX_L_TB][i]), double(batch.emg[REX_L_GT][i]),
            double(batch.emg[REX_R_TB][i]), double(batch.emg[REX_R_GT][i])};
        for (std::size_t c = 0; c < 10; ++c) data.channels[c].values.push_back(values[c]);
    }
    // 최근 60초만 화면에 유지합니다. 전체 기록은 CSV에서 별도로 보존됩니다.
    constexpr std::size_t capacity = 60 * 1000000 / REX_EMG_SAMPLE_PERIOD_US;
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

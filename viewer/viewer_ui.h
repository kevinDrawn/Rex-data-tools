#pragma once
#include "log_data.h"
#include <future>
#include "live_session.h"

namespace rex {
class ViewerUi {
public:
    ViewerUi();
    void draw(void* native_window);
private:
    void adopt(LogData data);
    void open(void* native_window);
    void clamp_range();
    void plot_group(SignalGroup group, const char* title, const char* unit, float height);
    LogData data_;
    std::vector<bool> selected_;
    std::future<LogData> loading_;
    std::string error_;
    double start_ = 0, duration_ = 5, playhead_ = 0;
    bool replay_ = false, auto_y_ = true;
    struct Cache {
        double start = -1, end = -1;
        std::size_t pixels = 0;
        PlotPoints points;
    };
    std::vector<Cache> cache_;
    LiveSession live_;
    LiveStatus live_status_;
    char port_[32] = "COM7";
    int baud_ = 460800;
    bool live_mode_ = false, follow_ = true, record_ = false;
};
}

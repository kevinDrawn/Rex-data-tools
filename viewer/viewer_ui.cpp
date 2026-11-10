#include "viewer_ui.h"
#include "imgui.h"
#include "implot.h"
#include <windows.h>
#include <commdlg.h>
#include <algorithm>
#include <chrono>
#include <cmath>

namespace rex {
ViewerUi::ViewerUi() { adopt(make_demo()); }

void ViewerUi::adopt(LogData data) {
    data_ = std::move(data);
    selected_.assign(data_.channels.size(), false);
    for (std::size_t c = 0; c < data_.channels.size(); ++c)
        selected_[c] = data_.channels[c].group != SignalGroup::Other;
    cache_.assign(data_.channels.size(), {});
    live_values_.clear();
    live_received_at_ = values_updated_at_ = -1;
    start_ = data_.seconds.empty() ? 0 : data_.seconds.front();
    duration_ = data_.seconds.empty() ? 5 : std::min(5.0, std::max(0.001, data_.seconds.back() - start_));
    playhead_ = start_;
    replay_ = false;
    error_.clear();
}

void ViewerUi::open(void* native_window) {
    wchar_t path[32768] = {};
    OPENFILENAMEW dialog = {};
    dialog.lStructSize = sizeof(dialog);
    dialog.hwndOwner = static_cast<HWND>(native_window);
    dialog.lpstrFilter = L"CSV files (*.csv)\0*.csv\0All files (*.*)\0*.*\0";
    dialog.lpstrFile = path;
    dialog.nMaxFile = static_cast<DWORD>(std::size(path));
    dialog.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST | OFN_NOCHANGEDIR;
    if (GetOpenFileNameW(&dialog)) {
        const std::filesystem::path filename(path);
        loading_ = std::async(std::launch::async, [filename] { return load_csv(filename); });
        replay_ = false;
        error_.clear();
    } else if (CommDlgExtendedError() != 0) {
        error_ = "Could not open file dialog.";
    }
}

void ViewerUi::clamp_range() {
    if (data_.seconds.empty()) return;
    const double lo = data_.seconds.front();
    const double hi = data_.seconds.back();
    const double total = live_mode_ ? 60.0 : std::max(0.001, hi - lo);
    if (!std::isfinite(duration_)) duration_ = 5;
    duration_ = std::clamp(duration_, std::min(0.001, total), total);
    if (!std::isfinite(start_)) start_ = lo;
    start_ = std::clamp(start_, lo, std::max(lo, hi - duration_));
}

void ViewerUi::plot_group(SignalGroup group, const char* title, const char* unit, float height) {
    bool any = false;
    for (std::size_t c = 0; c < selected_.size(); ++c)
        any |= selected_[c] && data_.channels[c].group == group;
    if (!any) return;
    if (ImPlot::BeginPlot(title, ImVec2(-1, height))) {
        ImPlot::SetupAxes("Time (s)", unit, ImPlotAxisFlags_NoMenus,
            auto_y_ ? ImPlotAxisFlags_AutoFit : ImPlotAxisFlags_None);
        // 연결된 그래프는 동일한 시간 범위를 사용하며, 사용자의 이동은 다음 프레임에 공유됩니다.
        if (group == SignalGroup::Sync)
            ImPlot::SetupAxisLimits(ImAxis_Y1, -0.1, 1.1, ImPlotCond_Always);
        const double old_start = start_, old_end = start_ + duration_;
        double linked_start = old_start, linked_end = old_end;
        ImPlot::SetupAxisLinks(ImAxis_X1, &linked_start, &linked_end);
        const auto pixels = static_cast<std::size_t>(std::max(1.0f, ImGui::GetContentRegionAvail().x));
        for (std::size_t c = 0; c < selected_.size(); ++c) {
            if (!selected_[c] || data_.channels[c].group != group) continue;
            auto& cache = cache_[c];
            if (cache.start != old_start || cache.end != old_end || cache.pixels != pixels) {
                cache.points = visible_points(data_, c, old_start, old_end, pixels);
                cache.start = old_start;
                cache.end = old_end;
                cache.pixels = pixels;
            }
            if (!cache.points.x.empty()) {
                if (group == SignalGroup::Sync)
                    ImPlot::PlotStairs(data_.channels[c].name.c_str(), cache.points.x.data(),
                        cache.points.y.data(), static_cast<int>(cache.points.x.size()));
                else
                    ImPlot::PlotLine(data_.channels[c].name.c_str(), cache.points.x.data(),
                        cache.points.y.data(), static_cast<int>(cache.points.x.size()));
            }
        }
        const auto limits = ImPlot::GetPlotLimits();
        if (std::abs(limits.X.Min - old_start) > 1e-8 || std::abs(limits.X.Max - old_end) > 1e-8) {
            start_ = limits.X.Min;
            duration_ = limits.X.Max - limits.X.Min;
            replay_ = false;
            follow_ = false;
            clamp_range();
        }
        ImPlot::EndPlot();
    }
}

void ViewerUi::draw_live_values() {
    const double now = ImGui::GetTime();
    const bool fresh = live_status_.running && live_received_at_ >= 0 &&
        now - live_received_at_ < 0.5;
    if (!data_.seconds.empty() &&
        (values_updated_at_ < 0 || now - values_updated_at_ >= 0.020)) {
        live_values_.resize(data_.channels.size());
        for (std::size_t c = 0; c < data_.channels.size(); ++c)
            live_values_[c] = data_.channels[c].values.back();
        values_updated_at_ = values_updated_at_ < 0 ? now :
            values_updated_at_ + std::floor((now - values_updated_at_) / 0.020) * 0.020;
    }
    ImGui::Separator();
    ImGui::TextUnformatted("Latest received values / Angle range: 45-130 deg");
    if (!fresh)
        ImGui::TextColored(ImVec4(1, 0.65f, 0.2f, 1),
            "Waiting for data or reception stopped - last received values shown.");
    if (ImGui::BeginTable("live_values", 3, ImGuiTableFlags_Borders | ImGuiTableFlags_RowBg)) {
        ImGui::TableSetupColumn("Channel");
        ImGui::TableSetupColumn("Value");
        ImGui::TableSetupColumn("Status");
        ImGui::TableHeadersRow();
        for (std::size_t c = 0; c < live_values_.size(); ++c) {
            if (!selected_[c]) continue;
            const auto& channel = data_.channels[c];
            const double value = live_values_[c];
            const bool angle = channel.group == SignalGroup::Angle;
            const bool outside = angle && (value < 45.0 || value > 130.0);
            ImGui::TableNextRow();
            ImGui::TableNextColumn();
            ImGui::TextUnformatted(channel.name.c_str());
            ImGui::TableNextColumn();
            if (angle) ImGui::SetWindowFontScale(1.5f);
            ImGui::TextColored(!fresh ? ImVec4(0.6f, 0.6f, 0.6f, 1) :
                outside ? ImVec4(1, 0.4f, 0.3f, 1) : ImVec4(0.4f, 1, 0.6f, 1),
                angle ? "%.2f deg" : "%.3f", value);
            if (angle) ImGui::SetWindowFontScale(1.0f);
            ImGui::TableNextColumn();
            ImGui::TextUnformatted(!fresh ? "Last value" :
                angle ? (outside ? "Out of range" : "In range") : "Receiving");
        }
        ImGui::EndTable();
    }
}

void ViewerUi::draw(void* native_window) {
    std::vector<TimedBatch> received;
    live_status_ = live_.drain(received);
    if (live_mode_ && !received.empty()) {
        for (const auto& timed : received) append_live_batch(data_, timed.batch, timed.first_sample);
        live_received_at_ = ImGui::GetTime();
        for (auto& cache : cache_) cache.start = -1;
        if (follow_) start_ = data_.seconds.back() - duration_;
    }
    const bool busy = loading_.valid();
    if (busy && loading_.wait_for(std::chrono::seconds(0)) == std::future_status::ready) {
        try { adopt(loading_.get()); }
        catch (const std::exception& e) { error_ = e.what(); }
    }
    if (replay_ && !live_mode_) {
        playhead_ += ImGui::GetIO().DeltaTime;
        if (playhead_ >= data_.seconds.back()) {
            playhead_ = data_.seconds.back();
            replay_ = false;
        }
        start_ = playhead_ - duration_;
    }
    clamp_range();

    const ImGuiViewport* viewport = ImGui::GetMainViewport();
    ImGui::SetNextWindowPos(viewport->WorkPos);
    ImGui::SetNextWindowSize(viewport->WorkSize);
    ImGui::Begin("Rex Data Viewer", nullptr,
        ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoSavedSettings);
    ImGui::TextUnformatted("REX  /  Data Explorer");
    ImGui::Separator();
    ImGui::BeginDisabled(loading_.valid() || live_status_.running);
    if (ImGui::Button("Open CSV")) { live_mode_ = false; open(native_window); }
    ImGui::SameLine();
    if (ImGui::Button("Demo Data")) { live_mode_ = false; adopt(make_demo()); }
    ImGui::EndDisabled();
    ImGui::SameLine();
    ImGui::BeginDisabled(live_mode_);
    if (ImGui::Button(replay_ ? "Pause Replay" : "Replay")) {
        replay_ = !replay_;
        playhead_ = start_ + duration_;
        if (playhead_ >= data_.seconds.back()) playhead_ = data_.seconds.front();
    }
    ImGui::EndDisabled();
    ImGui::SameLine();
    ImGui::TextDisabled(live_mode_ ? "Live MCU / Last 60 s displayed / All samples recorded" : "Browse and replay recorded data");
    ImGui::BeginDisabled(live_status_.running || loading_.valid());
    ImGui::SetNextItemWidth(95);
    ImGui::InputText("Port", port_, sizeof(port_));
    ImGui::SameLine(); ImGui::SetNextItemWidth(110);
    ImGui::InputInt("baud", &baud_, 0);
    ImGui::EndDisabled();
    ImGui::SameLine();
    ImGui::BeginDisabled(loading_.valid());
    if (ImGui::Button(live_status_.running ? "Disconnect" : "Connect MCU")) {
        if (live_status_.running) {
            live_.stop(); record_ = false;
        } else {
            const std::string port(port_);
            bool valid_port = port.size() > 3 && port.size() <= 8 && port.compare(0, 3, "COM") == 0;
            for (std::size_t i = 3; i < port.size(); ++i) valid_port &= port[i] >= '0' && port[i] <= '9';
            if (!valid_port || baud_ <= 0) error_ = "Enter a port such as COM7 and a positive baud rate.";
            else {
                adopt(make_live_data());
                live_mode_ = true; follow_ = true; record_ = false;
                live_.start(port, static_cast<unsigned>(baud_));
            }
        }
    }
    ImGui::EndDisabled();
    ImGui::SameLine();
    ImGui::BeginDisabled(!live_status_.running);
    if (ImGui::Checkbox("Record CSV", &record_)) live_.record(record_);
    ImGui::EndDisabled();
    ImGui::SameLine();
    if (live_mode_) ImGui::Checkbox("Follow Latest", &follow_);
    if (live_mode_) {
        ImGui::SameLine();
        if (ImGui::Checkbox("Show Live Values (50 Hz)", &show_live_values_))
            values_updated_at_ = -1;
    }
    if (live_mode_) {
        ImGui::Text("Frames %llu / Length errors %llu / Display drops %llu / Recording %s",
            static_cast<unsigned long long>(live_status_.frames),
            static_cast<unsigned long long>(live_status_.bad_headers),
            static_cast<unsigned long long>(live_status_.display_drops), live_status_.recording ? "On" : "Off");
        if (!live_status_.error.empty()) ImGui::TextWrapped("Reception error: %s", live_status_.error.c_str());
        if (!live_status_.filename.empty()) ImGui::TextWrapped("Recording file: %s", live_status_.filename.c_str());
    }
    ImGui::TextWrapped("%s  |  %zu rows / %zu channels", data_.name.c_str(),
        data_.seconds.size(), data_.channels.size());
    if (loading_.valid()) ImGui::TextUnformatted("Loading file...");
    if (!error_.empty()) ImGui::TextWrapped("Load failed: %s", error_.c_str());
    if (data_.seconds.empty()) {
        ImGui::TextUnformatted("Waiting for the first MCU frame. Check the port, baud rate, and board transmission.");
        ImGui::End();
        return;
    }

    ImGui::BeginChild("Channels", ImVec2(200, 0), ImGuiChildFlags_Borders);
    ImGui::TextUnformatted("Visible Channels");
    if (ImGui::Button("Select All")) std::fill(selected_.begin(), selected_.end(), true);
    ImGui::SameLine();
    if (ImGui::Button("Clear")) std::fill(selected_.begin(), selected_.end(), false);
    ImGui::Separator();
    for (std::size_t c = 0; c < selected_.size(); ++c) {
        bool checked = selected_[c];
        if (ImGui::Checkbox(data_.channels[c].name.c_str(), &checked)) selected_[c] = checked;
    }
    ImGui::Spacing();
    ImGui::TextWrapped("Left drag: pan\nWheel: zoom\nBottom slider: browse recording");
    ImGui::EndChild();
    ImGui::SameLine();
    ImGui::BeginChild("Plot Area", ImVec2(0, 0));
    if (live_mode_ && show_live_values_) draw_live_values();
    ImGui::SetNextItemWidth(160);
    if (ImGui::InputDouble("Start (s)", &start_, 0.1, 1, "%.3f")) { replay_ = false; follow_ = false; }
    ImGui::SameLine();
    ImGui::SetNextItemWidth(160);
    if (ImGui::InputDouble("Window (s)", &duration_, 0.1, 1, "%.3f")) replay_ = false;
    ImGui::SameLine();
    ImGui::Checkbox("Auto Y", &auto_y_);
    ImGui::SameLine();
    if (ImGui::Button("Full Range")) {
        start_ = data_.seconds.front();
        duration_ = data_.seconds.back() - start_;
        replay_ = false;
    }
    clamp_range();
    ImGui::Text("View %.3f to %.3f s / Full %.3f to %.3f s",
        start_, start_ + duration_, data_.seconds.front(), data_.seconds.back());
    ImGui::BeginChild("Scrollable Plots", ImVec2(0, -70));
    int groups = 0;
    for (auto group : {SignalGroup::Angle, SignalGroup::Torque, SignalGroup::Emg, SignalGroup::Sync, SignalGroup::Other}) {
        bool any = false;
        for (std::size_t c = 0; c < selected_.size(); ++c)
            any |= selected_[c] && data_.channels[c].group == group;
        groups += any ? 1 : 0;
    }
    const float height = std::max(180.0f,
        (ImGui::GetContentRegionAvail().y - 8 * groups) / std::max(1, groups));
    plot_group(SignalGroup::Angle, "Angle", "Angle (deg)", height);
    plot_group(SignalGroup::Torque, "Torque", "Logger-scaled units", height);
    plot_group(SignalGroup::Emg, "EMG", "ADC counts", height);
    plot_group(SignalGroup::Sync, "Sync input", "Low / High", height);
    plot_group(SignalGroup::Other, "Other Channels", "Native units", height);
    if (groups == 0) ImGui::TextUnformatted("Select channels on the left.");
    ImGui::EndChild();
    ImGui::Separator();
    ImGui::TextUnformatted("Browse recording / Drag the slider left or right");
    double minimum = data_.seconds.front();
    double maximum = std::max(minimum, data_.seconds.back() - duration_);
    if (maximum > minimum) {
        ImGui::SetNextItemWidth(-120);
        if (ImGui::SliderScalar("Recording Position", ImGuiDataType_Double,
            &start_, &minimum, &maximum, "%.3f s")) { replay_ = false; follow_ = false; }
    } else ImGui::TextUnformatted("The full recording is displayed.");
    ImGui::EndChild();
    ImGui::End();
}
}

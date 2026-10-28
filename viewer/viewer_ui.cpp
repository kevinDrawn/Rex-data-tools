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
    dialog.lpstrFilter = L"CSV 파일 (*.csv)\0*.csv\0모든 파일 (*.*)\0*.*\0";
    dialog.lpstrFile = path;
    dialog.nMaxFile = static_cast<DWORD>(std::size(path));
    dialog.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST | OFN_NOCHANGEDIR;
    if (GetOpenFileNameW(&dialog)) {
        const std::filesystem::path filename(path);
        loading_ = std::async(std::launch::async, [filename] { return load_csv(filename); });
        replay_ = false;
        error_.clear();
    } else if (CommDlgExtendedError() != 0) {
        error_ = "파일 선택 창을 열지 못했습니다.";
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
        ImPlot::SetupAxes("시간 (초)", unit, ImPlotAxisFlags_NoMenus,
            auto_y_ ? ImPlotAxisFlags_AutoFit : ImPlotAxisFlags_None);
        // 연결된 그래프는 동일한 시간 범위를 사용하며, 사용자의 이동은 다음 프레임에 공유됩니다.
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
            if (!cache.points.x.empty())
                ImPlot::PlotLine(data_.channels[c].name.c_str(), cache.points.x.data(),
                    cache.points.y.data(), static_cast<int>(cache.points.x.size()));
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

void ViewerUi::draw(void* native_window) {
    std::vector<TimedBatch> received;
    live_status_ = live_.drain(received);
    if (live_mode_ && !received.empty()) {
        for (const auto& timed : received) append_live_batch(data_, timed.batch, timed.first_sample);
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
    ImGui::Begin("Rex 데이터 뷰어", nullptr,
        ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoSavedSettings);
    ImGui::TextUnformatted("REX  /  데이터 탐색");
    ImGui::Separator();
    ImGui::BeginDisabled(loading_.valid() || live_status_.running);
    if (ImGui::Button("CSV 열기")) { live_mode_ = false; open(native_window); }
    ImGui::SameLine();
    if (ImGui::Button("샘플 데이터")) { live_mode_ = false; adopt(make_demo()); }
    ImGui::EndDisabled();
    ImGui::SameLine();
    ImGui::BeginDisabled(live_mode_);
    if (ImGui::Button(replay_ ? "재생 일시정지" : "기록 재생")) {
        replay_ = !replay_;
        playhead_ = start_ + duration_;
        if (playhead_ >= data_.seconds.back()) playhead_ = data_.seconds.front();
    }
    ImGui::EndDisabled();
    ImGui::SameLine();
    ImGui::TextDisabled(live_mode_ ? "MCU 수신 · 표시 최근 60초 / 저장 전체 샘플" : "저장된 데이터 탐색·재생");
    ImGui::BeginDisabled(live_status_.running || loading_.valid());
    ImGui::SetNextItemWidth(95);
    ImGui::InputText("포트", port_, sizeof(port_));
    ImGui::SameLine(); ImGui::SetNextItemWidth(110);
    ImGui::InputInt("baud", &baud_, 0);
    ImGui::EndDisabled();
    ImGui::SameLine();
    ImGui::BeginDisabled(loading_.valid());
    if (ImGui::Button(live_status_.running ? "연결 해제" : "MCU 연결")) {
        if (live_status_.running) {
            live_.stop(); record_ = false;
        } else {
            const std::string port(port_);
            bool valid_port = port.size() > 3 && port.size() <= 8 && port.compare(0, 3, "COM") == 0;
            for (std::size_t i = 3; i < port.size(); ++i) valid_port &= port[i] >= '0' && port[i] <= '9';
            if (!valid_port || baud_ <= 0) error_ = "COM7 형식의 포트와 양수 통신 속도를 입력하세요.";
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
    if (ImGui::Checkbox("CSV 저장", &record_)) live_.record(record_);
    ImGui::EndDisabled();
    ImGui::SameLine();
    if (live_mode_) ImGui::Checkbox("최신 구간 추적", &follow_);
    if (live_mode_) {
        ImGui::Text("프레임 %llu / 길이 오류 %llu / 표시 큐 누락 %llu / 저장 %s",
            static_cast<unsigned long long>(live_status_.frames),
            static_cast<unsigned long long>(live_status_.bad_headers),
            static_cast<unsigned long long>(live_status_.display_drops), live_status_.recording ? "진행 중" : "꺼짐");
        if (!live_status_.error.empty()) ImGui::TextWrapped("수신 오류: %s", live_status_.error.c_str());
        if (!live_status_.filename.empty()) ImGui::TextWrapped("저장 파일: %s", live_status_.filename.c_str());
    }
    ImGui::TextWrapped("%s  |  %zu행 / %zu변수", data_.name.c_str(),
        data_.seconds.size(), data_.channels.size());
    if (loading_.valid()) ImGui::TextUnformatted("파일을 읽고 있습니다...");
    if (!error_.empty()) ImGui::TextWrapped("불러오기 실패: %s", error_.c_str());
    if (data_.seconds.empty()) {
        ImGui::TextUnformatted("첫 번째 MCU 프레임을 기다리고 있습니다. 포트·통신 속도와 보드 전송 상태를 확인하세요.");
        ImGui::End();
        return;
    }

    ImGui::BeginChild("변수", ImVec2(200, 0), ImGuiChildFlags_Borders);
    ImGui::TextUnformatted("표시할 변수");
    if (ImGui::Button("전체 선택")) std::fill(selected_.begin(), selected_.end(), true);
    ImGui::SameLine();
    if (ImGui::Button("해제")) std::fill(selected_.begin(), selected_.end(), false);
    ImGui::Separator();
    for (std::size_t c = 0; c < selected_.size(); ++c) {
        bool checked = selected_[c];
        if (ImGui::Checkbox(data_.channels[c].name.c_str(), &checked)) selected_[c] = checked;
    }
    ImGui::Spacing();
    ImGui::TextWrapped("왼쪽 드래그: 이동\n휠: 확대·축소\n아래 막대: 전체 기록 탐색");
    ImGui::EndChild();
    ImGui::SameLine();
    ImGui::BeginChild("그래프 영역", ImVec2(0, 0));
    ImGui::SetNextItemWidth(160);
    if (ImGui::InputDouble("시작 (초)", &start_, 0.1, 1, "%.3f")) { replay_ = false; follow_ = false; }
    ImGui::SameLine();
    ImGui::SetNextItemWidth(160);
    if (ImGui::InputDouble("표시 길이 (초)", &duration_, 0.1, 1, "%.3f")) replay_ = false;
    ImGui::SameLine();
    ImGui::Checkbox("자동 Y축", &auto_y_);
    ImGui::SameLine();
    if (ImGui::Button("전체 구간")) {
        start_ = data_.seconds.front();
        duration_ = data_.seconds.back() - start_;
        replay_ = false;
    }
    clamp_range();
    ImGui::Text("표시 구간 %.3f ~ %.3f 초 / 전체 %.3f ~ %.3f 초",
        start_, start_ + duration_, data_.seconds.front(), data_.seconds.back());
    ImGui::BeginChild("스크롤 그래프", ImVec2(0, -70));
    int groups = 0;
    for (auto group : {SignalGroup::Angle, SignalGroup::Torque, SignalGroup::Emg, SignalGroup::Other}) {
        bool any = false;
        for (std::size_t c = 0; c < selected_.size(); ++c)
            any |= selected_[c] && data_.channels[c].group == group;
        groups += any ? 1 : 0;
    }
    const float height = std::max(180.0f,
        (ImGui::GetContentRegionAvail().y - 8 * groups) / std::max(1, groups));
    plot_group(SignalGroup::Angle, "각도", "도", height);
    plot_group(SignalGroup::Torque, "토크", "기존 로거 환산값", height);
    plot_group(SignalGroup::Emg, "EMG", "ADC 정수값", height);
    plot_group(SignalGroup::Other, "기타 변수", "원래 값", height);
    if (groups == 0) ImGui::TextUnformatted("왼쪽에서 표시할 변수를 선택하세요.");
    ImGui::EndChild();
    ImGui::Separator();
    ImGui::TextUnformatted("전체 기록 탐색 · 막대를 좌우로 드래그하세요");
    double minimum = data_.seconds.front();
    double maximum = std::max(minimum, data_.seconds.back() - duration_);
    if (maximum > minimum) {
        ImGui::SetNextItemWidth(-120);
        if (ImGui::SliderScalar("전체 기록 위치", ImGuiDataType_Double,
            &start_, &minimum, &maximum, "%.3f 초")) { replay_ = false; follow_ = false; }
    } else ImGui::TextUnformatted("전체 기록이 표시되고 있습니다.");
    ImGui::EndChild();
    ImGui::End();
}
}

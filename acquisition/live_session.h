#pragma once
#include "rex_protocol.h"
#include <atomic>
#include <cstdint>
#include <deque>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

namespace rex {
struct TimedBatch { RexBatch batch; uint64_t first_sample; };
struct LiveStatus {
    bool running = false, recording = false;
    uint64_t frames = 0, bad_headers = 0, display_drops = 0;
    std::string error, filename;
};
/* 작업 스레드만 시리얼과 파일을 소유하며 UI에는 배치 사본만 전달합니다. */
class LiveSession {
public:
    ~LiveSession();
    void start(std::string port, unsigned baud);
    void stop();
    void record(bool enabled) { record_requested_ = enabled; }
    LiveStatus drain(std::vector<TimedBatch>& batches);
private:
    void run(const std::string& port, unsigned baud);
    std::thread thread_;
    std::atomic<bool> stop_{false}, record_requested_{false};
    std::mutex mutex_;
    std::deque<TimedBatch> queue_;
    LiveStatus status_;
};
}

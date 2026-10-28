#define _CRT_SECURE_NO_WARNINGS
#include "live_session.h"
#include "frame_parser.h"
#include "csv_writer.h"
#include <windows.h>
#include <chrono>
#include <filesystem>
#include <memory>
#include <stdexcept>

namespace rex {
LiveSession::~LiveSession() { stop(); }
void LiveSession::start(std::string port, unsigned baud) {
    stop();
    {
        std::lock_guard<std::mutex> lock(mutex_);
        queue_.clear(); status_ = {}; status_.running = true;
    }
    stop_ = false;
    record_requested_ = false;
    thread_ = std::thread([this, port, baud] { run(port, baud); });
}
void LiveSession::stop() {
    stop_ = true;
    if (thread_.joinable()) thread_.join();
}
LiveStatus LiveSession::drain(std::vector<TimedBatch>& batches) {
    std::lock_guard<std::mutex> lock(mutex_);
    batches.assign(queue_.begin(), queue_.end());
    queue_.clear();
    return status_;
}

void LiveSession::run(const std::string& port, unsigned baud) {
    HANDLE serial = INVALID_HANDLE_VALUE;
    auto writer = std::make_unique<CsvWriter>();
    using Clock = std::chrono::steady_clock;
    try {
        const std::string path = "\\\\.\\" + port;
        serial = CreateFileA(path.c_str(), GENERIC_READ, 0, nullptr, OPEN_EXISTING,
                             FILE_ATTRIBUTE_NORMAL, nullptr);
        if (serial == INVALID_HANDLE_VALUE) throw std::runtime_error("COM 포트를 열지 못했습니다: " + std::to_string(GetLastError()));
        DCB dcb = {};
        dcb.DCBlength = sizeof(dcb);
        if (!GetCommState(serial, &dcb)) throw std::runtime_error("통신 설정을 읽지 못했습니다.");
        dcb.BaudRate = baud; dcb.ByteSize = 8; dcb.Parity = NOPARITY; dcb.StopBits = ONESTOPBIT;
        dcb.fBinary = TRUE; dcb.fParity = FALSE;
        dcb.fOutxCtsFlow = FALSE; dcb.fOutxDsrFlow = FALSE;
        dcb.fDtrControl = DTR_CONTROL_DISABLE; dcb.fDsrSensitivity = FALSE;
        dcb.fOutX = FALSE; dcb.fInX = FALSE; dcb.fErrorChar = FALSE;
        dcb.fNull = FALSE; dcb.fRtsControl = RTS_CONTROL_DISABLE; dcb.fAbortOnError = FALSE;
        if (!SetCommState(serial, &dcb)) throw std::runtime_error("통신 속도 또는 포트 설정에 실패했습니다.");
        COMMTIMEOUTS timeouts = {};
        timeouts.ReadIntervalTimeout = 1;
        timeouts.ReadTotalTimeoutConstant = 20;
        if (!SetCommTimeouts(serial, &timeouts)) throw std::runtime_error("수신 제한 시간 설정에 실패했습니다.");
        SetupComm(serial, 1 << 20, 1 << 16);
        PurgeComm(serial, PURGE_RXCLEAR);
        FrameParser parser;
        uint64_t sample = 0, record_sample = 0;
        auto record_start = Clock::now();
        auto last_flush = Clock::now();
        bool first_record_sample = true;
        while (!stop_) {
            if (!record_requested_ && writer->file) {
                if (!csv_writer_close(writer.get())) throw std::runtime_error("CSV 닫기에 실패했습니다.");
                std::lock_guard<std::mutex> lock(mutex_);
                status_.recording = false;
            }
            if (record_requested_ && !writer->file) {
                wchar_t executable[32768];
                DWORD size = GetModuleFileNameW(nullptr, executable, 32768);
                if (size == 0 || size >= 32768) throw std::runtime_error("실행 파일 경로를 읽지 못했습니다.");
                auto directory = std::filesystem::path(executable).parent_path() / L"logging";
                std::filesystem::create_directories(directory);
                SYSTEMTIME now; GetLocalTime(&now);
                wchar_t name[128];
                swprintf_s(name, L"rex_live_%04u%02u%02u_%02u%02u%02u_%03u.csv",
                    now.wYear, now.wMonth, now.wDay, now.wHour, now.wMinute, now.wSecond, now.wMilliseconds);
                auto filename = directory / name;
                // Windows의 한글 경로는 와이드 문자 파일 API로 열고 공통 저장기를 연결합니다.
                FILE* file = _wfopen(filename.c_str(), L"wb");
                if (!file) throw std::runtime_error("CSV 파일을 열지 못했습니다.");
                if (!csv_writer_attach(writer.get(), file)) throw std::runtime_error("CSV 헤더 쓰기에 실패했습니다.");
                record_sample = 0; record_start = Clock::now(); last_flush = record_start;
                first_record_sample = true;
                std::lock_guard<std::mutex> lock(mutex_);
                status_.recording = true; status_.filename = filename.u8string();
            }
            uint8_t bytes[4096];
            DWORD got = 0;
            if (!ReadFile(serial, bytes, sizeof(bytes), &got, nullptr))
                throw std::runtime_error("UART 읽기에 실패했습니다: " + std::to_string(GetLastError()));
            std::vector<RexBatch> batches;
            parser.feed(bytes, got, batches);
            {
                std::lock_guard<std::mutex> lock(mutex_);
                status_.bad_headers = parser.bad_headers();
            }
            for (const auto& batch : batches) {
                if (writer->file) {
                    if (first_record_sample) { record_start = Clock::now(); first_record_sample = false; }
                    for (std::size_t i = 0; i < LOG_BATCH_EMG; ++i) {
                        double pc_ms = std::chrono::duration<double, std::milli>(Clock::now() - record_start).count();
                        if (!csv_writer_write_sample(writer.get(), &batch, i,
                            record_sample * (REX_EMG_SAMPLE_PERIOD_US / 1000.0), pc_ms))
                            throw std::runtime_error("CSV 쓰기에 실패했습니다.");
                        ++record_sample;
                    }
                }
                {
                    std::lock_guard<std::mutex> lock(mutex_);
                    // 화면이 느리면 표시용 배치만 버립니다. 파일 저장은 앞에서 완료합니다.
                    if (queue_.size() >= 200) { queue_.pop_front(); ++status_.display_drops; }
                    queue_.push_back({batch, sample});
                    ++status_.frames;
                    status_.bad_headers = parser.bad_headers();
                }
                sample += LOG_BATCH_EMG;
            }
            if (writer->file && Clock::now() - last_flush >= std::chrono::seconds(1)) {
                if (!csv_writer_flush(writer.get())) throw std::runtime_error("CSV 버퍼 저장에 실패했습니다.");
                last_flush = Clock::now();
            }
        }
    } catch (const std::exception& e) {
        std::lock_guard<std::mutex> lock(mutex_);
        status_.error = e.what();
    }
    const bool closed = csv_writer_close(writer.get());
    if (serial != INVALID_HANDLE_VALUE) CloseHandle(serial);
    std::lock_guard<std::mutex> lock(mutex_);
    if (!closed && status_.error.empty()) status_.error = "CSV 마지막 저장에 실패했습니다.";
    status_.running = false; status_.recording = false;
}
}

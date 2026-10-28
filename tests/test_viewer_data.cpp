#undef NDEBUG
#include "log_data.h"
#include "csv_writer.h"
#include "frame_parser.h"
#include <cassert>
#include <cmath>
#include <fstream>
#include <sstream>
#include <stdexcept>

static void reject(const char* csv) {
    std::istringstream input(csv);
    bool rejected = false;
    try { rex::read_csv(input, "invalid"); }
    catch (const std::runtime_error&) { rejected = true; }
    assert(rejected);
}

int main() {
    // 기존 C 저장 모듈이 만든 파일을 C++ 로더로 다시 읽어 경계를 검증합니다.
    static CsvWriter writer;
    RexBatch batch = {};
    batch.qL[0] = 100;
    batch.emg[REX_L_TB][0] = -8388608;
    batch.emg[REX_R_GT][1] = 8388607;
    const char* filename = "viewer_test_roundtrip.csv";
    assert(csv_writer_open(&writer, filename));
    for (std::size_t i = 0; i < LOG_BATCH_EMG; ++i)
        assert(csv_writer_write_sample(&writer, &batch, i, i * 0.5, i * 0.5));
    assert(csv_writer_close(&writer));
    auto data = rex::load_csv(filename);
    std::filesystem::remove(filename);
    assert(data.seconds.size() == 20 && data.channels.size() == 12);
    assert(data.seconds[1] == 0.0005);
    assert(data.channels[8].name == "L_TB_EMG");
    assert(data.channels[8].values[0] == -8388608);
    assert(data.channels[11].values[1] == 8388607);
    assert(data.channels[2].values[0] == data.channels[2].values[1]);

    std::istringstream bom("\xef\xbb\xbfL_deg,time_ms\r\n1,0\r\n2,500\r\n");
    auto reordered = rex::read_csv(bom, "BOM");
    assert(reordered.seconds[1] == 0.5 && reordered.channels[0].values[1] == 2);
    reject("");
    reject("time_ms,L_deg\n");
    reject("time_ms,L_deg\n0,1\n0,2\n");
    reject("time_ms,L_deg\n1,1\n0,2\n");
    reject("time_ms,L_deg\n0,nan\n");
    reject("time_ms,L_deg\n0,1x\n");
    reject("time_ms,L_deg\n0\n");
    reject("time_ms,L_deg\n0,1,2\n");
    reject("L_deg,R_deg\n0,1\n");
    reject("time_ms,L_deg,L_deg\n0,1,2\n");
    reject("time_ms,L_deg\n0,\"1\"\n");

    rex::LogData peaks;
    peaks.channels.push_back({"EMG", rex::SignalGroup::Emg, {}});
    for (int i = 0; i < 10000; ++i) {
        peaks.seconds.push_back(i * 0.0005);
        peaks.channels[0].values.push_back(i == 1700 ? 123456 : (i == 1701 ? -654321 : 0));
    }
    auto visible = rex::visible_points(peaks, 0, 0, 5, 100);
    assert(visible.x.size() <= 400);
    bool positive = false, negative = false;
    for (std::size_t i = 0; i < visible.x.size(); ++i) {
        positive |= visible.y[i] == 123456;
        negative |= visible.y[i] == -654321;
        if (i) assert(visible.x[i] > visible.x[i - 1]);
    }
    assert(positive && negative);
    assert(rex::visible_points(peaks, 99, 0, 1, 100).x.empty());
    assert(rex::visible_points(peaks, 0, 1, 0, 100).x.empty());
    auto demo = rex::make_demo();
    assert(demo.channels.size() == 10 && demo.seconds.size() == 120000);
    auto live = rex::make_live_data();
    rex::append_live_batch(live, batch, 0);
    rex::append_live_batch(live, batch, 40);
    assert(live.seconds.size() == 40);
    assert(live.seconds[20] == 0.020); // 표시 큐에서 배치가 빠져도 원래 수신 샘플 위치를 유지합니다.
    assert(live.channels[6].values[0] == -8388608);
    assert(std::abs(live.channels[0].values[0] - data.channels[2].values[0]) < 1e-6);

    rex::FrameParser parser;
    std::vector<uint8_t> bytes = {0, 0xAA, 0xAA, 0x55, 0x01, 0x00, 0xAA};
    std::vector<uint8_t> frame(FRAME_LEN, 0);
    frame[0] = HDR0; frame[1] = HDR1;
    frame[2] = PAYLOAD_LEN & 0xff; frame[3] = PAYLOAD_LEN >> 8;
    // 잡음, 잘못된 길이, 겹치는 헤더, 바이트 단위 분할 수신, 연속 프레임을 검사합니다.
    bytes.insert(bytes.end(), frame.begin(), frame.end());
    bytes.insert(bytes.end(), frame.begin(), frame.end());
    std::vector<RexBatch> decoded;
    for (auto byte : bytes) parser.feed(&byte, 1, decoded);
    assert(decoded.size() == 2 && parser.bad_headers() == 1);
    assert(decoded[0].emg[0][0] == 0);
    return 0;
}

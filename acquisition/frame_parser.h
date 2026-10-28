#pragma once
#include "rex_protocol.h"
#include <cstdint>
#include <vector>

namespace rex {
/* 통신 장치와 무관하게 분할 수신된 바이트를 프레임으로 조립합니다. */
class FrameParser {
public:
    void feed(const uint8_t* bytes, std::size_t size, std::vector<RexBatch>& output);
    uint64_t bad_headers() const { return bad_headers_; }
private:
    std::vector<uint8_t> pending_;
    uint64_t bad_headers_ = 0;
};
}

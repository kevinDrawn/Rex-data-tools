#include "frame_parser.h"

namespace rex {
void FrameParser::feed(const uint8_t* bytes, std::size_t size, std::vector<RexBatch>& output) {
    if (size == 0) return;
    pending_.insert(pending_.end(), bytes, bytes + size);
    std::size_t offset = 0;
    while (offset + 1 < pending_.size()) {
        if (pending_[offset] != HDR0 || pending_[offset + 1] != HDR1) { ++offset; continue; }
        if (pending_.size() - offset < FRAME_HEADER_SIZE) break;
        const unsigned length = pending_[offset + 2] | (unsigned(pending_[offset + 3]) << 8);
        if (length != PAYLOAD_LEN) { ++bad_headers_; ++offset; continue; }
        if (pending_.size() - offset < FRAME_LEN) break;
        RexBatch batch;
        if (rex_decode_payload(pending_.data() + offset + FRAME_HEADER_SIZE, PAYLOAD_LEN, &batch))
            output.push_back(batch);
        offset += FRAME_LEN;
    }
    pending_.erase(pending_.begin(), pending_.begin() + offset);
}
}

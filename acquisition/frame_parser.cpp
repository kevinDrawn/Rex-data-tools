#include "frame_parser.h"

namespace rex {
void FrameParser::feed(const uint8_t* bytes, std::size_t size, std::vector<RexBatch>& output) {
    if (size == 0) return;
    pending_.insert(pending_.end(), bytes, bytes + size);
    const auto expected = rex_payload_length(format_);
    std::size_t offset = 0;
    while (offset + 1 < pending_.size()) {
        if (pending_[offset] != HDR0 || pending_[offset + 1] != HDR1) { ++offset; continue; }
        if (pending_.size() - offset < FRAME_HEADER_SIZE) break;
        const unsigned length = pending_[offset + 2] | (unsigned(pending_[offset + 3]) << 8);
        if (length != PAYLOAD_LEN && length != REX_TMECH_PAYLOAD_LEN) {
            ++bad_headers_;
            ++offset;
            continue;
        }
        const auto frame_size = FRAME_HEADER_SIZE + length;
        if (pending_.size() - offset < frame_size) break;
        RexBatch batch{};
        if (length != expected) {
            // Skip the other protocol as a whole, even if its samples contain header bytes.
            ++bad_headers_;
        } else if (rex_decode_log_payload(pending_.data() + offset + FRAME_HEADER_SIZE,
                                          length, &batch, format_)) {
            output.push_back(batch);
        }
        offset += frame_size;
    }
    pending_.erase(pending_.begin(), pending_.begin() + offset);
}
}

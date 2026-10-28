#include "rex_protocol.h"

_Static_assert(LOG_BATCH_EMG % LOG_BATCH_EXO == 0,
               "EMG batch must be an integer multiple of EXO batch");
_Static_assert(REX_R_GT + 1 == LOG_EMG_CHANNEL, "EMG channel count mismatch");

static int16_t read_i16_le(const uint8_t *p)
{
    uint32_t raw = (uint32_t)p[0] | ((uint32_t)p[1] << 8);
    return (int16_t)((raw & 0x8000u) ? (int32_t)raw - 65536 : (int32_t)raw);
}

bool rex_decode_payload(const uint8_t *payload, size_t length, RexBatch *batch)
{
    if (payload == NULL || batch == NULL || length != PAYLOAD_LEN) {
        return false;
    }

    int16_t *exo[] = {batch->qL, batch->qR, batch->qMirror,
                     batch->torque_axis, batch->torque_can_L, batch->torque_can_R};
    size_t off = 0;
    /* 송신 규약의 채널 순서대로 연속 샘플을 읽습니다. */
    for (size_t channel = 0; channel < REX_EXO_SIGNALS; ++channel) {
        for (size_t i = 0; i < LOG_BATCH_EXO; ++i) {
            exo[channel][i] = read_i16_le(payload + off);
            off += 2;
        }
    }
    for (size_t channel = 0; channel < LOG_EMG_CHANNEL; ++channel) {
        for (size_t i = 0; i < LOG_BATCH_EMG; ++i) {
            batch->emg[channel][i] = rex_read_i24_be(payload + off);
            off += EMG_WIRE_SAMPLE_BYTES;
        }
    }
    return off == length;
}

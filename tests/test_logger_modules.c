#define _CRT_SECURE_NO_WARNINGS
#undef NDEBUG
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "../protocol/rex_protocol.h"
#include "../acquisition/csv_writer.h"

static CsvWriter writer;

int main(void)
{
    uint8_t payload[PAYLOAD_LEN] = {0};
    RexBatch batch;
    size_t off = 0;
    /* 채널마다 다른 값과 샘플 번호를 넣어 순서와 경계를 확인합니다. */
    for (size_t channel = 0; channel < REX_EXO_SIGNALS; ++channel) {
        for (size_t i = 0; i < LOG_BATCH_EXO; ++i) {
            int value = (int)(channel * 100 + i) - 300;
            uint16_t raw = (uint16_t)value;
            payload[off++] = (uint8_t)raw;
            payload[off++] = (uint8_t)(raw >> 8);
        }
    }
    for (size_t channel = 0; channel < LOG_EMG_CHANNEL; ++channel) {
        for (size_t i = 0; i < LOG_BATCH_EMG; ++i) {
            int32_t value = (int32_t)(channel * 100 + i) - 200;
            uint32_t raw = (uint32_t)value;
            payload[off++] = (uint8_t)(raw >> 16);
            payload[off++] = (uint8_t)(raw >> 8);
            payload[off++] = (uint8_t)raw;
        }
    }
    assert(off == 360 && FRAME_LEN == 364);
    assert(!rex_decode_payload(NULL, PAYLOAD_LEN, &batch));
    assert(!rex_decode_payload(payload, PAYLOAD_LEN - 1, &batch));
    assert(!rex_decode_payload(payload, PAYLOAD_LEN + 1, &batch));
    assert(!rex_decode_payload(payload, PAYLOAD_LEN, NULL));
    assert(rex_decode_payload(payload, PAYLOAD_LEN, &batch));
    int16_t *exo[] = {batch.qL, batch.qR, batch.qMirror, batch.torque_axis,
                     batch.torque_can_L, batch.torque_can_R};
    for (size_t c = 0; c < REX_EXO_SIGNALS; ++c)
        for (size_t i = 0; i < LOG_BATCH_EXO; ++i)
            assert(exo[c][i] == (int)(c * 100 + i) - 300);
    for (size_t c = 0; c < LOG_EMG_CHANNEL; ++c)
        for (size_t i = 0; i < LOG_BATCH_EMG; ++i)
            assert(batch.emg[c][i] == (int32_t)(c * 100 + i) - 200);

    /* 자동으로 정리되는 임시 스트림으로 저장 결과를 검사합니다. */
    writer.file = tmpfile();
    assert(writer.file != NULL);
    assert(!csv_writer_write_sample(&writer, &batch, LOG_BATCH_EMG, 0, 0));
    for (size_t i = 0; i < LOG_BATCH_EMG; ++i)
        assert(csv_writer_write_sample(&writer, &batch, i, i * 0.5, i * 0.25));
    assert(csv_writer_flush(&writer));
    rewind(writer.file);
    for (size_t i = 0; i < LOG_BATCH_EMG; ++i) {
        char line[256], expected[256];
        size_t j = i / 2;
        assert(fgets(line, sizeof(line), writer.file) != NULL);
        /* 분리 이전 수식과 열 순서로 비교합니다. */
        snprintf(expected, sizeof(expected),
            "%.3f,%.3f,%.3f,%.6f,%.6f,%.6f,%.7f,%.7f,%.7f,%d,%d,%d,%d\n",
            i * 0.5, i * 0.25, i * 0.25,
            ((float)batch.qL[j] / 100.0f) * (180.0f / 3.1415926535f),
            ((float)batch.qR[j] / 100.0f) * (180.0f / 3.1415926535f),
            ((float)batch.qMirror[j] / 100.0f) * (180.0f / 3.1415926535f),
            (float)batch.torque_axis[j] / 10000.0f,
            (float)batch.torque_can_L[j] / 10000.0f,
            (float)batch.torque_can_R[j] / 10000.0f,
            (int)batch.emg[0][i], (int)batch.emg[1][i],
            (int)batch.emg[2][i], (int)batch.emg[3][i]);
        assert(strcmp(line, expected) == 0);
    }
    assert(fgetc(writer.file) == EOF);
    assert(csv_writer_close(&writer));
    assert(csv_writer_close(&writer));
    assert(!csv_writer_open(&writer, "missing-directory-for-test/output.csv"));
    return 0;
}

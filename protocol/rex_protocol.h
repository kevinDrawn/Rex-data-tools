#ifndef REX_PROTOCOL_H
#define REX_PROTOCOL_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "rex_emg_wire.h"

/* Central board와 함께 관리하는 전송 규약입니다. */
#define HDR0 0xAAu
#define HDR1 0x55u
#define FRAME_HEADER_SIZE 4u
#define LOG_BATCH_EXO 10u
#define LOG_BATCH_EMG 20u
#define REX_EXO_SIGNALS 6u
#define REX_EMG_SAMPLE_PERIOD_US 500u
#define REX_EMG_PER_EXO (LOG_BATCH_EMG / LOG_BATCH_EXO)
#define PAYLOAD_LEN (LOG_BATCH_EXO * REX_EXO_SIGNALS * 2u + \
                     LOG_BATCH_EMG * LOG_EMG_CHANNEL * EMG_WIRE_SAMPLE_BYTES + LOG_BATCH_EXO)
#define FRAME_LEN (FRAME_HEADER_SIZE + PAYLOAD_LEN)
#define REX_TMECH_EXO_SIGNALS 8u
#define REX_TMECH_SAMPLE_PERIOD_US 1000u
#define REX_TMECH_PAYLOAD_LEN (LOG_BATCH_EXO * (REX_TMECH_EXO_SIGNALS * 2u + 1u))
#define REX_TMECH_FRAME_LEN (FRAME_HEADER_SIZE + REX_TMECH_PAYLOAD_LEN)

typedef enum { REX_LOG_EMG, REX_LOG_TMECH } RexLogFormat;

static inline size_t rex_payload_length(RexLogFormat format)
{
    return format == REX_LOG_TMECH ? REX_TMECH_PAYLOAD_LEN : PAYLOAD_LEN;
}

static inline size_t rex_samples_per_batch(RexLogFormat format)
{
    return format == REX_LOG_TMECH ? LOG_BATCH_EXO : LOG_BATCH_EMG;
}

static inline unsigned rex_sample_period_us(RexLogFormat format)
{
    return format == REX_LOG_TMECH ? REX_TMECH_SAMPLE_PERIOD_US : REX_EMG_SAMPLE_PERIOD_US;
}

typedef enum {
    REX_L_TB = 0, REX_L_GT, REX_R_TB, REX_R_GT
} RexEmgChannel;

/* 단위 변환 전의 원시 측정값입니다. 저장과 뷰어에서 함께 사용할 수 있습니다. */
typedef struct {
    int16_t qL[LOG_BATCH_EXO];
    int16_t qR[LOG_BATCH_EXO];
    int16_t qMirror[LOG_BATCH_EXO];
    int16_t torque_axis[LOG_BATCH_EXO];
    int16_t torque_can_L[LOG_BATCH_EXO];
    int16_t torque_can_R[LOG_BATCH_EXO];
    int32_t emg[LOG_EMG_CHANNEL][LOG_BATCH_EMG];
    uint8_t sync_state[LOG_BATCH_EXO];
    int16_t q_nominal[LOG_BATCH_EXO];
    int16_t q_compensation[LOG_BATCH_EXO];
} RexBatch;

/* 헤더를 제외한 페이로드를 해석합니다. 포인터나 길이가 잘못되면 false입니다. */
#ifdef __cplusplus
extern "C" {
#endif
bool rex_decode_payload(const uint8_t *payload, size_t length, RexBatch *batch);
bool rex_decode_log_payload(const uint8_t *payload, size_t length, RexBatch *batch,
                            RexLogFormat format);
#ifdef __cplusplus
}
#endif

#endif

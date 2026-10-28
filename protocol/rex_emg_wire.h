#ifndef REX_EMG_WIRE_H
#define REX_EMG_WIRE_H
#include <stdint.h>
#define LOG_EMG_CHANNEL 4u
#define EMG_WIRE_SAMPLE_BYTES 3u
/* 상위 바이트부터 전송된 24비트 2의 보수 값을 int32_t로 복원합니다. */
static inline int32_t rex_read_i24_be(const uint8_t *p)
{
    uint32_t raw = ((uint32_t)p[0] << 16) | ((uint32_t)p[1] << 8) | p[2];
    /* 부호 비트가 켜져 있으면 2의 24제곱을 빼서 음수를 복원합니다. */
    return (raw & 0x800000u) ? (int32_t)raw - 16777216 : (int32_t)raw;
}
#endif

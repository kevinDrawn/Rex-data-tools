#ifndef REX_UNITS_H
#define REX_UNITS_H
#include <stdint.h>
/* 기존 로거의 환산식을 저장과 실시간 표시에서 함께 사용합니다. */
static inline float rex_angle_degrees(int16_t raw) {
    return ((float)raw / 100.0f) * (180.0f / 3.1415926535f);
}
static inline float rex_torque_value(int16_t raw) { return (float)raw / 10000.0f; }
#endif

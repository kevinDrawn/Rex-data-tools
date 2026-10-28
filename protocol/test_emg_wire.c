#undef NDEBUG
#include <assert.h>
#include <stddef.h>
#include "rex_emg_wire.h"

int main(void)
{
    /* 0, 양수, 바이트 순서, 양수 최댓값, 음수 최솟값, -2, -1을 확인합니다. */
    const uint8_t wire[][3] = {
        {0x00, 0x00, 0x00}, {0x00, 0x00, 0x01},
        {0x12, 0x34, 0x56}, {0x7f, 0xff, 0xff},
        {0x80, 0x00, 0x00}, {0xff, 0xff, 0xfe}, {0xff, 0xff, 0xff}
    };
    const int32_t expected[] = {0, 1, 1193046, 8388607, -8388608, -2, -1};
    for (size_t i = 0; i < sizeof(expected) / sizeof(expected[0]); ++i) {
        assert(rex_read_i24_be(wire[i]) == expected[i]);
    }
    return 0;
}

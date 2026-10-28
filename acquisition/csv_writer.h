#ifndef REX_CSV_WRITER_H
#define REX_CSV_WRITER_H

#include <stdbool.h>
#include <stdio.h>
#include "../protocol/rex_protocol.h"

#define CSV_BUFFER_SIZE (1024u * 1024u)

/* 큰 버퍼를 포함하므로 정적 영역이나 힙에 두고 사용합니다. */
typedef struct {
    FILE *file;
    char buffer[CSV_BUFFER_SIZE];
    size_t used;
    bool failed;
} CsvWriter;

/* 최초 사용 전에 CsvWriter를 0으로 초기화해야 합니다. 실패는 false로 반환합니다. */
#ifdef __cplusplus
extern "C" {
#endif
bool csv_writer_open(CsvWriter *writer, const char *filename);
/* 성공·실패와 관계없이 전달한 스트림의 소유권을 받습니다. 최초 호출 시 파일이 닫혀 있어야 합니다. */
bool csv_writer_attach(CsvWriter *writer, FILE *file);
bool csv_writer_flush(CsvWriter *writer);
bool csv_writer_close(CsvWriter *writer);
/* 시간은 호출자가 관리합니다. 이 함수는 단위 변환과 한 행의 CSV 생성을 담당합니다. */
bool csv_writer_write_sample(CsvWriter *writer, const RexBatch *batch,
                             size_t emg_index, double time_ms, double actual_time_ms);

#ifdef __cplusplus
}
#endif

#endif

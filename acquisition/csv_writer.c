#define _CRT_SECURE_NO_WARNINGS
#include "csv_writer.h"
#include <inttypes.h>
#include <string.h>
#include "../protocol/rex_units.h"

/* 기존 로거의 변환 계수입니다. 펌웨어의 단위 정의와 대조해야 합니다. */
bool csv_writer_open(CsvWriter *writer, const char *filename)
{
    if (writer == NULL || filename == NULL || writer->file != NULL) return false;
    FILE *file = fopen(filename, "wb");
    if (file == NULL) return false;
    return csv_writer_attach(writer, file);
}

bool csv_writer_attach(CsvWriter *writer, FILE *file)
{
    if (writer == NULL || writer->file != NULL || file == NULL) {
        if (file != NULL) fclose(file);
        return false;
    }
    writer->used = 0;
    writer->failed = false;
    writer->file = file;
    if (fprintf(writer->file,
        "time_ms,actual_time_ms,drift_ms,"
        "L_deg,R_deg,M_deg,Torque_axis,Torque_CAN_L,Torque_CAN_R,"
        "L_TB_EMG,L_GT_EMG,R_TB_EMG,R_GT_EMG\n") < 0) {
        fclose(writer->file);
        writer->file = NULL;
        writer->failed = true;
        return false;
    }
    return true;
}

bool csv_writer_flush(CsvWriter *writer)
{
    if (writer == NULL || writer->file == NULL || writer->failed) return false;
    if (writer->used > 0) {
        if (fwrite(writer->buffer, 1, writer->used, writer->file) != writer->used) {
            writer->failed = true;
            return false;
        }
        writer->used = 0;
    }
    if (fflush(writer->file) != 0) {
        writer->failed = true;
        return false;
    }
    return true;
}

bool csv_writer_close(CsvWriter *writer)
{
    if (writer == NULL) return false;
    if (writer->file == NULL) return !writer->failed;
    bool ok = csv_writer_flush(writer);
    if (fclose(writer->file) != 0) ok = false;
    writer->file = NULL;
    writer->used = 0;
    writer->failed = !ok;
    return ok;
}

bool csv_writer_write_sample(CsvWriter *writer, const RexBatch *batch,
                             size_t emg_index, double time_ms, double actual_time_ms)
{
    if (writer == NULL || writer->file == NULL || writer->failed ||
        batch == NULL || emg_index >= LOG_BATCH_EMG) return false;
    size_t exo_index = emg_index / REX_EMG_PER_EXO;
    char line[256];
    int length = snprintf(line, sizeof(line),
        "%.3f,%.3f,%.3f,%.6f,%.6f,%.6f,%.7f,%.7f,%.7f,"
        "%" PRId32 ",%" PRId32 ",%" PRId32 ",%" PRId32 "\n",
        time_ms, actual_time_ms, time_ms - actual_time_ms,
        rex_angle_degrees(batch->qL[exo_index]), rex_angle_degrees(batch->qR[exo_index]),
        rex_angle_degrees(batch->qMirror[exo_index]), rex_torque_value(batch->torque_axis[exo_index]),
        rex_torque_value(batch->torque_can_L[exo_index]), rex_torque_value(batch->torque_can_R[exo_index]),
        batch->emg[REX_L_TB][emg_index], batch->emg[REX_L_GT][emg_index],
        batch->emg[REX_R_TB][emg_index], batch->emg[REX_R_GT][emg_index]);
    if (length < 0 || (size_t)length >= sizeof(line)) {
        writer->failed = true;
        return false;
    }
    if (writer->used + (size_t)length >= sizeof(writer->buffer) &&
        !csv_writer_flush(writer)) return false;
    memcpy(writer->buffer + writer->used, line, (size_t)length);
    writer->used += (size_t)length;
    return true;
}

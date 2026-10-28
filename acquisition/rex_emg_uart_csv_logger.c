// Windows UART 수신 및 4채널 EMG CSV 저장 로거
#define _CRT_SECURE_NO_WARNINGS

#include <windows.h>
#include <stdint.h>
#include <inttypes.h>
#include "../protocol/rex_protocol.h"
#include "csv_writer.h"
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define COM_PORT_BUFFER_SIZE 32
#define DEFAULT_BAUD_RATE 460800u

static volatile BOOL stop_requested = FALSE;

static CsvWriter writer;

static BOOL WINAPI console_handler(DWORD signal)
{
    if (signal == CTRL_C_EVENT || signal == CTRL_CLOSE_EVENT || signal == CTRL_BREAK_EVENT) {
        stop_requested = TRUE;
        return TRUE;
    }
    return FALSE;
}

static void make_com_path(const char *port, char *out, size_t out_len)
{
    if (strncmp(port, "\\\\.\\", 4) == 0) {
        snprintf(out, out_len, "%s", port);
    } else {
        snprintf(out, out_len, "\\\\.\\%s", port);
    }
}

static HANDLE open_serial(const char *port_name, DWORD baud_rate)
{
    /* Windows 시리얼 포트를 8비트 데이터, 패리티 없음, 정지 비트 1개로 엽니다. */
    char path[64];
    make_com_path(port_name, path, sizeof(path));

    HANDLE h = CreateFileA(path, GENERIC_READ, 0, NULL, OPEN_EXISTING,
                           FILE_ATTRIBUTE_NORMAL, NULL);

    if (h == INVALID_HANDLE_VALUE) {
        fprintf(stderr, "Failed to open %s, err=%lu\n", path, GetLastError());
        return INVALID_HANDLE_VALUE;
    }

    DCB dcb;
    memset(&dcb, 0, sizeof(dcb));
    dcb.DCBlength = sizeof(dcb);

    if (!GetCommState(h, &dcb)) {
        fprintf(stderr, "GetCommState failed\n");
        CloseHandle(h);
        return INVALID_HANDLE_VALUE;
    }

    dcb.BaudRate = baud_rate;
    dcb.ByteSize = 8;
    dcb.Parity = NOPARITY;
    dcb.StopBits = ONESTOPBIT;
    dcb.fDtrControl = DTR_CONTROL_DISABLE;
    dcb.fRtsControl = RTS_CONTROL_DISABLE;

    if (!SetCommState(h, &dcb)) {
        fprintf(stderr, "SetCommState failed, baud=%lu\n", baud_rate);
        CloseHandle(h);
        return INVALID_HANDLE_VALUE;
    }

    COMMTIMEOUTS t;
    memset(&t, 0, sizeof(t));
    t.ReadIntervalTimeout = 1;
    t.ReadTotalTimeoutConstant = 1;
    t.ReadTotalTimeoutMultiplier = 0;
    SetCommTimeouts(h, &t);

    SetupComm(h, 1 << 20, 1 << 16);
    PurgeComm(h, PURGE_RXCLEAR | PURGE_TXCLEAR);

    return h;
}

static bool read_exact(HANDLE h, uint8_t *buf, DWORD len)
{
    DWORD got = 0;

    while (got < len && !stop_requested) {
        DWORD n = 0;
        if (!ReadFile(h, buf + got, len - got, &n, NULL)) {
            return false;
        }

        if (n == 0) {
            Sleep(1);
            continue;
        }

        got += n;
    }

    return got == len;
}

static bool read_one_byte(HANDLE h, uint8_t *b)
{
    DWORD n = 0;
    return ReadFile(h, b, 1, &n, NULL) && n == 1;
}

static bool read_frame(HANDLE h, uint8_t *frame, uint32_t *bad_frames)
{
    /* AA 55 헤더를 찾고 길이를 확인한 뒤 페이로드 전체를 읽습니다. */
    uint8_t b = 0;

    while (!stop_requested) {
        if (!read_one_byte(h, &b)) {
            Sleep(1);
            continue;
        }

        if (b != HDR0) {
            continue;
        }

        if (!read_one_byte(h, &b)) {
            continue;
        }

        if (b != HDR1) {
            continue;
        }

        frame[0] = HDR0;
        frame[1] = HDR1;

        if (!read_exact(h, &frame[2], 2)) {
            return false;
        }

        uint16_t payload_len = (uint16_t)frame[2] | ((uint16_t)frame[3] << 8);

        if (payload_len != PAYLOAD_LEN) {
            (*bad_frames)++;
            continue;
        }

        return read_exact(h, &frame[4], PAYLOAD_LEN);
    }

    return false;
}

static void make_csv_filename(char *out, size_t out_len)
{
    char exe_path[MAX_PATH];
    char logging_dir[MAX_PATH];
    char timestamp[64];

    time_t now = time(NULL);
    struct tm *tm_info = localtime(&now);
    strftime(timestamp, sizeof(timestamp),
             "rex_uart_%y%m%d_%H%M%S.csv", tm_info);

    DWORD len = GetModuleFileNameA(NULL, exe_path, MAX_PATH);
    if (len == 0 || len >= MAX_PATH) {
        snprintf(out, out_len, "%s", timestamp);
        return;
    }

    char *last_slash = strrchr(exe_path, '\\');
    if (last_slash == NULL) {
        snprintf(out, out_len, "%s", timestamp);
        return;
    }

    *last_slash = '\0';
    snprintf(logging_dir, sizeof(logging_dir),
             "%s\\logging", exe_path);

    if (!CreateDirectoryA(logging_dir, NULL) &&
        GetLastError() != ERROR_ALREADY_EXISTS) {
        fprintf(stderr, "Failed to create logging directory, err=%lu\n",
                GetLastError());
        snprintf(out, out_len, "%s", timestamp);
        return;
    }

    snprintf(out, out_len, "%s\\%s", logging_dir, timestamp);
}

int main(int argc, char **argv)
{
    char port_name[COM_PORT_BUFFER_SIZE];
    DWORD baud_rate = DEFAULT_BAUD_RATE;
    const bool interactive = (argc == 1);
    char input[128];

    for (;;) {
        if (interactive) {
            printf("COM port (e.g. COM7 or 7): ");
            fflush(stdout);
            if (fgets(input, sizeof(input), stdin) == NULL) {
                return 1;
            }
            if (strchr(input, '\n') == NULL && !feof(stdin)) {
                int ch;
                while ((ch = getchar()) != '\n' && ch != EOF) {}
                fprintf(stderr, "Port name is too long.\n");
                continue;
            }
        } else {
            if (strlen(argv[1]) >= sizeof(input)) {
                fprintf(stderr, "Port name is too long.\n");
                return 1;
            }
            strcpy(input, argv[1]);
        }

        char *p = input;
        while (*p == ' ' || *p == '\t') ++p;
        if (strncmp(p, "\\\\.\\", 4) == 0) p += 4;
        if (_strnicmp(p, "COM", 3) == 0) p += 3;
        char *digits = p;
        unsigned long number = 0;
        while (*p >= '0' && *p <= '9') {
            number = number * 10 + (unsigned long)(*p++ - '0');
            if (number > 65535) break;
        }
        bool has_digits = (p != digits);
        while (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n') ++p;
        if (has_digits && *p == '\0' && number > 0 && number <= 65535) {
            snprintf(port_name, sizeof(port_name), "COM%lu", number);
            break;
        }
        fprintf(stderr, "Enter a COM port number from 1 to 65535.\n");
        if (!interactive) return 1;
    }

    if (argc >= 3) {
        baud_rate = (DWORD)strtoul(argv[2], NULL, 10);
    }

    SetConsoleCtrlHandler(console_handler, TRUE);

    HANDLE serial = open_serial(port_name, baud_rate);
    if (serial == INVALID_HANDLE_VALUE) {
        if (interactive) {
            printf("Check the port and close other serial apps. Press Enter to exit.");
            getchar();
        }
        return 1;
    }

    double first_actual_time_ms = 0.0;
    bool first_sample = true;

    LARGE_INTEGER qpc_frequency;
    LARGE_INTEGER logging_start_qpc = {0};

    QueryPerformanceFrequency(&qpc_frequency);

    printf("Rex UART CSV logger\n");
    printf("Port=%s baud=%lu\n", port_name, baud_rate);
    printf("Payload=%u bytes, frame=%u bytes\n", (unsigned)PAYLOAD_LEN, (unsigned)FRAME_LEN);
    printf("F10: start logging, F11: stop logging, Ctrl+C: exit\n");

    uint8_t frame[FRAME_LEN];

    char csv_filename[MAX_PATH] = {0};

    bool logging_active = false;
    uint64_t time_us = 0;

    uint32_t frames_per_sec = 0;
    uint32_t rows_per_sec = 0;
    uint32_t bad_frames = 0;
    uint32_t last_bad_frames = 0;

    int32_t latest_tb = 0;
    int32_t latest_r_tb = 0;
    int32_t latest_gt = 0;
    int32_t latest_r_gt = 0;

    DWORD last_print = GetTickCount();
    DWORD last_f10 = 0;
    DWORD last_f11 = 0;

    while (!stop_requested) {
        DWORD now = GetTickCount();

        if ((GetAsyncKeyState(VK_F10) & 0x8000) && (now - last_f10 > 500)) {
            last_f10 = now;

            if (!logging_active) {
                make_csv_filename(csv_filename, sizeof(csv_filename));
                if (csv_writer_open(&writer, csv_filename)) {
                    printf("Logging STARTED: %s\n", csv_filename);
                    logging_active = true;
                    time_us = 0;
                    first_sample = true;

                    QueryPerformanceCounter(&logging_start_qpc);
                } else {
                    fprintf(stderr, "Failed to open CSV file\n");
                }
            }
        }

        if ((GetAsyncKeyState(VK_F11) & 0x8000) && (now - last_f11 > 500)) {
            last_f11 = now;

            if (logging_active) {
                if (!csv_writer_close(&writer)) {
                    fprintf(stderr, "CSV close failed\n");
                }
                printf("Logging STOPPED\n");
                logging_active = false;
            }
        }

        if (!read_frame(serial, frame, &bad_frames)) {
            continue;
        }

        /* 송신 순서에 따라 EXO 6개 신호와 EMG 4개 채널을 복원합니다. */
        RexBatch batch;
        if (!rex_decode_payload(frame + FRAME_HEADER_SIZE, PAYLOAD_LEN, &batch)) {
            ++bad_frames;
            continue;
        }

        frames_per_sec++;

        if (logging_active) {
            for (int emg_idx = 0; emg_idx < (int)LOG_BATCH_EMG; emg_idx++) {
                LARGE_INTEGER qpc_now;
                QueryPerformanceCounter(&qpc_now);

                double actual_time_ms =
                    (double)(qpc_now.QuadPart - logging_start_qpc.QuadPart)
                    * 1000.0
                    / (double)qpc_frequency.QuadPart;

                if (first_sample) {
                    first_actual_time_ms = actual_time_ms;
                    first_sample = false;
                }

                actual_time_ms -= first_actual_time_ms;

                double logging_time_ms = (double)time_us / 1000.0;
                if (!csv_writer_write_sample(&writer, &batch, (size_t)emg_idx,
                                             logging_time_ms, actual_time_ms)) {
                    fprintf(stderr, "CSV write failed; logging stopped\n");
                    csv_writer_close(&writer);
                    logging_active = false;
                    break;
                }

                latest_tb = batch.emg[REX_L_TB][emg_idx];
                latest_r_tb = batch.emg[REX_R_TB][emg_idx];
                latest_gt = batch.emg[REX_L_GT][emg_idx];
                latest_r_gt = batch.emg[REX_R_GT][emg_idx];

                /* 수신 샘플 수 기준의 명목 시간이며 유실된 프레임 시간은 포함하지 않습니다. */
                time_us += REX_EMG_SAMPLE_PERIOD_US;
                rows_per_sec++;
            }
        } else {
            latest_tb = batch.emg[REX_L_TB][LOG_BATCH_EMG - 1];
            latest_r_tb = batch.emg[REX_R_TB][LOG_BATCH_EMG - 1];
            latest_gt = batch.emg[REX_L_GT][LOG_BATCH_EMG - 1];
            latest_r_gt = batch.emg[REX_R_GT][LOG_BATCH_EMG - 1];
        }

        now = GetTickCount();
        if (now - last_print >= 1000) {
            uint32_t bad_delta = bad_frames - last_bad_frames;
            last_bad_frames = bad_frames;

            if (logging_active) {
                if (!csv_writer_flush(&writer)) {
                    fprintf(stderr, "CSV flush failed; logging stopped\n");
                    csv_writer_close(&writer);
                    logging_active = false;
                }
            }

            printf("frames=%u/s rows=%u/s bad=%u/s logging=%s L_TB=%" PRId32 " L_GT=%" PRId32 " R_TB=%" PRId32 " R_GT=%" PRId32 "\n",
                   frames_per_sec,
                   rows_per_sec,
                   bad_delta,
                   logging_active ? "ON" : "OFF",
                   latest_tb,
                   latest_gt, latest_r_tb, latest_r_gt);

            frames_per_sec = 0;
            rows_per_sec = 0;
            last_print = now;
        }
    }

    if (!csv_writer_close(&writer)) {
        fprintf(stderr, "CSV close failed\n");
    }
    CloseHandle(serial);

    printf("\nProgram stopped\n");
    return 0;
}

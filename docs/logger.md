# Windows UART 데이터 로거

프로젝트 루트에서 MSYS2 UCRT64 터미널을 열고 빌드합니다.

```sh
gcc -std=c11 -O2 -Wall -Wextra acquisition/rex_emg_uart_csv_logger.c acquisition/csv_writer.c protocol/rex_protocol.c -o acquisition/rex_logger.exe -luser32
./acquisition/rex_logger.exe COM7 460800
```

인수 없이 실행하면 COM 포트를 입력받습니다. F10은 저장 시작, F11은 저장 중지,
Ctrl+C는 종료입니다. CSV는 실행 파일 옆의 `logging/` 폴더에 생성됩니다.

## 데이터와 시간축

- EMG 열은 `L_TB_EMG`, `L_GT_EMG`, `R_TB_EMG`, `R_GT_EMG`입니다.
- 한 행의 명목 시간 간격은 0.5 ms이며 EXO 값 하나는 두 행에 반복됩니다.
- 각도와 토크 변환 계수는 기존 코드에서 가져왔으므로 펌웨어 단위와 대조해야 합니다.
- EMG는 변환 전 ADC 정수값입니다. 24비트라는 정보만으로 전압 단위를 정할 수 없습니다.
- `time_ms`는 수신한 샘플 수로 계산한 시간입니다.
- `actual_time_ms`는 PC 처리 시각이며 보드의 측정 시각이 아닙니다.
- `drift_ms`는 위 두 시간의 차이로, 일괄 전송과 버퍼링, PC 실행 지연도 포함합니다.

프레임 유실 시 현재 명목 시간축에는 누락 시간이 반영되지 않습니다.
보드가 전송을 멈추면 수신 대기로 단축키 처리가 지연될 수 있습니다.
헤더와 길이 확인은 체크섬을 대신하지 않습니다. CSV 열기·쓰기·닫기 실패는 보고하며,
쓰기나 주기적 버퍼 저장에 실패하면 로깅을 중지합니다.
실제 측정 전에 빌드와 보드 연결 시험이 필요합니다.

## 디코더 확인

다음 테스트는 바이트 순서와 양수·음수 경계값을 확인합니다.
전체 UART 수신이나 CSV 저장을 검증하는 테스트는 아닙니다.

```sh
gcc -std=c11 -Wall -Wextra protocol/test_emg_wire.c -o protocol/test_emg_wire.exe
./protocol/test_emg_wire.exe
```

모듈 통합 테스트는 전체 채널 순서, 잘못된 페이로드 길이, 기존 CSV 수식·열 순서,
EMG와 EXO 샘플 대응 관계를 확인합니다. 프로젝트 루트에서 실행합니다.

```sh
gcc -std=c11 -Wall -Wextra tests/test_logger_modules.c acquisition/csv_writer.c protocol/rex_protocol.c -o tests/test_logger_modules.exe
./tests/test_logger_modules.exe
```

이제 로거는 여러 `.c` 파일을 함께 빌드해야 합니다. IDE의 현재 파일만 실행하는 기능을
사용하면 다른 모듈의 함수 정의를 찾지 못할 수 있으므로 위 명령을 사용하세요.

## 확장 방향

초기에는 MATLAB과 뷰어에서 읽기 쉬운 CSV를 사용합니다. 장시간 측정에는 원본 바이너리와
메타데이터를 함께 저장하고 분석 시 CSV나 HDF5로 변환하는 방식을 고려할 수 있습니다.
메타데이터에는 프로토콜 버전, 샘플링 주파수, 채널명·단위, 보정 계수, 펌웨어 버전,
측정 시작 시각을 기록합니다.

전체 샘플 저장은 화면 갱신과 독립적으로 수행해야 합니다. 뷰어는 예를 들어 초당 20~60회
갱신하고 구간별 최솟값·최댓값을 표시하면 많은 샘플의 피크를 보존할 수 있습니다.
향후 EXO와 EMG 시간축을 분리하면 EXO 값의 중복 저장을 줄일 수 있습니다.

모듈 분리 제안은 [코드 구조 설명](architecture.md)을 참고하세요.

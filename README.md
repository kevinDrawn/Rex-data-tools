# Rex 데이터 도구

Rex 측정 데이터의 수신·저장, 실시간 표시, 분석을 위한 저장소입니다.
Windows UART CSV 로거와 24비트 EMG 디코더, ImGui·ImPlot 기반 파일·실시간 뷰어를 제공합니다.
분석 기능은 향후 구현 예정입니다.

## 로거 실행

| 실행 파일 | 연결할 Central 펌웨어 |
| --- | --- |
| `exec/EMG/rex_viewer.exe` | 2 kHz EMG가 포함된 기존 374바이트 프레임 |
| `exec/EMG/rex_logger.exe` | 기존 EMG 콘솔 로거 |
| `exec/TMECH_2026/rex_tmech_viewer.exe` | TMECH 리뷰용 1 kHz, 174바이트 프레임 |

Release 빌드 후 저장소 루트에서 `cmake --install build --config Release --prefix "$PWD"`를
실행하면 위 실행 파일이 배치됩니다. [GUI 빌드와 사용법](viewer/README.md)을 참고하세요.

| 폴더 | 역할 |
| --- | --- |
| `acquisition/` | UART 수신과 CSV 저장 |
| `protocol/` | 패킷 명세, 공통 측정 자료형과 해석 모듈 |
| `tests/` | 프레임 조립·CSV 저장과 읽기·뷰어 데이터 테스트 |
| `viewer/` | CSV 탐색, 변수·시간 범위 선택, MCU 실시간 그래프 |
| `analysis/` | 향후 필터링·통계·EMG 분석 |
| `docs/` | 사용법과 설계 설명 |
| `examples/` | 향후 작은 예제 데이터와 설정 |

- [빌드와 실행 방법](docs/logger.md)
- [GUI 빌드와 사용법](viewer/README.md)
- [UART 패킷 명세](protocol/README.md)
- [현재 코드 구조와 모듈화 방향](docs/architecture.md)

# MATLAB Data Packing

`DataPacker`는 프로젝트 config와 CSV 열 매핑을 사용해 로깅 데이터를 공통 구조로 패킹합니다.

## 파일 구성

- `Class/DataPacker.m`: CSV 읽기, 열 매핑 검증, 데이터 패킹 및 MAT 저장
- `Class/config/RexConfig.m`: Rex의 목표 필드 경로 10개 정의
- `Class/DataPlotter.m`: 데이터 그룹별 subplot 및 시간 범위 선택
- `Class/config/PlotConfig.m`: 그래프 스타일과 좌우 신호 색상 정의
- `Class/DataProcessor.m`: 지정한 raw EMG 처리와 MAT 파일 확장
- `Class/config/EMGConfig.m`: ADC, 샘플링 주파수 및 EMG 필터 설정
- `exec/packLoggingData.m`: CSV 경로와 열 번호를 지정하는 실행 프로그램

## 사용 방법

`exec/packLoggingData.m`을 열고 다음 설정을 수정한 뒤 스크립트 전체를 실행합니다.
`Class` 폴더는 스크립트 위치를 기준으로 MATLAB 경로에 자동 추가됩니다.

1. `LOGGING_PATH = "D:/logging/session01.csv";`처럼 CSV의 절대경로를 지정합니다.
2. `PROJECT_TYPE = "Rex";`로 프로젝트를 선택합니다.
3. `columnMap`의 10개 `NaN`을 해당 CSV의 열 번호로 바꿉니다.
4. 실행하면 CSV와 같은 폴더에 같은 이름의 MAT 파일이 저장되고, 저장된 데이터를 그래프로 표시합니다.

예: `D:/logging/session01.csv` → `D:/logging/session01.mat`.
다른 위치에 저장하려면 `MAT_PATH`에 MAT 파일의 절대경로를 입력합니다.
저장할 폴더는 미리 존재해야 합니다.

열 번호는 1부터 시작하며 CSV에서 읽은 테이블의 열 순서를 기준으로 합니다.
원본 CSV에 사용하지 않는 추가 열이 있어도 됩니다.

예를 들어 시간이 CSV의 3열, Left 각도가 7열이면 스크립트에서 다음처럼 지정합니다.

```matlab
columnMap.Time = 3;
columnMap.Left.Angle = 7;
```

나머지 항목도 모두 지정해야 합니다. 클래스는 `getColumnMap()`으로 프로젝트 config에서
매핑 구조를 만들며, 미지정된 열 번호(`NaN`)는 패킹 시 오류로 검출합니다.
실행 스크립트의 처리 순서는 다음과 같습니다.

```matlab
packer = DataPacker(PROJECT_TYPE);
columnMap = packer.getColumnMap();
% columnMap의 모든 항목에 CSV 열 번호 지정
data = packer.pack(LOGGING_PATH, columnMap, CSV_READ_OPTIONS{:});
packer.saveMat(data, MAT_PATH);
```

`columnMap`은 결과 `data`와 같은 필드 구조를 가지며, 각 값은 CSV 열 번호입니다.
전체 매핑 항목은 `exec/packLoggingData.m`을 참고하세요.
헤더 등 CSV 읽기 옵션은 `pack`의 추가 인수로 `readtable`에 전달할 수 있습니다.
CSV 헤더는 MATLAB의 자동 감지를 사용하므로 실제 파일에 맞는 옵션을 지정하세요.
헤더가 없는 CSV는 실행 스크립트에서
`CSV_READ_OPTIONS = {'ReadVariableNames', false};`로 설정할 수 있습니다.

MAT 파일에는 `data`라는 구조체 변수가 저장됩니다.

```text
data
  Time
  Left
    Angle
    Torque
    TA
    GM
  Right
    Angle
    Torque
    TA
    GM
  Assisted
    Angle
```

모든 데이터는 같은 길이의 숫자 N×1 벡터입니다. 단위 변환, 필터링,
리샘플링은 수행하지 않습니다. 숫자형 결측값(NaN)은 그대로 보존합니다.
`saveMat`은 MATLAB `save`의 기본 동작에 따라 같은 경로의 기존 파일을 덮어씁니다.

새 프로젝트를 추가할 때는 `Class/config/<프로젝트명>Config.m` 함수를 추가하고
반환 구조체에 `ProjectType`과 `Fields`를 정의합니다. 클래스는 프로젝트명으로
config를 조회합니다. config에는 CSV 열 번호를 저장하지 않습니다.
실행 스크립트의 프로젝트 타입과 열 매핑도 해당 프로젝트에 맞게 변경합니다.

## 그래프 설정

`exec/packLoggingData.m`의 `PLOT_TIME_RANGE`에 `[시작 끝]`을 지정합니다.
단위는 `data.Time`과 같으며 단위 변환이나 시간축 초기화는 하지 않습니다.
예를 들어 시간이 ms이면 `[1000 5000]`은 1초부터 5초까지입니다.
`[]`는 전체 범위입니다. 구간의 양 끝 샘플도 포함하며, 샘플이 없는 범위는 오류로 알립니다.

`PLOT_DIRECTION`은 `"vertical"`이면 N행×1열, `"horizontal"`이면 1행×N열입니다.
기본 실행 예제는 각도(Left/Right), 토크(Left/Right), 왼쪽 근육(TA/GM),
오른쪽 근육(TA/GM)의 4개 그룹을 위에서 아래로 표시합니다.

클래스의 함수 입력은 다음과 같습니다. 중괄호 안의 각 행렬이 하나의 subplot이고,
행렬의 각 열은 같은 축에 그려지는 곡선입니다.

```matlab
plotter = DataPlotter();
groups = {[data.Left.Angle, data.Right.Angle], ...
          [data.Left.Torque, data.Right.Torque]};
[fig, ax] = plotter.plotGroups(data.Time, groups, [1000 5000], 'vertical', ...
    'Titles', {'Angle', 'Torque'}, ...
    'Legends', {{'Left', 'Right'}, {'Left', 'Right'}});
```

추가 옵션은 `YLabels`(그룹별 셀), `Colors`(그룹별 RGB 행렬 셀), `XLabel`, `Visible`입니다.
범례와 색상을 지정하면 곡선의 열 순서대로 적용합니다.
`Class/config/PlotConfig.m`에서 Box off, Grid off, FontSize 20,
FontName Times New Roman과 선 굵기·색상을 변경할 수 있습니다.
각도·토크는 Left 파랑/Right 빨강, 근육은 좌우 구분 없이 TA 초록/GM 보라를 사용합니다.
배경은 흰색입니다.
데이터 단위는 아직 확정되지 않았으므로 축에 각도·토크의 단위를 임의로 붙이지 않습니다.

기존 MAT 파일만 다시 그리려면 실행 스크립트에서 `Class` 경로를 추가한 뒤
`MAT_PATH`를 지정하고 마지막 `Plot the saved MAT file` 섹션을 실행하면 됩니다.
이때 `PLOT_TIME_RANGE`와 `PLOT_DIRECTION`도 먼저 지정합니다.

## EMG 신호 처리

실행 스크립트의 `EMG_FIELDS`에서 처리할 raw 필드를 지정합니다.
`EMG_SAMPLE_RATE_HZ`는 기본 2000 Hz이며 로거의 0.5 ms 샘플 간격을 기준으로 합니다.
실행 스크립트는 네 채널(Left/Right TA/GM)을 모두 처리한 뒤 처리 결과를 그립니다.
MAT 저장 후, 그래프 생성 전에 처리합니다.

```matlab
processor = DataProcessor();
data = processor.processEMGMat(MAT_PATH, {'Left.TA', 'Right.GM'}, 2000);
% 추가 결과: data.Left.TA_filtered, data.Right.GM_filtered

% 메모리의 raw 신호만 처리할 수도 있습니다. 이 호출은 파일에 저장하지 않습니다.
envelope = processor.filterEMG(data.Left.TA, 2000);
```

이미 생성한 MAT 파일에도 `Class` 경로를 추가한 뒤 위 메서드를 호출할 수 있습니다.
선택한 raw 필드는 보존되고 같은 위치에 `_filtered` 필드가 추가됩니다.
동일한 결과 필드가 이미 있으면 raw에서 다시 계산해 해당 결과만 갱신합니다.
선택하지 않은 필드와 MAT 파일의 다른 변수는 유지됩니다.
`EMGProcessing`이라는 MAT 변수에 결과별 config, 원본 필드명, 샘플링 주파수와 단위를 기록합니다.
`data`에 결과를 추가한 뒤에는 원본 10개 필드만 허용하는 `DataPacker.saveMat` 대신
`processEMGMat`으로 결과를 저장하세요.

처리 순서는 다음과 같습니다.

1. 부호 있는 24비트 ADC 정수 → V 단위 환산
2. 15–500 Hz Butterworth 대역통과
3. 절댓값을 취하는 전파 정류
4. 10 Hz, 4차 Butterworth 저역통과로 envelope 생성

`EMGConfig.m`의 기본값은 `VRef = 2.4`, `ADCGain = 8`입니다.
전압 환산은 bipolar two's-complement ADC를 가정한
`raw × VRef / (ADCGain × 2^(ADCBits-1))`입니다.
하드웨어 PGA gain 8을 반영해 입력 전압으로 환산합니다.
이 설정은 ADC 앞단 회로 전체의 전압 보정을 대신하지 않습니다.

대역통과의 단방향 총 차수는 우선 4차로 설정했습니다(`butter` 입력 차수는 2).
저역통과 설계 차수는 요청한 4차입니다. 기본 `ZeroPhase = true`는 SOS 형태의
`filtfilt`로 양방향 처리하므로 위상 지연을 줄이며, 실효 차수는 각 설계 차수의 두 배가 됩니다.
단방향 필터가 필요하면 config에서 `ZeroPhase = false`로 변경합니다.
참고: [Butterworth 설계](https://www.mathworks.com/help/signal/ref/butter.html),
[양방향 필터링](https://www.mathworks.com/help/signal/ref/filtfilt.html).

Signal Processing Toolbox가 필요합니다. raw 값은 유한한 signed ADC 정수여야 합니다.
결측값이나 범위 밖의 값은 임의 보간하지 않고 오류로 알립니다.
MAT 처리 시 `data.Time`이 지정 주파수로 균일하게 샘플링됐는지도 확인합니다.
기본 시간 단위는 ms이며, 초 단위 MAT는 config의 `TimeScaleToSeconds = 1`로 변경합니다.
전체 신호를 처리한 뒤 plotting에서 시간 범위를 선택합니다.
그래프의 근육 그룹은 `TA_filtered`와 `GM_filtered`를 사용하며 축 단위는 V입니다.
각도와 토크는 기존 데이터를 표시하고, raw EMG는 MAT 파일에 보존합니다.

## 검증 실행 방법

MATLAB에서 이 폴더를 현재 폴더로 지정한 뒤 실행합니다.

```matlab
addpath('tests');
testDataPacker;
testDataPlotter;
testDataProcessor;
```

열 순서가 다른 두 CSV의 패킹 결과, 각 필드 값, MAT 저장 및 재로드,
누락/추가 매핑, 열 번호 범위, 데이터 길이 오류를 확인합니다.
그래프 검증은 화면에 창을 표시하지 않고 곡선 값, 시간 범위, 배치 방향, 스타일과 색상을 확인합니다.
EMG 검증은 합성 신호의 envelope 크기, 대역 밖 신호 억제, 선택 필드 처리,
원본 및 다른 MAT 변수 보존, 오류 발생 시 미저장을 확인합니다.

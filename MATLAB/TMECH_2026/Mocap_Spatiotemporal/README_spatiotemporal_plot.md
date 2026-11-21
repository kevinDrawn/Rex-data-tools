# Foot-drop 지표와 통계 통합 실행

MATLAB Current Folder를 이 `TMECH_2026/Mocap_Spatiotemporal` 폴더로 둡니다.
공통 입력 경로와 분석 설정은 `function/footdrop_config.m`에서 한 번만 지정합니다.
`Class`는 이 프로젝트의 상위 폴더를 탐색해 `MATLAB/Class`에 연결합니다.

```matlab
exec_oneshot_footdrop_function
exec_oneshot_footdrop_statistics
```

## 지표 집계와 그래프

`exec_oneshot_footdrop_function.m`은 다음 세 집계를 순서대로 실행합니다.

1. Paw clearance: 기존 paw/trajectory MAT와 각 recording의 `time_range.txt`를 읽어
   complete IC-to-IC cycle을 집계합니다. 기본 그래프는 각 rat의 평균 toe trajectory
   최대 높이(`MeanTrajectoryPeakHeight`)입니다. 개별 cycle 최대 높이의 평균인
   `MeanPeakPawHeight`와 구분합니다.
2. Swing dorsiflexion: `exp_data.mat`의 Hall angle과 이미 정렬된 IC/TO 이벤트에서
   complete swing의 최소 angle을 집계합니다. Baseline Hall 데이터가 없으면 NaN/N=0을
   유지합니다. 그래프에는 LE/LR을 표시합니다.
3. Dragging incidence: 기존 Excel의 관찰 횟수를 읽고 원본 MAT의 full-video detected
   swing 수로 나눕니다. 관찰된 open trailing swing을 포함하고 paw의 time range를
   분모에 적용하지 않습니다. 그래프에는 LE/LR을 표시합니다.

원본 CSV 추출, 추가 필터링, 자동 이상치 제거, 개별 쥐 진단 그래프는 실행하지 않습니다.
기존 `Paw Clearance`, `Dorsiflexion angle`, `Dragging Incidence`의 개별 분석 파일은
참고 및 개별 작업용으로 보존합니다. 원본 CSV/주석을 변경했다면 해당 전처리부터 갱신합니다.

출력은 기존 개별 exporter 결과를 덮어쓰지 않는
`Spatiotemporal_Index/_combined/footdrop_function`에 저장됩니다.

- `metrics/`: 세 지표의 전체 집계 MAT (`data` 변수), cycle/event/source provenance 포함
- `spatiotemporal_indices.mat`: 세 지표, 개체값, 그룹 요약, 정확한 입력 파일 및 설정
- `paw_clearance.fig/png`, `swing_dorsiflexion.fig/png`, `dragging_incidence.fig/png`: 지표별 독립 Figure
- `*_by_rat.csv`, `*_all_cycles.csv`, `*_all_swings.csv`, `*_source_counts.csv`: 확인용 표

그룹 평균과 SD는 rat별 값에 같은 가중치를 적용합니다. RatID/조건 이름으로 대응시키고
누락값은 NaN으로 유지합니다. 모든 단계에서 기존 Class 구현을 재사용합니다.

## 통계

`exec_oneshot_footdrop_statistics.m`은 저장된 `spatiotemporal_indices.mat`만 읽습니다.
원본 신호를 다시 처리하거나 다른 exporter의 값을 섞지 않습니다.
분석 후 설정의 PawMetric을 바꾸면 재집계를 요구합니다.
Statistics and Machine Learning Toolbox가 필요합니다.

- Paw: 기본 IE/LE/LR의 rat별 **그래프와 같은 지표 값**으로 기존
  `PawClearanceCollector.analyzeStatistics`를 호출합니다. Friedman 및 paired t /
  exact signed-rank, pairwise Holm 결과를 저장합니다. complete rat를 사용합니다.
- Dorsiflexion/dragging: 기존 `SpatiotemporalIndexAssembler.analyzeAssistance`의
  LE/LR paired t, exact signed-rank, paired sign-permutation 및 sign test를 유지합니다.
  두 endpoint에 대한 Holm 보정은 방법별로 적용합니다.
- 두 통계 family는 별도로 보정합니다. 모든 검정이 양측이며, 신뢰구간은 보정 전
  paired-t 95% CI입니다. 개별 step을 독립된 rat로 취급하지 않습니다.

Paw의 기본 통계 endpoint는 평균 trajectory의 최대 높이입니다. 기존
`exec_collect_paw_clearance`의 open swing 포함 cycle-peak 평균과는 다른 지표이므로,
예전 paw 통계값과 직접 같은 결과라고 간주하지 않습니다. 선택한 지표와 정의를 MAT에
기록합니다. 비교 조건은 `cfg.PawStatisticsConditions`에서 명시합니다.

통계 출력은 `footdrop_function/statistics`에 저장됩니다.

- `footdrop_statistics.mat`: Paw와 assistance 통계를 합친 단일 bundle
- `paw_clearance_pairwise.csv`, `paw_clearance_omnibus.csv`
- `assistance_statistics.csv`, `assistance_paired_differences.csv`
- `analyzed_rat_values.csv`: 분석에 사용한 rat별 값

## Batch 실행 설정 재정의

기본 설정을 파일 수정 없이 재정의하려면 실행 전에 명시적으로 지정합니다.

```matlab
addpath('function');
FOOTDROP_CONFIG = footdrop_config(pwd);
FOOTDROP_CONFIG.OutputDirectory = fullfile(tempdir, 'footdrop_check');
exec_oneshot_footdrop_function
exec_oneshot_footdrop_statistics
clear FOOTDROP_CONFIG
```

기본 실행으로 돌아갈 때는 `FOOTDROP_CONFIG`를 지웁니다.

그래프는 unction/plot_footdrop_metric.m에서 그립니다. IE/IR/LE/LR의 bar와
scatter/errorbar 색상은 Rex의 plot_SI_bar_multi_purpose.m과 동일한 RGB를 사용합니다.
Baseline은 중립 회색이며, grid/box와 상단 Mean/SD 설명 문구는 표시하지 않습니다.

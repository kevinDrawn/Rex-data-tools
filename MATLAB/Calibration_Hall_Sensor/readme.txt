센서 및 자석 샤프트 고정하는 방법

1. 홀센서와 자석 샤프트를 외골격 로봇에 고정하기 전에 센서의 range of motion이 나오는지 확인해야 한다. (95도 이상)
1-1 자석의 높이를 조정하거나, hall sensor의 높이를 조정한다.
2. 135도 각도 기준에서 자석이 3700~3900 ADC 값이 되게 위치를 조정한다. (작은 니퍼를 통해 돌릴 수 있다.)
2-1 이때, 발목 각도가 작아질 때 ADC 크기도 작아지게 자석을 배치해야 한다.
3. range of motion이 나오는 상태를 찾으면 우레탄 본드를 통해 위치를 단단히 고정한다.

Auto Calibration Mannual

0. STM 보드에서 auto_calibration 함수를 실행한다.
1. Exoskeleton의 발판을 135도 지점으로 돌려둔다. (발판이 Ankle brace에 닿는 지점)
2. Auto Calibration Python Code를 실행한다. (UART_Serial_Hall_Sensor_Auto_Calibration.py) - C:\Users\qoxmf\Desktop\park\Exoskeleton\python\20250225_UART_RX\03. Hall_Sensor_Auto_Calibration
3. 시작한 상태에서 스테이지를 건드리지 않고 7초 정도 대기한다. (135도 각도를 유지한 상태)
3. Calibration interval (ex. 4도) 간격으로 스테이지를 돌려주고 눈금을 맞춘 후에 7~10초 정도 기다린다.
3-1 매번 스테이지로 눈금을 맞춘 후에 실시간 그래프를 확인하고 값이 제대로 변하고 있는지 확인해야 한다.
3-2 더이상 센서 값의 변화가 나타나지 않거나 Raw data의 데이터 노이즈가 매우 심해질 때까지 계속해서 3-1 과정을 반복한다.

4. 파이썬 코드 경로에 있는 logging 폴더에 저장된 excel 파일이 제대로 저장된 것인지 확인한다.
5. Matlab 코드(hall_auto_calibration_result.m)을 실행한다. 
5-1 파일 탐색기를 통해 방금 저장된 excel 파일을 지정한다.
5-2 데이터 산출하기 위한 구간을 마우스로 클릭 두 번을 통해 지정한다.
5-3 각 calibration 각도마다 대기하는 동안 평탄화된 데이터를 자동으로 검출한다.
5-4 평탄 영역마다 중복으로 Calibration 값이 검출되지는 않았는지, 검출되지 않은 평탄 영역이 있는지 확인한다.
5-5 매틀랩 코드 9) 단계에서 각 calibration 각도에 대한 데이터를 저장한다. (csv 형식과 txt 파일)

6. txt 파일에 있는 첫번째 줄 데이터는 STM 보드에서  hall sensor angle 배열이고, 두번째 줄은 measured_angles에 대한 배열이다. 5-3에서 발견한 문제들을 txt 파일에서 수정한다. 
6-1 두 배열을 대체한 후에 STM 코드 중, calibrate_angle 함수를 통해 calibrate 된 각도를 사용한다.
7. stm 보드에서 auto_calibration_validate 함수를 stm 보드에 빌드하고, Validate_Hall_Sensor_Calibration.py 파이썬 코드를 통해 calibrate 된 각도가 station에서 나타내는 각도값을 제대로 반영하는지 확인한다.  
 
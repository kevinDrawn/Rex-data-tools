cmake_minimum_required(VERSION 3.20)
project(RexDataTools VERSION 0.1.0 LANGUAGES C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(MSVC)
    add_compile_options(/utf-8 /W4)
else()
    add_compile_options(-Wall -Wextra)
endif()

add_library(rex_protocol protocol/rex_protocol.c)
target_include_directories(rex_protocol PUBLIC protocol)
add_library(rex_csv acquisition/csv_writer.c)
target_include_directories(rex_csv PUBLIC acquisition)
target_link_libraries(rex_csv PUBLIC rex_protocol)

if(WIN32)
    add_executable(rex_logger acquisition/rex_emg_uart_csv_logger.c)
    target_link_libraries(rex_logger PRIVATE rex_csv user32)
endif()

add_library(rex_viewer_data viewer/log_data.cpp)
target_include_directories(rex_viewer_data PUBLIC viewer)
target_link_libraries(rex_viewer_data PUBLIC rex_protocol)
add_library(rex_frame_parser acquisition/frame_parser.cpp)
target_include_directories(rex_frame_parser PUBLIC acquisition)
target_link_libraries(rex_frame_parser PUBLIC rex_protocol)

include(CTest)
if(BUILD_TESTING)
    add_executable(test_emg_wire protocol/test_emg_wire.c)
    add_executable(test_logger_modules tests/test_logger_modules.c)
    target_link_libraries(test_logger_modules PRIVATE rex_csv)
    add_executable(test_viewer_data tests/test_viewer_data.cpp)
    target_link_libraries(test_viewer_data PRIVATE rex_viewer_data rex_csv rex_frame_parser)
    # Release에서도 assert 기반 검증이 실행되도록 합니다.
    foreach(test_target test_emg_wire test_logger_modules test_viewer_data)
        add_test(NAME ${test_target} COMMAND ${test_target})
    endforeach()
endif()

option(REX_BUILD_VIEWER "Windows ImPlot 뷰어 빌드" ON)
if(REX_BUILD_VIEWER AND WIN32)
    include(FetchContent)
    # 검증 대상 버전을 고정하여 이후 상위 API 변경의 영향을 줄입니다.
    FetchContent_Declare(imgui
        GIT_REPOSITORY https://github.com/ocornut/imgui.git
        GIT_TAG v1.91.9b GIT_SHALLOW TRUE)
    FetchContent_Declare(implot
        GIT_REPOSITORY https://github.com/epezent/implot.git
        GIT_TAG 4707b245fbcd69075b1a8a74fa8d2435561b3134)
    FetchContent_MakeAvailable(imgui implot)
    add_library(rex_plot_ui
        ${imgui_SOURCE_DIR}/imgui.cpp
        ${imgui_SOURCE_DIR}/imgui_draw.cpp
        ${imgui_SOURCE_DIR}/imgui_tables.cpp
        ${imgui_SOURCE_DIR}/imgui_widgets.cpp
        ${imgui_SOURCE_DIR}/backends/imgui_impl_win32.cpp
        ${imgui_SOURCE_DIR}/backends/imgui_impl_dx11.cpp
        ${implot_SOURCE_DIR}/implot.cpp
        ${implot_SOURCE_DIR}/implot_items.cpp)
    target_include_directories(rex_plot_ui PUBLIC ${imgui_SOURCE_DIR}
        ${imgui_SOURCE_DIR}/backends ${implot_SOURCE_DIR})
    target_link_libraries(rex_plot_ui PUBLIC d3d11 dxgi d3dcompiler dwmapi)
    add_executable(rex_viewer WIN32 viewer/main_win32.cpp viewer/viewer_ui.cpp acquisition/live_session.cpp)
    target_compile_definitions(rex_viewer PRIVATE NOMINMAX UNICODE _UNICODE)
    target_link_libraries(rex_viewer PRIVATE rex_plot_ui rex_viewer_data rex_frame_parser rex_csv comdlg32)
endif()

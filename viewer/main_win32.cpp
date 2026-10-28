// Win32 창과 DirectX 11 렌더링 수명 주기를 관리합니다.
#include <windows.h>
#include <d3d11.h>
#include "imgui.h"
#include "imgui_impl_win32.h"
#include "imgui_impl_dx11.h"
#include "implot.h"
#include "viewer_ui.h"
#include <filesystem>
#include <fstream>
#include <string>

namespace {
ID3D11Device* device = nullptr;
ID3D11DeviceContext* context = nullptr;
IDXGISwapChain* swap_chain = nullptr;
ID3D11RenderTargetView* target = nullptr;
UINT resize_width = 0, resize_height = 0;

void destroy_target() { if (target) { target->Release(); target = nullptr; } }
bool create_target() {
    ID3D11Texture2D* buffer = nullptr;
    if (FAILED(swap_chain->GetBuffer(0, IID_PPV_ARGS(&buffer)))) return false;
    HRESULT result = device->CreateRenderTargetView(buffer, nullptr, &target);
    buffer->Release();
    return SUCCEEDED(result);
}
void cleanup() {
    destroy_target();
    if (swap_chain) { swap_chain->Release(); swap_chain = nullptr; }
    if (context) { context->Release(); context = nullptr; }
    if (device) { device->Release(); device = nullptr; }
}
bool create_device(HWND window) {
    DXGI_SWAP_CHAIN_DESC desc = {};
    desc.BufferCount = 2;
    desc.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    desc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    desc.OutputWindow = window;
    desc.SampleDesc.Count = 1;
    desc.Windowed = TRUE;
    desc.SwapEffect = DXGI_SWAP_EFFECT_DISCARD;
    D3D_FEATURE_LEVEL level;
    const D3D_FEATURE_LEVEL levels[] = {D3D_FEATURE_LEVEL_11_0, D3D_FEATURE_LEVEL_10_0};
    HRESULT result = D3D11CreateDeviceAndSwapChain(nullptr, D3D_DRIVER_TYPE_HARDWARE,
        nullptr, 0, levels, 2, D3D11_SDK_VERSION, &desc, &swap_chain, &device, &level, &context);
    if (result == DXGI_ERROR_UNSUPPORTED) {
        result = D3D11CreateDeviceAndSwapChain(nullptr, D3D_DRIVER_TYPE_WARP,
            nullptr, 0, levels, 2, D3D11_SDK_VERSION, &desc, &swap_chain, &device, &level, &context);
    }
    return SUCCEEDED(result) && create_target();
}

/* 시험 모드에서 앱이 그린 프레임만 읽어 미리보기 파일로 저장합니다. */
bool save_preview() {
    ID3D11Texture2D* buffer = nullptr;
    if (FAILED(swap_chain->GetBuffer(0, IID_PPV_ARGS(&buffer)))) return false;
    D3D11_TEXTURE2D_DESC desc;
    buffer->GetDesc(&desc);
    desc.Usage = D3D11_USAGE_STAGING;
    desc.BindFlags = 0;
    desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
    desc.MiscFlags = 0;
    ID3D11Texture2D* staging = nullptr;
    HRESULT result = device->CreateTexture2D(&desc, nullptr, &staging);
    if (FAILED(result)) { buffer->Release(); return false; }
    context->CopyResource(staging, buffer);
    buffer->Release();
    D3D11_MAPPED_SUBRESOURCE mapped;
    result = context->Map(staging, 0, D3D11_MAP_READ, 0, &mapped);
    if (FAILED(result)) { staging->Release(); return false; }
    BITMAPFILEHEADER header = {};
    BITMAPINFOHEADER info = {};
    header.bfType = 0x4d42;
    header.bfOffBits = sizeof(header) + sizeof(info);
    header.bfSize = header.bfOffBits + desc.Width * desc.Height * 4;
    info.biSize = sizeof(info);
    info.biWidth = static_cast<LONG>(desc.Width);
    info.biHeight = -static_cast<LONG>(desc.Height);
    info.biPlanes = 1;
    info.biBitCount = 32;
    info.biCompression = BI_RGB;
    std::ofstream file("rex_viewer_preview.bmp", std::ios::binary);
    file.write(reinterpret_cast<const char*>(&header), sizeof(header));
    file.write(reinterpret_cast<const char*>(&info), sizeof(info));
    std::string row(desc.Width * 4, '\0');
    for (UINT y = 0; y < desc.Height; ++y) {
        auto source = static_cast<const unsigned char*>(mapped.pData) + y * mapped.RowPitch;
        for (UINT x = 0; x < desc.Width; ++x) {
            row[x * 4] = static_cast<char>(source[x * 4 + 2]);
            row[x * 4 + 1] = static_cast<char>(source[x * 4 + 1]);
            row[x * 4 + 2] = static_cast<char>(source[x * 4]);
            row[x * 4 + 3] = static_cast<char>(255);
        }
        file.write(row.data(), static_cast<std::streamsize>(row.size()));
    }
    context->Unmap(staging, 0);
    staging->Release();
    return file.good();
}
}

extern IMGUI_IMPL_API LRESULT ImGui_ImplWin32_WndProcHandler(HWND, UINT, WPARAM, LPARAM);
static LRESULT WINAPI window_proc(HWND window, UINT message, WPARAM wp, LPARAM lp) {
    if (ImGui_ImplWin32_WndProcHandler(window, message, wp, lp)) return 1;
    switch (message) {
    case WM_SIZE:
        if (wp != SIZE_MINIMIZED) { resize_width = LOWORD(lp); resize_height = HIWORD(lp); }
        return 0;
    case WM_SYSCOMMAND:
        if ((wp & 0xfff0) == SC_KEYMENU) return 0;
        break;
    case WM_DESTROY: PostQuitMessage(0); return 0;
    }
    return DefWindowProcW(window, message, wp, lp);
}

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR command_line, int show) {
    const bool smoke_test = std::wstring(command_line).find(L"--smoke-test") != std::wstring::npos;
    ImGui_ImplWin32_EnableDpiAwareness();
    WNDCLASSEXW wc = {};
    wc.cbSize = sizeof(wc);
    wc.style = CS_CLASSDC;
    wc.lpfnWndProc = window_proc;
    wc.hInstance = instance;
    wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
    wc.lpszClassName = L"RexDataViewer";
    if (!RegisterClassExW(&wc)) return 1;
    HWND window = CreateWindowW(wc.lpszClassName, L"Rex 데이터 뷰어", WS_OVERLAPPEDWINDOW,
        80, 60, 1440, 960, nullptr, nullptr, instance, nullptr);
    if (!window || !create_device(window)) {
        cleanup();
        if (window) DestroyWindow(window);
        UnregisterClassW(wc.lpszClassName, instance);
        MessageBoxW(nullptr, L"창 또는 DirectX 11 장치를 만들지 못했습니다.", L"Rex", MB_ICONERROR);
        return 1;
    }
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImPlot::CreateContext();
    auto& io = ImGui::GetIO();
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;
    io.IniFilename = nullptr;
    // Windows 기본 한글 글꼴을 사용하여 외부 글꼴 배포 의존성을 줄입니다.
    wchar_t windows_dir[MAX_PATH] = {};
    GetWindowsDirectoryW(windows_dir, MAX_PATH);
    auto font = std::filesystem::path(windows_dir) / L"Fonts" / L"malgun.ttf";
    if (!io.Fonts->AddFontFromFileTTF(font.u8string().c_str(), 18.0f, nullptr,
                                     io.Fonts->GetGlyphRangesKorean())) {
        MessageBoxW(window, L"한글 글꼴 malgun.ttf를 불러오지 못했습니다.", L"Rex", MB_ICONERROR);
        ImPlot::DestroyContext();
        ImGui::DestroyContext();
        cleanup(); DestroyWindow(window); UnregisterClassW(wc.lpszClassName, instance);
        return 1;
    }
    ImGui::StyleColorsDark();
    auto& style = ImGui::GetStyle();
    style.WindowRounding = 6;
    style.FrameRounding = 4;
    style.FramePadding = ImVec2(8, 6);
    style.ItemSpacing = ImVec2(10, 8);
    ImGui_ImplWin32_Init(window);
    ImGui_ImplDX11_Init(device, context);
    ShowWindow(window, smoke_test ? SW_HIDE : show);
    UpdateWindow(window);
    int exit_code = 0;
    {
        rex::ViewerUi ui;
        bool done = false;
        unsigned frames = 0;
        while (!done) {
            MSG message;
            while (PeekMessageW(&message, nullptr, 0, 0, PM_REMOVE)) {
                TranslateMessage(&message); DispatchMessageW(&message);
                if (message.message == WM_QUIT) done = true;
            }
            if (done) break;
            if (IsIconic(window)) { Sleep(20); continue; }
            if (resize_width && resize_height) {
                destroy_target();
                const HRESULT result = swap_chain->ResizeBuffers(0, resize_width, resize_height,
                    DXGI_FORMAT_UNKNOWN, 0);
                resize_width = resize_height = 0;
                if (FAILED(result) || !create_target()) { exit_code = 1; break; }
            }
            ImGui_ImplDX11_NewFrame(); ImGui_ImplWin32_NewFrame(); ImGui::NewFrame();
            ui.draw(window);
            ImGui::Render();
            const float background[] = {0.05f, 0.07f, 0.1f, 1};
            context->OMSetRenderTargets(1, &target, nullptr);
            context->ClearRenderTargetView(target, background);
            ImGui_ImplDX11_RenderDrawData(ImGui::GetDrawData());
            if (smoke_test && ++frames == 4) {
                if (!save_preview()) exit_code = 1;
                break;
            }
            if (FAILED(swap_chain->Present(1, 0))) { exit_code = 1; break; }
        }
    }
    ImGui_ImplDX11_Shutdown(); ImGui_ImplWin32_Shutdown();
    ImPlot::DestroyContext(); ImGui::DestroyContext();
    cleanup(); DestroyWindow(window); UnregisterClassW(wc.lpszClassName, instance);
    return exit_code;
}

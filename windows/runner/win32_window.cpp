#include "win32_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>
#include <shellapi.h>

#include "resource.h"

namespace {

#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";
constexpr const wchar_t kTrayTooltip[] = L"Mayday";
constexpr const wchar_t kGetPreferredBrightnessRegKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
constexpr const wchar_t kGetPreferredBrightnessRegValue[] =
    L"AppsUseLightTheme";
constexpr UINT kTrayIconId = 1;
constexpr UINT kTrayCallbackMessage = WM_APP + 1;
constexpr UINT kTrayShowCommand = 40001;
constexpr UINT kTrayExitCommand = 40002;

static int g_active_window_count = 0;

using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

int Scale(int source, double scale_factor) {
  return static_cast<int>(source * scale_factor);
}

void EnableFullDpiSupportIfAvailable(HWND hwnd) {
  HMODULE user32_module = LoadLibraryA("User32.dll");
  if (!user32_module) {
    return;
  }
  auto enable_non_client_dpi_scaling =
      reinterpret_cast<EnableNonClientDpiScaling*>(
          GetProcAddress(user32_module, "EnableNonClientDpiScaling"));
  if (enable_non_client_dpi_scaling != nullptr) {
    enable_non_client_dpi_scaling(hwnd);
  }
  FreeLibrary(user32_module);
}

}  // namespace

class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() = default;

  static WindowClassRegistrar* GetInstance() {
    if (!instance_) {
      instance_ = new WindowClassRegistrar();
    }
    return instance_;
  }

  const wchar_t* GetWindowClass();
  void UnregisterWindowClass();

 private:
  WindowClassRegistrar() = default;
  static WindowClassRegistrar* instance_;
  bool class_registered_ = false;
};

WindowClassRegistrar* WindowClassRegistrar::instance_ = nullptr;

const wchar_t* WindowClassRegistrar::GetWindowClass() {
  if (!class_registered_) {
    WNDCLASS window_class{};
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon =
        LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    window_class.hbrBackground = 0;
    window_class.lpszMenuName = nullptr;
    window_class.lpfnWndProc = Win32Window::WndProc;
    RegisterClass(&window_class);
    class_registered_ = true;
  }
  return kWindowClassName;
}

void WindowClassRegistrar::UnregisterWindowClass() {
  UnregisterClass(kWindowClassName, nullptr);
  class_registered_ = false;
}

Win32Window::Win32Window() {
  ++g_active_window_count;
}

Win32Window::~Win32Window() {
  --g_active_window_count;
  Destroy();
}

bool Win32Window::Create(const std::wstring& title, const Point& origin,
                         const Size& size) {
  Destroy();

  const wchar_t* window_class =
      WindowClassRegistrar::GetInstance()->GetWindowClass();

  const POINT target_point = {static_cast<LONG>(origin.x),
                              static_cast<LONG>(origin.y)};
  HMONITOR monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  double scale_factor = dpi / 96.0;

  HWND window = CreateWindow(
      window_class, title.c_str(), WS_OVERLAPPEDWINDOW,
      Scale(origin.x, scale_factor), Scale(origin.y, scale_factor),
      Scale(size.width, scale_factor), Scale(size.height, scale_factor),
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  if (!window) {
    return false;
  }

  UpdateTheme(window);
  return OnCreate();
}

bool Win32Window::Show() {
  return ShowWindow(window_handle_, SW_SHOWNORMAL);
}

LRESULT CALLBACK Win32Window::WndProc(HWND const window, UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto window_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(window_struct->lpCreateParams));

    auto that = static_cast<Win32Window*>(window_struct->lpCreateParams);
    EnableFullDpiSupportIfAvailable(window);
    that->window_handle_ = window;
  } else if (Win32Window* that = GetThisFromHandle(window)) {
    return that->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT Win32Window::MessageHandler(HWND hwnd, UINT const message,
                                    WPARAM const wparam,
                                    LPARAM const lparam) noexcept {
  switch (message) {
    case WM_CLOSE:
      if (minimize_to_tray_on_close_ && !exit_requested_) {
        ShowWindow(hwnd, SW_HIDE);
        return 0;
      }
      break;

    case WM_COMMAND:
      switch (LOWORD(wparam)) {
        case kTrayShowCommand:
          ShowFromTray();
          return 0;
        case kTrayExitCommand:
          ExitApplication();
          return 0;
      }
      break;

    case kTrayCallbackMessage:
      switch (LOWORD(lparam)) {
        case NIN_SELECT:
        case NIN_KEYSELECT:
        case WM_LBUTTONUP:
        case WM_LBUTTONDBLCLK:
          ShowFromTray();
          return 0;
        case WM_CONTEXTMENU:
        case WM_RBUTTONUP:
          ShowTrayMenu();
          return 0;
      }
      break;

    case WM_DESTROY:
      window_handle_ = nullptr;
      Destroy();
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;

    case WM_DPICHANGED: {
      auto new_rect_size = reinterpret_cast<RECT*>(lparam);
      LONG new_width = new_rect_size->right - new_rect_size->left;
      LONG new_height = new_rect_size->bottom - new_rect_size->top;

      SetWindowPos(hwnd, nullptr, new_rect_size->left, new_rect_size->top,
                   new_width, new_height, SWP_NOZORDER | SWP_NOACTIVATE);
      return 0;
    }

    case WM_SIZE: {
      RECT rect = GetClientArea();
      if (child_content_ != nullptr) {
        MoveWindow(child_content_, rect.left, rect.top,
                   rect.right - rect.left, rect.bottom - rect.top, TRUE);
      }
      return 0;
    }

    case WM_ACTIVATE:
      if (child_content_ != nullptr) {
        SetFocus(child_content_);
      }
      return 0;

    case WM_DWMCOLORIZATIONCOLORCHANGED:
      UpdateTheme(hwnd);
      return 0;
  }

  return DefWindowProc(window_handle_, message, wparam, lparam);
}

void Win32Window::Destroy() {
  OnDestroy();

  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  if (g_active_window_count == 0) {
    WindowClassRegistrar::GetInstance()->UnregisterWindowClass();
  }
}

Win32Window* Win32Window::GetThisFromHandle(HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  SetParent(content, window_handle_);
  RECT frame = GetClientArea();

  MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
             frame.bottom - frame.top, true);

  SetFocus(child_content_);
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

HWND Win32Window::GetHandle() {
  return window_handle_;
}

bool Win32Window::RaiseExistingWindow(const std::wstring& title) {
  HWND existing_window = nullptr;
  for (int attempt = 0; attempt < 40 && existing_window == nullptr;
       ++attempt) {
    existing_window = FindWindow(kWindowClassName, title.c_str());
    if (existing_window == nullptr) {
      Sleep(100);
    }
  }

  if (existing_window == nullptr) {
    return false;
  }

  ShowWindow(existing_window, SW_SHOW);
  ShowWindow(existing_window, SW_RESTORE);
  BringWindowToTop(existing_window);
  SetForegroundWindow(existing_window);
  return true;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

void Win32Window::SetMinimizeToTrayOnClose(bool minimize_to_tray_on_close) {
  minimize_to_tray_on_close_ = minimize_to_tray_on_close;
}

void Win32Window::SetTrayVpnConnected(bool connected) {
  if (tray_vpn_connected_ == connected) {
    return;
  }

  tray_vpn_connected_ = connected;
  UpdateTrayIcon();
}

bool Win32Window::OnCreate() {
  if (minimize_to_tray_on_close_) {
    AddTrayIcon();
  }
  return true;
}

void Win32Window::OnDestroy() {
  RemoveTrayIcon();
}

void Win32Window::UpdateTheme(HWND const window) {
  DWORD light_mode;
  DWORD light_mode_size = sizeof(light_mode);
  LSTATUS result = RegGetValue(HKEY_CURRENT_USER, kGetPreferredBrightnessRegKey,
                               kGetPreferredBrightnessRegValue,
                               RRF_RT_REG_DWORD, nullptr, &light_mode,
                               &light_mode_size);

  if (result == ERROR_SUCCESS) {
    BOOL enable_dark_mode = light_mode == 0;
    DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,
                          &enable_dark_mode, sizeof(enable_dark_mode));
  }
}

void Win32Window::AddTrayIcon() {
  if (tray_icon_added_ || window_handle_ == nullptr) {
    return;
  }

  NOTIFYICONDATA nid{};
  nid.cbSize = sizeof(nid);
  nid.hWnd = window_handle_;
  nid.uID = kTrayIconId;
  nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  nid.uCallbackMessage = kTrayCallbackMessage;
  nid.hIcon = LoadTrayIcon();
  wcscpy_s(nid.szTip, kTrayTooltip);

  if (Shell_NotifyIcon(NIM_ADD, &nid)) {
    nid.uVersion = NOTIFYICON_VERSION_4;
    Shell_NotifyIcon(NIM_SETVERSION, &nid);
    tray_icon_added_ = true;
    tray_window_handle_ = window_handle_;
  }
}

void Win32Window::RemoveTrayIcon() {
  if (!tray_icon_added_ || tray_window_handle_ == nullptr) {
    return;
  }

  NOTIFYICONDATA nid{};
  nid.cbSize = sizeof(nid);
  nid.hWnd = tray_window_handle_;
  nid.uID = kTrayIconId;
  Shell_NotifyIcon(NIM_DELETE, &nid);
  tray_icon_added_ = false;
  tray_window_handle_ = nullptr;
}

void Win32Window::UpdateTrayIcon() {
  if (!tray_icon_added_ || tray_window_handle_ == nullptr) {
    return;
  }

  NOTIFYICONDATA nid{};
  nid.cbSize = sizeof(nid);
  nid.hWnd = tray_window_handle_;
  nid.uID = kTrayIconId;
  nid.uFlags = NIF_ICON | NIF_TIP;
  nid.hIcon = LoadTrayIcon();
  wcscpy_s(nid.szTip, kTrayTooltip);
  Shell_NotifyIcon(NIM_MODIFY, &nid);
}

HICON Win32Window::LoadTrayIcon() const {
  const int resource_id = tray_vpn_connected_ ? IDI_TRAY_ON : IDI_TRAY_OFF;
  const int width = GetSystemMetrics(SM_CXSMICON);
  const int height = GetSystemMetrics(SM_CYSMICON);
  HICON icon = reinterpret_cast<HICON>(LoadImage(
      GetModuleHandle(nullptr), MAKEINTRESOURCE(resource_id), IMAGE_ICON,
      width, height, LR_DEFAULTCOLOR | LR_SHARED));
  if (icon != nullptr) {
    return icon;
  }

  return LoadIcon(GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON));
}

void Win32Window::ShowFromTray() {
  if (window_handle_ == nullptr) {
    return;
  }

  ShowWindow(window_handle_, SW_SHOW);
  ShowWindow(window_handle_, SW_RESTORE);
  SetForegroundWindow(window_handle_);
}

void Win32Window::ShowTrayMenu() {
  HWND target_window = window_handle_ != nullptr ? window_handle_ : tray_window_handle_;
  if (target_window == nullptr) {
    return;
  }

  POINT cursor;
  GetCursorPos(&cursor);

  HMENU menu = CreatePopupMenu();
  AppendMenu(menu, MF_STRING, kTrayShowCommand, L"Show Mayday");
  AppendMenu(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenu(menu, MF_STRING, kTrayExitCommand, L"Exit");

  SetForegroundWindow(target_window);
  const UINT command = TrackPopupMenu(
      menu, TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON, cursor.x, cursor.y,
      0, target_window, nullptr);
  DestroyMenu(menu);
  PostMessage(target_window, WM_NULL, 0, 0);

  if (command == kTrayShowCommand) {
    ShowFromTray();
  } else if (command == kTrayExitCommand) {
    ExitApplication();
  }
}

void Win32Window::ExitApplication() {
  exit_requested_ = true;
  RemoveTrayIcon();
  HWND target_window = window_handle_ != nullptr ? window_handle_ : tray_window_handle_;
  if (target_window != nullptr) {
    DestroyWindow(target_window);
    return;
  }
  PostQuitMessage(0);
}

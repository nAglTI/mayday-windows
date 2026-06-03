#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <algorithm>
#include <cstdint>
#include <cwctype>
#include <iomanip>
#include <sstream>
#include <string>

#include "flutter_window.h"
#include "utils.h"

namespace {

constexpr wchar_t kAppWindowTitle[] = L"Mayday";

std::wstring CurrentExecutablePath() {
  std::wstring path(MAX_PATH, L'\0');
  DWORD length = GetModuleFileNameW(nullptr, path.data(),
                                    static_cast<DWORD>(path.size()));
  while (length == static_cast<DWORD>(path.size())) {
    path.resize(path.size() * 2);
    length = GetModuleFileNameW(nullptr, path.data(),
                                static_cast<DWORD>(path.size()));
  }
  path.resize(length);
  return path;
}

std::wstring ToLower(std::wstring value) {
  std::transform(value.begin(), value.end(), value.begin(),
                 [](wchar_t ch) { return static_cast<wchar_t>(towlower(ch)); });
  return value;
}

std::wstring HexHash(const std::wstring& value) {
  uint64_t hash = 1469598103934665603ull;
  for (wchar_t ch : ToLower(value)) {
    hash ^= static_cast<uint64_t>(ch);
    hash *= 1099511628211ull;
  }

  std::wstringstream stream;
  stream << std::hex << std::setw(16) << std::setfill(L'0') << hash;
  return stream.str();
}

std::wstring SingleInstanceMutexName(const std::wstring& executable_path) {
  return L"Local\\MaydayWindowsSingleInstance-" + HexHash(executable_path);
}

std::wstring WindowTitle(const std::wstring& executable_path) {
  const std::wstring normalized = ToLower(executable_path);
  if (normalized.find(L"\\build\\windows\\") != std::wstring::npos) {
    return L"Mayday Local";
  }
  return kAppWindowTitle;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  const std::wstring executable_path = CurrentExecutablePath();
  const std::wstring window_title = WindowTitle(executable_path);
  const std::wstring mutex_name = SingleInstanceMutexName(executable_path);
  HANDLE single_instance_mutex =
      CreateMutex(nullptr, TRUE, mutex_name.c_str());
  if (single_instance_mutex == nullptr) {
    return EXIT_FAILURE;
  }

  if (GetLastError() == ERROR_ALREADY_EXISTS) {
    Win32Window::RaiseExistingWindow(window_title);
    CloseHandle(single_instance_mutex);
    return EXIT_SUCCESS;
  }

  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  window.SetMinimizeToTrayOnClose(true);
  Win32Window::Point origin(30, 30);
  Win32Window::Size size(560, 760);
  if (!window.Create(window_title, origin, size)) {
    ::CoUninitialize();
    CloseHandle(single_instance_mutex);
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  CloseHandle(single_instance_mutex);
  return EXIT_SUCCESS;
}

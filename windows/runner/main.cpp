#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

constexpr wchar_t kAppWindowTitle[] = L"Mayday";
constexpr wchar_t kSingleInstanceMutexName[] =
    L"Local\\MaydayWindowsSingleInstance";

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  HANDLE single_instance_mutex =
      CreateMutex(nullptr, TRUE, kSingleInstanceMutexName);
  if (single_instance_mutex == nullptr) {
    return EXIT_FAILURE;
  }

  if (GetLastError() == ERROR_ALREADY_EXISTS) {
    Win32Window::RaiseExistingWindow(kAppWindowTitle);
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
  if (!window.Create(kAppWindowTitle, origin, size)) {
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

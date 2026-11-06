#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter_windows.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  // Window size in logical pixels (1000x620), centered on the primary monitor.
  const unsigned int kWidth = 1000;
  const unsigned int kHeight = 620;
  POINT zero = {0, 0};
  HMONITOR monitor = MonitorFromPoint(zero, MONITOR_DEFAULTTOPRIMARY);
  MONITORINFO monitor_info = {};
  monitor_info.cbSize = sizeof(MONITORINFO);
  GetMonitorInfo(monitor, &monitor_info);
  double scale = FlutterDesktopGetDpiForMonitor(monitor) / 96.0;
  double work_w = (monitor_info.rcWork.right - monitor_info.rcWork.left) / scale;
  double work_h = (monitor_info.rcWork.bottom - monitor_info.rcWork.top) / scale;
  double x = monitor_info.rcWork.left / scale + (work_w - kWidth) / 2;
  double y = monitor_info.rcWork.top / scale + (work_h - kHeight) / 2;
  if (x < 0) x = 0;
  if (y < 0) y = 0;
  Win32Window::Point origin(static_cast<unsigned int>(x),
                            static_cast<unsigned int>(y));
  Win32Window::Size size(kWidth, kHeight);
  if (!window.Create(L"Zembo Browser", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shobjidl.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Ensure the current working directory is the executable's directory so that
  // relative asset paths (like L"data") and bundled DLLs resolve correctly
  // regardless of how the process was launched (e.g. updater scripts or shortcuts).
  wchar_t exe_path_buf[MAX_PATH];
  if (::GetModuleFileNameW(nullptr, exe_path_buf, MAX_PATH) > 0) {
    wchar_t *last_slash = wcsrchr(exe_path_buf, L'\\');
    if (last_slash != nullptr) {
      *last_slash = L'\0';
      ::SetCurrentDirectoryW(exe_path_buf);
    }
  }

  // Set explicit AppUserModelID before any window is created or UI displayed.
  // This ensures the Windows Taskbar correctly associates this running process
  // with pinned shortcuts across updates, relaunches, and secondary processes.
  ::SetCurrentProcessExplicitAppUserModelID(L"neckbeard.flax");

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
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"flax", origin, size)) {
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

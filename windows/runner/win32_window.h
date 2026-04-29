#ifndef RUNNER_WIN32_WINDOW_H_
#define RUNNER_WIN32_WINDOW_H_

#include <windows.h>

#include <string>

class Win32Window {
 public:
  struct Point {
    unsigned int x;
    unsigned int y;
    Point(unsigned int x, unsigned int y) : x(x), y(y) {}
  };

  struct Size {
    unsigned int width;
    unsigned int height;
    Size(unsigned int width, unsigned int height)
        : width(width), height(height) {}
  };

  Win32Window();
  virtual ~Win32Window();

  bool Create(const std::wstring& title, const Point& origin, const Size& size);
  bool Show();
  void Destroy();
  void SetChildContent(HWND content);
  HWND GetHandle();
  void SetQuitOnClose(bool quit_on_close);
  void SetMinimizeToTrayOnClose(bool minimize_to_tray_on_close);
  void SetTrayVpnConnected(bool connected);
  RECT GetClientArea();
  static bool RaiseExistingWindow(const std::wstring& title);

 protected:
  virtual LRESULT MessageHandler(HWND window,
                                 UINT const message,
                                 WPARAM const wparam,
                                 LPARAM const lparam) noexcept;
  virtual bool OnCreate();
  virtual void OnDestroy();

 private:
  friend class WindowClassRegistrar;

  static LRESULT CALLBACK WndProc(HWND const window,
                                  UINT const message,
                                  WPARAM const wparam,
                                  LPARAM const lparam) noexcept;

  static Win32Window* GetThisFromHandle(HWND const window) noexcept;
  static void UpdateTheme(HWND const window);
  void AddTrayIcon();
  void RemoveTrayIcon();
  void UpdateTrayIcon();
  HICON LoadTrayIcon() const;
  void ShowFromTray();
  void ShowTrayMenu();
  void ExitApplication();

  bool quit_on_close_ = false;
  bool minimize_to_tray_on_close_ = false;
  bool tray_icon_added_ = false;
  bool tray_vpn_connected_ = false;
  bool exit_requested_ = false;
  HWND window_handle_ = nullptr;
  HWND tray_window_handle_ = nullptr;
  HWND child_content_ = nullptr;
};

#endif  // RUNNER_WIN32_WINDOW_H_

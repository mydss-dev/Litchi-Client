#include "flutter_window.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"

namespace {

// Posted only after the Dart side has removed the tray icon and shut down the
// proxy. Handling this in the runner bypasses window-manager close interception
// and guarantees that HWND receives WM_DESTROY before the process exits.
constexpr UINT kDestroyForProcessExit = WM_APP + 0x2A;

std::wstring Utf8ToWide(const std::string& value) {
  if (value.empty()) {
    return {};
  }
  const int size = MultiByteToWideChar(CP_UTF8, 0, value.c_str(),
                                       static_cast<int>(value.size()), nullptr,
                                       0);
  if (size <= 0) {
    return {};
  }
  std::wstring result(size, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.c_str(),
                      static_cast<int>(value.size()), result.data(), size);
  return result;
}

const std::string* ReadStringArgument(const flutter::EncodableMap& arguments,
                                      const char* key) {
  const auto iterator = arguments.find(flutter::EncodableValue(key));
  if (iterator == arguments.end()) {
    return nullptr;
  }
  return std::get_if<std::string>(&iterator->second);
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  process_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "litchi/windows_process",
          &flutter::StandardMethodCodec::GetInstance());
  process_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<
                 flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() != "quit") {
          result->NotImplemented();
          return;
        }

        // Complete the method call while the engine is still alive, then let
        // the window procedure perform the native teardown.
        result->Success(flutter::EncodableValue(true));
        const HWND window = GetHandle();
        if (window != nullptr) {
          PostMessage(window, kDestroyForProcessExit, 0, 0);
        }
      });

  wfp_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "litchi/windows_wfp",
          &flutter::StandardMethodCodec::GetInstance());
  wfp_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<
                 flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "release") {
          wfp_kill_switch_.Disengage();
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (call.method_name() == "isEngaged") {
          result->Success(
              flutter::EncodableValue(wfp_kill_switch_.IsEngaged()));
          return;
        }
        if (call.method_name() != "engage") {
          result->NotImplemented();
          return;
        }

        const auto* arguments =
            std::get_if<flutter::EncodableMap>(call.arguments());
        if (arguments == nullptr) {
          result->Error("invalid_arguments", "Expected an argument map");
          return;
        }
        const std::string* core_path =
            ReadStringArgument(*arguments, "corePath");
        const std::string* interface_alias =
            ReadStringArgument(*arguments, "interfaceAlias");
        if (core_path == nullptr || interface_alias == nullptr) {
          result->Error("invalid_arguments",
                        "corePath and interfaceAlias are required");
          return;
        }

        std::string error;
        const bool engaged =
            wfp_kill_switch_.Engage(Utf8ToWide(*core_path),
                                    Utf8ToWide(*interface_alias), &error);
        if (!engaged) {
          result->Error("wfp_failed", error);
          return;
        }
        result->Success(flutter::EncodableValue(true));
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  process_channel_.reset();
  wfp_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == kDestroyForProcessExit) {
    DestroyWindow(hwnd);
    return 0;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

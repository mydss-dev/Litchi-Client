#ifndef RUNNER_WFP_KILL_SWITCH_H_
#define RUNNER_WFP_KILL_SWITCH_H_

#include <windows.h>

#include <string>

// Owns a dynamic Windows Filtering Platform session. Every filter is removed
// automatically when the session is closed or the runner process exits.
class WfpKillSwitch {
 public:
  WfpKillSwitch() = default;
  ~WfpKillSwitch();

  WfpKillSwitch(const WfpKillSwitch&) = delete;
  WfpKillSwitch& operator=(const WfpKillSwitch&) = delete;

  bool Engage(const std::wstring& app_path,
              const std::wstring& interface_alias,
              std::string* error);
  void Disengage();
  bool IsEngaged() const { return engine_ != nullptr; }

 private:
  HANDLE engine_ = nullptr;
};

#endif  // RUNNER_WFP_KILL_SWITCH_H_

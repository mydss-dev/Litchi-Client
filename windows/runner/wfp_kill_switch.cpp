#include "wfp_kill_switch.h"

#include <fwpmu.h>
#include <iphlpapi.h>

#include <cstdint>
#include <cstring>

namespace {

const GUID kLitchiSublayer = {
    0x183ec698,
    0x78ad,
    0x4f07,
    {0x8d, 0x57, 0x0e, 0xae, 0xc7, 0xe4, 0x6c, 0x91}};

std::string ErrorMessage(const char* operation, DWORD code) {
  return std::string(operation) + " failed (" + std::to_string(code) + ")";
}

DWORD AddFilter(HANDLE engine,
                const GUID& layer,
                const wchar_t* name,
                FWP_ACTION_TYPE action,
                UINT8 weight,
                FWPM_FILTER_CONDITION0* conditions,
                UINT32 condition_count) {
  FWPM_FILTER0 filter{};
  filter.displayData.name = const_cast<wchar_t*>(name);
  filter.layerKey = layer;
  filter.subLayerKey = kLitchiSublayer;
  filter.action.type = action;
  filter.weight.type = FWP_UINT8;
  filter.weight.uint8 = weight;
  filter.filterCondition = conditions;
  filter.numFilterConditions = condition_count;
  return FwpmFilterAdd0(engine, &filter, nullptr, nullptr);
}

DWORD AddLayerFilters(HANDLE engine,
                      const GUID& layer,
                      FWP_BYTE_BLOB* core_app_id,
                      UINT64 interface_luid) {
  FWPM_FILTER_CONDITION0 core_condition{};
  core_condition.fieldKey = FWPM_CONDITION_ALE_APP_ID;
  core_condition.matchType = FWP_MATCH_EQUAL;
  core_condition.conditionValue.type = FWP_BYTE_BLOB_TYPE;
  core_condition.conditionValue.byteBlob = core_app_id;
  DWORD result = AddFilter(engine, layer, L"Litchi permit isolated core",
                           FWP_ACTION_PERMIT, 15, &core_condition, 1);
  if (result != ERROR_SUCCESS) {
    return result;
  }

  FWPM_FILTER_CONDITION0 interface_condition{};
  interface_condition.fieldKey = FWPM_CONDITION_IP_LOCAL_INTERFACE;
  interface_condition.matchType = FWP_MATCH_EQUAL;
  interface_condition.conditionValue.type = FWP_UINT64;
  interface_condition.conditionValue.uint64 = &interface_luid;
  result = AddFilter(engine, layer, L"Litchi permit TUN interface",
                     FWP_ACTION_PERMIT, 14, &interface_condition, 1);
  if (result != ERROR_SUCCESS) {
    return result;
  }

  FWPM_FILTER_CONDITION0 loopback_condition{};
  loopback_condition.fieldKey = FWPM_CONDITION_FLAGS;
  loopback_condition.matchType = FWP_MATCH_FLAGS_ALL_SET;
  loopback_condition.conditionValue.type = FWP_UINT32;
  loopback_condition.conditionValue.uint32 = FWP_CONDITION_FLAG_IS_LOOPBACK;
  result = AddFilter(engine, layer, L"Litchi permit loopback",
                     FWP_ACTION_PERMIT, 13, &loopback_condition, 1);
  if (result != ERROR_SUCCESS) {
    return result;
  }

  return AddFilter(engine, layer, L"Litchi block non-TUN outbound",
                   FWP_ACTION_BLOCK, 0, nullptr, 0);
}

}  // namespace

WfpKillSwitch::~WfpKillSwitch() {
  Disengage();
}

bool WfpKillSwitch::Engage(const std::wstring& core_path,
                           const std::wstring& interface_alias,
                           std::string* error) {
  if (IsEngaged()) {
    // A recreated Wintun adapter receives a new LUID. Rebuild the dynamic
    // session so the permit rule always targets the current TUN instance.
    Disengage();
  }
  if (core_path.empty() || interface_alias.empty()) {
    if (error) {
      *error = "core path and TUN interface are required";
    }
    return false;
  }

  NET_LUID interface_luid{};
  DWORD result =
      ConvertInterfaceAliasToLuid(interface_alias.c_str(), &interface_luid);
  if (result != NO_ERROR) {
    if (error) {
      *error = ErrorMessage("ConvertInterfaceAliasToLuid", result);
    }
    return false;
  }

  FWP_BYTE_BLOB* core_app_id = nullptr;
  result = FwpmGetAppIdFromFileName0(core_path.c_str(), &core_app_id);
  if (result != ERROR_SUCCESS) {
    if (error) {
      *error = ErrorMessage("FwpmGetAppIdFromFileName0", result);
    }
    return false;
  }

  FWPM_SESSION0 session{};
  session.displayData.name =
      const_cast<wchar_t*>(L"Litchi TUN kill switch session");
  session.flags = FWPM_SESSION_FLAG_DYNAMIC;
  result =
      FwpmEngineOpen0(nullptr, RPC_C_AUTHN_WINNT, nullptr, &session, &engine_);
  if (result != ERROR_SUCCESS) {
    FwpmFreeMemory0(reinterpret_cast<void**>(&core_app_id));
    engine_ = nullptr;
    if (error) {
      *error = ErrorMessage("FwpmEngineOpen0", result);
    }
    return false;
  }

  bool transaction_started = false;
  result = FwpmTransactionBegin0(engine_, 0);
  if (result == ERROR_SUCCESS) {
    transaction_started = true;

    FWPM_SUBLAYER0 sublayer{};
    sublayer.subLayerKey = kLitchiSublayer;
    sublayer.displayData.name =
        const_cast<wchar_t*>(L"Litchi TUN kill switch");
    sublayer.displayData.description = const_cast<wchar_t*>(
        L"Blocks outbound traffic outside TUN except the isolated proxy core");
    sublayer.weight = 0x7f00;
    result = FwpmSubLayerAdd0(engine_, &sublayer, nullptr);
  }

  if (result == ERROR_SUCCESS) {
    result = AddLayerFilters(engine_, FWPM_LAYER_ALE_AUTH_CONNECT_V4,
                             core_app_id, interface_luid.Value);
  }
  if (result == ERROR_SUCCESS) {
    result = AddLayerFilters(engine_, FWPM_LAYER_ALE_AUTH_CONNECT_V6,
                             core_app_id, interface_luid.Value);
  }

  if (result == ERROR_SUCCESS) {
    result = FwpmTransactionCommit0(engine_);
    transaction_started = false;
  }
  if (result != ERROR_SUCCESS) {
    if (transaction_started) {
      FwpmTransactionAbort0(engine_);
    }
    FwpmFreeMemory0(reinterpret_cast<void**>(&core_app_id));
    Disengage();
    if (error) {
      *error = ErrorMessage("install WFP filters", result);
    }
    return false;
  }

  FwpmFreeMemory0(reinterpret_cast<void**>(&core_app_id));
  return true;
}

void WfpKillSwitch::Disengage() {
  if (engine_ != nullptr) {
    FwpmEngineClose0(engine_);
    engine_ = nullptr;
  }
}

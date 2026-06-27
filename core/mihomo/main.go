package main

/*
#include <stdlib.h>
#include "bridge.h"
*/
import "C"

import (
	"fmt"
	"net"
	"net/netip"
	"strings"
	"sync"
	"syscall"
	"unsafe"

	"github.com/metacubex/mihomo/adapter/outboundgroup"
	"github.com/metacubex/mihomo/component/dialer"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/dns"
	"github.com/metacubex/mihomo/hub"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/listener"
	LC "github.com/metacubex/mihomo/listener/config"
	mihomoTun "github.com/metacubex/mihomo/listener/sing_tun"
	"github.com/metacubex/mihomo/tunnel"
	"github.com/metacubex/mihomo/tunnel/statistic"
)

var (
	coreLock sync.Mutex
	tun      *mihomoTun.Listener
	bridge   unsafe.Pointer
	version  = "dev"
)

func recoverCString(result **C.char) {
	if value := recover(); value != nil {
		*result = C.CString(fmt.Sprintf("mihomo panic: %v", value))
	}
}

func recoverVoid() {
	_ = recover()
}

//export litchiMihomoStart
func litchiMihomoStart(
	configJSON *C.char,
	homePath *C.char,
	tunFD C.int,
	callback unsafe.Pointer,
) (result *C.char) {
	defer recoverCString(&result)
	coreLock.Lock()
	defer coreLock.Unlock()

	stopLocked()
	constant.SetHomeDir(C.GoString(homePath))
	bridge = callback
	dialer.DefaultSocketHook = func(
		network string,
		address string,
		connection syscall.RawConn,
	) error {
		return connection.Control(func(fd uintptr) {
			C.litchi_protect_socket(bridge, C.int(fd))
		})
	}

	cfg, err := executor.ParseWithBytes([]byte(C.GoString(configJSON)))
	if err != nil {
		stopLocked()
		return C.CString(fmt.Sprintf("invalid mihomo config: %v", err))
	}
	cfg.General.Tun.Enable = false
	hub.ApplyConfig(cfg)

	listener.SetAllowLan(cfg.General.AllowLan)
	listener.SetBindAddress(cfg.General.BindAddress)
	listener.ReCreateMixed(cfg.General.MixedPort, tunnel.Tunnel)

	stack := constant.TunMixed
	prefix4 := netip.MustParsePrefix("172.19.0.1/30")
	prefix6 := netip.MustParsePrefix("fdfe:dcba:9876::1/126")
	options := LC.Tun{
		Enable:              true,
		Device:              "Litchi",
		Stack:               stack,
		DNSHijack:           []string{net.JoinHostPort("0.0.0.0", "53")},
		AutoRoute:           false,
		AutoDetectInterface: false,
		Inet4Address:        []netip.Prefix{prefix4},
		Inet6Address:        []netip.Prefix{prefix6},
		MTU:                 1500,
		FileDescriptor:      int(tunFD),
	}
	tun, err = mihomoTun.New(options, tunnel.Tunnel)
	if err != nil {
		stopLocked()
		return C.CString(fmt.Sprintf("start Android TUN: %v", err))
	}
	return C.CString("")
}

//export litchiMihomoStartVpn
func litchiMihomoStartVpn(
	tunFD C.int,
	callback unsafe.Pointer,
) (result *C.char) {
	defer recoverCString(&result)
	coreLock.Lock()
	defer coreLock.Unlock()

	// Only tear down a previous TUN — never touch the core listeners.
	stopVpnLocked()

	bridge = callback
	dialer.DefaultSocketHook = func(
		network string,
		address string,
		connection syscall.RawConn,
	) error {
		return connection.Control(func(fd uintptr) {
			C.litchi_protect_socket(bridge, C.int(fd))
		})
	}

	stack := constant.TunMixed
	prefix4 := netip.MustParsePrefix("172.19.0.1/30")
	prefix6 := netip.MustParsePrefix("fdfe:dcba:9876::1/126")
	options := LC.Tun{
		Enable:              true,
		Device:              "Litchi",
		Stack:               stack,
		DNSHijack:           []string{net.JoinHostPort("0.0.0.0", "53")},
		AutoRoute:           false,
		AutoDetectInterface: false,
		Inet4Address:        []netip.Prefix{prefix4},
		Inet6Address:        []netip.Prefix{prefix6},
		MTU:                 1500,
		FileDescriptor:      int(tunFD),
	}
	var err error
	tun, err = mihomoTun.New(options, tunnel.Tunnel)
	if err != nil {
		stopVpnLocked()
		return C.CString(fmt.Sprintf("start Android TUN: %v", err))
	}
	return C.CString("")
}

//export litchiMihomoStartCoreOnly
func litchiMihomoStartCoreOnly(
	configJSON *C.char,
	homePath *C.char,
) (result *C.char) {
	defer recoverCString(&result)
	coreLock.Lock()
	defer coreLock.Unlock()

	stopLocked()
	constant.SetHomeDir(C.GoString(homePath))

	cfg, err := executor.ParseWithBytes([]byte(C.GoString(configJSON)))
	if err != nil {
		stopLocked()
		return C.CString(fmt.Sprintf("invalid mihomo config: %v", err))
	}
	// Core-only: no socket protection, no TUN.
	cfg.General.Tun.Enable = false
	hub.ApplyConfig(cfg)

	listener.SetAllowLan(cfg.General.AllowLan)
	listener.SetBindAddress(cfg.General.BindAddress)
	listener.ReCreateMixed(cfg.General.MixedPort, tunnel.Tunnel)

	return C.CString("")
}

//export litchiMihomoStopVpn
func litchiMihomoStopVpn() {
	defer recoverVoid()
	coreLock.Lock()
	defer coreLock.Unlock()
	stopVpnLocked()
}

//export litchiMihomoStop
func litchiMihomoStop() {
	defer recoverVoid()
	coreLock.Lock()
	defer coreLock.Unlock()
	stopLocked()
}

//export litchiMihomoUpdateDns
func litchiMihomoUpdateDns(servers *C.char) {
	defer recoverVoid()
	raw := C.GoString(servers)
	values := make([]string, 0)
	for _, server := range strings.Split(raw, ",") {
		server = strings.TrimSpace(server)
		if server != "" {
			values = append(values, server)
		}
	}
	dns.UpdateSystemDNS(values)
	dns.FlushCacheWithDefaultResolver()
}

//export litchiMihomoSetSuspended
func litchiMihomoSetSuspended(suspended C.int) {
	defer recoverVoid()
	if suspended != 0 {
		tunnel.OnSuspend()
		return
	}
	tunnel.OnRunning()
}

//export litchiMihomoCloseConnections
func litchiMihomoCloseConnections() {
	defer recoverVoid()
	statistic.DefaultManager.Range(func(connection statistic.Tracker) bool {
		_ = connection.Close()
		return true
	})
}

//export litchiMihomoSwitchProxy
func litchiMihomoSwitchProxy(
	groupName *C.char,
	proxyName *C.char,
) (result *C.char) {
	defer recoverCString(&result)
	coreLock.Lock()
	defer coreLock.Unlock()

	group, ok := tunnel.Proxies()[C.GoString(groupName)]
	if !ok {
		return C.CString("proxy group not found")
	}
	selector, ok := group.Adapter().(outboundgroup.SelectAble)
	if !ok {
		return C.CString("proxy group is not selectable")
	}
	if err := selector.Set(C.GoString(proxyName)); err != nil {
		return C.CString(err.Error())
	}
	return C.CString("")
}

//export litchiMihomoSetMode
func litchiMihomoSetMode(modeName *C.char) (result *C.char) {
	defer recoverCString(&result)
	coreLock.Lock()
	defer coreLock.Unlock()

	mode, ok := tunnel.ModeMapping[strings.ToLower(C.GoString(modeName))]
	if !ok {
		return C.CString("invalid proxy mode")
	}
	tunnel.SetMode(mode)
	return C.CString("")
}

//export litchiMihomoReloadConfig
func litchiMihomoReloadConfig(configJSON *C.char) (result *C.char) {
	defer recoverCString(&result)
	coreLock.Lock()
	defer coreLock.Unlock()

	cfg, err := executor.ParseWithBytes([]byte(C.GoString(configJSON)))
	if err != nil {
		return C.CString(fmt.Sprintf("invalid mihomo config: %v", err))
	}
	// Android owns the TUN interface. Keep the config-managed TUN disabled
	// while applying proxies, rules, DNS, ports, and other runtime settings.
	cfg.General.Tun.Enable = false
	executor.ApplyConfig(cfg, true)
	return C.CString("")
}

// stopVpnLocked tears down the TUN listener and socket protection but
// keeps the mixed/http/socks listeners alive so the external-controller
// (URLTest, proxy switching, etc.) continues to work.
func stopVpnLocked() {
	dialer.DefaultSocketHook = nil
	if tun != nil {
		_ = tun.Close()
		tun = nil
	}
	bridge = nil
}

func stopLocked() {
	dialer.DefaultSocketHook = nil
	if tun != nil {
		_ = tun.Close()
		tun = nil
	}
	listener.Cleanup()
	bridge = nil
}

//export litchiMihomoVersion
func litchiMihomoVersion() (result *C.char) {
	defer recoverCString(&result)
	return C.CString(version)
}

//export litchiMihomoFree
func litchiMihomoFree(value *C.char) {
	C.free(unsafe.Pointer(value))
}

func main() {}

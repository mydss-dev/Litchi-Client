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
	"sync"
	"syscall"
	"unsafe"

	"github.com/metacubex/mihomo/component/dialer"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/hub"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/listener"
	LC "github.com/metacubex/mihomo/listener/config"
	mihomoTun "github.com/metacubex/mihomo/listener/sing_tun"
	"github.com/metacubex/mihomo/tunnel"
)

var (
	coreLock sync.Mutex
	tun      *mihomoTun.Listener
	bridge   unsafe.Pointer
	version  = "dev"
)

//export litchiMihomoStart
func litchiMihomoStart(
	configJSON *C.char,
	homePath *C.char,
	tunFD C.int,
	callback unsafe.Pointer,
) *C.char {
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

//export litchiMihomoStartCoreOnly
func litchiMihomoStartCoreOnly(
	configJSON *C.char,
	homePath *C.char,
) *C.char {
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

//export litchiMihomoStop
func litchiMihomoStop() {
	coreLock.Lock()
	defer coreLock.Unlock()
	stopLocked()
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
func litchiMihomoVersion() *C.char {
	return C.CString(version)
}

//export litchiMihomoFree
func litchiMihomoFree(value *C.char) {
	C.free(unsafe.Pointer(value))
}

func main() {}

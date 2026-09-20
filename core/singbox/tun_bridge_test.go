package main

import (
	"encoding/json"
	"path/filepath"
	"strings"
	"testing"
)

func TestBuildTunBridgeConfigUsesMainCoreSocks(t *testing.T) {
	mainExe := `C:\Program Files\Litchi\litchi-core.exe`
	content, err := buildTunBridgeConfig(17890, 1500, false, "system", mainExe)
	if err != nil {
		t.Fatalf("buildTunBridgeConfig: %v", err)
	}
	var config map[string]any
	if err := json.Unmarshal([]byte(content), &config); err != nil {
		t.Fatalf("decode config: %v", err)
	}

	inbounds := config["inbounds"].([]any)
	tun := inbounds[0].(map[string]any)
	if tun["type"] != "tun" || tun["interface_name"] != windowsTunInterfaceName {
		t.Fatalf("unexpected TUN inbound: %#v", tun)
	}
	addresses := tun["address"].([]any)
	if len(addresses) != 2 ||
		addresses[0] != windowsTunBridgeAddress ||
		addresses[1] != windowsTunBridgeAddressV6 {
		t.Fatalf("Windows TUN must be IPv4/IPv6 dual-stack: %#v", addresses)
	}
	if tun["auto_route"] != true {
		t.Fatalf("dual-stack TUN must install IPv4/IPv6 routes: %#v", tun)
	}
	if tun["mtu"] != float64(1500) || tun["strict_route"] != false || tun["stack"] != "system" {
		t.Fatalf("unexpected conservative Windows TUN profile: %#v", tun)
	}

	outbounds := config["outbounds"].([]any)
	mainCore := outbounds[0].(map[string]any)
	if mainCore["type"] != "socks" || mainCore["server"] != "127.0.0.1" || mainCore["server_port"] != float64(17890) {
		t.Fatalf("unexpected main-core outbound: %#v", mainCore)
	}

	route := config["route"].(map[string]any)
	if route["final"] != "main-core" {
		t.Fatalf("unexpected route final: %#v", route["final"])
	}
	rules := route["rules"].([]any)
	processRule := rules[0].(map[string]any)
	if processRule["outbound"] != "direct" {
		t.Fatalf("main core must bypass bridge: %#v", processRule)
	}
	// Must use process_path (absolute path), NOT process_name (bare filename).
	// A bare process_name match would allow any process named litchi-core.exe
	// (e.g. dropped in %TEMP%) to bypass the TUN — a VPN bypass.
	paths, ok := processRule["process_path"].([]any)
	if !ok || len(paths) == 0 {
		t.Fatalf("process bypass must use process_path, got: %#v", processRule)
	}
	if paths[0] != mainExe {
		t.Fatalf("process_path must be the exact main-core exe: got %v, want %v", paths[0], mainExe)
	}
	if _, hasName := processRule["process_name"]; hasName {
		t.Fatalf("process_name must not be used alongside process_path: %#v", processRule)
	}
	dnsRule := rules[1].(map[string]any)
	if dnsRule["port"] != float64(53) || dnsRule["outbound"] != "main-core" {
		t.Fatalf("DNS must reach main core before private-IP bypass: %#v", dnsRule)
	}
	privateRule := rules[2].(map[string]any)
	if privateRule["ip_is_private"] != true || privateRule["outbound"] != "direct" {
		t.Fatalf("unexpected private-IP bypass rule: %#v", privateRule)
	}
}

func TestBuildTunBridgeConfigRejectsUnsafeInputs(t *testing.T) {
	for _, tc := range []struct {
		name  string
		port  int
		mtu   int
		stack string
	}{
		{name: "port", port: 0, mtu: 1500, stack: "system"},
		{name: "mtu", port: 7890, mtu: 100, stack: "system"},
		{name: "stack", port: 7890, mtu: 1500, stack: "unknown"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if _, err := buildTunBridgeConfig(tc.port, tc.mtu, false, tc.stack, `C:\test\core.exe`); err == nil {
				t.Fatal("expected validation error")
			}
		})
	}
}

func TestBuildTunBridgeConfigProcessPathIsAbsolute(t *testing.T) {
	// The process_path value must be an absolute path so a bare filename
	// cannot match from an arbitrary directory.
	mainExe := `C:\Program Files\Litchi\litchi-core.exe`
	content, err := buildTunBridgeConfig(7890, 1500, true, "gvisor", mainExe)
	if err != nil {
		t.Fatalf("buildTunBridgeConfig: %v", err)
	}
	var config map[string]any
	if err := json.Unmarshal([]byte(content), &config); err != nil {
		t.Fatalf("decode config: %v", err)
	}
	rules := config["route"].(map[string]any)["rules"].([]any)
	processRule := rules[0].(map[string]any)
	paths := processRule["process_path"].([]any)
	p := paths[0].(string)
	if !filepath.IsAbs(p) {
		t.Fatalf("process_path must be absolute: %q", p)
	}
	if !strings.HasSuffix(strings.ToLower(p), ".exe") {
		t.Fatalf("process_path must point to an .exe: %q", p)
	}
}

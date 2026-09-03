package main

import (
	"encoding/json"
	"testing"
)

func TestBuildTunBridgeConfigUsesMainCoreSocks(t *testing.T) {
	content, err := buildTunBridgeConfig(17890, 1500, false, "system")
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
			if _, err := buildTunBridgeConfig(tc.port, tc.mtu, false, tc.stack); err == nil {
				t.Fatal("expected validation error")
			}
		})
	}
}

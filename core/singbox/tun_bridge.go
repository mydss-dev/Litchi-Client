package main

import (
	"encoding/json"
	"fmt"
)

const (
	windowsTunInterfaceName   = "TUN-LOCAL"
	windowsTunBridgeAddress   = "172.19.0.1/30"
	windowsTunBridgeAddressV6 = "fdfe:dcba:9876::1/126"
)

// buildTunBridgeConfig creates the deliberately small privileged sing-box
// instance used by the Windows TUN service. The normal user-owned main core
// keeps all node, DNS, selector and rule state; this privileged box only turns
// packets from the TUN interface into SOCKS traffic for that main core.
func buildTunBridgeConfig(mainProxyPort, mtu int, strictRoute bool, stack string) (string, error) {
	if mainProxyPort <= 0 || mainProxyPort > 65535 {
		return "", fmt.Errorf("invalid main proxy port %d", mainProxyPort)
	}
	if mtu < 576 || mtu > 9000 {
		return "", fmt.Errorf("invalid TUN MTU %d", mtu)
	}
	switch stack {
	case "system", "gvisor", "mixed":
	default:
		return "", fmt.Errorf("invalid TUN stack %q", stack)
	}

	config := map[string]any{
		"log": map[string]any{
			"level":     "warn",
			"timestamp": true,
		},
		"inbounds": []any{
			map[string]any{
				"type":           "tun",
				"tag":            "tun-in",
				"interface_name": windowsTunInterfaceName,
				// Keep the bridge dual-stack so IPv6 application traffic cannot
				// bypass the Windows TUN route. Node transport resolution stays
				// controlled by the main core and does not require an AAAA record.
				"address": []string{
					windowsTunBridgeAddress,
					windowsTunBridgeAddressV6,
				},
				"mtu":          mtu,
				"auto_route":   true,
				"strict_route": strictRoute,
				"stack":        stack,
			},
		},
		"outbounds": []any{
			map[string]any{
				"type":        "socks",
				"tag":         "main-core",
				"server":      "127.0.0.1",
				"server_port": mainProxyPort,
				"version":     "5",
			},
			map[string]any{
				"type": "direct",
				"tag":  "direct",
			},
		},
		"route": map[string]any{
			"auto_detect_interface": true,
			"rules": []any{
				// The main core creates the real node sockets. Those sockets must
				// bypass the TUN bridge or they recursively return to main-core.
				map[string]any{
					"process_name": []string{"litchi-core.exe"},
					"outbound":     "direct",
				},
				// Protocol rules only match metadata populated by sniffing. Keep the
				// privileged bridge thin and route DNS by destination port instead;
				// the main core sniffs and hijacks the DNS payload into its DNS module.
				map[string]any{
					"port":     53,
					"outbound": "main-core",
				},
				// Keep loopback/LAN traffic out of the bridge, including the
				// bridge's own 127.0.0.1 SOCKS hop to the main core.
				map[string]any{
					"ip_is_private": true,
					"outbound":      "direct",
				},
			},
			"final": "main-core",
		},
	}

	content, err := json.Marshal(config)
	if err != nil {
		return "", fmt.Errorf("encode TUN bridge config: %w", err)
	}
	return string(content), nil
}

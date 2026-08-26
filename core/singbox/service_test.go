package main

import "testing"

func TestRejectsInvalidConfig(t *testing.T) {
	var service nativeCore
	if err := service.check(`{"inbounds": [}`, ""); err == nil {
		t.Fatal("invalid JSON was accepted")
	}
	if service.lastError() == "" {
		t.Fatal("validation error was not retained")
	}
}

func TestAcceptsMinimalConfig(t *testing.T) {
	var service nativeCore
	config := `{
  "inbounds": [{"type":"mixed","tag":"mixed-in","listen":"127.0.0.1","listen_port":17890}],
  "outbounds": [{"type":"direct","tag":"direct"}],
  "route": {"final":"direct"}
}`
	if err := service.check(config, t.TempDir()); err != nil {
		t.Fatalf("valid config rejected: %v", err)
	}
}

func TestAcceptsLitchiDesktopSchema(t *testing.T) {
	var service nativeCore
	config := `{
  "log": {"level":"warn","timestamp":true},
  "dns": {
    "servers":[{"type":"local","tag":"dns-local"}],
    "final":"dns-local",
    "strategy":"ipv4_only"
  },
  "inbounds":[{"type":"mixed","tag":"mixed-in","listen":"127.0.0.1","listen_port":17891}],
  "outbounds":[
    {"type":"trojan","tag":"node-1","server":"example.com","server_port":443,"password":"secret","tls":{"enabled":true,"server_name":"example.com"}},
    {"type":"urltest","tag":"auto","outbounds":["node-1"],"url":"https://www.gstatic.com/generate_204","interval":"10m","tolerance":50},
    {"type":"selector","tag":"proxy","outbounds":["auto","node-1"],"default":"node-1"},
    {"type":"direct","tag":"direct"},
    {"type":"block","tag":"block"}
  ],
  "route": {
    "auto_detect_interface":true,
    "rules":[
      {"clash_mode":"direct","outbound":"direct"},
      {"clash_mode":"global","outbound":"proxy"},
      {"ip_is_private":true,"outbound":"direct"},
      {"domain_suffix":["example.org"],"outbound":"proxy"}
    ],
    "final":"proxy"
  },
  "experimental": {
    "clash_api":{"external_controller":"127.0.0.1:19090","default_mode":"rule"},
    "cache_file":{"enabled":true,"path":"sing-box.db","store_fakeip":false}
  }
}`
	if err := service.check(config, t.TempDir()); err != nil {
		t.Fatalf("Litchi desktop schema rejected: %v", err)
	}
}

func TestAcceptsImportedV2BoardSingBoxOutbounds(t *testing.T) {
	var service nativeCore
	config := `{
  "dns":{"servers":[{"type":"local","tag":"dns-local"}],"final":"dns-local"},
  "inbounds":[{"type":"mixed","tag":"mixed-in","listen":"127.0.0.1","listen_port":17892}],
  "outbounds":[
    {"type":"vless","tag":"node-1","server":"example.com","server_port":443,"uuid":"00000000-0000-0000-0000-000000000001","packet_encoding":"xudp","tls":{"enabled":true,"server_name":"example.com"}},
    {"type":"hysteria","tag":"node-2","server":"hy.example.com","server_ports":["20000:30000"],"auth_str":"secret","up_mbps":10,"down_mbps":50,"tls":{"enabled":true,"server_name":"hy.example.com"}},
    {"type":"selector","tag":"proxy","outbounds":["node-1","node-2"],"default":"node-1"},
    {"type":"direct","tag":"direct"}
  ],
  "route":{"final":"proxy"}
}`
	if err := service.check(config, t.TempDir()); err != nil {
		t.Fatalf("V2Board sing-box outbounds rejected: %v", err)
	}
}

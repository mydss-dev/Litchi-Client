//go:build windows

package main

import tun "github.com/sagernet/sing-tun"

func init() {
	tun.TunnelType = "Litchi"
}

//go:build !windows

package main

import (
	"fmt"
	"os"
)

func runTunServiceCommand(args []string) (bool, int) {
	if len(args) == 0 || args[0] != "tun-service" {
		return false, 0
	}
	fmt.Fprintln(os.Stderr, "tun-service is only supported on Windows")
	return true, 2
}

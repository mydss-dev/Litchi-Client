//go:build !windows

package main

func parentProcessAlive(pid int) bool {
	return pid > 0
}

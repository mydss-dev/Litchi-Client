//go:build !windows

package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"fmt"
	"os"
	"unsafe"
)

func resultCode(err error) C.int {
	if err != nil {
		return -1
	}
	return 0
}

// capturePanic protects the C ABI used by macOS/Linux.
func capturePanic(code *C.int) {
	if r := recover(); r != nil {
		coreService.setError(fmt.Sprintf("panic: %v", r))
		*code = -1
	}
}

//export litchi_core_check_config
func litchi_core_check_config(config *C.char, workDir *C.char) (code C.int) {
	if config == nil {
		return resultCode(coreService.setError("config is required"))
	}
	defer capturePanic(&code)
	return resultCode(coreService.check(C.GoString(config), cString(workDir)))
}

//export litchi_core_start
func litchi_core_start(config *C.char, workDir *C.char) (code C.int) {
	if config == nil {
		return resultCode(coreService.setError("config is required"))
	}
	defer capturePanic(&code)
	return resultCode(coreService.start(C.GoString(config), cString(workDir)))
}

//export litchi_core_stop
func litchi_core_stop() C.int { return resultCode(coreService.stop()) }

//export litchi_core_is_running
func litchi_core_is_running() C.int {
	if coreService.isRunning() {
		return 1
	}
	return 0
}

//export litchi_core_version
func litchi_core_version() *C.char { return C.CString(coreService.version()) }

//export litchi_core_last_error
func litchi_core_last_error() *C.char { return C.CString(coreService.lastError()) }

//export litchi_core_free_string
func litchi_core_free_string(value *C.char) { C.free(unsafe.Pointer(value)) }

func cString(value *C.char) string {
	if value == nil {
		return ""
	}
	return C.GoString(value)
}

func main() {
	os.Exit(runCLI(os.Args[1:]))
}

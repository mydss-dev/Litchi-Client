//go:build windows

package main

import (
	"context"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
	"unsafe"

	"golang.org/x/sys/windows/svc"
	"golang.org/x/sys/windows/svc/mgr"
	"golang.org/x/sys/windows/registry"
)

const (
	windowsTunServiceName        = "LitchiTunService"
	windowsTunServiceDisplayName = "Litchi TUN Service"
	windowsTunServiceRegistryKey = `SOFTWARE\Litchi\TunService`
)

type tunServiceSettings struct {
	Port     int
	AuthHash [sha256.Size]byte
}

type tunServiceStartRequest struct {
	MainProxyPort int    `json:"main_proxy_port"`
	MTU           int    `json:"mtu"`
	StrictRoute   bool   `json:"strict_route"`
	Stack         string `json:"stack"`
}

type tunServiceStatus struct {
	State string `json:"state"`
	Error string `json:"error,omitempty"`
	PID   int    `json:"pid"`
}

type tunRuntime struct {
	mu            sync.Mutex
	core          nativeCore
	state         string
	lastErr       string
	mainProxyPort int
	mainCoreExePath string
	generation    uint64
}

func newTunRuntime() *tunRuntime {
	return &tunRuntime{state: "idle"}
}

func (r *tunRuntime) snapshot() tunServiceStatus {
	r.mu.Lock()
	defer r.mu.Unlock()
	return tunServiceStatus{State: r.state, Error: r.lastErr, PID: os.Getpid()}
}

func (r *tunRuntime) start(req tunServiceStartRequest) error {
	if req.MTU == 0 {
		req.MTU = 1500
	}
	if strings.TrimSpace(req.Stack) == "" {
		req.Stack = "system"
	}
	if !tcpPortReady(req.MainProxyPort) {
		return fmt.Errorf("main core SOCKS port %d is not ready", req.MainProxyPort)
	}
	executable, err := os.Executable()
	if err != nil {
		return fmt.Errorf("resolve main core executable path: %w", err)
	}
	executable, _ = filepath.Abs(executable)

	// Verify the process listening on the main-core port is actually our own
	// binary. A local process that binds the (usually predictable) mixed/SOCKS
	// port would otherwise become the SOCKS destination for ALL TUN-captured
	// traffic — an on-device MITM / proxy-bypass via port squatting.
	if err := verifyPortListenerIsSelf(req.MainProxyPort, executable); err != nil {
		return fmt.Errorf("port %d listener identity check failed: %w", req.MainProxyPort, err)
	}
	// Remember the expected path so the monitor can re-check if the port
	// disappears and reappears.
	r.mainCoreExePath = executable

	config, err := buildTunBridgeConfig(req.MainProxyPort, req.MTU, req.StrictRoute, req.Stack, executable)
	if err != nil {
		return err
	}

	r.mu.Lock()
	defer r.mu.Unlock()
	if r.state == "running" && r.mainProxyPort == req.MainProxyPort {
		return nil
	}
	r.generation++
	_ = r.core.stop()
	r.state = "starting"
	r.lastErr = ""
	if err := r.core.start(config, ""); err != nil {
		r.state = "error"
		r.lastErr = err.Error()
		return err
	}
	r.mainProxyPort = req.MainProxyPort
	r.state = "running"
	generation := r.generation
	go r.monitorMainCore(generation, req.MainProxyPort)
	return nil
}

func (r *tunRuntime) stop() error {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.stopLocked("")
}

func (r *tunRuntime) stopLocked(reason string) error {
	r.generation++
	err := r.core.stop()
	r.mainProxyPort = 0
	if reason != "" {
		r.state = "error"
		r.lastErr = reason
	} else if err != nil {
		r.state = "error"
		r.lastErr = err.Error()
	} else {
		r.state = "idle"
		r.lastErr = ""
	}
	return err
}

func (r *tunRuntime) monitorMainCore(generation uint64, port int) {
	missed := 0
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()
	for range ticker.C {
		r.mu.Lock()
		active := r.generation == generation && r.state == "running" && r.mainProxyPort == port
		exePath := r.mainCoreExePath
		r.mu.Unlock()
		if !active {
			return
		}
		if tcpPortReady(port) {
			missed = 0
			// After the port was missing and reappears, verify the listener
			// is still our own binary. A port squatter that binds between
			// probes would otherwise keep the TUN alive and MITM all traffic.
			if err := verifyPortListenerIsSelf(port, exePath); err != nil {
				fmt.Fprintf(os.Stderr, "tun-service: main-core port %d listener identity changed: %v — stopping TUN for fail-safe\n", port, err)
				r.mu.Lock()
				if r.generation == generation && r.state == "running" {
					_ = r.stopLocked("main core listener replaced by unknown process")
				}
				r.mu.Unlock()
				return
			}
			continue
		}
		missed++
		if missed < 3 {
			continue
		}
		r.mu.Lock()
		if r.generation == generation && r.state == "running" {
			_ = r.stopLocked("main core disappeared; TUN stopped for fail-safe cleanup")
		}
		r.mu.Unlock()
		return
	}
}

func tcpPortReady(port int) bool {
	if port <= 0 || port > 65535 {
		return false
	}
	conn, err := net.DialTimeout("tcp", net.JoinHostPort("127.0.0.1", strconv.Itoa(port)), 400*time.Millisecond)
	if err != nil {
		return false
	}
	_ = conn.Close()
	return true
}

type litchiTunWindowsService struct{}

func (s *litchiTunWindowsService) Execute(_ []string, changes <-chan svc.ChangeRequest, statuses chan<- svc.Status) (bool, uint32) {
	statuses <- svc.Status{State: svc.StartPending}
	settings, err := readTunServiceSettings()
	if err != nil {
		return false, 1
	}
	runtime := newTunRuntime()
	server, err := startTunControlServer(settings, runtime)
	if err != nil {
		return false, 2
	}
	statuses <- svc.Status{State: svc.Running, Accepts: svc.AcceptStop | svc.AcceptShutdown}

	for change := range changes {
		switch change.Cmd {
		case svc.Interrogate:
			statuses <- change.CurrentStatus
		case svc.Stop, svc.Shutdown:
			statuses <- svc.Status{State: svc.StopPending}
			_ = runtime.stop()
			ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
			_ = server.Shutdown(ctx)
			cancel()
			return false, 0
		}
	}
	return false, 0
}

func startTunControlServer(settings tunServiceSettings, runtime *tunRuntime) (*http.Server, error) {
	authorized := func(r *http.Request) bool {
		token := r.Header.Get("X-Litchi-Tun-Token")
		if token == "" {
			return false
		}
		sum := sha256.Sum256([]byte(token))
		return subtle.ConstantTimeCompare(sum[:], settings.AuthHash[:]) == 1
	}
	writeStatus := func(w http.ResponseWriter, status int) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(status)
		_ = json.NewEncoder(w).Encode(runtime.snapshot())
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/status", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		if !authorized(r) {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		writeStatus(w, http.StatusOK)
	})
	mux.HandleFunc("/start", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		if !authorized(r) {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		defer r.Body.Close()
		var req tunServiceStartRequest
		decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 16*1024))
		if err := decoder.Decode(&req); err != nil {
			http.Error(w, "invalid request", http.StatusBadRequest)
			return
		}
		if err := runtime.start(req); err != nil {
			writeStatus(w, http.StatusInternalServerError)
			return
		}
		writeStatus(w, http.StatusOK)
	})
	mux.HandleFunc("/stop", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		if !authorized(r) {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		if err := runtime.stop(); err != nil {
			writeStatus(w, http.StatusInternalServerError)
			return
		}
		writeStatus(w, http.StatusOK)
	})

	listener, err := net.Listen("tcp", net.JoinHostPort("127.0.0.1", strconv.Itoa(settings.Port)))
	if err != nil {
		return nil, err
	}
	server := &http.Server{
		Handler:           mux,
		ReadHeaderTimeout: 2 * time.Second,
		ReadTimeout:       5 * time.Second,
		WriteTimeout:      5 * time.Second,
		IdleTimeout:       15 * time.Second,
		MaxHeaderBytes:    8 * 1024,
	}
	go func() { _ = server.Serve(listener) }()
	return server, nil
}

func runTunServiceCommand(args []string) (bool, int) {
	if len(args) == 0 || args[0] != "tun-service" {
		return false, 0
	}
	if len(args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: litchi-core.exe tun-service run|install|uninstall")
		return true, 2
	}
	switch args[1] {
	case "run":
		if err := svc.Run(windowsTunServiceName, &litchiTunWindowsService{}); err != nil {
			fmt.Fprintln(os.Stderr, err)
			return true, 1
		}
		return true, 0
	case "install":
		return true, installTunWindowsService(args[2:])
	case "uninstall":
		return true, uninstallTunWindowsService()
	default:
		fmt.Fprintln(os.Stderr, "unknown tun-service command")
		return true, 2
	}
}

func installTunWindowsService(args []string) int {
	flags := flag.NewFlagSet("tun-service install", flag.ContinueOnError)
	authHash := flags.String("auth-hash", "", "SHA-256 of the local control token")
	port := flags.Int("port", 0, "localhost control port")
	if err := flags.Parse(args); err != nil {
		return 2
	}
	if _, err := decodeAuthHash(*authHash); err != nil || *port <= 1024 || *port > 65535 {
		fmt.Fprintln(os.Stderr, "invalid TUN service credentials")
		return 2
	}

	manager, err := mgr.Connect()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	defer manager.Disconnect()

	if existing, openErr := manager.OpenService(windowsTunServiceName); openErr == nil {
		if err := stopManagedService(existing); err != nil {
			existing.Close()
			fmt.Fprintln(os.Stderr, err)
			return 1
		}
		if err := existing.Delete(); err != nil {
			existing.Close()
			fmt.Fprintln(os.Stderr, err)
			return 1
		}
		existing.Close()
		// SCM deletion is asynchronous; do not create a replacement until the
		// old registration is actually gone.
		deleted := false
		for i := 0; i < 40; i++ {
			probe, probeErr := manager.OpenService(windowsTunServiceName)
			if probeErr != nil {
				deleted = true
				break
			}
			probe.Close()
			time.Sleep(100 * time.Millisecond)
		}
		if !deleted {
			fmt.Fprintln(os.Stderr, "timed out waiting for old TUN service deletion")
			return 1
		}
	}

	if err := writeTunServiceSettings(*authHash, *port); err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	executable, err := os.Executable()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	executable, _ = filepath.Abs(executable)

	// Refuse to install a LocalSystem service from a user-writable directory.
	// A standard user who can replace the service binary gets SYSTEM on next boot (LPE).
	// Official Inno installs always land under Program Files which passes both checks.
	if err := verifyInstallPathSafety(executable); err != nil {
		fmt.Fprintf(os.Stderr, "install path unsafe: %v\n", err)
		return 1
	}

	var service *mgr.Service
	for attempt := 0; attempt < 20; attempt++ {
		service, err = manager.CreateService(
			windowsTunServiceName,
			executable,
			mgr.Config{
				DisplayName: windowsTunServiceDisplayName,
				Description: "Privileged TUN bridge for Litchi Client",
				StartType:   mgr.StartAutomatic,
			},
			"tun-service", "run",
		)
		if err == nil {
			break
		}
		time.Sleep(150 * time.Millisecond)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	defer service.Close()
	if err := service.Start(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	return 0
}

func uninstallTunWindowsService() int {
	manager, err := mgr.Connect()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	defer manager.Disconnect()

	if service, openErr := manager.OpenService(windowsTunServiceName); openErr == nil {
		if err := stopManagedService(service); err != nil {
			service.Close()
			fmt.Fprintln(os.Stderr, err)
			return 1
		}
		if err := service.Delete(); err != nil {
			service.Close()
			fmt.Fprintln(os.Stderr, err)
			return 1
		}
		service.Close()
	}
	_ = registry.DeleteKey(registry.LOCAL_MACHINE, windowsTunServiceRegistryKey)
	return 0
}

func stopManagedService(service *mgr.Service) error {
	status, err := service.Query()
	if err != nil {
		return fmt.Errorf("query TUN service before stop: %w", err)
	}
	if status.State == svc.Stopped {
		return nil
	}

	if _, err := service.Control(svc.Stop); err != nil {
		// The service can race to Stopped between Query and Control. Confirm that
		// state once more before treating the control error as fatal.
		status, queryErr := service.Query()
		if queryErr == nil && status.State == svc.Stopped {
			return nil
		}
		return fmt.Errorf("stop TUN service: %w", err)
	}

	deadline := time.Now().Add(10 * time.Second)
	for time.Now().Before(deadline) {
		status, err := service.Query()
		if err != nil {
			return fmt.Errorf("query TUN service while stopping: %w", err)
		}
		if status.State == svc.Stopped {
			return nil
		}
		time.Sleep(150 * time.Millisecond)
	}
	return fmt.Errorf("timed out waiting for TUN service to stop")
}

func writeTunServiceSettings(authHash string, port int) error {
	if _, err := decodeAuthHash(authHash); err != nil {
		return err
	}
	key, _, err := registry.CreateKey(
		registry.LOCAL_MACHINE,
		windowsTunServiceRegistryKey,
		registry.SET_VALUE|registry.QUERY_VALUE,
	)
	if err != nil {
		return err
	}
	defer key.Close()
	if err := key.SetStringValue("AuthHash", strings.ToLower(authHash)); err != nil {
		return err
	}
	return key.SetDWordValue("Port", uint32(port))
}

func readTunServiceSettings() (tunServiceSettings, error) {
	key, err := registry.OpenKey(
		registry.LOCAL_MACHINE,
		windowsTunServiceRegistryKey,
		registry.QUERY_VALUE,
	)
	if err != nil {
		return tunServiceSettings{}, err
	}
	defer key.Close()
	hashText, _, err := key.GetStringValue("AuthHash")
	if err != nil {
		return tunServiceSettings{}, err
	}
	hash, err := decodeAuthHash(hashText)
	if err != nil {
		return tunServiceSettings{}, err
	}
	port, _, err := key.GetIntegerValue("Port")
	if err != nil || port <= 1024 || port > 65535 {
		return tunServiceSettings{}, fmt.Errorf("invalid TUN service port")
	}
	return tunServiceSettings{Port: int(port), AuthHash: hash}, nil
}

func decodeAuthHash(value string) ([sha256.Size]byte, error) {
	var result [sha256.Size]byte
	decoded, err := hex.DecodeString(strings.TrimSpace(value))
	if err != nil || len(decoded) != sha256.Size {
		return result, fmt.Errorf("invalid auth hash")
	}
	copy(result[:], decoded)
	return result, nil
}

// verifyInstallPathSafety rejects installing a LocalSystem service from a
// user-writable location. A standard user who can replace the service binary
// gains SYSTEM code execution on the next boot (local privilege escalation).
//
// The check: the executable must live under %ProgramFiles% or
// %ProgramFiles(x86)%, which default to Administrators-only write access.
// Portable installs from user-writable directories are explicitly refused.
// This mirrors the Inno Setup default of PrivilegesRequired=admin +
// DefaultDirName={autopf}\... .
func verifyInstallPathSafety(executable string) error {
	executable = filepath.Clean(executable)
	programFiles := os.Getenv("ProgramFiles")
	programFilesX86 := os.Getenv("ProgramFiles(x86)")
	for _, base := range []string{programFiles, programFilesX86} {
		if base == "" {
			continue
		}
		base = filepath.Clean(base)
		if strings.EqualFold(executable, base) {
			continue
		}
		if strings.HasPrefix(strings.ToLower(executable+"\\"), strings.ToLower(base+"\\")) {
			return nil
		}
	}
	return fmt.Errorf(
		"refusing to install privileged service from %s — "+
			"the TUN service runs as LocalSystem and the binary must live "+
			"under %%ProgramFiles%% to prevent replacement by a standard user",
		executable,
	)
}

// verifyPortListenerIsSelf checks that the process listening on 127.0.0.1:port
// is the same binary as expectedPath. This prevents a local port squatting
// attack where another process binds the main-core mixed/SOCKS port and
// becomes the SOCKS destination for all TUN traffic (on-device MITM).
//
// It uses GetExtendedTcpTable to find the LISTENING socket's owning PID,
// then QueryFullProcessImageNameW to compare the image path. The check is
// best-effort: if the API is unavailable or the PID disappears between
// lookups, we fail closed (return an error) rather than assume it's safe.
func verifyPortListenerIsSelf(port int, expectedPath string) error {
	pid, err := getTcpListenerPID(uint16(port))
	if err != nil {
		return fmt.Errorf("cannot resolve listener PID: %w", err)
	}
	imagePath, err := getProcessImagePath(pid)
	if err != nil {
		return fmt.Errorf("cannot resolve listener image path (pid=%d): %w", pid, err)
	}
	if !strings.EqualFold(filepath.Clean(imagePath), filepath.Clean(expectedPath)) {
		return fmt.Errorf("port %d is owned by %q, not by %q", port, imagePath, expectedPath)
	}
	return nil
}

// getTcpListenerPID returns the PID of the process listening on 127.0.0.1:port.
// It calls GetExtendedTcpTable (TCP_TABLE_OWNER_PID_LISTENER) and scans for
// the matching port. Returns an error if no listener is found.
func getTcpListenerPID(port uint16) (uint32, error) {
	// Use the iphlpapi API directly.
	// TCP_TABLE_OWNER_PID_LISTENER = 3
	const tableClass = 3 // TCP_TABLE_OWNER_PID_LISTENER
	const iphlpapi = "iphlpapi.dll"
	const procName = "GetExtendedTcpTable"

	// Start with a 4 KB buffer and grow up to ~1 MB.
	var buf []byte
	for size := uint32(4096); size < 1024*1024; {
		buf = make([]byte, size)
		ret := getExtendedTcpTableSyscall(
			unsafe.Pointer(&buf[0]),
			&size,
			false, // sorted
			2,     // AF_INET (IPv4 only — main core listens on 127.0.0.1)
			tableClass,
			0, // reserved
		)
		const errorInsufficientBuffer = 122
		if ret == errorInsufficientBuffer {
			// size was updated with the required size; retry.
			continue
		}
		if ret != 0 {
			return 0, fmt.Errorf("GetExtendedTcpTable failed: %d", ret)
		}
		break
	}
	if len(buf) == 0 {
		return 0, fmt.Errorf("GetExtendedTcpTable buffer allocation failed")
	}

	// MIB_TCPTABLE_OWNER_PID layout:
	//   dwNumEntries: uint32
	//   table: [dwNumEntries]MIB_TCPROW_OWNER_PID
	// Each MIB_TCPROW_OWNER_PID is 4 uint32s (state, localAddr, localPort, remoteAddr, remotePort, owningPid) — actually 6.
	// Actually: state, localAddr, localPort, remoteAddr, remotePort, owningPid = 6*4=24 bytes.
	numEntries := *(*uint32)(unsafe.Pointer(&buf[0]))
	rowOffset := 4 // after dwNumEntries
	rowSize := 6 * 4
	for i := uint32(0); i < numEntries; i++ {
		rowStart := rowOffset + int(i)*rowSize
		if rowStart+rowSize > len(buf) {
			break
		}
		localPortNet := *(*uint32)(unsafe.Pointer(&buf[rowStart+2*4]))
		// Port is stored in network byte order (big-endian) as a uint32.
		localPort := uint16((localPortNet >> 8) | (localPortNet << 8))
		// Also check localAddr is 127.0.0.1 (loopback).
		localAddr := *(*uint32)(unsafe.Pointer(&buf[rowStart+1*4]))
		if localPort == port && localAddr == 0x0100007F { // 127.0.0.1 little-endian
			pid := *(*uint32)(unsafe.Pointer(&buf[rowStart+5*4]))
			return pid, nil
		}
	}
	return 0, fmt.Errorf("no listener found on port %d", port)
}

// getProcessImagePath returns the full image path of the process with pid
// using QueryFullProcessImageNameW. Fails closed if the process has exited.
func getProcessImagePath(pid uint32) (string, error) {
	if pid == 0 {
		return "", fmt.Errorf("invalid pid 0")
	}
	const processQueryLimitedInformation = 0x1000
	h, err := openProcess(processQueryLimitedInformation, false, pid)
	if err != nil || h == 0 {
		return "", fmt.Errorf("OpenProcess failed: %w", err)
	}
	defer closeHandle(h)

	var size uint32 = 1024
	buf := make([]uint16, size)
	err = queryFullProcessImageNameW(h, 0, &buf[0], &size)
	if err != nil {
		return "", fmt.Errorf("QueryFullProcessImageNameW failed: %w", err)
	}
	return syscall.UTF16ToString(buf[:size]), nil
}

// ── Win32 syscall shims ──────────────────────────────────────────────────
//
// These use the standard Windows API so we don't have to depend on the full
// golang.org/x/sys/windows mksysc output for these specific APIs.
// They are thin wrappers; all error handling lives in the callers above.

var (
	iphlpapi        = syscall.NewLazyDLL("iphlpapi.dll")
	procGetExtTcp   = iphlpapi.NewProc("GetExtendedTcpTable")
	kernel32        = syscall.NewLazyDLL("kernel32.dll")
	procOpenProcess = kernel32.NewProc("OpenProcess")
	procCloseHandle = kernel32.NewProc("CloseHandle")
	procQueryImg    = kernel32.NewProc("QueryFullProcessImageNameW")
)

func getExtendedTcpTableSyscall(
	table unsafe.Pointer,
	size *uint32,
	sorted bool,
	ipVersion uint32,
	tableClass uint32,
	reserved uint32,
) uint32 {
	var sortParam uint32
	if sorted {
		sortParam = 1
	}
	ret, _, _ := procGetExtTcp.Call(
		uintptr(table),
		uintptr(unsafe.Pointer(size)),
		uintptr(sortParam),
		uintptr(ipVersion),
		uintptr(tableClass),
		uintptr(reserved),
	)
	return uint32(ret)
}

func openProcess(access uint32, inheritHandle bool, pid uint32) (syscall.Handle, error) {
	var inherit uint32
	if inheritHandle {
		inherit = 1
	}
	r1, _, e1 := procOpenProcess.Call(
		uintptr(access),
		uintptr(inherit),
		uintptr(pid),
	)
	if r1 == 0 {
		return 0, e1
	}
	return syscall.Handle(r1), nil
}

func closeHandle(h syscall.Handle) error {
	r1, _, e1 := procCloseHandle.Call(uintptr(h))
	if r1 == 0 {
		return e1
	}
	return nil
}

func queryFullProcessImageNameW(
	h syscall.Handle,
	flags uint32,
	name *uint16,
	size *uint32,
) error {
	r1, _, e1 := procQueryImg.Call(
		uintptr(h),
		uintptr(flags),
		uintptr(unsafe.Pointer(name)),
		uintptr(unsafe.Pointer(size)),
	)
	if r1 == 0 {
		return e1
	}
	return nil
}
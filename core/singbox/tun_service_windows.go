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
	"time"

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
	config, err := buildTunBridgeConfig(req.MainProxyPort, req.MTU, req.StrictRoute, req.Stack)
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
		r.mu.Unlock()
		if !active {
			return
		}
		if tcpPortReady(port) {
			missed = 0
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
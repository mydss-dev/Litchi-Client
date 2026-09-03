package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"sync"
	"time"
)

type processStatus struct {
	State   string `json:"state"`
	Error   string `json:"error,omitempty"`
	Version string `json:"version"`
	PID     int    `json:"pid"`
}

type statusStore struct {
	mu    sync.RWMutex
	state string
	err   string
}

func (s *statusStore) set(state string, err error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.state = state
	if err == nil {
		s.err = ""
	} else {
		s.err = err.Error()
	}
}

func (s *statusStore) snapshot() processStatus {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return processStatus{
		State:   s.state,
		Error:   s.err,
		Version: coreService.version(),
		PID:     os.Getpid(),
	}
}

func runCLI(args []string) int {
	if handled, code := runTunServiceCommand(args); handled {
		return code
	}
	if len(args) == 1 && args[0] == "version" {
		fmt.Println(coreService.version())
		return 0
	}
	if len(args) == 0 || args[0] != "run" {
		fmt.Fprintln(os.Stderr, "usage: litchi-core.exe run --config <path> --working-directory <path> --control-port <port> --token <token> --parent-pid <pid>")
		return 2
	}

	flags := flag.NewFlagSet("run", flag.ContinueOnError)
	configPath := flags.String("config", "", "sing-box config path")
	workingDirectory := flags.String("working-directory", "", "sing-box working directory")
	controlPort := flags.Int("control-port", 0, "localhost control port")
	token := flags.String("token", "", "control authentication token")
	parentPID := flags.Int("parent-pid", 0, "Flutter parent process ID")
	if err := flags.Parse(args[1:]); err != nil {
		return 2
	}
	if *configPath == "" || *controlPort <= 0 || *controlPort > 65535 || *token == "" {
		fmt.Fprintln(os.Stderr, "missing required run arguments")
		return 2
	}

	state := &statusStore{state: "starting"}
	stopCh := make(chan struct{})
	var stopOnce sync.Once
	requestStop := func() { stopOnce.Do(func() { close(stopCh) }) }

	mux := http.NewServeMux()
	authorized := func(w http.ResponseWriter, r *http.Request) bool {
		if r.Header.Get("X-Litchi-Token") == *token {
			return true
		}
		http.Error(w, "forbidden", http.StatusForbidden)
		return false
	}
	mux.HandleFunc("/status", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet || !authorized(w, r) {
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(state.snapshot())
	})
	mux.HandleFunc("/stop", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost || !authorized(w, r) {
			return
		}
		w.WriteHeader(http.StatusAccepted)
		_, _ = w.Write([]byte("stopping"))
		requestStop()
	})

	listener, err := net.Listen("tcp", "127.0.0.1:"+strconv.Itoa(*controlPort))
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
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

	if *parentPID > 0 {
		go func() {
			ticker := time.NewTicker(time.Second)
			defer ticker.Stop()
			for {
				select {
				case <-stopCh:
					return
				case <-ticker.C:
					if !parentProcessAlive(*parentPID) {
						requestStop()
						return
					}
				}
			}
		}()
	}

	interrupts := make(chan os.Signal, 1)
	signal.Notify(interrupts, os.Interrupt)
	defer signal.Stop(interrupts)
	go func() {
		select {
		case <-interrupts:
			requestStop()
		case <-stopCh:
		}
	}()

	content, err := os.ReadFile(*configPath)
	if err != nil {
		state.set("error", err)
		waitForErrorAcknowledgement(stopCh)
		shutdownControlServer(server)
		return 1
	}

	startResult := make(chan error, 1)
	go func() {
		defer func() {
			if recovered := recover(); recovered != nil {
				startResult <- fmt.Errorf("panic: %v", recovered)
			}
		}()
		startResult <- coreService.start(string(content), *workingDirectory)
	}()

	select {
	case <-stopCh:
		// If native startup is wedged, returning from main terminates the isolated
		// process without ever endangering the Flutter GUI.
		shutdownControlServer(server)
		return 1
	case err = <-startResult:
	}
	if err != nil {
		state.set("error", err)
		waitForErrorAcknowledgement(stopCh)
		shutdownControlServer(server)
		return 1
	}
	state.set("running", nil)

	<-stopCh
	state.set("stopping", nil)
	stopErr := coreService.stop()
	if stopErr != nil {
		state.set("error", stopErr)
	} else {
		state.set("stopped", nil)
	}
	shutdownControlServer(server)
	if stopErr != nil {
		fmt.Fprintln(os.Stderr, stopErr)
		return 1
	}
	return 0
}

func waitForErrorAcknowledgement(stopCh <-chan struct{}) {
	select {
	case <-stopCh:
	case <-time.After(15 * time.Second):
	}
}

func shutdownControlServer(server *http.Server) {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	_ = server.Shutdown(ctx)
}

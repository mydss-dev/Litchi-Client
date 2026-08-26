package main

import (
	"context"
	"errors"
	"sync"

	box "github.com/sagernet/sing-box"
	CBox "github.com/sagernet/sing-box/constant"
	"github.com/sagernet/sing-box/experimental/deprecated"
	"github.com/sagernet/sing-box/include"
	"github.com/sagernet/sing-box/log"
	"github.com/sagernet/sing-box/option"
	E "github.com/sagernet/sing/common/exceptions"
	"github.com/sagernet/sing/common/json"
	"github.com/sagernet/sing/service"
	"github.com/sagernet/sing/service/filemanager"
)

var coreService nativeCore

type nativeCore struct {
	sync.Mutex
	instance *box.Box
	cancel   context.CancelFunc
	lastErr  string
}

func coreContext(workDir string) context.Context {
	ctx := context.Background()
	if workDir != "" {
		ctx = filemanager.WithDefault(ctx, workDir, workDir, -1, -1)
	}
	return include.Context(
		service.ContextWith(ctx, deprecated.NewStderrManager(log.StdLogger())),
	)
}

func parseOptions(ctx context.Context, content string) (option.Options, error) {
	options, err := json.UnmarshalExtendedContext[option.Options](ctx, []byte(content))
	if err != nil {
		return option.Options{}, E.Cause(err, "decode config")
	}
	return options, nil
}

func (c *nativeCore) check(content, workDir string) error {
	c.Lock()
	defer c.Unlock()
	ctx := coreContext(workDir)
	options, err := parseOptions(ctx, content)
	if err != nil {
		return c.remember(err)
	}
	instance, err := box.New(box.Options{Context: ctx, Options: options})
	if err == nil {
		err = instance.Close()
	}
	return c.remember(err)
}

func (c *nativeCore) start(content, workDir string) error {
	c.Lock()
	defer c.Unlock()
	if c.instance != nil {
		return c.remember(errors.New("core is already running"))
	}
	ctx, cancel := context.WithCancel(coreContext(workDir))
	options, err := parseOptions(ctx, content)
	if err != nil {
		cancel()
		return c.remember(err)
	}
	instance, err := box.New(box.Options{Context: ctx, Options: options})
	if err != nil {
		cancel()
		return c.remember(err)
	}
	if err = instance.Start(); err != nil {
		cancel()
		_ = instance.Close()
		return c.remember(E.Cause(err, "start service"))
	}
	c.instance = instance
	c.cancel = cancel
	return c.remember(nil)
}

func (c *nativeCore) stop() error {
	c.Lock()
	defer c.Unlock()
	if c.instance == nil {
		return c.remember(nil)
	}
	c.cancel()
	err := c.instance.Close()
	c.instance = nil
	c.cancel = nil
	return c.remember(err)
}

func (c *nativeCore) isRunning() bool {
	c.Lock()
	defer c.Unlock()
	return c.instance != nil
}

func (c *nativeCore) version() string { return CBox.Version }

func (c *nativeCore) lastError() string {
	c.Lock()
	defer c.Unlock()
	return c.lastErr
}

func (c *nativeCore) setError(message string) error {
	c.Lock()
	defer c.Unlock()
	return c.remember(errors.New(message))
}

func (c *nativeCore) remember(err error) error {
	if err == nil {
		c.lastErr = ""
		return nil
	}
	c.lastErr = err.Error()
	return err
}

//go:build windows
// +build windows

package tmux

import (
	"fmt"
	"os/exec"
	"syscall"
)

// killProcessGroup kills a process group on Windows using taskkill
func killProcessGroup(pgid int) error {
	// On Windows, use taskkill to kill process tree
	cmd := exec.Command("taskkill", "/F", "/T", "/PID", fmt.Sprintf("%d", pgid))
	return cmd.Run()
}

// killProcess kills a process on Windows
func killProcess(pid int, sig syscall.Signal) error {
	// On Windows, use taskkill
	cmd := exec.Command("taskkill", "/F", "/PID", fmt.Sprintf("%d", pid))
	return cmd.Run()
}

//go:build !windows
// +build !windows

package tmux

import (
	"syscall"
)

// killProcessGroup kills a process group using Unix syscalls
func killProcessGroup(pgid int) error {
	_ = syscall.Kill(-pgid, syscall.SIGTERM)
	return nil
}

// killProcess kills a process using Unix syscalls  
func killProcess(pid int, sig syscall.Signal) error {
	return syscall.Kill(pid, sig)
}

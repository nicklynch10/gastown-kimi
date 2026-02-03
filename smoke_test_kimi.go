// +build ignore

// Smoke test for Kimi K2.5 integration
// This test validates that Gastown's Kimi integration works correctly
// by testing the agent preset, runtime config, and command generation.

package main

import (
	"fmt"
	"os"
	"strings"

	"github.com/steveyegge/gastown/internal/config"
)

func main() {
	fmt.Println("=== GASTOWN KIMI K2.5 SMOKE TEST ===")
	fmt.Println()

	passed := 0
	failed := 0

	// Test 1: AgentKimi constant exists
	fmt.Println("[TEST 1] AgentKimi constant...")
	if config.AgentKimi == "kimi" {
		fmt.Println("  ✓ PASS: AgentKimi = 'kimi'")
		passed++
	} else {
		fmt.Printf("  ✗ FAIL: AgentKimi = '%s', expected 'kimi'\n", config.AgentKimi)
		failed++
	}

	// Test 2: Kimi preset is accessible
	fmt.Println("[TEST 2] Kimi preset accessibility...")
	preset := config.GetAgentPreset(config.AgentKimi)
	if preset != nil {
		fmt.Println("  ✓ PASS: GetAgentPreset(AgentKimi) returned non-nil")
		passed++
	} else {
		fmt.Println("  ✗ FAIL: GetAgentPreset(AgentKimi) returned nil")
		failed++
	}

	// Test 3: Preset configuration
	fmt.Println("[TEST 3] Kimi preset configuration...")
	if preset != nil {
		checks := []struct {
			name     string
			got      string
			expected string
		}{
			{"Command", preset.Command, "kimi"},
			{"SessionIDEnv", preset.SessionIDEnv, "KIMI_SESSION_ID"},
			{"ResumeFlag", preset.ResumeFlag, "--continue"},
			{"ResumeStyle", preset.ResumeStyle, "flag"},
		}

		allPass := true
		for _, check := range checks {
			if check.got != check.expected {
				fmt.Printf("  ✗ FAIL: %s = '%s', expected '%s'\n", check.name, check.got, check.expected)
				allPass = false
			}
		}

		// Check Args
		if len(preset.Args) != 1 || preset.Args[0] != "--yolo" {
			fmt.Printf("  ✗ FAIL: Args = %v, expected ['--yolo']\n", preset.Args)
			allPass = false
		}

		// Check ProcessNames
		if len(preset.ProcessNames) != 1 || preset.ProcessNames[0] != "kimi" {
			fmt.Printf("  ✗ FAIL: ProcessNames = %v, expected ['kimi']\n", preset.ProcessNames)
			allPass = false
		}

		// Check SupportsHooks
		if !preset.SupportsHooks {
			fmt.Println("  ✗ FAIL: SupportsHooks should be true")
			allPass = false
		}

		if allPass {
			fmt.Println("  ✓ PASS: All preset fields correct")
			passed++
		} else {
			failed++
		}
	} else {
		fmt.Println("  ✗ SKIP: Preset is nil")
	}

	// Test 4: RuntimeConfig generation
	fmt.Println("[TEST 4] RuntimeConfig generation...")
	rc := config.RuntimeConfigFromPreset(config.AgentKimi)
	if rc != nil && rc.Command == "kimi" && len(rc.Args) == 1 && rc.Args[0] == "--yolo" {
		fmt.Println("  ✓ PASS: RuntimeConfig correct")
		passed++
	} else {
		fmt.Printf("  ✗ FAIL: RuntimeConfig = %+v\n", rc)
		failed++
	}

	// Test 5: Resume command generation
	fmt.Println("[TEST 5] Resume command generation...")
	resumeCmd := config.BuildResumeCommand("kimi", "test-session-123")
	expectedParts := []string{"kimi", "--yolo", "--continue", "test-session-123"}
	allFound := true
	for _, part := range expectedParts {
		if !strings.Contains(resumeCmd, part) {
			fmt.Printf("  ✗ FAIL: Missing '%s' in resume command\n", part)
			allFound = false
		}
	}
	if allFound {
		fmt.Printf("  ✓ PASS: Resume command = '%s'\n", resumeCmd)
		passed++
	} else {
		fmt.Printf("  ✗ FAIL: Resume command = '%s'\n", resumeCmd)
		failed++
	}

	// Test 6: GetAgentPresetByName
	fmt.Println("[TEST 6] GetAgentPresetByName lookup...")
	byName := config.GetAgentPresetByName("kimi")
	if byName != nil && byName.Name == config.AgentKimi {
		fmt.Println("  ✓ PASS: Lookup by name works")
		passed++
	} else {
		fmt.Println("  ✗ FAIL: Lookup by name failed")
		failed++
	}

	// Test 7: IsKnownPreset
	fmt.Println("[TEST 7] IsKnownPreset check...")
	if config.IsKnownPreset("kimi") {
		fmt.Println("  ✓ PASS: 'kimi' is known preset")
		passed++
	} else {
		fmt.Println("  ✗ FAIL: 'kimi' is not known preset")
		failed++
	}

	// Test 8: Session ID env var
	fmt.Println("[TEST 8] Session ID environment variable...")
	sessionEnv := config.GetSessionIDEnvVar("kimi")
	if sessionEnv == "KIMI_SESSION_ID" {
		fmt.Println("  ✓ PASS: Session ID env = 'KIMI_SESSION_ID'")
		passed++
	} else {
		fmt.Printf("  ✗ FAIL: Session ID env = '%s'\n", sessionEnv)
		failed++
	}

	// Test 9: Process names
	fmt.Println("[TEST 9] Process names for detection...")
	processNames := config.GetProcessNames("kimi")
	if len(processNames) == 1 && processNames[0] == "kimi" {
		fmt.Println("  ✓ PASS: Process names = ['kimi']")
		passed++
	} else {
		fmt.Printf("  ✗ FAIL: Process names = %v\n", processNames)
		failed++
	}

	// Test 10: Kimi is in preset list
	fmt.Println("[TEST 10] Kimi in preset list...")
	presets := config.ListAgentPresets()
	found := false
	for _, p := range presets {
		if p == "kimi" {
			found = true
			break
		}
	}
	if found {
		fmt.Println("  ✓ PASS: 'kimi' found in preset list")
		passed++
	} else {
		fmt.Println("  ✗ FAIL: 'kimi' not found in preset list")
		failed++
	}

	// Summary
	fmt.Println()
	fmt.Println("=== SUMMARY ===")
	fmt.Printf("Passed: %d\n", passed)
	fmt.Printf("Failed: %d\n", failed)
	fmt.Printf("Total:  %d\n", passed+failed)
	fmt.Println()

	if failed == 0 {
		fmt.Println("✅ ALL SMOKE TESTS PASSED!")
		fmt.Println()
		fmt.Println("Kimi K2.5 integration is working correctly.")
		fmt.Println("Commands you can use:")
		fmt.Println("  gt config default-agent kimi")
		fmt.Println("  gt sling <id> <project> --agent kimi")
		fmt.Println("  gt crew add <name> --rig <rig> --agent kimi")
		os.Exit(0)
	} else {
		fmt.Println("❌ SOME TESTS FAILED")
		os.Exit(1)
	}
}

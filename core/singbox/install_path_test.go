//go:build windows

package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// TestVerifyInstallPathSafetyRejectsUserDirectories ensures that portable
// installations in user-writable directories (Desktop, Downloads, TEMP, etc.)
// are refused before a LocalSystem service is registered from them.
func TestVerifyInstallPathSafetyRejectsUserDirectories(t *testing.T) {
	userDirs := []string{
		os.Getenv("USERPROFILE") + `\Desktop\Litchi\litchi-core.exe`,
		os.Getenv("USERPROFILE") + `\Downloads\litchi-core.exe`,
		os.Getenv("TEMP") + `\litchi-core.exe`,
		`C:\Users\Public\litchi-core.exe`,
		`D:\Games\litchi-core.exe`,
	}
	for _, p := range userDirs {
		if p == "" {
			continue
		}
		err := verifyInstallPathSafety(p)
		if err == nil {
			t.Errorf("expected rejection for user-writable path %q, got nil", p)
		}
	}
}

// TestVerifyInstallPathSafetyAcceptsProgramFiles ensures that installs under
// the standard Program Files directories pass the check.
func TestVerifyInstallPathSafetyAcceptsProgramFiles(t *testing.T) {
	for _, base := range []string{
		os.Getenv("ProgramFiles"),
		os.Getenv("ProgramFiles(x86)"),
	} {
		if base == "" {
			continue
		}
		p := filepath.Join(base, "Litchi", "litchi-core.exe")
		if err := verifyInstallPathSafety(p); err != nil {
			t.Errorf("expected accept for %q, got %v", p, err)
		}
	}
}

// TestVerifyInstallPathSafetyIsCaseInsensitive verifies that the path
// comparison handles mixed case correctly on Windows.
func TestVerifyInstallPathSafetyIsCaseInsensitive(t *testing.T) {
	pf := os.Getenv("ProgramFiles")
	if pf == "" {
		t.Skip("ProgramFiles not set")
	}
	// Build a mixed-case version of a path under Program Files.
	lower := strings.ToLower(pf) + `\litchi\litchi-core.exe`
	if err := verifyInstallPathSafety(lower); err != nil {
		t.Errorf("expected case-insensitive accept for %q, got %v", lower, err)
	}
}

// TestVerifyInstallPathSafetyExactDirNoSlip ensures that a sibling directory
// whose name starts with "Program Files" does NOT bypass the check.
func TestVerifyInstallPathSafetyExactDirNoSlip(t *testing.T) {
	pf := os.Getenv("ProgramFiles")
	if pf == "" {
		t.Skip("ProgramFiles not set")
	}
	// A directory whose name *contains* the Program Files path but is not a
	// subdirectory of it (e.g. Program Files Evil) must not pass. Since we
	// can't create one, we verify the prefix logic is anchored with a
	// separator by checking the canonical form.
	sibling := filepath.Dir(pf) + `\Program Files Evil\litchi-core.exe`
	// Program Files is typically "C:\Program Files"; sibling would be
	// "C:\Program Files Evil\..." which should NOT match.
	err := verifyInstallPathSafety(sibling)
	if err == nil {
		t.Errorf("expected rejection for directory that merely shares a name prefix: %q", sibling)
	}
}

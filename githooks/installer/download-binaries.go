// +build !mock

package main

import (
	cm "rycus86/githooks/common"
	"rycus86/githooks/updates"
)

func downloadBinaries(
	settings *InstallSettings,
	tempDir string,
	status updates.ReleaseStatus) updates.Binaries {
	cm.Panic("Not implemented")
	return updates.Binaries{} //nolint:nlreturn
}

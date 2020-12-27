// +build !mock

package main

const (
	// DevIsDispatchSkipped tells if the dispatch (to the build installer) is skipped.
	// This should never be switched to true here, because that is what we want always.
	// This is for testing/debugging only.
	DevIsDispatchSkipped = false
)

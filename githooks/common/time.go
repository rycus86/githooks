package common

import (
	"time"

	"github.com/loov/hrtime"
)

// GetStartTime gets the start duration.
func GetStartTime() time.Duration {
	return hrtime.Now()
}

// GetDuration gets the duration since a time `since`.
func GetDuration(since time.Duration) time.Duration {
	return hrtime.Since(since)
}

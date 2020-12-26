package common

import "time"

// IBackgroundTask is a background task which
// can be run with `RunBackgroundTask`.
// The exit channel `exitCh` can be used to
// signal an early exit of the running task
// if it supports early termination.
type ITask interface {
	Run(exitCh chan bool) (taskError error)
	Clone() ITask
}

// ProgressSettings defines the settings for the progress spinner
// for `RunTaskWithProgress`.
type ProgressSettings struct {
	Title             string
	TitleStillRunning string

	ProgressUpdateInterval    time.Duration
	ProgressStillRunningAfter time.Duration
}

func CreateDefaultProgressSettings(title string, titleStillRunning string) ProgressSettings {
	return ProgressSettings{
		Title:                     title,
		TitleStillRunning:         titleStillRunning,
		ProgressUpdateInterval:    100 * time.Millisecond, //nolint: gomnd
		ProgressStillRunningAfter: 5 * time.Second}        //nolint: gomnd
}

// RunTaskWithProgress runs a task with a progress spinner
// (if available) in a coroutine.
// The returned task `taskOut` contains the output of the run.
// If the task timed out, it will be `nil`.
func RunTaskWithProgress(
	taskIn ITask,
	log ILogContext,
	timeout time.Duration,
	sett ProgressSettings) (taskOut ITask, taskError error) {

	spinner := GetProgressBar(log, sett.Title, -1)
	if spinner == nil {
		log.Info(sett.Title)
	}

	// Run in background coroutiune.
	taskOut = taskIn.Clone()
	taskCh := make(chan error, 1)
	exitCh := make(chan bool, 1)

	go func() {
		taskCh <- taskOut.Run(exitCh)
	}()

	spinnerT := time.NewTicker(sett.ProgressUpdateInterval)
	stillRunningT := time.After(sett.ProgressStillRunningAfter)
	timeoutT := time.After(timeout)

	running := true

	for running {
		select {
		case taskError = <-taskCh:
			running = false
			if spinner != nil {
				_ = spinner.Clear()
			}

		case <-stillRunningT:
			if spinner == nil {
				log.Info(sett.TitleStillRunning)
			} else {
				spinner.Describe(sett.TitleStillRunning)
			}
		case <-spinnerT.C:
			if spinner != nil {
				_ = spinner.Add(1)
			}
		case <-timeoutT:
			running = false
			taskOut = nil
			exitCh <- true
			taskError = ErrorF("Timed out.")
		}
	}

	return
}

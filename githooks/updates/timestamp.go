package updates

import (
	"fmt"
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
	"rycus86/githooks/hooks"
	strs "rycus86/githooks/strings"
	"strconv"
	"time"
)

func RecordUpdateCheckTimestamp() error {
	return git.Ctx().SetConfig(hooks.GitCK_AutoUpdateLastRun,
		fmt.Sprintf("%v", time.Now().Unix()), git.GlobalScope)
}

func ResetUpdateCheckTimestamp() error {
	return git.Ctx().UnsetConfig(hooks.GitCK_AutoUpdateLastRun, git.GlobalScope)
}

func GetUpdateCheckTimestamp() (t time.Time, isSet bool, err error) {

	// Initialize with too old time...
	t = time.Unix(0, 0)

	timeLastUpdateCheck := git.Ctx().GetConfig(hooks.GitCK_AutoUpdateLastRun, git.GlobalScope)
	if strs.IsEmpty(timeLastUpdateCheck) {
		return
	}
	isSet = true

	value, err := strconv.ParseInt(timeLastUpdateCheck, 10, 64)
	if err != nil {
		err = cm.CombineErrors(cm.Error("Could not parse update time."), err)

		return
	}

	t = time.Unix(value, 0)

	return
}

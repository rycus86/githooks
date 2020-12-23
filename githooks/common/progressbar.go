package common

import (
	pb "github.com/schollz/progressbar/v3"
)

// GetProgressBar returns a progressbar or nil (if log has no terminal attached).
func GetProgressBar(log ILogContext, title string, length int) (bar *pb.ProgressBar) {
	if log.IsInfoATerminal() {
		bar = pb.NewOptions(length,
			pb.OptionSetWriter(log.GetInfoWriter()),
			pb.OptionEnableColorCodes(log.HasColors()),
			pb.OptionShowBytes(false),
			pb.OptionSetWidth(15),    // nolint:gomnd
			pb.OptionSpinnerType(69), // nolint:gomnd
			pb.OptionSetDescription(title),
			pb.OptionSetTheme(pb.Theme{
				Saucer:        "[green]=[reset]",
				SaucerHead:    "[green]>[reset]",
				SaucerPadding: " ",
				BarStart:      "[",
				BarEnd:        "]",
			}))
	}

	return
}

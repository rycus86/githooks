package cmd

import (
	"strings"

	"github.com/spf13/cobra"
)

func indentLeft(s string, indent string) string {
	return indent + strings.ReplaceAll(s, "\n", "\n"+indent)
}

var usageTemplate = `Usage:{{if .Runnable}}
  {{.UseLine}}{{end}}{{if .HasAvailableSubCommands}}
  {{.CommandPath}} [command]{{end}}{{if gt (len .Aliases) 0}}

Aliases:
  {{.NameAndAliases}}{{end}}{{if .HasExample}}

Examples:
{{.Example}}{{end}}{{if .HasAvailableSubCommands}}

Available Commands:{{range .Commands}}{{if (or .IsAvailableCommand (eq .Name "help"))}}
  {{rpad .Name .NamePadding }} {{.Short}}{{end}}{{end}}{{end}}{{if .HasAvailableLocalFlags}}

Flags:
{{.LocalFlags.FlagUsages |  trimTrailingWhitespaces}}{{end}}{{if .HasAvailableInheritedFlags}}

Global Flags:
{{.InheritedFlags.FlagUsages | trimTrailingWhitespaces}}{{end}}{{if .HasHelpSubCommands}}

Additional help topics:{{range .Commands}}{{if .IsAdditionalHelpTopicCommand}}
  {{.CommandPath .CommandPathPadding}} {{.Short}}{{end}}{{end}}{{end}}{{if .HasAvailableSubCommands}}

Use "{{.CommandPath}} [command] --help" for more information about a command.{{end}}`

var helpTemplate = `{{with (or .Long .Short)}}{{. | idnt | trimTrailingWhitespaces}}

{{end}}{{if or .Runnable .HasSubCommands}}{{ .UsageString | idnt }}{{end}}
`

func InitTemplates(title string, indent string) {
	cobra.AddTemplateFunc("idnt", func(s string) string { return indentLeft(s, indent) })
	helpTemplate = title + "\n" + helpTemplate
}

func ModifyTemplate(cmd *cobra.Command, indent string) {
	cmd.SetUsageTemplate(usageTemplate)
	cmd.SetHelpTemplate(helpTemplate)
}

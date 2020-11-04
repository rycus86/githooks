package cmd

import (
	"fmt"
	"os"
	cm "rycus86/githooks/common"

	"github.com/spf13/cobra"

	homedir "github.com/mitchellh/go-homedir"
	"github.com/spf13/viper"
)

var cfgFile string

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "githooks-installer",
	Short: "Githooks installer application",
	Long:  `See `,
	// Uncomment the following line if your bare application
	// has an action associated with it:
	//	Run: func(cmd *cobra.Command, args []string) { },
}

// ProxyWriter is solely used for the cobra logging.
type ProxyWriter struct {
	log cm.ILogContext
}

func (p *ProxyWriter) Write(s []byte) (int, error) {
	return os.Stdout.Write([]byte(p.log.ColorInfo(string(s))))
}

// Execute adds all child commands to the root command and sets flags appropriately.
// This is called by main.main(). It only needs to happen once to the rootCmd.
func Execute() {

	log, err := cm.CreateLogContext(false)
	cm.AssertOrPanic(err == nil, "Could not create log")
	rootCmd.SetOutput(&ProxyWriter{log: log})

	log.Info("1")
	log.Error("2")
	log.Info("1")
	log.Error("2")
	log.Info("1")
	log.Error("2")
	log.Info("1")
	log.Error("2")
	log.Info("1")
	log.Error("2")
	log.Info("1")
	log.Error("2")

	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}

func init() {
	cobra.OnInitialize(initConfig)

	// Here you will define your flags and configuration settings.
	// Cobra supports persistent flags, which, if defined here,
	// will be global for your application.

	rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default is $HOME/.githooks-istaller.yaml)")

	// Cobra also supports local flags, which will only run
	// when this action is called directly.
	rootCmd.Flags().BoolP("toggle", "t", false, "Help message for toggle")
}

// initConfig reads in config file and ENV variables if set.
func initConfig() {
	if cfgFile != "" {
		// Use config file from the flag.
		viper.SetConfigFile(cfgFile)
	} else {
		// Find home directory.
		home, err := homedir.Dir()
		if err != nil {
			fmt.Println(err)
			os.Exit(1)
		}

		// Search config in home directory with name ".githooks-istaller" (without extension).
		viper.AddConfigPath(home)
		viper.SetConfigName(".githooks-istaller")
	}

	viper.AutomaticEnv() // read in environment variables that match

	// If a config file is found, read it in.
	if err := viper.ReadInConfig(); err == nil {
		fmt.Println("Using config file:", viper.ConfigFileUsed())
	}
}

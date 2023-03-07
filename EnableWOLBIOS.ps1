#downloads and installs the latest version of the Dell Command | PowerShell Provider
Install-Module -Name DellBIOSProvider

#adds the Dell Command | PowerShell Provider module to the current session
Import-Module DellBIOSProvider –Verbose

#changes the directory to the DellSMBIOS drive
cd dellsmbios:

#configures the wake-on-LAN feature
Set-Item -Path .\PowerManagement\WakeOnLan LANOnly

#configures the system power mode when the system is in S4 and S5 state
Set-Item -Path .\PowerManagement\DeepSleepCtrl Disabled
#obtains a list of all devices that are user-configurable to wake the computer
powercfg -devicequery wake_programmable

#enables the option to wake the computer from the selected network device
powercfg -deviceenablewake $args[0]

#disables Energy Efficient Ethernet located in the network properties advanced menu
Set-NetAdapterAdvancedProperty -Name "Ethernet" -DisplayName "Energy Efficient Ethernet" -DisplayValue "Disabled""

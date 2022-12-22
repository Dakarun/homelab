# Homelab

## Notes
### Windows Node Exporter
Repo can be found [here](https://github.com/prometheus-community/windows_exporter).
Current install command
```
msiexec /i windows_exporter-0.20.0-amd64.msi ENABLED_COLLECTORS=cpu,cs,logical_disk,logon,memory,net,os,service,system,thermalzone,textfile
```

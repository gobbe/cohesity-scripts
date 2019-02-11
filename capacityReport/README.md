# Introduction

`capacityReport.ps1` is a simple script that lists all or specified backupjob runs used capacity (Both frontend and backend) and optionally outputs a csv list with usage details. This data can be used for billing purposes. It is recommended to run the script daily and calculate the monthly average for a more accurate consumption report. 

# How to use
## Notes
This is not an official NetApp repository. NetApp Inc. is not affiliated with the posted examples in any way.

```
capacityReport.ps1 -vip {ip or name} -username {username} [-jobName {search only matching jobs} -runs {number of backupjob runs to list, default 30} -export {name of csvfile}
```

# Additional repository

These scripts are using Brian Seltzer's cohesity-api.ps1. You can get it and guide to it from he's repository; https://github.com/bseltz-cohesity/scripts/tree/master/powershell

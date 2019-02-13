# Introduction

`dataprotectionUSed.ps1` is a simple script that lists backjobs utilizing Cohesity DataProtection license and calculates total capacity to be reported.

# How to use

```
dataprotectionUsed.ps1 -vip {ip or name} -username {username} -export {name of csvfile}
```

# Additional repository

These scripts are using Brian Seltzer's cohesity-api.ps1. You can get it and guide to it from he's repository; https://github.com/bseltz-cohesity/scripts/tree/master/powershell

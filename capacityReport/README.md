# capacityReport.ps1 - Capacity reporting 

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

## Introduction

capacityReport.ps1 is a simple script that lists all or specified backupjob runs used capacity (Both frontend and backend) and optionally outputs a csv list with usage details. This data can be used for billing purposes. It is recommended to run the script daily and calculate the monthly average for a more accurate consumption report. 

## How to use

capacityReport.ps1 -vip {ip or name} -username {username} [-jobName {search only matching jobs} -runs {number of backupjob runs to list, default 30} -export {name of csvfile}

## Additional repository

These scripts are using Brian Seltzer's cohesity-api.ps1. You can get it and guide to it from he's repository; https://github.com/bseltz-cohesity/scripts/tree/master/powershell
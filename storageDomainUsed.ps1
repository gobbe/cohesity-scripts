### usage: ./storageDomainUsed.ps1 -vip 192.168.1.198 -export file.cvs

### Example script to get billing statistics - Jussi Jaurola <jussi@cohesity.com>
###
### Assumptions:
###
###  - Script uses always previous months statistics
###  - Script looks customer names from StorageDomains and uses these for Protection Jobs also
###

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #cohesity cluster vip
    [Parameter(Mandatory = $True)][string]$export #cvs-file name

    )
Get-Module -ListAvailable -Name Cohesity* | Import-Module

# Connect to Cohesity cluster
try {
    Connect-CohesityCluster -Server $vip 
} catch {
    write-host "Cannot connect to Cohesity cluster $vip" -ForegroundColor Yellow
    exit
}

# Get last months first and last day
$firstDay  = (Get-Date -day 1 -hour 0 -minute 0 -second 0).AddMonths(-1)
$lastDay = (($firstDay).AddMonths(1).AddSeconds(-1))
$startTime = Convert-CohesityDateTimeToUsecs -DateTime $firstDay
$endTime = Convert-CohesityDateTimeToUsecs -DateTime $lastDay


# Write headers to CSV-file 
Add-Content -Path $export -Value "'Customer','Storage domain size (GiB)','Client amount'"

# Get customer-name and storage domain statistics
$stats = Get-CohesityStorageDomain -fetchstats | select-object id,name,stats

Write-Host "Billing statistics for $($lastDay.toString("MMMM yyyy"))" -ForegroundColor Yellow
foreach ($stat in $stats) {

    $virtualNames = @()
    $physicalNames = @()
    $dbNames = @()

    $vmCount = 0
    $physicalCount = 0
    $dbCount = 0

    $customerName = $stat.Name
    $customerStorageDomainUsed = ($stat.Stats.UsagePerfStats.totalPhysicalUsageBytes/1GB).Tostring(".00")

    Write-Host "Fetching statistics for customer $customerName ...." -ForegroundColor Yellow

    
    # Fetch VMware/Nutanix/HyperV jobs with tag Virtual
    $jobs = Get-CohesityProtectionJob -Names $customerName | Where-Object Name -match Virtual
    foreach ($job in $jobs) {
        $runClients = @()
        $maxClients = 0
        $sources = ""

        # Get only runs for last month
        $runs = Get-CohesityProtectionJobRun -JobId $($job.Id) -StartTime $startTime -EndTime $endTime -ExcludeErrorRuns

        # Find run containing max amount of clients for month
        foreach ($run in $runs) {
            $runId = $run.BackupRun.JobRunId
            $runSources = $run.BackupRun.SourceBackupStatus.Source.Name
            $runCount = $runSources.count

            if ($runCount -gt $maxClients) {
                $runClients += @{$runId = $runCount} 
                $maxClients = $runCount
                
                $virtualNames = $runSources
                $vmCount = $runCount
            }
        }
    }

    # Fetch physical jobs with tag Physical
    $jobs = Get-CohesityProtectionJob -Names $customerName | Where-Object Name -match Physical
    foreach ($job in $jobs) {
        $runClients = @()
        $maxClients = 0
        $sources = ""

        # Get only runs for last month
        $runs = Get-CohesityProtectionJobRun -JobId $($job.Id) -StartTime $startTime -EndTime $endTime -ExcludeErrorRuns

        # Find run containing max amount of clients for month
        foreach ($run in $runs) {
            $runId = $run.BackupRun.JobRunId
            $runSources = $run.BackupRun.SourceBackupStatus.Source.Name
            $runCount = $runSources.count

            if ($runCount -gt $maxClients) {
                $runClients += @{$runId = $runCount} 
                $maxClients = $runCount
                
                $physicalNames = $runSources
                $physicalCount = $runCount
            }
        }
    }
    
    $clientAmount = $vmCount + $physicalCount
    # Write statistics to csv file
    $line = "'{0}','{1}','{2}'" -f $customerName, $customerStorageDomainUsed, $clientAmount 
    Add-Content -Path $export -Value $line

    Write-Host "Used capacity is $customerStorageDomainUsed GiB with $clientAmount clients" -ForegroundColor Yellow
}

### usage: ./capacityReport.ps1 -vip 192.168.1.198 -username admin [ -domain local ] [-jobName 'Virtual']i [-runs '30'] [-export 'filename.csv']

### Capacity reporting example - Jussi Jaurola <jussi@cohesity.com>

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$jobName,
    [Parameter()][string]$runs = '30',
    [Parameter()][string]$export
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### cluster Id
$clusterId = (api get cluster).id

$csvcontent =""
### find protectionRuns 

if ($export) {
    Add-Content -Path $export -Value '"Source job","Frontend Capacity (MB)","Backend Capacity (MB)"'
} 

"Collecting Job Run Statistics..."

if ($jobName) {
    foreach ($job in ((api get protectionJobs) | Where-Object{ $_.policyId.split(':')[0] -eq $clusterId }|Where name -match $jobName)) {
        "Runs for $($job.name)"
        $jobId = $job.id
        $jobName = $job.name
        $run = api get protectionRuns?jobId=$($job.id)`&numRuns=$runs`&excludeTasks=true`&excludeNonRestoreableRuns=true
        $run | Select-Object -Property @{Name="Run Date"; Expression={usecsToDate $_.backupRun.stats.startTimeUsecs}},
                                        @{Name="Run Seconds"; Expression={[math]::Round(($_.backupRun.stats.endTimeUsecs - $_.backupRun.stats.startTimeUsecs)/(1000*1000))}},
                                        @{Name="MB Read"; Expression={[math]::Round(($_.backupRun.stats.totalBytesReadFromSource)/(1024*1024))}},
                                        @{Name="MB Written"; Expression={[math]::Round(($_.backupRun.stats.totalPhysicalBackupSizeBytes)/(1024*1024))}} | ft 
        
        $fsum = 0
        $bsum = 0
    
        $sum = $run.backupRun.stats.totalBytesReadFromSource
        $sum | Foreach { $fsum += $_}
    
        $sum = $run.backupRun.stats.totalPhysicalBackupSizeBytes
        $sum | Foreach { $bsum += $_}
    
        $bsumMB = [math]::Round($bsum/(1024*1024))
        $fsumMB = [math]::Round($fsum/(1024*1024))
        write-host "Total frontend capacity: $fsumMB MB"
        write-host "Total backend capacity used: $bsumMB MB"
    
        if ($export) {
            $line = "{0},{1},{2}" -f $jobName, $fsumMB, $bsumMB
            Add-Content -Path $export -Value $line
        } 
       
    } 
} else {
    foreach ($job in ((api get protectionJobs) | Where-Object{ $_.policyId.split(':')[0] -eq $clusterId })) {
        "Runs for $($job.name)"
        $jobId = $job.id
        $jobName = $job.name
        $run = api get protectionRuns?jobId=$($job.id)`&numRuns=$runs`&excludeTasks=true`&excludeNonRestoreableRuns=true
        $run | Select-Object -Property @{Name="Run Date"; Expression={usecsToDate $_.backupRun.stats.startTimeUsecs}},
                                        @{Name="Run Seconds"; Expression={[math]::Round(($_.backupRun.stats.endTimeUsecs - $_.backupRun.stats.startTimeUsecs)/(1000*1000))}},
                                        @{Name="MB Read"; Expression={[math]::Round(($_.backupRun.stats.totalBytesReadFromSource)/(1024*1024))}},
                                        @{Name="MB Written"; Expression={[math]::Round(($_.backupRun.stats.totalPhysicalBackupSizeBytes)/(1024*1024))}} | ft 
        
        $fsum = 0
        $bsum = 0
    
        $sum = $run.backupRun.stats.totalBytesReadFromSource
        $sum | Foreach { $fsum += $_}
    
        $sum = $run.backupRun.stats.totalPhysicalBackupSizeBytes
        $sum | Foreach { $bsum += $_}
    
        $bsumMB = [math]::Round($bsum/(1024*1024))
        $fsumMB = [math]::Round($fsum/(1024*1024))
        write-host "Total frontend capacity: $fsumMB MB"
        write-host "Total backend capacity used: $bsumMB MB"
    
        if ($export) {
            $line = "{0},{1},{2}" -f $jobName, $fsumMB, $bsumMB
            Add-Content -Path $export -Value $line
        } 
       
    } 

}

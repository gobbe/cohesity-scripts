### usage: ./dataprotectionUsed.ps1 -vip 192.168.1.198 -username admin [-export <filename.csv[ -domain local ] 

### DataProtection Capacity reporting example - Jussi Jaurola <jussi@cohesity.com>

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$export
)


### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### cluster Id
$clusterId = (api get cluster).id
 
$csvcontent = ""
### find protectionRuns 

Add-Content -Path $export -Value '"Source job","Total written capacity (MB)"'

"Collecting Job Run Statistics..."

$protectionJobs = (api get protectionJobs) | Where-Object{ $_.policyId.split(':')[0] -eq $clusterId }|Where-Object { $_.environment -ne "kView"}

foreach ($job in $protectionJobs) {
    "Runs for $($job.name)"
    $jobId = $job.id
    $jobName = $job.name
    $run = api get protectionRuns?jobId=$($job.id)`&excludeTasks=true`&excludeNonRestoreableRuns=true
    
    $run | Select-Object -Property @{Name="Run Date"; Expression={usecsToDate $_.backupRun.stats.startTimeUsecs}},
                                    @{Name="Run Seconds"; Expression={[math]::Round(($_.backupRun.stats.endTimeUsecs - $_.backupRun.stats.startTimeUsecs)/(1000*1000))}},
                                    @{Name="MiB Read"; Expression={[math]::Round(($_.backupRun.stats.totalBytesReadFromSource)/(1024*1024))}},
                                     @{Name="MiB Written"; Expression={[math]::Round(($_.backupRun.stats.totalPhysicalBackupSizeBytes)/(1024*1024))}} | ft 
    
    
        
    $fsum = 0
    $bsum = 0
    
    $sum = $run.backupRun.stats.totalBytesReadFromSource
    $sum | Foreach { $fsum += $_}
    
    $sum = $run.backupRun.stats.totalPhysicalBackupSizeBytes
    $sum | Foreach { $bsum += $_}
    
    $bunitsum = [math]::Round($bsum/(1024*1024))
    $funitsum = [math]::Round($fsum/(1024*1024))

    write-host "Total backend capacity used: $bunitsum MiB"
    
    if ($export) {
        $line = "{0},{1}" -f $jobName, $bunitsum
        Add-Content -Path $export -Value $line
    } 
       
} 

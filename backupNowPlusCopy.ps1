### usage: ./backupNowPlusCopy.ps1 -vip 192.168.1.198 -username admin [ -domain local ] -jobName 'Virtual'

### Run protectionJob and its replication jobs - Jussi Jaurola <jussi@cohesity.com>

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$jobName
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### find job with name
$job = api get protectionJobs | where name -match $jobName

if (!$job) {
    write-host "No job found with name $jobName" -ForegroundColor Yellow
    exit
}

$jobId = $job.Id
### get policy and replication retention period for job
$policyId = $job.policyId
$policy = api get protectionPolicies/$policyId

if (!$policy) {
    write-host "No job $jobName uses policy with policyid $policyId which is not found" -ForegroundColor Yellow
    exit
}

$replicationCopyPolicies = $policy.snapshotReplicationCopyPolicies
$copyRunTargets = @()

if ($replicationCopyPolicies) {
    $replicationCopyPolicies | Foreach {
        $daysToKeep = $_.daysToKeep
        $targetClusterId = $_.target.clusterId
        $targetClusterName = $_.target.clusterName
        write-host "Replication target for job $jobName is $targetClusterName with id $targetClusterId. Keeping copy $daysToKeep" 
    
        $copyRunTargets += @{
            "daysToKeep" = $daysToKeep;
            "replicationTarget"  =@{
                "clusterId" = $targetClusterId;
                "clusterName" = $targetClusterName;
            }
            "type" =  "kRemote" ;
        }
    
    }
    
    $sourceIds = @()
    $jobData = @{
        "copyRunTargets"  = $copyRunTargets;
        "sourceIds" = $sourceIds;
        "runType" = "kRegular"
    }
}

write-host "Running $jonName..."
$run = api post protectionJobs/run/$jobId $jobData

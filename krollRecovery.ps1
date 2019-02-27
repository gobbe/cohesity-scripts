### usage: ./krollRecovery.ps1 -vip 192.168.1.198 -username admin [ -domain local ] -sourceServer 'SQL2012' -sourceDB 'CohesityDB' [ -targetServer 'SQLDEV01' ] [ -targetDB 'CohesityDB-Dev' ] [ -targetInstance 'MSSQLSERVER' ]

### Automate Kroll OnTrack recovery for SQL/Sharepoint - Jussi Jaurola <jussi@cohesity.com>
###

[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter(Mandatory = $True)][string]$sourceServer, #source server that was backed up
    [Parameter()][string]$targetServer = $env:COMPUTERNAME, #target server to mount the volumes to, default this computer
    [Parameter()][string]$targetUsername = '', #credentials to ensure disks are online (optional, only needed if it's a VM with no agent)
    [Parameter()][string]$targetPw = '' #credentials to ensure disks are online (optional, only needed if it's a VM with no agent)
)
$ErrorActionPreference = 'Stop'
$finishedStates =  @('kCanceled', 'kSuccess', 'kFailure') 

### source the cohesity-api helper code
. ./cohesity-api

# Connect to Cohesity cluster
try {
    apiauth -vip $vip -username $username -domain $domain
} catch {
    write-host "Cannot connect to Cohesity cluster $vip" -ForegroundColor Yellow
    exit
}

### search for the source server
$searchResults = api get "/searchvms?entityTypes=kVMware&entityTypes=kPhysical&entityTypes=kHyperV&entityTypes=kHyperVVSS&entityTypes=kAcropolis&entityTypes=kView&vmName=$sourceServer"

### narrow the results to the correct server from this cluster
$searchResults = $searchresults.vms | Where-Object { $_.vmDocument.objectName -ieq $sourceServer } | Select-Object -First 1

### list snapshots for VM
$snapshots = $searchResults.vmDocument.versions.snapshotTimestampUsecs

if(!$searchResults){
    write-host "Source Server $sourceServer Not Found" -foregroundcolor yellow
    exit
}

$physicalEntities = api get "/entitiesOfType?environmentTypes=kVMware&environmentTypes=kPhysical&physicalEntityTypes=kHost&vmwareEntityTypes=kVCenter"
$virtualEntities = api get "/entitiesOfType?environmentTypes=kVMware&environmentTypes=kPhysical&isProtected=true&physicalEntityTypes=kHost&vmwareEntityTypes=kVirtualMachine" #&vmwareEntityTypes=kVCenter
$sourceEntity = (($physicalEntities + $virtualEntities) | Where-Object { $_.displayName -ieq $sourceServer })[0]
$targetEntity = (($physicalEntities + $virtualEntities) | Where-Object { $_.displayName -ieq $targetServer })[0]

if(!$sourceEntity){
    Write-Host "Source Server $sourceServer Not Found" -ForegroundColor Yellow
    exit
}

if(!$targetEntity){
    Write-Host "Target Server $targetServer Not Found" -ForegroundColor Yellow
    exit
}

Write-Host "Available recovery points:" -ForegroundColor Yellow
Write-Host "--------------------------" -ForegroundColor Yellow

$snapshots | ForEach-object -Begin {$i=0} -Process {"Id $i - $(usecsToDate $_)";$i++}
$snapshotId = Read-Host 'Enter ID of selected recovery point'



$mountTask = @{
    'name' = 'Kroll OnTrack recovery mount';
    'objects' = @(
        @{
            'jobId' = $searchResults.vmDocument.objectId.jobId;
            'jobUid' = $searchResults.vmDocument.objectId.jobUid;
            'entity' = $sourceEntity;
            'jobInstanceId' = $searchResults.vmDocument.versions[$snapshotId].instanceId.jobInstanceId;
            'startTimeUsecs' = $searchResults.vmDocument.versions[$snapshotId].instanceId.jobStartTimeUsecs
        }
    );
    'mountVolumesParams' = @{
        'targetEntity' = $targetEntity;
        'vmwareParams' = @{
            'bringDisksOnline' = $true;
            'targetEntityCredentials' = @{
                'username' = $targetUsername;
                'password' = $targetPw;
            }
        }
    }
}

if($targetEntity.parentId ){
    $mountTask['restoreParentSource'] = @{ 'id' = $targetEntity.parentId }
}

Write-Host "Mounting volumes to $targetServer" -ForegroundColor Yellow
$result = api post /restore $mountTask
$taskid = $result.restoreTask.performRestoreTaskState.base.taskId

### monitor process until it is finished
do
{
    sleep 3
    $restoreTask = api get /restoretasks/$taskid
    $restoreTaskStatus = $restoreTask.restoreTask.performRestoreTaskState.base.publicStatus
} until ($restoreTaskStatus -in $finishedStates)

### check if mount was success
if($restoreTaskStatus -eq 'kSuccess'){
    Write-Host "Task ID for tearDown is: {0}" -f $restoreTask.restoreTask.performRestoreTaskState.base.taskId -ForegroundColor Yellow
    $mountPoints = $restoreTask.restoreTask.performRestoreTaskState.mountVolumesTaskState.mountInfo.mountVolumeResultVec
    foreach($mountPoint in $mountPoints){
        Write-Host "{0} mounted to {1}" -f ($mountPoint.originalVolumeName, $mountPoint.mountPoint) -ForegroundColor Yellow
    }
}else{
    Write-Warning "mount operation ended with: $restoreTaskStatus"
}



if ($recoverymethod -eq 'sql') {
    ### get db instance
    $dbInstance = Get-CohesityMSSQLObject | where-object name -match $sourceDB
    $dbInstanceId = $dbInstance.Id
    $dbNewName = $dbInstance.Name + "-Kroll"

    ### get hostSourceId
    $hostSource = Get-CohesityProtectionSourceObject | Where-Object name -eq $sourceServer
    $hostSourceId = $hostSource.Id[0]

    ### get protectionjobId
    $pJob = Get-CohesityProtectionJob | Where-Object name -eq $protectionJob
    $protectionJobId = $pJob.Id
    $protectionJobName = $pJob.Name

    ### get recovery points
    $snapshots = Get-CohesityProtectionJobRun | where-object JobId -eq $protectionJobId

    if (!$snapshots) {
        Write-Host "Couldn't find any restore points for DB $sourceDB with protectionjob $protectionJobName" -ForegroundColor Yellow
        exit
    }
    Write-Host "Available snapshots:" -ForegroundColor Yellow
    $snapshots | Select-Object -Property @{Name="Run Id"; Expression={ $_.BackupRun.JobRunId}},
                                        @{Name="Job Date"; Expression= { Convert-CohesityUsecsToDateTime -Usecs $_.BackupRun.Stats.StartTimeUsecs}} | ft


    $jobRunId = Read-Host 'Select Run Id of recovery point (Leave blank for latest)'

    if (!$jobRunId) {
        $jobRunId = $snapshots[0].BackupRun.JobRunId
    }

    $jobRun = Get-CohesityProtectionJobRun | where-object{$_.BackupRun.JobRunId -eq $jobRunId}
    $startTime = $jobRun.BackupRun.Stats.StartTimeUsecs
    
    Write-Host "Using recovery point $jobRunId"

    ### Clone the DB from selected recovery point
    $clonetask = Copy-CohesityMSSQLObject -TaskName "Kroll OnTrack recovery" -SourceId $dbInstanceId -HostSourceId $hostSourceId -StartTime $startTime -JobRunId $jobRunid -JobId $protectionJobId -NewDatabaseName $dbNewName -InstanceName "MSSQLSERVER"
}

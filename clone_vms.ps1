### usage: ./clone-vms.ps1 -vip 192.168.1.198 -username admin [ -domain local ] -target 'vcenter' -resourcepool 'resources' -viewName 'backupview' -jobName 'Virtual'

### Thanks Brian Seltzer for base of this script!

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter(Mandatory = $True)][string]$target,
    [Parameter(Mandatory = $True)][string]$resourcepool,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$viewName,
    [Parameter(Mandatory = $True)][string]$jobName
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### search for VMs to clone

$jobs = api get protectionJobs | Where-Object {$_.name -ieq $jobName}
$jobId = $jobs.Id
$vms = $jobs.sourceIds
$vmcount = $vms.count

if ($vms) {

    $runs = api get protectionRuns?"jobId=$jobId&excludeNonRestoreableRuns=true"
    
    $latestrun = $runs.backupRun[0]
    $latestrundate = usecsToDate $runs.backupRun.stats.startTimeUsecs[0]
    write-host "Backup job $jobName contains $vmcount VMs"
    write-host "Latest recoverable snapshot for job is $latestrundate"

    ### clone each vm from latest run of backupjob
    $objects = @()
    foreach ($vm in $vms){
        $a = api get protectionSources/virtualMachines?vCenterId=$($jobs.parentSourceId) | Where-Object {$_.id -ieq $vm}
        $vm_name = $a.Name
        write-host "Adding $vm_name to clone task"
        $objects += @{
            "jobId" = $jobs.Id;
            "protectionSourceId" = $vm; 
        }
    }

    $clonetask = @{
        "name"  = "BackupExport_" + $((get-date).ToString().Replace('/', '_').Replace(':', '_').Replace(' ', '_'));
        "objects"   = $objects;
        "type" = "kCloneVMs";
            "newParentId" = $target;
            "targetViewName" = $viewName;
        "continueOnError" = "false";
        "vmwareParameters"  = @{
            "disableNetwork" = "true";
            "poweredOn" = "false";
            "suffix" =  "export-";
            "resourcePoolId" = $resourcepool;
        }
    }

    write-host "Running rest-api command:"
    $clonetask | ConvertTo-Json
    $cloneoperation = api post /clone $clonetask

    if ($cloneoperation) {
        write-host "Cloned VMs!"
    }

}
else {
    write-host "Cannot find backupjob with VMs" -ForegroundColor Yellow
}

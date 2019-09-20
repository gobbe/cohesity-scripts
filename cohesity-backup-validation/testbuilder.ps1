###
### Helper tool to build backup validation testing for VMs - Jussi Jaurola <jussi@cohesity.com>
###


param (
    #### Path to the environment JSON file for Cohesity and vCenter
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [String]$EnvironmentFile,
    
    #### Path to the configuration JSON file for applications
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [String]$ConfigFile,
    
    ### Path to the folder containing XML credential files for this buildrun
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [String]$IdentityPath
)

### Get  configuration from config.json
task getConfig {
    $script:Environment = Get-Content -Path $EnvironmentFile | ConvertFrom-Json
    $script:Config = Get-Content -Path $ConfigFile | ConvertFrom-Json
    if ($IdentityPath.Substring($IdentityPath.Length - 1) -ne '\') {
        $script:IdentityPath += '\'
    }
}

### Connect to Cohesity cluster
task connectCohesity {
    Write-Host "Importing Credential file: $($IdentityPath + $Environment.cohesityCred)" -ForegroundColor Yellow
    $Credential = Import-Clixml -Path ($IdentityPath + $Environment.cohesityCred)
    try {
        Connect-CohesityCluster -Server $Environment.cohesityCluster -Credential $Credential
        Write-Host "Connected to Cohesity Cluster $($Environment.cohesityCluster)" -ForegroundColor Yellow
    } catch {
        write-host "Cannot connect to Cohesity cluster $Environment.cohesityCluster" -ForegroundColor Yellow
        exit
    }
}

### Connect to VMware vCenter
task connectVMware {
    Write-Host "Getting credentials from credential file $($IdentityPath + $Environment.vmwareCred)" -ForegroundColor Yellow
    $Credential = Import-Clixml -Path ($IdentityPath + $Environment.vmwareCred)
    try {
        Connect-VIServer -Server $Environment.vmwareServer -Credential $Credential
        Write-Host "Connected to VMware vCenter $($global:DefaultVIServer.Name)" -ForegroundColor Yellow
    } catch {
        write-host "Cannot connect to VMware vCenter $Environment.vmwareServer" -ForegroundColor Yellow
        exit
    }
}

### Create a clone task for virtual machine(s)
task createCloneTask {

    # Get vmware source ID for resource pool
    $vmwareSource = Get-CohesityProtectionSourceObject -Environments kVMware | Where-Object Name -eq $Environment.vmwareServer 
    $vmwareResourcePool = Get-CohesityProtectionSourceObject -Environments kVMware | Where-Object ParentId -eq $($vmwareSource.Id) | Where-Object Name -eq $Environment.vmwareResourcePool 

    # Uses a null array of Mount IDs that will be used to track the request process
    [Array]$Script:CloneArray = $null
    foreach ($VM in $Config.virtualMachines) {  
        $backupJob =  Find-CohesityObjectsForRestore -Search $($VM.name) -environments kVMware | Where-Object JobName -eq $($VM.backupJobName) 
        $cloneVM = Get-CohesityVMwareVM -name $VM.name 
        $cloneTask = Copy-CohesityVMwareVM -TaskName "BTest_$($VM.name)" -PoweredOn:$true -DisableNetwork:$true -Jobid $($backupJob.JobId) -SourceId $($cloneVM.id) -TargetViewName "BTest_$($VM.name)" -VmNamePrefix "BTest_" -ResourcePoolId $($vmwareResourcePool.id) -NewParent $($vmwareSource.Id)
        Write-Host "Created cloneTask $($cloneTask.Id) for VM $($VM.name)" -ForegroundColor Yellow

        $Script:CloneArray += $cloneTask
    }
}
### Validate sstatus of Clone Task and Power State of VM
task checkCloneTask {
    foreach ($Clone in $CloneArray) {
        while ($true) {
            $validateTask = (Get-CohesityRestoreTask -Id $Clone.Id).Status
            $validatePowerOn = (Get-VM -Name $Clone.Name -ErrorAction:SilentlyContinue).PowerState

            Write-Host "$($Clone.Name) clone status is $validateTask and Power Status is $ValidatePowerOn" -ForegroundColor Yellow
            if ($validateTask -eq 'kFinished' -and $validatePowerOn -eq 'PoweredOn') {
                break
            } elseif ($sleepCount -gt '30') {
                throw "Clone of VM $($Clone.Name) failed. Failing tests. Other cloned VMs remain cloned status, manual cleanup might needed!"
            } else {
                Start-Sleep 5
                $sleepCount++
            }
        }
    }
}

### Check the status of VMware Tools in Cloned VMs
task checkVmwareTools {
    foreach ($Clone in $CloneArray) {
        while ($true) {
            $toolStatus = (Get-VM -Name $Clone.Name).ExtensionData.Guest.ToolsRunningStatus
            
            Write-Host "VM $($Clone.Name) VMware Tools Status is $toolStatus" -ForegroundColor Yellow
            if ($toolStatus -ne 'guestToolsRunning') {
                Start-Sleep 5
            } else {
                break
            }
        }
    }
}

task checkPSScriptExecution {
    foreach ($Clone in $CloneArray) {
        $count = 1
        while ($true) {

            Write-Host "Run ($count): Script test on $($Clone.name)" -ForegroundColor Yellow
            $splat = @{
                ScriptText      = 'hostname'
                ScriptType      = 'PowerShell'
                VM              = $Clone.name
                GuestCredential = $GuestCredential
            }
            try {
                $results = Invoke-VMScript @splat -ErrorAction Stop
                Write-Host "checkPSScriptExecution status $results" -ForegroundColor Yellow
                break
            } catch { }
            
            $count++
            Sleep -Seconds 5
            
            if ($LoopCount -gt 5) {
                throw "Could not execute script on: $($Clone.Name)..."
            }
        }
    }
}

### Config network for cloned VMs
task configVMNetwork {
    $i = 0
    foreach ($Clone in $CloneArray) {
        $SplatNetAdapter = @{
            NetworkName  = $Config.virtualMachines[$i].testNetwork
            Connected    = $true
            Confirm      = $false
        }
        $vmnetwork = Get-NetworkAdapter -VM $Clone.Name |
            Set-NetworkAdapter @SplatNetAdapter
        Write-Host "Virtual machine $($Clone.name) current network $($vmnetwork.NetworkName) status is $($vmnetwork.ConnectionState)" -ForegroundColor Yellow
        $i++
    }
}

### Change VM network IPs to test IPs
task configVMNetworkIP {
    $i = 0
    foreach ($Clone in $CloneArray) {
        Write-Host "$($Clone.Name): Importing credential file $($IdentityPath + $($Config.virtualMachines[$i].guestCred))" -ForegroundColor Yellow
        $vmCredentials = Import-Clixml -Path ($IdentityPath + $($Config.virtualMachines[$i].guestCred))
        
        $TestInterfaceMAC = ((Get-NetworkAdapter -VM $Config.virtualMachines[$i].mountName | Select-Object -first 1).MacAddress).ToLower() -replace ":","-"
        $splat = @{
            ScriptText      = 'Get-NetAdapter | where {($_.MacAddress).ToLower() -eq "' + $TestInterfaceMAC + '"} | Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue;`
                               Get-NetAdapter | where {($_.MacAddress).ToLower() -eq "' + $TestInterfaceMAC + '"} | Get-NetIPAddress | Remove-NetIPAddress -confirm:$false;`
                               Get-NetAdapter | where {($_.MacAddress).ToLower() -eq "' + $TestInterfaceMAC + '"} | `
                               New-NetIPAddress -IPAddress ' + $Config.virtualMachines[$i].testIp + ' -PrefixLength ' + $Config.virtualMachines[$i].testSubnet + `
                               ' -DefaultGateway ' + $Config.virtualMachines[$i].testGateway
            ScriptType      = 'PowerShell'
            VM              = $Clone.mountName
            GuestCredential = $vmCredentials
        }
        $output = Invoke-VMScript @splat -ErrorAction Stop
        $splat = @{
            ScriptText      = '(Get-NetAdapter| where {($_.MacAddress).ToLower() -eq "' + $TestInterfaceMAC + '"} | Get-NetIPAddress -AddressFamily IPv4).IPAddress'
            ScriptType      = 'PowerShell'
            VM              = $Clone.mountName
            GuestCredential = $vmCredentials
        }
        $output = Invoke-VMScript @splat -ErrorAction Stop
        $new_ip = $output.ScriptOutput -replace "`r`n", ""
        if ( $new_ip -eq $Config.virtualMachines[$i].testIp ) {
            Write-Host "$($Clone.Name): Network IP changed to $($new_ip)" -ForegroundColor Yellow
        }
        else {
            throw "$($Clone.Name): Network IP change to $($Config.virtualMachines[$i].testIp) failed. Failing tests. Cloned VMs remain cloned status, manual cleanup might needed!"
        }
        $i++
    }
}

### Run backup validation tests defined in configuration json per VM
task validationTests {
    $i = 0
    foreach ($Clone in $CloneArray) {
        Write-Host "$($Clone.Name): Running tests $($Config.virtualMachines[$i].tasks)" -ForegroundColor Yellow
        $vmCredentials = Import-Clixml -Path ($IdentityPath + $($Config.virtualMachines[$i].guestCred))
        Invoke-Build -File .\validationTests.ps1 -Task $Config.virtualMachines[$i].tasks -Config $Config.virtualMachines[$i] -GuestCredential $vmCredentials
        Write-Host "$($Clone.Name): Testing complete" -ForegroundColor Yellow
        $i++
    }
}

### After testing remove clones
task removeClones {
    foreach ($Clone in $CloneArray) {
        $removeRequest = Remove-CohesityClone -TaskId $Clone.id -Confirm:$false
        Write-Host "$($Clone.Name): $removeRequest"
    }
}

task 1_Init `
getConfig

task 2_Connect `
connectCohesity,
connectVMware

task 3_Clone `
createCloneTask,
checkCloneTask,
checkVmwareTools,
checkPSScriptExecution

task 4_VMNetwork `
configVMNetwork,
configVMNetworkIP

task 5_Testing `
validationTests

task . `
1_Init,
2_Connect,
3_Clone,
4_VMNetwork,
5_Testing,
removeClones
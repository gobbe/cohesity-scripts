###
### Helper tool to specify all possible application tests - Jussi Jaurola <jussi@cohesity.com>
###
### This sample contains only three tests but more tests can be added and tests can be assigned per vm on configuration files
###

param(
    $Config,
    [System.Management.Automation.PSCredential]$vmCredentials
)

task Ping {
    assert (Test-Connection -ComputerName $Config.testIp -Quiet) "Unable to ping the server."
    
}

task MySQLStatus {
    ### Get credentials
    $vmCredentials = Import-Clixml -Path ($Config.guestCred))

    $vm = "BTest_" + $Config.name

    $command = "service mysqld status"

    $run = @{
        VM = $vm 
        GuestCredential = $vmCredentials
        ScriptType  = 'bash'
        ScriptText = $command
    }
    $results = Invoke-VMScript @run
    Write-Host "$VM MySQL Status: $results"
}

task Netlogon {
    $GuestCredentialModified = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ('.\'+$GuestCredential.UserName), ($GuestCredential.Password)
    $ValidateService = (Get-WmiObject -Class Win32_Service -ComputerName $Config.testIp -Credential $GuestCredentialModified -Filter "name='Netlogon'").State
    equals $ValidateService 'Running'
}

task .

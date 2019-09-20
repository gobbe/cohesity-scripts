###
### Automate backup validation testing for VMs - Jussi Jaurola <jussi@cohesity.com>
###

$testrun = @{
    File            = 'testbuilder.ps1'
    EnvironmentFile = 'environment.json'
    ConfigFile      = 'config.json'
    IdentityPath    = '.\credentials'
    }

Invoke-Build @testrun -Result Result

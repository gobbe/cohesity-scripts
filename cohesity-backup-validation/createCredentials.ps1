###
### Helper tool to create encrypted credential files - Jussi Jaurola <jussi@cohesity.com>
###

param(
    $Path
)

$CredType = @("cohesity_cred.xml","vmware_cred.xml","guestvm_cred.xml")

foreach ($Type in $CredType) {
    $Credential = Get-Credential -Message $Type
    $Credential | Export-Clixml -Path ($Path + "\" + $Type)
}

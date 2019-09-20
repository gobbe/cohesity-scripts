# Cohesity backup validation PowerShell example

This is an example powershell for simple parallel and serial backup validation testing. 

With this example you can easily run testing for single VM or even against very complex application topology. All VMs are automatically cloned and then user-defined tests are applied against each VM. When tests are done all clones are automatically removed and summary of test results are shown.

# Prerequisites

* [PowerShell](https://aka.ms/getps6)
* [Cohesity PowerShell Module](https://cohesity.github.io/cohesity-powershell-module/#/)
* [VMware PowerCLI](https://www.powershellgallery.com/packages/VMware.PowerCLI/)
* [InvokeBuild](https://www.powershellgallery.com/packages/InvokeBuild/)


# Installation

Content of this folder can be downloaded to computer with network connectivity Cohesity and vCenter.

## Configuration

Configuration contains three files: environment.json, config.json and identity xml files for authentication.

### environment.json

This file contains both Cohesity and VMware vCenter server information. Cohesity part contains Cohesity cluster name and credential files. VMware part contains vCenter address, credentials and resource pool used for testing.

```PowerShell
{
        "cohesityCluster": cohesity-01",
        "cohesityCred": "cohesity_cred.xml",
        "vmwareServer": "vcenter-01",
        "vmwareResourcePool": "Resources",
        "vmwareCred": "vmware_cred.xml"
}
```

### config.json

This file contains information about virtual machines being tested and tests run per virtual machine

```PowerShell
{
    "virtualMachines": [
        {
            "name": "windows",
            "guestCred": "guestCred.xml",
            "testIp": "10.10.1.10",
            "testNetwork": "VMnetwork",
            "testGateway": "10.10.1.1",
            "tasks": ["Ping","Netlogon"]
        },
        {
            "name": "sql",
            "guestCred": "guestCred.xml",
            "testIp": "10.10.2.10",
            "testNetwork": "VMnetwork",
            "testGateway": "10.10.2.1",
            "tasks": ["Ping","Netlogon"]
        }
    ]
}
```

### identity xml files

The `Identity` folder is not included in this repository. It can be placed anywhere in your environment and should host secure XML files created with `Export-Clixml` containing the credentials needed to communicate with the Rubrik cluster, vCenter Server, and any guest operating systems involved in the application testing.

Use the [generateCreds.ps1](https://github.com/rubrikinc/PowerShell-Backup-Validation/blob/master/helper/generateCreds.ps1) file to create a starter set of credentials or see how the generation process works.

_Note: Secure XML files can only be decrypted by the user account that created them._

## Usage

After creation of environment.json, config.json and required identity xml files you can run cohesity-backup-validation.ps1 to automate testing.


# :pushpin: Notes
This is not an official Cohesity repository. Cohesity Inc. is not affiliated with the posted examples in any way.

```
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```

You can contact me via email (firstname AT cohesity.com)

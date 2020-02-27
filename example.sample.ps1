# import the workday api module
Import-Module C:\path\to\WorkdayApi

# set the connection to use TLS 1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

# tenant and api connection options
$tenant = ""
$api_endpoint = "https://wd5-impl-services1.workday.com/ccx/service/$tenant"
$api_version = "v33.2"

# build the full api url endpoints
$api_hr_endpoint = "$api_endpoint/Human_Resources/$api_version"
$api_integrations_endpoint = "$api_endpoint/Integrations/$api_version"
$api_staffing_endpoint = "$api_endpoint/Staffing/$api_version"

# api authentication options
$isu_username = ""
$isu_password = ""
$password = ConvertTo-SecureString $isu_password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential -ArgumentList ($isu_username, $password)

# set the workday creds and endpoints
Set-WorkdayCredential -Credential $credential
Set-WorkdayEndpoint -Endpoint Human_Resources $api_hr_endpoint
Set-WorkdayEndpoint -Endpoint Integrations $api_integrations_endpoint
Set-WorkdayEndpoint -Endpoint Staffing $api_staffing_endpoint

Save-WorkdayConfiguration

# get workers
$workers = Get-WorkdayWorker -IncludeWork -IncludePersonal

# output and format as a table 
$workers | Format-Table

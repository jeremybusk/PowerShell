# Search Active Directory and winrm hosts to check what user service is running as
Param(
  [Parameter(Mandatory=$true)][string]$domain,
  [Parameter(Mandatory=$false)][switch]$credprompt
)
$ErrorActionPreference = "Stop"                                                                                                                                                                                                                 $SearchBase = ""
$domain.Split(".") | ForEach {
    $SearchBase = $SearchBase + "DC=$_,"
 }
$SearchBase = $SearchBase.Substring(0,$SearchBase.Length-1)
if ($credprompt.IsPresent) {
  $cred = Get-Credential
}

$hostnames = (Get-ADComputer -Filter {(Name -like "*") -and (OperatingSystem -like "*windows*server*") -and (Enabled -eq "True")} -SearchBase $SearchBase -Server $domain -Properties Name | select-object -expandproperty name)

$sb = {Get-WmiObject Win32_Process -Filter "name='sensu-agent.exe'" |
 Select Name, @{Name="UserName";Expression={$_.GetOwner().Domain+"\"+$_.GetOwner().User}} |
 Sort-Object UserName, Name}

function check_service($fqdn, $sb) {
  try {
    if ($credprompt.IsPresent) {
      $service_username = (Invoke-Command -ComputerName $fqdn -Credential $cred -scriptblock $sb).UserName
    } else {
      $service_username = (Invoke-Command -ComputerName $fqdn -scriptblock $sb).UserName
    }
  } catch {
    Write-Host "E: $fqdn connection issue."
    return
  }
  if (!$service_username) {
    Write-Host "E: host: $fqdn sensu-agent appears to not be installed or running."
  } elseif ($service_username -like '*NT AUTHORITY*') {
    Write-Host "host: $fqdn service: sensu-agent username: $service_username."
  } elseif ($service_username -like '*prtg*') {
    Write-Host "host: $fqdn service: sensu-agent username: $service_username."
  } else {
    Write-Host "host: $fqdn service: sensu-agent username: $service_username."
  }
}

foreach ($hostname in $hostnames)
{
  $fqdn = "$hostname.$domain"
  $fqdn = ($hostname).tolower()
  check_service $fqdn $sb
  sleep 1
}

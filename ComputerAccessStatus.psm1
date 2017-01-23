function Get-ComputerAccessStatus {
[Cmdletbinding()]
param (
	[Parameter(Mandatory)]
	[string]$computer
)
#region ping
if (Test-Connection -ComputerName $computer -Count 1 -Quiet) {
		$ping = 'ok'
		Write-Verbose 'pinged' -Verbose
	} # end if
	else {
		$ping = 'no ping'
		$dns = ''
		Write-Warning "$computer no ping"
	} # end else
#endregion
	
#region dns
if ($ping -eq 'ok') 
{
  # $HostName = "$computer.gstt.local"
	$HostIP = Test-Connection $computer -Count 1 | Select-Object ProtocolAddress
	$ErrorActionPreference = 'SilentlyContinue'
  $HostResolved = [System.Net.Dns]::GetHostEntry($HostIP.ProtocolAddress) | Select-Object HostName
  $ErrorActionPreference = 'Continue'
	if ($HostResolved -ne $null)
  {
    if ($HostResolved.HostName.TrimEnd('.gstt.local') -ne $computer) 
    {
	    # Write-Warning "DNS problem, resolves to $($HostResolved.HostName)"
		  $HR = $($HostResolved.HostName)
	  }
  }
  
		
	if ($HR) 
  {
	  $dns = $HR.trim('.gstt.local')
		Write-warning "dns issue, resolved to $HR"
		# Write-Output $dns
    # no need to check wmi if we have dns issue
  } # end if HR we have dns problem
	else 
  {
	  if ($HostResolved -eq $null)
    {
      $dns = ''
    }
    else
    {
      $dns = 'ok'
    }
    
		Write-verbose 'dns ok'
        
    #region wmi
    $job = Get-WmiObject win32_ComputerSystem -ComputerName $computer -AsJob | 
    Wait-Job -Timeout 5 -ErrorAction SilentlyContinue
    
    $job = get-job

    if ($job.State -ne 'Completed') 
    {
      # write-warning "$computer timed out"
      if ($job.State -eq 'Failed') 
      {
        Write-Warning 'wmi broken'
        $wmistatus = 'broken'
        remove-job -State Failed
      } # end if

      elseif ($job.State -eq 'Running') 
      {
        <#
          If the State is Running the job could timeout but in 99%
          it's fine, that's why wmistatus is ok here.
        #>
      
        $wmistatus = 'ok'
        Stop-Job -State Running
        start-sleep -s 1
        Remove-Job -State Stopped
        Remove-Job -State Failed
        Remove-Job -State Completed
      } # end elseif job.State Running

      elseif ($job.State -eq 'Stopped') 
      {
        $wmistatus = 'stopped'
        Remove-Job -State Stopped
      } # end elseif job.State Stopped
      else {}
    } # end if job.State not completed
    else 
    {
      $wmistatus = 'ok'
      Write-Verbose 'wmi ok'
      remove-job -State Completed
      Remove-Job -State Failed
    } # end else wmi job status is Completed
    #endregion

    #region browse
    try
    {
      Get-ChildItem \\$computer\c$ -ErrorAction Stop | Out-Null
      $browse = 'ok'
    }
    catch
    {
      Write-Warning 'No browsing'
      $browse = 'no'
    }
    #endregion
		} # end else
} # end if ping ok
#endregion
	
	$ComputerStatus = [PSCustomObject]@{ 
                      name = $computer; 
                      ping = $ping; 
                      dns = $dns; 
                      wmi = $wmistatus; 
                      browse = $browse }
	Write-Output $ComputerStatus
} # end function Get-ComputerStatus

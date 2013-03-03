function GetMandatoryArgument(
	[Parameter(Position = 0, Mandatory = $true)]
	[hashtable] $AllArguments,
	[Parameter(Position = 1, Mandatory = $true)]
	[string] $Name)
{
	$result = $AllArguments[$Name]
	
	if (-not $result)
	{
		throw New-Object ArgumentNullException ($Name, "Argument '$Name' is undefined")
	}

	return $result
}

$Department = GetMandatoryArgument $Arguments "Department"
$DepartmentDir = "Configs\$Department"

try
{
	Get-ChildItem $DepartmentDir *.cfg
}
catch
{
	if ($_.CategoryInfo.Category -eq [System.Management.Automation.ErrorCategory]::ObjectNotFound)
	{
		throw New-Object ApplicationException "Department '$Department' is not found"
	}

	throw
}

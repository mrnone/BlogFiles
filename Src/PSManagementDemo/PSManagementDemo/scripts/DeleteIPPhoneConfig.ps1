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
$DeviceMAC = GetMandatoryArgument $Arguments "DeviceMAC"

# Validate MAC address
$regex = New-Object System.Text.RegularExpressions.Regex "^[a-fA-F0-9]{12}$"
if (-not $regex.IsMatch($DeviceMAC))
{
	throw New-Object ArgumentException (`
		"DeviceMAC", `
		"MAC address can contain only digits and characters A, B, C, D, E and F. A length of the MAC address must be 12 symbols.")
}

$DepartmentDir = "Configs\$Department"

Remove-Item "$DepartmentDir\$DeviceMAC.cfg" -Confirm:$false -Force

if (-not (Get-ChildItem $DepartmentDir))
{
	Remove-Item $DepartmentDir -Confirm:$false -Force
}

Write-Output "Success"
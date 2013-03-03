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

function CreateLocalUser(
	[Parameter(Mandatory = $true)]
	[string] $Name,
	[Parameter(Mandatory = $true)]
	[string] $Password)
{
	$Computer = [ADSI]"WinNT://$Env:COMPUTERNAME,Computer"
	$DeviceUser = $Computer.PSBase.Children | where {$_.PSBase.schemaClassName -match "user" -and $_.Name -eq $Name}

	if (-not $DeviceUser)
	{
		$DeviceUser = $Computer.Create("User", $Name)
		$DeviceUser.SetPassword($Password)
		$DeviceUser.SetInfo()
		$DeviceUser.FullName = "Demo: IP Phone User"
		$DeviceUser.SetInfo()
		$DeviceUser.UserFlags = 64 + 65536 # ADS_UF_PASSWD_CANT_CHANGE + ADS_UF_DONT_EXPIRE_PASSWD
		$DeviceUser.SetInfo()
	}
}

function ConfigureACL(
	[Parameter(Mandatory = $true)]
	[string] $ConfigFile,
	[Parameter(Mandatory = $true)]
	[string] $UserName)
{
	$ConfigAcl = Get-Acl $ConfigFile

	$Rule = New-Object System.Security.AccessControl.FileSystemAccessRule(`
		"$UserName","Read", "None", "None", "Allow")

	$ConfigAcl.AddAccessRule($Rule)
	Set-Acl $ConfigFile $ConfigAcl
}

# Read all arguments
$Department = GetMandatoryArgument $Arguments "Department"
$DeviceMAC = GetMandatoryArgument $Arguments "DeviceMAC"
$PhoneNumber = GetMandatoryArgument $Arguments "PhoneNumber"
$Password = GetMandatoryArgument $Arguments "Password"

# Validate MAC address
$regex = New-Object System.Text.RegularExpressions.Regex "^[a-fA-F0-9]{12}$"
if (-not $regex.IsMatch($DeviceMAC))
{
	throw New-Object ArgumentException (`
		"DeviceMAC", `
		"MAC address can contain only digits and characters A, B, C, D, E and F. A length of the MAC address must be 12 symbols.")
}

$DepartmentDir = "Configs\$Department"
$DeviceUserName = "Device_$DeviceMAC"

# Create a department's directory if need
if (-not (Get-Item $DepartmentDir -ErrorAction:SilentlyContinue))
{
	New-Item -Type directory -Path $DepartmentDir -Force | Out-Null
}

# Create a configuration file
New-Item -Type file -Path $DepartmentDir -Name "$DeviceMAC.cfg" -Value "#Config file for IP Phone with number $PhoneNumber" -Force | Out-Null

# Create a device user
CreateLocalUser -Name $DeviceUserName -Password $Password

# Set permissions for the user to the configuration file
ConfigureACL -ConfigFile "$DepartmentDir\$DeviceMAC.cfg" -UserName $DeviceUserName

Write-Output "Success"
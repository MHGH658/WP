PARAM(
    [STRING]$REGPATH="HKLM:\Software\MyScript",
    [STRING]$REGKEY="State",
    [STRING]$MyDirectory="C:\MyScript",
    [STRING]$MyService="MyScript",
    [STRING]$MyLogFile="MyScript.Log",
    [STRING]$DomainToJoin="Contoso"
    [SWITCH]$PromptForCredentials,
    [SWITCH]$Activate
)


####################################
#        *Informational*           #
#         Script States            #
####################################

# 1. Script ran, created service and registry keys

# 2. Renamed Computer and Restarted

# 3. Joined Domain and Restarted

# 4. Deleted service, registry keys and files

####################################
#       Set Script Variables       #
####################################

$SCRIPTROOT = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$SCRIPT = $MyInvocation.MyCommand.Definition

$MyScript="$MyDirectory\MyScript.ps1"
$CredentialFile="$MyDirectory\MyCredntials.csv"
$MyBinPath="CMD /C Powershell -File "+[char]34+"$MYSCRIPT"+[char]34+" -ExecutionPolicy Bypass"

$NewName="MyComputer01"

If(Test-Path "$CredentialFile"){ForEach($i in Import-CSV "$CredentialFile"){$UserName=$i.UserName;$Password=($i.Password | convertto-securestring);};$Credentials = new-object -typename System.Management.Automation.PSCredential -argumentlist $UserName, $Password}}

####################################
#     Load Script Functions        #
####################################

Function LOG($Content){Add-Content -Path "$MyLogFile" -Value "$Content" -Force} 

Function Setup-MyDirectory(){If(!(Test-Path "$MyDirectory")){New-Item -Path "$MyDirectory" -ItemType Directory -Force | Out-Null; Get-ChildItem "$SCRIPTROOT" | %{If(!($_.PSIsContainer)){Copy-Item -Path "$_" -Destination "$MyDirectory" -Force | Out-Null}}}ELSE{Get-ChildItem "$SCRIPTROOT" | %{If(!($_.PSIsContainer)){Copy-Item -Path "$_" -Destination "$MyDirectory" -Force | Out-Null}}}}
Function Create-MyService($serviceName, $binaryPath){New-Service -Name $serviceName -binaryPathName $binaryPath -displayName $serviceName -startupType Automatic | Out-Null}

Function Get-MyService($ServiceName){If(Get-Service -Name $ServiceName -EA SilentlyCOntinue){Return $True}ELSE{Return $False}}
Function Get-CurrentState(){If(!(Get-Item -Path $REGPATH -EA SilentlyContinue)){$MyCurrentState="NULL"}ELSE{If(Get-ItemProperty -Path $REGPATH -Name $REGKEY -EA SilentlyContinue){Return Get-ItemProperty -Path $REGPATH -Name $REGKEY -EA SilentlyContinue | %{$_.State}}ELSE{$MyCurrentState="NULL"}} Return $MyCurrentState}
Function Set-CurrentState($State){If(!(Get-Item -Path $REGPATH -EA SilentlyContinue)){New-Item -Path $REGPATH | Out-Null}; If(Test-Path $REGPATH\State){Set-ItemProperty -Path $REGPATH -Name $REGKEY -Value $State | Out-Null}ELSE{New-ItemProperty -Path $REGPATH -Name $REGKEY -PropertyType String -Value $State | Out-Null}}

Function Delete-MyService($serviceName){Get-WmiObject -Class Win32_Service -Filter "name='$serviceName'" | %{$_.Delete() | Out-Null}}

####################################
#   Check if script has ever ran   #
####################################

[STRING]$CurrentState=Get-CurrentState

If($CurrentState -eq "NULL"){

	##############################
	#   If not, create service   #
	##############################

	If(!(Get-MyService "$MyService")){Setup-MyDirectory; Create-MyService "$MyService" "$MyBinPath"; Set-CurrentState "0"}

}ELSE{

	#####################################
	#   If so, Where did is leave off   #
	#####################################

	If($CurrentState -eq "3"){Delete-MyService "$MyService"; Remove-Item -Path $REGPATH -EA SilentlyContinue; Remove-Item $SCRIPTROOT\* -Force; Remove-Item $SCRIPTROOT -Force}

	If($CurrentState -eq "2"){Add-Computer -Domain $Domain -Credential $Credentials -Force; Set-CurrentState "3"; Restart-Computer}

	If($CurrentState -eq "1"){Rename-Computer -NewName $NewName -ComputerName $env:computername; Set-CurrentState "2"; Restart-Computer}

}

####################################
#  Checking Certain Switches       #
####################################

If($PromptForCredentials){$Credentials=Get-Credential;$L1C1=[CHAR]34+"UserName"+[CHAR]34;$L1C2=[CHAR]34+"Password"+[CHAR]34;$L2C1=[CHAR]34+$Credentials.UserName+[CHAR]34;$L2C2=[CHAR]34+($Credentials.Password | ConvertFrom-SecureString)+[CHAR]34;$Line01=$L1C1, $L1C2 -Join ",";$Line02=$L2C1, $L2C2 -Join ",";If(Test-Path "$CredentialFile"){Remove-Item "$CredentialFile" -Force};Add-Content -Path "$CredentialFile" -Value $Line01;Add-Content -Path "$CredentialFile" -Value $Line02;}

If($Activate){Set-CurrentState "1"}

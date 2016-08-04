# Copyright 2011 - Present RealDimensions Software, LLC & original authors/contributors from https://github.com/chocolatey/chocolatey
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

function Get-ChecksumValid {
<#
.SYNOPSIS
Checks a file's checksum versus a passed checksum and checksum type.

.DESCRIPTION
Makes a determination if a file meets an expected checksum. This
function is usually used when comparing a file that is downloaded from
an official distribution point. If the checksum fails to
match, this function throws an error.

.NOTES
This uses the checksum.exe tool available separately at
https://chocolatey.org/packages/checksum.

.INPUTS
None

.OUTPUTS
None

.PARAMETER File
The full path to a binary file that is checksummed and compared to the
passed Checksum parameter value.

.PARAMETER Checksum
The expected checksum hash value of the File resource. The checksum
type is covered by ChecksumType.

.PARAMETER ChecksumType
The type of checkum that the file is validated with - 'md5', 'sha1',
'sha256' or 'sha512' - defaults to 'md5'.

MD5 is not recommended as certain organizations need to use FIPS
compliant algorithms for hashing - see
https://support.microsoft.com/en-us/kb/811833 for more details.

.PARAMETER IgnoredArguments
Allows splatting with arguments that do not apply. Do not use directly.

.EXAMPLE
Get-ChecksumValid -File $fileFullPath -CheckSum $checksum -ChecksumType $checksumType

.LINK
Get-ChocolateyWebFile

.LINK
Install-ChocolateyPackage
#>
param(
  [parameter(Mandatory=$true, Position=0)][string] $file,
  [parameter(Mandatory=$false, Position=1)][string] $checksum = '',
  [parameter(Mandatory=$false, Position=2)][string] $checksumType = 'md5',
  [parameter(Mandatory=$false, Position=3)][string] $originalUrl = '',
  [parameter(ValueFromRemainingArguments = $true)][Object[]] $ignoredArguments
)
  Write-Debug "Running 'Get-ChecksumValid' with file:`'$file`', checksum: `'$checksum`', checksumType: `'$checksumType`'";
  if ($env:ChocolateyIgnoreChecksums -eq 'true') {
    Write-Warning "Ignoring checksums due to feature checksumFiles turned off or option --ignore-checksums set."
    return
  }

  if ($checksum -eq '' -or $checksum -eq $null) { 
    $allowEmptyChecksums = $env:ChocolateyAllowEmptyChecksums
    if ($allowEmptyChecksums -eq 'true') {
      Write-Debug "Empty checksums are allowed due to allowEmptyChecksums feature or option"
      return
    }

    Write-Warning "Missing package checksums are no longer allowed (by default) for safety and security reasons. `n If you need this functionality, please set the feature allowEmptyChecksums `n (choco feature enable -n allowEmptyChecksums) or pass in the option `n --allow-empty-checksums."
    Write-Debug "If you are a maintainer attempting to determine the checksum for packaging purposes, please run `n 'choco install checksum' and run 'checksum -t sha256 -f $file' `n Ensure you do this for all remote resources."

    if ($env:ChocolateyPowerShellHost -eq 'true') { 
      $statement = "$([System.IO.Path]::GetFileName($file))"
      if ($originalUrl -ne $null -and $originalUrl -ne '') {
        $statement += " from '$originalUrl'"
      }
      $statement += " has not been verified by a package checksum as the originally intended file."
      $question = 'Do you wish to allow the install to continue (not recommended)?'
      $choices = New-Object System.Collections.ObjectModel.Collection[System.Management.Automation.Host.ChoiceDescription]
      $choices.Add((New-Object System.Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
      $choices.Add((New-Object System.Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))

      $selection = $Host.UI.PromptForChoice($statement, $question, $choices, 1)

      if ($selection -eq 0) { return }
    }
    
    throw "Empty checksums are no longer allowed by default. Please ask the maintainer to add checksums to this package. In the meantime, if you need this package to work correctly, please enable the feature allowEmptyChecksums or provide the runtime switch --allowEmptyChecksums"
  }

  if (!([System.IO.File]::Exists($file))) { throw "Unable to checksum a file that doesn't exist - Could not find file `'$file`'" }

  if ($checksumType -ne 'sha1' -and $checksumType -ne 'sha256' -and $checksumType -ne 'sha512' -and $checksumType -ne 'md5') {
    Write-Debug 'Setting checksumType to md5 due to non-set value or type is not specified correctly.'
    $checksumType = 'md5'
  }

  $checksumExe = Join-Path "$helpersPath" '..\tools\checksum.exe'
  if (!([System.IO.File]::Exists($checksumExe))) {
    Update-SessionEnvironment
    $checksumExe = Join-Path "$env:ChocolateyInstall" 'tools\checksum.exe'
  }
  Write-Debug "checksum.exe found at `'$checksumExe`'"

  $params = "-c=`"$checksum`" -t=`"$checksumType`" -f=`"$file`""

  Write-Debug "Executing command ['$checksumExe' $params]"
  $process = New-Object System.Diagnostics.Process
  $process.StartInfo = New-Object System.Diagnostics.ProcessStartInfo($checksumExe, $params)
  $process.StartInfo.UseShellExecute = $false
  $process.StartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden

  $process.Start() | Out-Null
  $process.WaitForExit()
  $exitCode = $process.ExitCode
  $process.Dispose()

  Write-Debug "Command [`'$checksumExe`' $params] exited with `'$exitCode`'."

  if ($exitCode -ne 0) {
    throw "Checksum for '$file' did not meet '$checksum' for checksum type '$checksumType'. Consider passing --ignore-checksums if necessary."
  }

  #$fileCheckSumActual = $md5Output.Split(' ')[0]
  # if ($fileCheckSumActual -ne $checkSum) {
  #   throw "CheckSum for `'$file'` did not meet `'$checkSum`'."
  # }
}

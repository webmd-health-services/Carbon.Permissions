
function Test-CPermission
{
    <#
    .SYNOPSIS
    Tests permissions on a file, directory, or registry key

    .DESCRIPTION
    The `Test-CPermission` function tests if permissions are granted to a user or group on a file, directory, or
    registry key. Using this function and module are not recommended. Instead,

    * for file directory permissions, use `Test-CNtfsPermission` in the `Carbon.FileSystem` module.
    * for registry permissions, use `Test-CRegistryPermission` in the `Carbon.Registry` module.
    * for private key and/or key container permissions, use `Test-CPrivateKeyPermission` in the `Carbon.Cryptography`
      module.

    Pass the path to the item to the `Path` parameter. Pass the user/group name to the `Identity` parameter. Pass the
    permissions to check for to the `Permission` parameter. If the user has all those permissions on that item, the
    function returns `true`. Otherwise it returns `false`.

    The `Permissions` attribute should be a list of
    [FileSystemRights](http://msdn.microsoft.com/en-us/library/system.security.accesscontrol.filesystemrights.aspx) or
    [RegistryRights](http://msdn.microsoft.com/en-us/library/system.security.accesscontrol.registryrights.aspx). These
    commands will show you the values for the appropriate permissions for your object:

        [Enum]::GetValues([Security.AccessControl.FileSystemRights])
        [Enum]::GetValues([Security.AccessControl.RegistryRights])

    Extra/additional permissions on the item are ignored. To check that the user/group has the exact permissions passed
    to the `Permission` parameter, use the `Strict` switch.

    You can also test how the item's permissions are applied and inherited, use the `ApplyTo` and `OnlyApplyToChildren`
    parameters. These match the "Applies to" and "Only apply these permissions to objects and/or containers within this
    container" fields in the Windows Permission user interface. The following table shows how these parameters are
    converted to `[Security.AccesControl.InheritanceFlags]` and `[Security.AccessControl.PropagationFlags]` values:

    | ApplyTo                         | OnlyApplyToChildren | InheritanceFlags                | PropagationFlags
    | ------------------------------- | ------------------- | ------------------------------- | ----------------
    | ContainerOnly                   | false               | None                            | None
    | ContainerSubcontainersAndLeaves | false               | ContainerInherit, ObjectInherit | None
    | ContainerAndSubcontainers       | false               | ContainerInherit                | None
    | ContainerAndLeaves              | false               | ObjectInherit                   | None
    | SubcontainersAndLeavesOnly      | false               | ContainerInherit, ObjectInherit | InheritOnly
    | SubcontainersOnly               | false               | ContainerInherit                | InheritOnly
    | LeavesOnly                      | false               | ObjectInherit                   | InheritOnly
    | ContainerOnly                   | true                | None                            | None
    | ContainerSubcontainersAndLeaves | true                | ContainerInherit, ObjectInherit | NoPropagateInherit
    | ContainerAndSubcontainers       | true                | ContainerInherit                | NoPropagateInherit
    | ContainerAndLeaves              | true                | ObjectInherit                   | NoPropagateInherit
    | SubcontainersAndLeavesOnly      | true                | ContainerInherit, ObjectInherit | NoPropagateInherit, InheritOnly
    | SubcontainersOnly               | true                | ContainerInherit                | NoPropagateInherit, InheritOnly
    | LeavesOnly                      | true                | ObjectInherit                   | NoPropagateInherit, InheritOnly

    By default, inherited permissions are ignored. To check inherited permission, use the `-Inherited` switch.

    .OUTPUTS
    System.Boolean.

    .LINK
    Get-CPermission

    .LINK
    Grant-CPermission

    .LINK
    Revoke-CPermission

    .LINK
    http://msdn.microsoft.com/en-us/library/system.security.accesscontrol.filesystemrights.aspx

    .LINK
    http://msdn.microsoft.com/en-us/library/system.security.accesscontrol.registryrights.aspx

    .EXAMPLE
    Test-CPermission -Identity 'STARFLEET\JLPicard' -Permission 'FullControl' -Path 'C:\Enterprise\Bridge'

    Demonstrates how to check that Jean-Luc Picard has `FullControl` permission on the `C:\Enterprise\Bridge`.

    .EXAMPLE
    Test-CPermission -Identity 'STARFLEET\GLaForge' -Permission 'WriteKey' -Path 'HKLM:\Software\Enterprise\Engineering'

    Demonstrates how to check that Geordi LaForge can write registry keys at `HKLM:\Software\Enterprise\Engineering`.

    .EXAMPLE
    Test-CPermission -Identity 'STARFLEET\Worf' -Permission 'Write' -ApplyTo 'Container' -Path 'C:\Enterprise\Brig'

    Demonstrates how to test for inheritance/propogation flags, in addition to permissions.
    #>
    [CmdletBinding(DefaultParameterSetName='ExcludeApplyTo')]
    param(
        # The path on which the permissions should be checked.  Can be a file system or registry path.
        [Parameter(Mandatory)]
        [String] $Path,

        # The user or group whose permissions to check.
        [Parameter(Mandatory)]
        [String] $Identity,

        # The permission to test for: e.g. FullControl, Read, etc.  For file system items, use values from
        # [System.Security.AccessControl.FileSystemRights](http://msdn.microsoft.com/en-us/library/system.security.accesscontrol.filesystemrights.aspx).
        # For registry items, use values from
        # [System.Security.AccessControl.RegistryRights](http://msdn.microsoft.com/en-us/library/system.security.accesscontrol.registryrights.aspx).
        [Parameter(Mandatory)]
        [String[]] $Permission,

        # How the permissions should be applied recursively to subcontainers and leaves. Default is
        # `ContainerSubcontainersAndLeaves`.
        [Parameter(Mandatory, ParameterSetName='IncludeApplyTo')]
        [ValidateSet('ContainerOnly', 'ContainerSubcontainersAndLeaves', 'ContainerAndSubcontainers',
            'ContainerAndLeaves', 'SubcontainersAndLeavesOnly', 'SubcontainersOnly', 'LeavesOnly')]
        [String] $ApplyTo,

        # Inherited permissions should only apply to the children of the container, i.e. only one level deep.
        [Parameter(ParameterSetName='IncludeApplyTo')]
        [switch] $OnlyApplyToChildren,

        # Include inherited permissions in the check.
        [switch] $Inherited,

        # Check for the exact permissions, inheritance flags, and propagation flags, i.e. make sure the identity has
        # *only* the permissions you specify.
        [switch] $Strict
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -Session $ExecutionContext.SessionState

    $rArgs = Resolve-Arg -Path $Path `
                         -Identity $Identity `
                         -Permission $Permission `
                         -ApplyTo $ApplyTo `
                         -OnlyApplyToChildren:$OnlyApplyToChildren `
                         -Action 'test'
    if (-not $rArgs)
    {
        return
    }

    $providerName = $rArgs.ProviderName
    $rights = $rArgs.Rights
    $inheritanceFlags = $rArgs.InheritanceFlags
    $propagationFlags = $rArgs.PropagationFlags

    if ($providerName -eq 'FileSystem' -and $Strict)
    {
        # Synchronize is always on and can't be turned off.
        $rights = $rights -bor [FileSystemRights]::Synchronize
    }

    foreach ($currentPath in $rArgs.Paths)
    {
        $isLeaf = (Test-Path -LiteralPath $currentPath -PathType Leaf)
        $testFlags = $PSCmdlet.ParameterSetName -eq 'IncludeApplyTo'

        if ($isLeaf -and $testFlags)
        {
            $msg = "Failed to test ""applies to"" flags on path ""${currentPath}"" because it is a file. Please omit " +
                   '"ApplyTo" and "OnlyApplyToChildren" parameters when testing permissions on a file.'
            Write-Warning $msg
        }

        $rightsPropertyName = "${providerName}Rights"
        $acl =
            Get-CPermission -Path $currentPath -Identity $Identity -Inherited:$Inherited |
            Where-Object 'AccessControlType' -eq 'Allow' |
            Where-Object 'IsInherited' -eq $Inherited |
            Where-Object {
                if ($Strict)
                {
                    return ($_.$rightsPropertyName -eq $rights)
                }

                return ($_.$rightsPropertyName -band $rights) -eq $rights
            } |
            Where-Object {
                if ($isLeaf -or -not $testFlags)
                {
                    return $true
                }

                return $_.InheritanceFlags -eq $inheritanceFlags -and $_.PropagationFlags -eq $propagationFlags
            }

        if ($acl)
        {
            $true | Write-Output
            continue
        }

        $false | Write-Output
    }
}


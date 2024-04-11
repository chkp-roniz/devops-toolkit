param(
    [string]$org,
    [int]$threshold = 30,
    [bool]$dryRun = $true
)

if($org -eq "" -or $org -eq $null) {
    write-host "Usage: copilot.ps1 -org <organization> [-threshold <days>] [-dryRun <true/false>]"
    exit
}

<#
.SYNOPSIS
    Retrieves all seats for the Copilot billing in an organization.
.DESCRIPTION
    The Get-Seats function retrieves all seats for the Copilot billing in an organization. It uses pagination to retrieve seats from multiple pages.
.PARAMETER page
    The page number to retrieve seats from. Defaults to 1 if not specified.
.EXAMPLE
    Get-Seats -page 1
    Retrieves all seats from page 1 of the Copilot billing.
.OUTPUTS
    System.Object[]
    An array of seats retrieved from the Copilot billing.
#>
function Get-Seats {
    param (
        $page = 1
    )

    write-host "Getting seats... (page $page)"

    $seats = (gh api orgs/$org/copilot/billing/seats?page=$page | ConvertFrom-Json).seats
    
    if($seats.Count -eq 0) { 
        return 
    }

    return $seats + (Get-Seats -page ($page + 1))
}


<#
.SYNOPSIS
Checks if a seat is active based on the last update and last activity timestamps.
.DESCRIPTION
The Get-IsActive function determines whether a seat is considered active or not based on the last update and last activity timestamps. It compares these timestamps with a threshold date to determine the seat's activity status.
.PARAMETER seat
The seat object to check for activity.
.EXAMPLE
$seat = Get-Seat
$isActive = Get-IsActive -seat $seat
# Returns $true if the seat is active, otherwise returns $false.
#>
function Get-IsActive {
    param (
        $seat
    )

    $base = $CurrentDate.AddDays(-1*$threshold)
    $recentlyUpdated = (Get-Date $seat.updated_at) -gt $base
    if($recentlyUpdated){
        # In case the seat was updated in the the threshold period, it is considered active (avoid delteing new seats)
        return $true
    }

    if($null -eq $seat.last_activity_at) { 
        return $false 
    }

    # In case the seat was recently active, return true
    return (Get-Date $seat.last_activity_at) -gt $base
}

<#
.SYNOPSIS
Revokes a GitHub Copilot seat in the organization.
.DESCRIPTION
The Revoke-Seat function is used to revoke a seat from a user in Copilot. It checks if the seat is assigned to a team or directly to a user and performs the necessary actions to revoke the seat.
.PARAMETER seat
The seat object representing the user's seat in Copilot.
.EXAMPLE
Revoke-Seat -seat $seat
Revokes the seat assigned to the user specified in the $seat object.
#>

function Revoke-Seat {
    param (
        $seat
    )

    $userName = $seat.assignee.login
    if($seat.assigning_team) {
        write-host "Removing $userName membership from $($seat.assigning_team.name) team (last activity: $($seat.last_activity_at))" $seat.updated_at
        if (!$dryRun) { 
            gh api orgs/$org/teams/$($seat.assigning_team.name)/memberships/$userName -X DELETE
        }
    }
    else {
        write-host "Revoke $userName seat in copilot (last activity: $($seat.last_activity_at))" $seat.updated_at
        if (!$dryRun){
            gh api orgs/$org/copilot/billing/selected_users -X DELETE -f selected_usernames=$userName
        }
    }
}

$CurrentDate = Get-Date

write-host "Cleanup GitHub Copilot seats for organization $org"
if($dryRun) {
    write-host "Running in dry-run mode. No changes will be made."
}else {
    write-host "Running in live mode. Changes will be made!!!"
}

$seats = Get-Seats
write-host "$($seats.Count) seats found in the organization."

ForEach ($seat in $seats) {
    $userName = $seat.assignee.login  
    if(!(Get-IsActive $seat)) {
        Revoke-Seat $seat
    }
}
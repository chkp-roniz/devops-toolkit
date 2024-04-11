## Revoke Inactive GitHub Copilot Seats
This script will revoke inactive GitHub Copilot seats from your organization. It will revoke the seat of any user who has not used Copilot in the given threshold days.
### Pre-requisites
1. Download and istall GitHub CLI from [here](https://cli.github.com/).
2. Authenticate with GitHub CLI using `gh auth login`.

### How to use?
```
PS> ./revoke-copilot-seats.ps1 -org <org-name> -threshold <days>
```
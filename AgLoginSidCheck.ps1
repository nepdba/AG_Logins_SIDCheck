<#
Description:
This PowerShell script checks for login SID mismatches and missing logins across different servers within Availability Groups (AG). 
It defines AG server sets and retrieves login information from both primary and secondary servers within each AG set. 
The script compares the SIDs of logins on primary and secondary servers and identifies mismatches or missing logins. 
The results are stored in the `loginSidCheckAg` table in the DBA database on the CMS server.

Details:
1. **Define AG Server Sets:**
   - AG_01: NodeA, NodeB, NodeC
   - AG_02: NodeAA, NodeBB, NodeCC

2. **CMS Server and  Database:**
   - CMS Server: <CMS Server Name>
   - DBA Database: <Database>

3. **Function to Get Logins and SIDs:**
   - Retrieves logins and their SIDs from a specified server.
   - Excludes logins starting with 'NT%', '##%', and 'Exeter_sa'.

4. **Store Results:**
   - An array `$results` is prepared to store the comparison results.

5. **Iterate Through AG Server Sets:**
   - For each AG set, logins from the primary server are retrieved.
   - These logins are compared with logins from the secondary servers in the same AG set.

6. **Compare Logins:**
   - If a login exists on both primary and secondary servers but has different SIDs, it is recorded as an SID mismatch.
   - If a login on the primary server is not found on the secondary server, it is recorded as a login not found.

7. **Insert Results into the Database:**
   - Results are inserted into the `[DBA].[dbo].[loginSidCheckAg]` table on the CMS server.

8. **Output:**
   - Confirmation message indicating the results have been inserted into the table.

Script Created by: Shakti Baral
Created Date: 07/26/2024
Example Execution: ./AgLoginSidCheck.ps1
#>


# Define the AG server sets
$AGServers = @{
    AG_01 = @("NodeA", "NodeB",'NodeC')       # Change server name
    AG_02 = @("NodeAA", "NodeBB",'NodeCC')    # Change server name
} 

# CMS server and DBA database
$CMSserver = "SERVERA"     # Change server name
$DBAdatabase = "Database"  # Change Database name

# Function to get logins and their SIDs from a server
function Get-Logins {
    param (
        [string]$serverName
    )

    $query = @"
SELECT name AS LoginName, CONVERT(VARCHAR(128), sid, 1) AS LoginSID, type_desc AS LoginType
FROM sys.server_principals
WHERE type_desc IN ('SQL_LOGIN', 'WINDOWS_LOGIN', 'WINDOWS_GROUP')
AND name NOT LIKE ('NT%') and name NOT LIKE ('##%')
AND name <> 'Exeter_sa'
"@

    $connectionString = "Server=$serverName;Integrated Security=True;"
    $logins = Invoke-Sqlcmd -Query $query -ConnectionString $connectionString
    return $logins
}

# Prepare an array to store the results
$results = @()

# Iterate through each AG server set
foreach ($ag in $AGServers.Keys) {
    Write-Host "Checking logins for AG set: $ag" -ForegroundColor Green

    $primaryServer = $AGServers[$ag][0]
    $secondaryServers = $AGServers[$ag][1..($AGServers[$ag].Count - 1)]

    # Get logins from the primary server
    $primaryLogins = Get-Logins -serverName $primaryServer

    # Iterate through each secondary server and compare logins
    foreach ($secondaryServer in $secondaryServers) {
        $secondaryLogins = Get-Logins -serverName $secondaryServer

        # Compare logins
        foreach ($primaryLogin in $primaryLogins) {
            $secondaryLogin = $secondaryLogins | Where-Object { $_.LoginName -eq $primaryLogin.LoginName }

            if ($secondaryLogin) {
                if ($primaryLogin.LoginSID -ne $secondaryLogin.LoginSID) {
                    $results += [PSCustomObject]@{
                        AgName           = $ag
                        PrimaryServer   = $primaryServer
                        SecondaryServer = $secondaryServer
                        LoginName       = $primaryLogin.LoginName
                        LoginType       = $primaryLogin.LoginType
                        Issue           = "SID mismatch"
                    }
                }
            } else {
                $results += [PSCustomObject]@{
                    AgName           = $ag
                    PrimaryServer   = $primaryServer
                    SecondaryServer = $secondaryServer
                    LoginName       = $primaryLogin.LoginName
                    LoginType       = $primaryLogin.LoginType
                    Issue           = "Login not found"
                }
            }
        }
    }
}

# Insert results into the loginCheck table
foreach ($result in $results) {
    $insertQuery = @"
INSERT INTO [DBA].[dbo].[loginSidCheckAg] (AgName, PrimaryServer, SecondaryServer, LoginName, LoginType, Issue)
VALUES ('$($result.AgName)', '$($result.PrimaryServer)', '$($result.SecondaryServer)', '$($result.LoginName)', '$($result.LoginType)', '$($result.Issue)')
"@
    Invoke-Sqlcmd -ServerInstance $CMSserver -Database $DBAdatabase -Query $insertQuery
}

Write-Host "Results inserted into [DBA].[dbo].[loginSidCheckAg] table on $CMSserver." -ForegroundColor Green

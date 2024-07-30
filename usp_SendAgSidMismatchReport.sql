USE [DBA]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[usp_SendAgSidMismatchReport]
AS
/********************************************************
<>
=========================================================
Name: usp_SendAgSidMismatchReport
Author: Shakti Baral
Created: 07-26-2024

Description: This script creates a stored procedure dbo.[usp_SendAgSidMismatchReport] in the DBA database. 
The procedure checks for Login SID mismatch or missing logins in AG servers and sends an HTML email report if data is found in loginSidCheckAg table.

exec [dbo].[usp_SendAgSidMismatchReport]
Dependency: [DBA].[dbo].[loginSidCheckAg]
*********************************************************/ 

BEGIN
    SET NOCOUNT ON;

    DECLARE @Today DATETIME;
    DECLARE @EmailBody NVARCHAR(MAX);

    -- Get today's date (without time)
    SET @Today = CAST(GETDATE() AS DATE);

    -- Check if there is data for today's date
    IF EXISTS (SELECT 1 FROM [DBA].[dbo].[loginSidCheckAg] WHERE CAST(CheckDate AS DATE) = CAST(GETDATE() AS DATE))	
    BEGIN
        -- Generate the HTML email body
        SET @EmailBody = 
        N'<html>
        <head>
            <style>
                table { border-collapse: collapse; width: 100%; }
                th, td { border: 1px solid black; padding: 8px; text-align: left; }
                th { background-color: red; }
            </style>
        </head>
        <body>
            <h2>ALERT: AG Servers Login SID mismatch / Login Missing</h2>
            <p>Report Date: ' + CONVERT(NVARCHAR, @Today, 120) + N'</p>
			<p>Note: Please make sure all the logins in AG servers are in sync.Thank you! </p>
            <table>
                <tr>
                    <th>AgName</th>
                    <th>PrimaryServer</th>
                    <th>SecondaryServer</th>
                    <th>LoginName</th>
                    <th>LoginType</th>
                    <th>Issue</th>
                </tr>';

        -- Append rows to the HTML email body
        SELECT @EmailBody = @EmailBody + 
        N'<tr>
            <td>' + ISNULL(AgName, '') + N'</td>
            <td>' + ISNULL(PrimaryServer, '') + N'</td>
            <td>' + ISNULL(SecondaryServer, '') + N'</td>
            <td>' + ISNULL(LoginName, '') + N'</td>
            <td>' + ISNULL(LoginType, '') + N'</td>
            <td>' + ISNULL(Issue, '') + N'</td>

        </tr>'
        FROM [DBA].[dbo].[loginSidCheckAg]
        WHERE CAST(CheckDate AS DATE) = CAST(GETDATE() AS DATE)
		

        -- Close the HTML tags
        SET @EmailBody = @EmailBody + 
        N'</table>
        </body>
        </html>';

        -- Send the email
        EXEC msdb.dbo.sp_send_dbmail
            @profile_name = 'PROD DBA',                -- Replace with your Database Mail profile
		    @recipients = 'shakti.baral@gmail.com',   -- Replace with the recipient email address
            @subject = 'ALERT : AG Servers Login SID mismatch / Login Missing',
            @body = @EmailBody,
            @body_format = 'HTML';
    END
    ELSE
    BEGIN
        PRINT 'Logins are in sync in AG Servers.';
    END
END;


GO



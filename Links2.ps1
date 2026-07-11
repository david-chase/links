#-------------------------------------------------------------------
#  Links v2.0
#  Manage a JSON file of links
#-------------------------------------------------------------------

$sSharedFunctions = $env:SharedFunctions
Push-Location $sSharedFunctions
. ".\General Functions v1.ps1"
. ".\Tags Functions v1.ps1"
Pop-Location

$bExit = $false
$sDataFile = $env:DataFiles + [IO.Path]::DirectorySeparatorChar + "bookmarks.json"

# ---------------------------------------
#  Load all links from the JSON file into memory
# ---------------------------------------
function Get-BookmarksData {
    if( ( Test-Path -Path $sDataFile ) -and ( ( Get-Item -Path $sDataFile ).Length -gt 0 ) ) {
        $oJson = Get-Content -Path $sDataFile -Raw | ConvertFrom-Json
        if( $oJson.links ) { $aData = @( $oJson.links ) } else { $aData = @() }
    } else {
        $aData = @()
    } # END if( Test-Path )
    return , $aData
} # END function Get-BookmarksData

# ---------------------------------------
#  Save all links back out to the JSON file
# ---------------------------------------
function Save-BookmarksData {
    param( [Parameter(Mandatory)] $aData )
    $oOutput = [PSCustomObject]@{ links = @( $aData ) }
    $oOutput | ConvertTo-Json -Depth 5 | Set-Content -Path $sDataFile -Encoding utf8
} # END function Save-BookmarksData

# ---------------------------------------
#  Turn a raw tag entry string (# delimited, no spaces) into a sorted,
#  lowercase array of tags, e.g. "#Zabbix#Product" -> @( "#product", "#zabbix" )
# ---------------------------------------
function ConvertTo-TagArray {
    param( [string]$sTagString )
    $aRawTags = $sTagString -split '#' | Where-Object { $_ -ne '' }
    $aTags = @( $aRawTags | ForEach-Object { '#' + $_.Trim().ToLower() } | Sort-Object )
    return , $aTags
} # END function ConvertTo-TagArray

$aLinks = Get-BookmarksData

do {
    #cls
    Write-Host 
    Write-Host ::: Links v2.0 ::: -ForegroundColor Cyan
    Write-Host 
    $sParam = ""

    $sInput = ( ( Read-Host -Prompt "> " ).Trim() )
    if( $sInput.Contains( " " ) ) { 
        $sCommand = $sInput.split( " ", 2 )[ 0 ].ToLower()
        $sParam = $sInput.split( " ", 2 )[ 1 ]
    } else {
        $sCommand = $sInput.ToLower()
    } # END if( $sInput.Contains( " " ) )

    switch( $sCommand ) {
        # ---------------------------------------
        #  Help
        # ---------------------------------------
        "?" {
            Write-Host 
            Write-Host "add [url]" -ForegroundColor Cyan
            Write-Host "find [url]" -ForegroundColor Cyan
            Write-Host "quit" -ForegroundColor Cyan
            Write-Host "update [url]" -ForegroundColor Cyan
            Write-Host "verbose [string1]&[string2]&[string3]" -ForegroundColor Cyan
        } # END Case ?
       
        # ---------------------------------------
        #  Add a link
        # ---------------------------------------
        { ( $_ -eq "a" ) -or ( $_ -eq "add" ) } { 
            if( $sParam ) {
                # Verify the url is unique before adding
                $aResults = @( $aLinks | Where-Object { $_.url -eq $sParam } )
                if( $aResults.Count ) { Write-Host "$sParam already exists" -ForegroundColor Red; Break }
                
                $sUrl = $sParam
                do { $sTitle = Read-Host -Prompt "Enter title" } while( -not $sTitle )
                do { $sTagString = Read-Host -Prompt "Enter tags" } while( -not $sTagString )
                $aTags = ConvertTo-TagArray -sTagString $sTagString

                $oNewRecord = [PSCustomObject]@{
                    title = $sTitle
                    url   = $sUrl
                    tags  = $aTags
                }
                $aLinks = @( $aLinks ) + $oNewRecord
                Save-BookmarksData -aData $aLinks
            } else 
            { Write-Host "a (Add) command requires a parameter" -ForegroundColor Red }
        } # END Case add

        # ---------------------------------------
        #  Find and display one record per line
        # ---------------------------------------
        { ( $_ -eq "f" ) -or ( $_ -eq "find" ) } {
            $aResults = @( $aLinks | Where-Object { $_.url -like "*$sParam*" } )
            $aResults | Select-Object -Property title, url, @{ Name = "tags"; Expression = { $_.tags -join '' } } | Sort-Object -Property title | Out-Host
            Write-Host $aResults.Count matches... -ForegroundColor Cyan
        } # END Case find

        # ---------------------------------------
        #  Quit
        # ---------------------------------------
        { ( $_ -eq "q" ) -or ( $_ -eq "quit" ) } {
            $bExit = $true 
        } # END Case quit      

        # ---------------------------------------
        # Update a link
        # ---------------------------------------
        { ( $_ -eq "u" ) -or ( $_ -eq "update" ) } { 
            if( $sParam ) {
                # Locate the record by url so there are no duplicates
                $aResults = @( $aLinks | Where-Object { $_.url -eq $sParam } )
                if( -not $aResults.Count ) { Write-Host "No record matching $sParam" -ForegroundColor Red; Break }
                if( $aResults.Count -gt 1 ) { Write-Host "Multiple records matching $sParam" -ForegroundColor Red; Break }
                
                $oRecord = $aResults[ 0 ]
                $sTitle = $oRecord.title
                $sInput = Read-Host -Prompt "Enter title [$sTitle]"
                # Set $sTitle to what I just entered if anything, otherwise use the previous value
                if( $sInput ) { $sTitle = $sInput }

                $sTagString = ( $oRecord.tags -join '' )
                $sInput = Read-Host -Prompt "Enter tags [$sTagString]"
                
                # Set $sTagString to what I just entered if anything, otherwise use the previous value
                if( $sInput ) { 

                    # A silly little hack such that if you type +#tags it will add them rather than overwrite
                    $aInput = $sInput.Split( "+", 2 )
                    if( $aInput.Count -eq 2 ) {
                        $sTagString = $sTagString + $aInput[ 1 ]
                    } # END if( $aTags.Count -eq 2 )
                    else {
                        # A silly little hack such that if you type -#tags it will delete them rather than overwrite
                        $aInput = $sInput.Split( "-", 2 )
                        if( $aInput.Count -eq 2 ) {
                            $sTagString = $sTagString.replace( $aInput[ 1 ], '' )
                        } # END if( $aTags.Count -eq 2 )  
                        else{ 
                            $sTagString = $sInput
                        } # END if( $aTags.Count -eq 2 )  
                    } 

                } # if( $sInput )

                $oRecord.title = $sTitle
                $oRecord.tags  = ConvertTo-TagArray -sTagString $sTagString
                Save-BookmarksData -aData $aLinks
            } else 
            { Write-Host "u (Update) command requires a parameter" -ForegroundColor Red }
        } # END Case add

        # ---------------------------------------
        #  Find and display a verbose record
        # ---------------------------------------
        { ( $_ -eq "v" ) -or ( $_ -eq "verbose" ) } {
            # To support multiple queries we'll start by filtering the in-memory data.  Then we remove results in-memory.
            $iParamNum = 0
            $aParams = $sParam.Split( '&' )
            # Now lets do some cleanup of our parameters
            foreach( $sParam in $aParams ) {
                $iParamNum++
                # Strips off whitespace and single quotes
                $sParam = $sParam.Trim( ' ' )
                $sParam = $sParam.Trim( '"' )
            
                # If this is our very first parameter, filter the full data set
                if( $iParamNum -eq 1 ) { 
                    $aResults = @( $aLinks | Where-Object { ( $_.url -like "*$sParam*" ) -or ( $_.title -like "*$sParam*" ) -or ( ( $_.tags -join '' ) -like "*$sParam*" ) } | Sort-Object -Property title )
                } else {
                    $aResults = $aResults | Where-Object { ( $_.title -CMatch $sParam ) -or ( $_.url -CMatch $sParam ) -or ( ( $_.tags -join '' ) -CMatch $sParam ) }
                }

            } # END foreach( $sParam in $aParams )

            # Output in verbose format
            Write-Host
            foreach( $oResult in $aResults ) {
                Write-Host "title: " -NoNewline -ForegroundColor Green
                Write-Host $oResult.title
                Write-Host "url:   " -NoNewline -ForegroundColor Green
                Write-Host $oResult.url
                Write-Host "tags:  " -NoNewline -ForegroundColor Green
                Write-Host ( $oResult.tags -join '' )
                Write-Host
            } # END foreach( $oResult in $aResults )

        Write-Host $aResults.Count matches... -ForegroundColor Cyan

        } # END Case verbose

        # ---------------------------------------
        #  Add a tag in bulk - this is a placeholder
        # ---------------------------------------
        { $_ -eq "addtag" } {
            Write-Host $aResults.Count
        } # END { $_ -eq "addtag" }

        # ---------------------------------------
        #  Delete a Link
        # ---------------------------------------
        { ( $_ -eq "d" ) -or ( $_ -eq "delete" ) } {
            # Only proceed if a parameter has been supplied
            if( $sParam ) {
                $aResults = @( $aLinks | Where-Object { $_.url -eq $sParam } )
                if( -not $aResults.Count ) { Write-Host "No record matching $sParam" -ForegroundColor Red; Break }
                if( $aResults.Count -gt 1 ) { Write-Host "Multiple records matching $sParam" -ForegroundColor Red; Break }
                
                $aLinks = @( $aLinks | Where-Object { $_.url -ne $sParam } )
                Save-BookmarksData -aData $aLinks
            } else 
            { Write-Host "d (Delete) command requires a parameter" -ForegroundColor Red }
        } # END ( $_ -eq "d" ) -or ( $_ -eq "delete" )

    } # END switch( $sCommand )

} while ( -not $bExit )
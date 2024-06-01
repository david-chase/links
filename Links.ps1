#-------------------------------------------------------------------
#  Links
#  Manage a CosmosDB database of links
#-------------------------------------------------------------------

$sSharedFunctions = $env:SharedFunctions
Push-Location $sSharedFunctions
. ".\General Functions v1.ps1"
. ".\CosmosDB Functions v2.ps1"
. ".\Tags Functions v1.ps1"
Pop-Location

$bExit = $false
$sCollection = "Links"

do {
    #cls
    Write-Host 
    Write-Host ::: Links ::: -ForegroundColor Cyan
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
        "?" {
            Write-Host 
            Write-Host "add [link]" -ForegroundColor Cyan
            Write-Host "find [link]" -ForegroundColor Cyan
            Write-Host "quit" -ForegroundColor Cyan
            Write-Host "update [link]" -ForegroundColor Cyan
            Write-Host "verbose [string1]&[string2]&[string3]" -ForegroundColor Cyan
        } # END Case ?
       
        { ( $_ -eq "a" ) -or ( $_ -eq "add" ) } { 
            if( $sParam ) {
                # Query the database so there are no duplicates
                $sQuery = "SELECT * FROM " + $sCollection + " c WHERE c.link='" + $sParam + "'"
                $aResults = Query-CosmosDb -EndPoint $sDBEndpoint -DBName $sDBName -Collection $sCollection -Key $sReadOnlyKey -Query $sQuery
                if( $aResults.Count ) { Write-Host "$sParam already exists" -ForegroundColor Red; Break }
                
                $sLink = $sParam
                do { $sTitle = Read-Host -Prompt "Enter title" } while( -not $sTitle )
                do { $sTags = Read-Host -Prompt "Enter tags" } while( -not $sTags )
                $sTags = CleanTagString $sTags
                $sJson = @"
{
    `"id`" : `"$([Guid]::NewGuid().ToString())`",
    `"link`": `"$sLink`",
    `"title`": `"$sTitle`",
    `"tags`": `"$sTags`"
}
"@ # This can't be preceded by whitespace
                $aResults = Post-CosmosDb -EndPoint $sDBEndpoint -DBName $sDBName -Collection $sCollection -Key $sReadWriteKey -DocumentBody $sJson -PartitionKey $sLink
            } else 
            { Write-Host "a (Add) command requires a parameter" -ForegroundColor Red }
        } # END Case add

        <# { ( $_ -eq "c" ) -or ( $_ -eq "count" ) } {
            $sQuery = "SELECT VALUE COUNT(1) FROM c"
            $aResults = Count-CosmosDb -EndPoint $sDBEndpoint -DBName $sDBName -Collection $sCollection -Key $sReadOnlyKey -Query $sQuery
            $aResults | Out-Host
        } # END Case acount #>

        { ( $_ -eq "f" ) -or ( $_ -eq "find" ) } {
            $sQuery = "SELECT * FROM " + $sCollection + " c WHERE CONTAINS( c.link, '" + $sParam + "', true )"
            $aResults = Query-CosmosDb -EndPoint $sDBEndpoint -DBName $sDBName -Collection $sCollection -Key $sReadOnlyKey -Query $sQuery
            $aResults | Select-Object -Property title, link, tags | Sort-Object -Property title | Out-Host
            Write-Host $aResults.Count matches... -ForegroundColor Cyan
        } # END Case find

        { ( $_ -eq "q" ) -or ( $_ -eq "quit" ) } {
            $bExit = $true 
        } # END Case quit      

        { ( $_ -eq "u" ) -or ( $_ -eq "update" ) } { 
            if( $sParam ) {
                # Query the database so there are no duplicates
                $sQuery = "SELECT * FROM " + $sCollection + " c WHERE c.link='" + $sParam + "'"
                $aResults = Query-CosmosDb -EndPoint $sDBEndpoint -DBName $sDBName -Collection $sCollection -Key $sReadOnlyKey -Query $sQuery
                if( -not $aResults.Count ) { Write-Host "No record matching $sParam" -ForegroundColor Red; Break }
                if( $aResults.Count -gt 1 ) { Write-Host "Multiple records matching $sParam" -ForegroundColor Red; Break }
                
                $sId = $aResults[ 0 ].id
                $sLink = $sParam
                $sTitle = $aResults[ 0 ].title
                $sInput = Read-Host -Prompt "Enter title [$sTitle]"
                # Set $sLink to what I just entered if anything, otherwise use the previous value
                if( $sInput ) { $sTitle = $sInput }

                $sTags = $aResults[ 0 ].tags
                $sInput = Read-Host -Prompt "Enter tags [$sTags]"
                
                # Set $sTags to what I just entered if anything, otherwise use the previous value
                if( $sInput ) { 

                    # A silly little hack such that if you type +#tags it will add them rather than overwrite
                    $aInput = $sInput.Split( "+", 2 )
                    if( $aInput.Count -eq 2 ) {
                        $sTags = $sTags + $aInput[ 1 ]
                    } # END if( $aTags.Count -eq 2 )
                    else {
                        # A silly little hack such that if you type -#tags it will delete them rather than overwrite
                        $aInput = $sInput.Split( "-", 2 )
                        if( $aInput.Count -eq 2 ) {
                            $sTags = $sTags.replace( $aInput[ 1 ], '' )
                        } # END if( $aTags.Count -eq 2 )  
                        else{ 
                            $sTags = $sInput
                        } # END if( $aTags.Count -eq 2 )  
                    } 

                } # if( $sInput )

                $sTags = CleanTagString $sTags
                $sJson = @"
{
    `"id`" : `"$sId`",
    `"link`": `"$sLink`",
    `"title`": `"$sTitle`",
    `"tags`": `"$sTags`"
}
"@ # This can't be preceded by whitespace
                $aResults = Post-CosmosDb -EndPoint $sDBEndpoint -DBName $sDBName -Collection $sCollection -Key $sReadWriteKey -DocumentBody $sJson -PartitionKey $sLink
            } else 
            { Write-Host "u (Update) command requires a parameter" -ForegroundColor Red }
        } # END Case add

        { ( $_ -eq "v" ) -or ( $_ -eq "verbose" ) } {
            # To support multiple queries we'll start by doing the first query direct to the database.  Then we remove results in-memory.
            $iParamNum = 0
            $aParams = $sParam.Split( '&' )
            # Now lets do some cleanup of our parameters
            foreach( $sParam in $aParams ) {
                $iParamNum++
                # Strips off whitespace and single quotes
                $sParam = $sParam.Trim( ' ' )
                $sParam = $sParam.Trim( '"' )
            
                # If this is our very first parameter, query the database
                if( $iParamNum -eq 1 ) { 
                    $sQuery = "SELECT * FROM " + $sCollection + " c WHERE CONTAINS( c.link, '" + $sParam + "', true ) OR CONTAINS( c.title, '" + $sParam + "', true ) OR CONTAINS( c.tags, '" + $sParam + "', true )"
                    $aResults = Query-CosmosDb -EndPoint $sDBEndpoint -DBName $sDBName -Collection $sCollection -Key $sReadOnlyKey -Query $sQuery | Sort-Object -Property title
                } else {
                    $aResults = $aResults | Where-Object { ( $_.title -CMatch $sParam ) -or ( $_.link -CMatch $sParam ) -or ( $_.tags -CMatch $sParam ) }
                }

            } # END foreach( $sParam in $aParams )

            # Output in verbose format
            Write-Host
            foreach( $oResult in $aResults ) {
                Write-Host "title: " -NoNewline -ForegroundColor Green
                Write-Host $oResult.title
                Write-Host "link:  " -NoNewline -ForegroundColor Gree
                Write-Host $oResult.link
                Write-Host "tags:  " -NoNewline -ForegroundColor Green
                Write-Host $oResult.tags
                Write-Host
            } # END foreach( $oResult in $aResults )

        Write-Host $aResults.Count matches... -ForegroundColor Cyan

        } # END Case verbose

        { $_ -eq "addtag" } {
            Write-Host $aResults.Count
        } # END { $_ -eq "addtag" }

    } # END switch( $sCommand )

} while ( -not $bExit )
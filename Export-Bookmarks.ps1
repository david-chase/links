#-------------------------------------------------------------------
#  Export-Bookmarks
#  Export a CosmosDB database of links
#-------------------------------------------------------------------

$sSharedFunctions = $env:SharedFunctions
Push-Location $sSharedFunctions
. ".\General Functions v1.ps1"
. ".\CosmosDB Functions v2.ps1"
. ".\Tags Functions v1.ps1"
Pop-Location

$sCollection = "Links"

$sQuery = "SELECT * FROM " + $sCollection + " c"
$bookmarks = Query-CosmosDb -EndPoint $sDBEndpoint -DBName $sDBName -Collection $sCollection -Key $sReadOnlyKey -Query $sQuery

foreach( $oBookmark in $bookmarks ) {
    # $arr = $arr[1..($arr.Length-1)]
    $oBookmark.tags = ( $oBookmark.tags.Split( "#" ) )[ 1..( $oBookmark.tags.Split( "#" ).Length - 1 ) ]

    for( $i=0; $i -le ( $oBookmark.tags.Length - 1); $i++ ) { 
        $oBookmark.tags[ $i ] = "#" + $oBookmark.tags[ $i ]
     }
}

$sOutput = $bookmarks | Select-Object -Property title, @{Name='url'; Expression='link'}, tags | Sort-Object -Property title | ConvertTo-Json
$sOutput = '{  "bookmarks": ' + $sOutput + ' }'
$sOutFile = $env:DataFiles + "\bookmarks.json"
$sOutput | Out-File $sOutFile
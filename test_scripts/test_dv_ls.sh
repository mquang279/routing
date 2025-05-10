##
## SYNOPSIS
##    test_dv_ls.ps1
##
## DESCRIPTION
##    CS145 test script for project2.
##    Runs a simulation of a network given each JSON file, then tests whether
##    the routes obtained are correct (given the correct routes in the JSON file)

# parse command line arguments
param(
    [Parameter(Position=0)]
    [ValidateSet("DV", "LS", "BOTH")]
    [string] $ROUTER = "BOTH"
)

$numCorrect = 0
$testNum = 1
$SUCCESS_MESSAGE = "SUCCESS: All Routes correct!"
$FAILURE_MESSAGE = "FAILURE: Not all routes are correct"
$TIMEOUT_PER_TEST = 60
$WORKSPACE = "$env:TEMP\network_test"
$RESULT_FILE = "test_result.txt"

# testing functions

# $1 = DV|LS, $2 = network simulation file, $3 = print separator (no if 0, yes otherwise)
function Test-Router {
    param(
        [string] $routerType,
        [string] $networkFile,
        [int] $printSeparator
    )

    $timeOut = 0
    Write-Host "`n$testNum. Testing $networkFile with $routerType`router"
    $script:testNum++

    # Using Start-Process with -Wait and -TimeoutSec for timeout functionality
    $process = Start-Process -FilePath python -ArgumentList "network.py", $networkFile, $routerType -NoNewWindow -PassThru -RedirectStandardOutput "$WORKSPACE\$RESULT_FILE"
    $process | Wait-Process -Timeout $TIMEOUT_PER_TEST -ErrorAction SilentlyContinue

    if (-not $process.HasExited) {
        $timeOut = 1
        $process | Stop-Process -Force
        Write-Host "TIMED OUT"
    }

    $resultTail = Get-Content -Path "$WORKSPACE\$RESULT_FILE" -Tail 1 -ErrorAction SilentlyContinue
    Remove-Item -Path $RESULT_FILE -Force -ErrorAction SilentlyContinue

    if ($resultTail -eq $SUCCESS_MESSAGE) {
        $script:numCorrect++
    } elseif ($resultTail -ne $FAILURE_MESSAGE -and $timeOut -eq 0) {
        Write-Host "Fatal error: failed to parse test result message"
        Remove-Item -Path $WORKSPACE -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }

    if ($printSeparator -ne 0) {
        Write-Host "________________________________________"
    }
    Write-Host ""
}

# $1 = DV|LS
function Test-AllNetworks {
    param(
        [string] $routerType
    )

    if ($routerType -eq "DV") {
        $testMessage = "Testing Distance Vector routing implementation"
    } else {
        $testMessage = "Testing Link State routing implementation"
    }

    Write-Host "================================================================"
    Write-Host $testMessage
    Write-Host "================================================================"

    $jsonFiles = Get-ChildItem -Path "$PSScriptRoot" -Filter "*.json" -Recurse
    $numJsonFiles = $jsonFiles.Count

    foreach ($jsonFile in $jsonFiles) {
        $numJsonFiles--
        $printSeparator = if ($numJsonFiles -eq 0) { 0 } else { 1 }
        Test-Router $routerType $jsonFile.FullName $printSeparator
    }
}

####################################################
# RUN TESTS
####################################################

# Cleanup on script termination
try {
    Remove-Item -Path $WORKSPACE -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -Path $WORKSPACE -ItemType Directory -Force | Out-Null

    if ($ROUTER -eq "DV") {
        Test-AllNetworks "DV"
    } elseif ($ROUTER -eq "LS") {
        Test-AllNetworks "LS"
    } else {
        Test-AllNetworks "DV"
        Test-AllNetworks "LS"
    }
} finally {
    Remove-Item -Path $WORKSPACE -Recurse -Force -ErrorAction SilentlyContinue
}

#####################################################
# Summary Results
#####################################################

Write-Host "================================================================`n"
Write-Host "TESTS PASSED: $numCorrect/$($testNum - 1)"

﻿
Function Start-TypedDemo {
    [cmdletBinding(DefaultParameterSetName = "Random")]
    [Alias("std")]

    Param(
        [Parameter(Position = 0, Mandatory = $True, HelpMessage = "Enter the name of a text file with your demo commands")]
        [ValidateScript( {Test-Path $_})]
        [string]$File,
        [ValidateScript( {$_ -gt 0})]
        [Parameter(ParameterSetName = "Static")]
        [int]$Pause = 80,
        [Parameter(ParameterSetName = "Random")]
        [ValidateScript( {$_ -gt 0})]
        [int]$RandomMinimum = 50,
        [Parameter(ParameterSetName = "Random")]
        [ValidateScript( {$_ -gt 0})]
        [int]$RandomMaximum = 140,
        [Parameter(ParameterSetName = "Random")]
        [string]$Transcript,
        [switch]$NoExecute,
        [switch]$NewSession
    )

    $colorParmsNotFound = "Red"
    $colorCommandName = "Yellow"
    $colorMandatoryParam = "Yellow"
    $colorParam = "DarkGray"
    $colorFoundAsterisk = "Green"
    $colorNotFoundAsterisk = "Magenta"
    $colParmValue = "DarkCyan"
    $colorEqualSign = "DarkGray"
    $colorVariable = "Green"
    $colorText = "White"
    $colorCommandNameSplat = "Yellow"
    $colorComment = "DarkGreen"

    
    #this is an internal function so I'm not worried about the name
    Function PauseIt {
        [cmdletbinding()]
        Param()
        Write-Verbose "PauseIt"

        #wait for a key press
        $Running = $true
        #keep looping until a key is pressed
        While ($Running) {
            if ($host.ui.RawUi.KeyAvailable) {
                $key = $host.ui.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                if ($key) {
                    $Running = $False  
                    #check the value and if it is q or ESC, then bail out
                    if ($key -match "q|27") {
                        Write-Host "`r"
                        Return "quit"
                    } #if match q|27
                } #if $key
            } #if key available
            Start-Sleep -millisecond 100
        } #end While
    } #PauseIt function

    #abort if running in the ISE
    if ($host.name -match "PowerShell ISE") {
        Write-Warning "This will not work in the ISE. Use the PowerShell console host."
        Return
    }

    Clear-Host

    if ($NewSession) {
        #simulate a new PowerShell session
        #define a set of coordinates
        $z = new-object System.Management.Automation.Host.Coordinates 0, 0
        #year is no longer part of the output
        #$year = '2016'

        $header = @"
Windows PowerShell
Copyright (C) Microsoft Corporation. All rights reserved.
`r
"@

        Write-Host $header
    } #if new session

    #Start a transcript if requested
    $RunningTranscript = $False

    if ($Transcript) {
        Try {
            Start-Transcript -Path $Transcript -ErrorAction Stop | Out-Null
            $RunningTranscript = $True
        }
        Catch {
            Write-Warning "Could not start a transcript. One may already be running."
        }
    }
    #strip out all comments and blank lines
    Write-Verbose "Getting commands from $file"

    $commands = Get-Content -Path $file | Where {$_ -notmatch "#" -AND $_ -match "\w|::|{|}|\(|\)"}

    $count = 0

    #write a prompt using your current prompt function
    Write-Verbose "prompt"
    Write-Host $(prompt) -NoNewline

    $NoMultiLine = $True 
    $StartMulti = $False

    #define a scriptblock to get typing interval
    Write-Verbose "Defining interval scriptblock"
    $interval = {
        if ($pscmdlet.ParameterSetName -eq "Random") {
            #get a random pause interval
            Get-Random -Minimum $RandomMinimum -Maximum $RandomMaximum
        }
        else {
            #use the static pause value
            $Pause
        }
    } #end Interval scriptblock 

    Write-Verbose "Defining PipeCheck Scriptblock"
    #define a scriptblock to pause at a | character in case an explanation is needed
    $PipeCheck = {
        if ($command[$i] -eq "|") {
            If ((PauseIt) -eq "quit") {Return}
        }
    } #end PipeCheck scriptblock

    $PauseCharacterCheck = {
        # Write-Verbose "`$`$Inside: $($command[$i])"      
        If ($command[$i] -eq "þ") {
            If ((PauseIt) -eq "quit") {Return}
        }
    } #end PauseCharacterCheck scriptblock


    Write-Verbose "Processing commands"
    foreach ($command in $commands) {
        #trim off any spaces
        $command = $command.Trim()
  
        $count++
        #pause until a key is pressed which will then process the next command
        if ($NoMultiLine) {
            If ((PauseIt) -eq "quit") {Return}
        }
   
        $firstSpace = $false
        $firstQoute = $false
        $firstPipe = $false

    $color = $colorCommandName

        # Write-Host "Hit foreach"
        #SINGLE LINE COMMAND
        if ($command -ne "::" -AND $NoMultiLine) {
            Write-Verbose "single line command"
            for ($i = 0; $i -lt $command.length; $i++) {
     
                &$PauseCharacterCheck
                
                if ($($command[$i]) -eq "þ") {
                    continue
                }

                switch($($command[$i])) {
                    " " {
                        if(-not ($firstPipe) -and (-not ($firstQoute))){
                            $firstSpace = $true
                            #White
                            $color = $colorText
                        }
                    }
                    "|" {
                        $firstPipe = $true
                        $firstSpace = $false
                        $color = $colorText
                    }
                    {$_ -in "-", "–"} {
                        if($firstSpace) {
                            if(-not ($firstQoute)) {
                                #Dark Grey
                                $color = $colorParam
                            }
                        }
                    }
                    "$"{
                        #Green
                        $color = $colorVariable
                    }
                    {$_ -in '"', "'"} {
                        if(-not ($firstQoute)) {
                            $firstQoute = $true
                        }else {
                            $firstQoute = $false
                        }

                        $color = $colParmValue
                    }
                    default {
                        if($firstPipe) {
                            $color = $colorCommandName
                            $firstPipe = $false
                        }
                    }
                }
                
                $char = $command[$i]

                #write the character
                Write-PSFHostColor -String "<c='$color'>$char</c>" -NoNewLine

                #insert a pause to simulate typing
                Start-sleep -Milliseconds $(&$Interval)
     
                &$PipeCheck
     
            }
    
            #remove the backtick line continuation character if found
            if ($command.contains('`')) {
                $command = $command.Replace('`', "")
            }
    
            #Pause until ready to run the command 
            If ((PauseIt) -eq "quit") {Return}
            Write-host "`r"
            #execute the command unless -NoExecute was specified

            $command = $command -replace "þ", ""

            if (-NOT $NoExecute) {
                Invoke-Expression $command | Out-Default
            }
            else {
                Write-Host $command -ForegroundColor Cyan
            }
        } #IF SINGLE COMMAND
        #START MULTILINE
        #skip the ::
        elseif ($command -eq "::" -AND $NoMultiLine) {
            $NoMultiLine = $False
            $StartMulti = $True
            #define a variable to hold the multiline expression
            [string]$multi = ""
        } #elseif
        #FIRST LINE OF MULTILINE
        elseif ($StartMulti) {
            for ($i = 0; $i -lt $command.length; $i++) {
                &$PauseCharacterCheck
                
                if ($($command[$i]) -eq "þ") {
                    continue
                }

                switch($($command[$i])) {
                    " " {
                        if(-not ($firstPipe) -and (-not ($firstQoute))){
                            $firstSpace = $true
                            #White
                            $color = $colorText
                        }
                    }
                    "|" {
                        $firstPipe = $true
                        $firstSpace = $false
                        $color = $colorText
                    }
                    {$_ -in "-", "–"} {
                        if($firstSpace) {
                            if(-not ($firstQoute)) {
                                #Dark Grey
                                $color = $colorParam
                            }
                        }
                    }
                    "$"{
                        #Green
                        $color = $colorVariable
                    }
                    {$_ -in '"', "'"} {
                        if(-not ($firstQoute)) {
                            $firstQoute = $true
                        }else {
                            $firstQoute = $false
                        }

                        $color = $colParmValue
                    }
                    default {
                        if($firstPipe) {
                            $color = $colorCommandName
                            $firstPipe = $false
                        }
                    }
                }
                
                $char = $command[$i]

                if ($IncludeTypo -AND ($(&$Interval) -ge ($RandomMaximum - 5))) {
                    &$Typo
                }
                else {
                    Write-PSFHostColor -String "<c='$color'>$char</c>" -NoNewLine
                }
                
                start-sleep -Milliseconds $(&$Interval)
                
                #only check for a pipe if we're not at the last character
                #because we're going to pause anyway
                if ($i -lt $command.length - 1) {
                    &$PipeCheck
                }
            } #for
    
            $StartMulti = $False

            #add the command to the multiline variable
            $multi += " $command"
            if ($command -notmatch ',$|{$|}$|\|$|\($|`$') { $multi += " ; " }
            If ((PauseIt) -eq "quit") {Return}
        
        } #elseif
        #END OF MULTILINE
        elseif ($command -eq "::" -AND !$NoMultiLine) {
            $firstSpace = $false
            $color = $colorCommandName
            
            Write-host "`r"
            Write-Host ">> " -NoNewline
            $NoMultiLine = $True
            If ((PauseIt) -eq "quit") {Return}
            #execute the command unless -NoExecute was specified

            Write-Host "`r"


            $multi = $multi -replace "þ", ""
            $multi = $multi -replace '`', ""
            
            if (-NOT $NoExecute) {
            
                Invoke-Expression $multi | Out-Default
            }
            else {
                Write-Host $multi -ForegroundColor Cyan
            }
        }  #elseif end of multiline
        #NESTED PROMPTS
        else {
            $firstSpace = $false
            $color = $colorCommandName

            Write-Host "`r"
            Write-Host ">> " -NoNewLine
            If ((PauseIt) -eq "quit") {Return}
            for ($i = 0; $i -lt $command.length; $i++) {

                &$PauseCharacterCheck
                
                if ($($command[$i]) -eq "þ") {
                    continue
                }

                switch($($command[$i])) {
                    " " {
                        if(-not ($firstPipe) -and (-not ($firstQoute))){
                            $firstSpace = $true
                            #White
                            $color = $colorText
                        }
                    }
                    "|" {
                        $firstPipe = $true
                        $firstSpace = $false
                        $color = $colorText
                    }
                    '`' {
                        $previousColor = $color
                        $color = $colorText
                    }
                    {$_ -in "-", "–"} {
                        if(($firstSpace) -or ($i -eq 0)) {

                        if(-not ($firstQoute)) {
                            #Dark Grey
                            $color = $colorParam
                        }
                    }
                    }
                    "$"{
                        #Green
                        $color = $colorVariable
                    }
                    {$_ -in '"', "'"} {
                        if(-not ($firstQoute)) {
                            $firstQoute = $true
                        }else {
                            $firstQoute = $false
                        }

                        $color = $colParmValue
                    }
                    default {
                        if($firstPipe) {
                            Write-Host "Hit yellow"
                            $color = $colorCommandName
                            $firstPipe = $false
                        }
                    }
                }
                
                $char = $command[$i]

                if ($IncludeTypo -AND ($(&$Interval) -ge ($RandomMaximum - 5)))                { 
                    &$Typo  
                } 
                else { 
                    # Write-Host $command[$i] -NoNewline 
                    Write-PSFHostColor -String "<c='$color'>$char</c>" -NoNewLine

                    if($char -eq '`') {
                        $color = $previousColor
                    }
                }

                Start-Sleep -Milliseconds $(&$Interval)
                &$PipeCheck
            } #for
   
            #remove the backtick line continuation character if found
            # if ($command.contains('`')) {
            #     $command = $command.Replace('`', "")
            # }

            #add the command to the multiline variable and include the line break 
            #character 
            $multi += " $command"
            #  if (!$command.Endswith('{')) { $multi += ";" }  
    
            if ($command -notmatch ',$|{$|\|$|\($|`$') {
                $multi += " ; "
                #$command
            }
      
        } #else nested prompts  
   
        #reset the prompt unless we've just done the last command
        if (($count -lt $commands.count) -AND ($NoMultiLine)) {
            Write-Host $(prompt) -NoNewline 
        } 
    
    } #foreach  
  
    #stop a transcript if it is running
    if ($RunningTranscript) {
        #stop this transcript if it is running
        Stop-Transcript | Out-Null
    }
  
} #function





# Interrogates all csproj files and increments their <Version/> tag
# The version is simply the timestamp
# Get-Date -UFormat "%m%d.%H%M" | Set date

# .Net doesn't like build numbers with too many letters, so we'll go:
# Major - fixed to whatever you want here
# Minor - two-digit year date - this should see us through to year 3000 before we start having potential for conflict - in which case just increase Major build number
# Patch - MMDD. Note that even if our version string here starts with a '0' (ie. all months until October), the zero is respected in the assemblyinfo patch, but it is removed when versioning the packages
# Build - hhmm - we can have a max of FIVE characters here, hence we can't append ss to this. This means if we run this file twice in the same minute we'll create the SAME version number
Get-Date -Format "3.yy.MMdd.HHmm" | Set packageVersion

"Setting package version $packageVersion"
return

Set versionTag "<version>$packageVersion</version>"
Get-Date -Format "yyyy" | Set currentYear
Set copyrightTag "<copyright>Copyright Blackball Software Ltd $currentYear</copyright>"
Set assemblyFileVersionInfoTag "AssemblyFileVersion(""$packageVersion"")"
Set assemblyVersionInfoTag "AssemblyVersion(""$packageVersion"")"
Set netFrameworkProjects @()
Set standardProjects @('Entities')
Set coreProjects @('UI.Web.Core', 'CodeGen', 'ECommerce', 'Contracts', 'Typescript', 'Messaging', 'BackgroundTasks', 'DataAccess', 'Environment', 'Calendars', 'Media', 'Reporting', 'Security', 'Test', 'Messaging.Twilio', 'Messaging.Mailchimp', 'Messaging.Jango', 'API.Kounta', 'API.Xero', 'CMS')


Set msBuild "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MsBuild.exe"
Set forcePublishForAll false
Set pendingProjects @()


Clear-Host


# Patch .Net Framework projects
foreach ($file in $netFrameworkProjects) {""
    ""
    "$file"
    "-------------------------------"

    Set folderName "../Foundation.$file";
    Set nuspecPath "../Foundation.$file/Blackball.Foundation.$file.nuspec"
    Set assemblyInfoPath "../Foundation.$file/properties/AssemblyInfo.cs"

    # When you rebuild a project, the staticwebassets.pack.sentinel file seems to be last modified. Let's restrict to just those files
    # which are actual code (ie. which warrant a deploy)
    # runtimeconfig.json is tagged when you build the app
    Set filter {(($_.name -like "*.png") -or ($_.name -like "*.gif") -or ($_.name -like "*.jpg") -or ($_.name -like "*.svg") -or ($_.name -like "*.json") -or ($_.name -like "*.cs") -or ($_.name -like "*.csproj") -or ($_.name -like "*.ts") -or ($_.name -like "*.js") -or ($_.name -like "*.less") -or ($_.name -like "*.cshtml") -or ($_.name -like "*.xml")) -and ($_.name -notlike "*.runtimeconfig.json")}
    
    Set lastModifiedFile $null
    Get-ChildItem $folderName -Recurse | Where-Object $filter | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Set lastModifiedFile
    if ($lastModifiedFile -eq $null){
        "No modified files were found for $file"
        continue
    }
    
    Set lastModified ($lastModifiedFile).LastWriteTime
    Set lastModifiedFileName ($lastModifiedFile).Name
    Set lastPublishDate $lastModified
    Set lastPublishDateDesc ""
    "The last modified file was $lastModifiedFileName, at $lastModified"

    # We now have the last file that was changed. So, has this occurred after the last publish?
    select-string -Path $assemblyInfoPath -Pattern 'AssemblyInformationalVersion\("(?<date>[^\<]+)"\)' -AllMatches | % { $_.Matches } | % { $_.Groups["date"].Value } | Select-Object -First 1 | Set lastPublishDateDesc

    # If we have a prior date, we load this to our publish timestamp. Otherwise, it will just retain it's prior value (which is defaulted to the last modified date above)
    if ($lastPublishDateDesc -ne ""){
        [DateTime]$lastPublishDateDesc | Set lastPublishDate 
    }else {
        Write-Error "Please create a AssemblyInformationalVersion value at $assemblyInfoPath"
        return
    }
        
    # Break if there are no changes?
    if ($forcePublishForAll -eq $false){
        if ($lastPublishDate -ge $lastModified){
            "$file has not been modified since it was last published ($lastPublishDate)"
            continue;
        }


        "$file has been modified since $lastPublishDate - preparing for packaging"
    }else{
        "Publish forced for $file - preparing for packaging"
    }

    
    # Load the nuspec file, replace the <version/> tag with the new version. Note that the first time this runs, the <version/> tag must not be empty. Subsequently, it will contain the prior version number
    ((Get-Content -path $nuspecPath -Raw) -replace '\<version\>[^\<]+\</version\>', $versionTag) | Set-Content -path $nuspecPath

    # Replace copyright
    ((Get-Content -path $nuspecPath -Raw) -replace '\<copyright\>[^\<]+\</copyright\>', $copyrightTag) | Set-Content -path $nuspecPath

    ## Assembly info patching too!
    ((Get-Content -path $assemblyInfoPath -Raw) -replace 'AssemblyVersion\([^)]+\)', $assemblyVersionInfoTag) | Set-Content -path $assemblyInfoPath
    ((Get-Content -path $assemblyInfoPath -Raw) -replace 'AssemblyFileVersion\([^)]+\)', $assemblyFileVersionInfoTag) | Set-Content -path $assemblyInfoPath

    # Now, mark this file as ready for publish, and we'll continue through our loop
    $projectDetails = [PSCustomObject]@{
        File     = $file
        AssemblyInfoPath = $assemblyInfoPath
        Type = "netframework"
        
    }
    $pendingProjects += $projectDetails;
}


# Patch .Net Standard projects
foreach ($file in $standardProjects) {
    ""
    "$file..."
    "-------------------------------"

    Set folderName "../Foundation.$file";
    Set nuspecPath "../Foundation.$file/Blackball.Foundation.$file.nuspec"
    Set assemblyInfoPath "../Foundation.$file/Blackball.Foundation.$file.csproj"

    # When you rebuild a project, the staticwebassets.pack.sentinel file seems to be last modified. Let's restrict to just those files
    # which are actual code (ie. which warrant a deploy)
    # runtimeconfig.json is tagged when you build the app
    Set filter {(($_.name -like "*.png") -or ($_.name -like "*.gif") -or ($_.name -like "*.jpg") -or ($_.name -like "*.svg") -or ($_.name -like "*.json") -or ($_.name -like "*.cs") -or ($_.name -like "*.csproj") -or ($_.name -like "*.ts") -or ($_.name -like "*.js") -or ($_.name -like "*.less") -or ($_.name -like "*.cshtml") -or ($_.name -like "*.xml")) -and ($_.name -notlike "*.runtimeconfig.json") -and ($_.name -notlike "*.nuget.dgspec.json") -and ($_.FullName -notlike "*\bin\*") -and ($_.FullName -notlike "*\obj\*") -and ($_.FullName -notlike "*\.vscode\*")}

    Set lastModifiedFile $null
    Get-ChildItem $folderName -Recurse | Where-Object $filter | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Set lastModifiedFile
    if ($lastModifiedFile -eq $null){
        "No modified files were found for $file"
        continue
    }

    Set lastModified ($lastModifiedFile).LastWriteTime
    Set lastModifiedFileName ($lastModifiedFile).Name
    Set lastPublishDate $lastModified
    Set lastPublishDateDesc ""
    "The last modified file was $lastModifiedFileName, at $lastModified"


    # We now have the last file that was changed. So, has this occurred after the last publish?
    select-string -Path $assemblyInfoPath -Pattern '\<foundation-last-publish-date\>(?<date>[^\<]+)\</foundation-last-publish-date\>' -AllMatches | % { $_.Matches } | % { $_.Groups["date"].Value } | Select-Object -First 1 | Set lastPublishDateDesc

    # If we have a prior date, we load this to our publish timestamp. Otherwise, it will just retain it's prior value (which is defaulted to the last modified date above)
    if ($lastPublishDateDesc -ne ""){
        [DateTime]$lastPublishDateDesc | Set lastPublishDate 
    }else {
        Write-Error "Please create a <foundation-last-publish-date/> tag at $assemblyInfoPath"
        return
    }
        
    # Break if there are no changes?
    if ($forcePublishForAll -eq $false){
        if ($lastPublishDate -ge $lastModified){
            "$file has not been modified since it was last published ($lastPublishDate)"
            continue;
        }


        "$file has been modified since $lastPublishDate - preparing for packaging"
    }else{
        "Publish forced for $file - preparing for packaging"
    }
    
    
    # Load the nuspec file, replace the <version/> tag with the new version. Note that the first time this runs, the <version/> tag must not be empty. Subsequently, it will contain the prior version number
    ((Get-Content -path $nuspecPath -Raw) -replace '\<version\>[^\<]+\</version\>', $versionTag) | Set-Content -path $nuspecPath

    # Load the csproj file, replace the <version/> tag with the new version. Note that the first time this runs, the <version/> tag must not be empty. Subsequently, it will contain the prior version number
    ((Get-Content -path $assemblyInfoPath -Raw) -replace '\<version\>[^\<]+\</version\>', $versionTag) | Set-Content -path $assemblyInfoPath

    $projectDetails = [PSCustomObject]@{
        File     = $file
        AssemblyInfoPath = $assemblyInfoPath
        Type = "netstandard"
        
    }
    $pendingProjects += $projectDetails;
}



# Patch .Net Core projects
foreach ($file in $coreProjects) {
    ""
    "$file"
    "-------------------------------"

    Set folderName "../Foundation.$file";
    Set assemblyInfoPath "../Foundation.$file/Blackball.Foundation.$file.csproj"

    # When you rebuild a project, the staticwebassets.pack.sentinel file seems to be last modified. Let's restrict to just those files
    # which are actual code (ie. which warrant a deploy)
    # runtimeconfig.json is tagged when you build the app
    Set filter {(($_.name -like "*.png") -or ($_.name -like "*.gif") -or ($_.name -like "*.jpg") -or ($_.name -like "*.targets") -or ($_.name -like "*.svg") -or ($_.name -like "*.json") -or ($_.name -like "*.cs") -or ($_.name -like "*.csproj") -or ($_.name -like "*.ts") -or ($_.name -like "*.js") -or ($_.name -like "*.less") -or ($_.name -like "*.cshtml") -or ($_.name -like "*.xml")) -and ($_.name -notlike "*.runtimeconfig.json") -and ($_.name -notlike "*.nuget.dgspec.json") -and ($_.FullName -notlike "*\bin\*") -and ($_.FullName -notlike "*\obj\*") -and ($_.FullName -notlike "*\.vscode\*")}

    # Have to clear the variable, otherwise PS will remember the value from the prior loop!
    Set lastModifiedFile $null
    Get-ChildItem $folderName -Recurse | Where-Object $filter | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Set lastModifiedFile
    if ($lastModifiedFile -eq $null){
        "No modified files were found for $file"
        continue
    }


    Set lastModified ($lastModifiedFile).LastWriteTime
    Set lastModifiedFileName ($lastModifiedFile).Name
    Set lastPublishDate $lastModified
    Set lastPublishDateDesc ""
    "The last modified file was $lastModifiedFileName, at $lastModified"
    

    # We now have the last file that was changed. So, has this occurred after the last publish?
    select-string -Path $assemblyInfoPath -Pattern '\<foundation-last-publish-date\>(?<date>[^\<]+)\</foundation-last-publish-date\>' -AllMatches | % { $_.Matches } | % { $_.Groups["date"].Value } | Select-Object -First 1 | Set lastPublishDateDesc
    
    # If we have a prior date, we load this to our publish timestamp. Otherwise, it will just retain it's prior value (which is defaulted to the last modified date above)
    if ($lastPublishDateDesc -ne ""){
        [DateTime]$lastPublishDateDesc | Set lastPublishDate 
    }else {
        Write-Error "Please create a <foundation-last-publish-date/> tag at $assemblyInfoPath"
        return
    }
        
    # Break if there are no changes?
    if ($forcePublishForAll -eq $false){
        if ($lastPublishDate -ge $lastModified){
            "$file has not been modified since it was last published ($lastPublishDate)"
            continue;
        }


        "$file has been modified since $lastPublishDate - preparing for packaging"
    }else{
        "Publish forced for $file - preparing for packaging"
    }
    
    
    # Load the csproj file, replace the <version/> tag with the new version. Note that the first time this runs, the <version/> tag must not be empty. Subsequently, it will contain the prior version number
    ((Get-Content -path $assemblyInfoPath -Raw) -replace '\<version\>[^\<]+\</version\>', $versionTag) | Set-Content -path $assemblyInfoPath

     # Now, mark this file as ready for publish, and we'll continue through our loop
    $projectDetails = [PSCustomObject]@{
        File     = $file
        AssemblyInfoPath = $assemblyInfoPath
        Type = "netcore"
        
    }
    $pendingProjects += $projectDetails;
}



# Build the entire project in release mode first - need to build HQ too so that it restores its packages as required
""
"Building..."
"-----------------------"
# Removed the nuget restore because it is an older version of nuget and compiles the wrong target to our project.assets.json file. But I can't get the new
# version of nuget to work and it's not super important for this anyway, so I'll just comment out for now so that I can move on with my life
# cmd /c nuget restore "../HQ/BlackballHQ Web.sln"
cmd /c $msBuild "../Blackball.Foundation.sln" /p:Configuration=Release /m


# Break if the build failed
"Exit code $LastExitCode"
If ($LastExitCode -ne 0){
    "Error in MSBUILD"
    break
}

"Building packages"
foreach ($project in ($pendingProjects)) {
    $file = $project.File

    ""
     "Packaging $file..."
    "-----------------------"
    

    # Switch build type depending on style of project
    If (($project.Type -eq "netframework") -or ($project.Type -eq "netstandard")){
        # Note that since installing VS 2022, we have to add the -MSBuildVersion 16.11 argument to this line. Ref https://developercommunity.visualstudio.com/t/filenotfound-exception-in-msbuildexe-version-1700/1547673
        cmd /c "nuget pack" "../Foundation.$file/Blackball.Foundation.$file.csproj" -BasePath "../Foundation.$file/" -IncludeReferencedProjects -Prop Configuration=Release -MSBuildVersion 16.11
    }ElseIf ($project.Type -eq "netcore"){
        cmd /c "dotnet.exe pack" "../Foundation.$file/Blackball.Foundation.$file.csproj" --output "../NugetFeed/" --no-build --configuration Release # -p:IncludeSymbols=true -p:SymbolPackageFormat=snupkg
    }Else{
        Write-Error "Unrecognized project type, $project.Type"
        return;
    }
    
   
    If ($LastExitCode -ne 0){
        "Error in dotnet pack - publish aborted"
        return
    }

    # Mark the latest modification. We add a few seconds because patching the file
    # also marks it's modification timestamp, but we don't want THAT to count as the project being modified :)
    # I also believe that this update ripples through other files, for example csproj.nuget.dgspec.json is often tagged
    $assemblyInfoPath = $project.AssemblyInfoPath;
    (Get-Date).AddSeconds(5) | Set lastPublishDate 
    Set formattedDate $lastPublishDate.ToString("yyyy-MM-ddTHH:mm:ss")
    
    # Different project types have different ways of flagging modifications
    If (($project.Type -eq "netframework")){
        Set newPublishTag "AssemblyInformationalVersion(`"$formattedDate`")"
        ((Get-Content -path $assemblyInfoPath -Raw) -replace 'AssemblyInformationalVersion\("[^\)]+"\)', $newPublishTag) | Set-Content -path $assemblyInfoPath
    }ElseIf ($project.Type -eq "netcore" -or ($project.Type -eq "netstandard")){
       Set newPublishTag "<foundation-last-publish-date>$formattedDate</foundation-last-publish-date>"
       ((Get-Content -path $assemblyInfoPath -Raw) -replace '\<foundation-last-publish-date\>[^\<]+\</foundation-last-publish-date\>', $newPublishTag) | Set-Content -path $assemblyInfoPath
    }Else{
        Write-Error "Unrecognized project type, $project.Type"
        return;
    }

    
}


# Celebrate
$count = $pendingProjects.Count
""
"Publish complete"
"-----------------------"
"$count packages have been published"
Get-Date
param(
    [Parameter(Mandatory=$true)]
    [string]$NewName
)

# Replace in pubspec.yaml
(Get-Content pubspec.yaml) -replace 'c_template_app', $NewName | Set-Content pubspec.yaml

# Replace in all Dart files
Get-ChildItem -Recurse -Include *.dart | ForEach-Object {
    (Get-Content $_.FullName) -replace 'c_template_app', $NewName | Set-Content $_.FullName
}

Write-Host "App renamed to $NewName. Run 'flutter pub get' to update dependencies."
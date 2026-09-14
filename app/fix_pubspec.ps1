$content = Get-Content 'pubspec.yaml'
$idx = $content.IndexOf('  url_launcher: ^6.2.5')
$content = $content[0..$idx] + '  image_picker: ^1.1.2' + $content[($idx+1)..($content.Length-1)]
Set-Content 'pubspec.yaml' $content

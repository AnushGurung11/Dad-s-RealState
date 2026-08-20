Add-Type -AssemblyName System.Drawing

$accent = [System.Drawing.Color]::FromArgb(255, 15, 118, 110)
$white = [System.Drawing.Color]::FromArgb(255, 246, 246, 246)
$size = 1024

function Draw-Icon([bool]$transparent) {
  $bmp = New-Object System.Drawing.Bitmap($size, $size)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  if ($transparent) {
    $g.Clear([System.Drawing.Color]::Transparent)
  } else {
    $g.Clear($white)
  }

  $brush = New-Object System.Drawing.SolidBrush($accent)
  $whiteBrush = New-Object System.Drawing.SolidBrush($white)
  $clearBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Transparent)
  $pen = New-Object System.Drawing.Pen($accent, 48)
  $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

  # House: roof lines
  $g.DrawLine($pen, 232, 440, 512, 248)
  $g.DrawLine($pen, 512, 248, 792, 440)

  # House: body outline (three sides, open top to let the roof meet)
  $g.DrawLine($pen, 232, 440, 232, 800)
  $g.DrawLine($pen, 792, 440, 792, 800)
  $g.DrawLine($pen, 232, 800, 792, 800)

  # Key: bow (filled ring)
  $ringOuter = New-Object System.Drawing.Rectangle(398, 566, 128, 128)
  $ringInner = New-Object System.Drawing.Rectangle(430, 598, 64, 64)
  $g.FillEllipse($brush, $ringOuter)
  if ($transparent) {
    $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $g.FillEllipse($clearBrush, $ringInner)
    $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
  } else {
    $g.FillEllipse($whiteBrush, $ringInner)
  }

  # Key: shaft
  $g.FillRectangle($brush, 506, 594, 150, 44)

  # Key: teeth
  $g.FillRectangle($brush, 586, 638, 44, 78)
  $g.FillRectangle($brush, 640, 638, 44, 46)

  $g.Dispose()
  return $bmp
}

$dir = "app\assets\icon"
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }

$full = Draw-Icon $false
$full.Save((Join-Path $dir "app_icon.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$fg = Draw-Icon $true
$fg.Save((Join-Path $dir "app_icon_foreground.png"), [System.Drawing.Imaging.ImageFormat]::Png)

$full.Dispose()
$fg.Dispose()
"generated"
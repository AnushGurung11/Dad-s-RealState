Add-Type -AssemblyName System.Drawing

# LUCKY brand icon: a simple finance-app mark — three ascending bars with a
# coin above them, drawn in the single accent color from app_theme.dart.
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

  # Ascending bar chart (symbol only - text does not read at launcher size).
  # Bars share a baseline and grow left to right.
  $barWidth = 130
  $baseline = 820
  $g.FillRectangle($brush, 200, $baseline - 260, $barWidth, 260)   # bar 1
  $g.FillRectangle($brush, 447, $baseline - 420, $barWidth, 420)   # bar 2
  $g.FillRectangle($brush, 694, $baseline - 580, $barWidth, 580)   # bar 3

  # Coin above the tallest bar: filled disc with an accent ring cut by a
  # white inner ring so it reads as a coin, not a dot.
  $coinOuter = New-Object System.Drawing.Rectangle(521, 120, 220, 220)
  $g.FillEllipse($brush, $coinOuter)
  $coinInner = New-Object System.Drawing.Rectangle(561, 160, 140, 140)
  if ($transparent) {
    $hole = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(90, $accent))
    $g.FillEllipse($hole, $coinInner)
    $hole.Dispose()
  } else {
    $g.FillEllipse($whiteBrush, $coinInner)
    $ring = New-Object System.Drawing.Rectangle(591, 190, 80, 80)
    $g.FillEllipse($brush, $ring)
  }

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

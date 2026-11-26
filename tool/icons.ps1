Add-Type -AssemblyName System.Drawing
function Draw-Icon([string]$Path,[int]$Size){
$b=New-Object System.Drawing.Bitmap($Size,$Size);$g=[System.Drawing.Graphics]::FromImage($b);$g.SmoothingMode='AntiAlias';$g.Clear([System.Drawing.Color]::FromArgb(255,111,50));$pen=New-Object System.Drawing.Pen([System.Drawing.Color]::White,($Size*0.065));$pen.StartCap='Round';$pen.EndCap='Round';$g.DrawLine($pen,($Size*.25),($Size*.46),($Size*.5),($Size*.24));$g.DrawLine($pen,($Size*.5),($Size*.24),($Size*.75),($Size*.46));$g.DrawLine($pen,($Size*.31),($Size*.43),($Size*.31),($Size*.72));$g.DrawLine($pen,($Size*.31),($Size*.72),($Size*.69),($Size*.72));$g.DrawLine($pen,($Size*.69),($Size*.72),($Size*.69),($Size*.43));$g.DrawArc($pen,($Size*.42),($Size*.46),($Size*.16),($Size*.14),0,180);$b.Save($Path,[System.Drawing.Imaging.ImageFormat]::Png);$g.Dispose();$pen.Dispose();$b.Dispose();
}
Draw-Icon 'D:/BanDoCu/web/icons/Icon-192.png' 192
Draw-Icon 'D:/BanDoCu/web/icons/Icon-512.png' 512
Draw-Icon 'D:/BanDoCu/web/icons/Icon-maskable-192.png' 192
Draw-Icon 'D:/BanDoCu/web/icons/Icon-maskable-512.png' 512
Draw-Icon 'D:/BanDoCu/web/favicon.png' 32
$densities=@{'mdpi'=48;'hdpi'=72;'xhdpi'=96;'xxhdpi'=144;'xxxhdpi'=192}
foreach($d in $densities.Keys){Draw-Icon "D:/BanDoCu/android/app/src/main/res/mipmap-$d/ic_launcher.png" $densities[$d]}

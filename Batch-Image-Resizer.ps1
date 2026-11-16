# Batch-Image-Resizer.ps1 - v2.0 (Matrix Edition)
# Ridimensiona in batch immagini (JPG/PNG) a 1080p, con CPU o GPU (CUDA).

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:workDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$script:ffmpegPath = Join-Path $script:workDir "ffmpeg.exe"
$script:ffprobePath = Join-Path $script:workDir "ffprobe.exe"
$script:logFile = $null
$script:isWorking = $false

# ============================================
# AUTO-FFMPEG
# ============================================
function Initialize-FFmpeg {
    if ((Test-Path $script:ffmpegPath) -and (Test-Path $script:ffprobePath)) { return $true }
    
    try {
        $sysPath = (Get-Command ffmpeg -ErrorAction SilentlyContinue).Source
        if ($sysPath) { 
            $script:ffmpegPath = $sysPath
            $script:ffprobePath = (Get-Command ffprobe -ErrorAction SilentlyContinue).Source
            return $true 
        }
    } catch {}

    $resp = [System.Windows.Forms.MessageBox]::Show("FFmpeg non trovato. Vuoi scaricarlo automaticamente?", "FFmpeg Missing", [System.Windows.Forms.MessageBoxButtons]::YesNo)
    if ($resp -eq "No") { return $false }

    $zipPath = Join-Path $env:TEMP "ffmpeg_dl.zip"
    $extractPath = Join-Path $env:TEMP "ffmpeg_temp"
    $url = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"

    try {
        Write-Host "Download FFmpeg in corso..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        Get-ChildItem -Path $extractPath -Include "ffmpeg.exe", "ffprobe.exe" -Recurse | ForEach-Object {
            Move-Item $_.FullName $script:workDir -Force
        }
        Remove-Item $zipPath -Force
        Remove-Item $extractPath -Recurse -Force
        return $true
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Errore download: $($_.Exception.Message)", "Errore")
        return $false
    }
}

# ============================================
# LOGGING
# ============================================
function Start-Log {
    param([string]$Folder)
    $ts = Get-Date -Format "yyyyMMdd_HHmmss"
    $script:logFile = Join-Path $Folder "ImgResizer_$ts.log"
    "--- BATCH IMAGE RESIZER LOG ---`r`n" | Set-Content -Path $script:logFile -Encoding UTF8
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "HH:mm:ss"
    $line = "[$ts] [$Level] $Message"
    if ($txtLog) {
        $txtLog.AppendText("$line`r`n")
        $txtLog.SelectionStart = $txtLog.TextLength
        $txtLog.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    }
    if ($script:logFile) {
        [System.IO.File]::AppendAllText($script:logFile, "$line`r`n")
    }
}

# ============================================
# GUI MATRIX
# ============================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "BATCH IMAGE RESIZER - MATRIX CORE"
$form.Size = New-Object System.Drawing.Size(600, 600)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::Black
$form.ForeColor = [System.Drawing.Color]::Lime
$form.Font = New-Object System.Drawing.Font("Consolas", 9)
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$form.MaximizeBox = $false

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "BATCH IMAGE RESIZER TO 1080P"
$lblTitle.Font = New-Object System.Drawing.Font("Consolas", 16, [System.Drawing.FontStyle]::Bold)
$lblTitle.TextAlign = "MiddleCenter"
$lblTitle.Location = New-Object System.Drawing.Point(20, 10)
$lblTitle.Size = New-Object System.Drawing.Size(540, 30)
$form.Controls.Add($lblTitle)

function New-MatrixLabel($text, $x, $y) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text; $l.Location = New-Object System.Drawing.Point($x, $y)
    $l.AutoSize = $true; $l.ForeColor = [System.Drawing.Color]::Lime
    $form.Controls.Add($l)
    return $l
}
function New-MatrixTextBox($x, $y, $w) {
    $t = New-Object System.Windows.Forms.TextBox
    $t.Location = New-Object System.Drawing.Point($x, $y)
    $t.Size = New-Object System.Drawing.Size($w, 25)
    $t.BackColor = [System.Drawing.Color]::FromArgb(10, 10, 10)
    $t.ForeColor = [System.Drawing.Color]::Lime
    $t.BorderStyle = "FixedSingle"
    $form.Controls.Add($t)
    return $t
}

# Cartelle
New-MatrixLabel "Sorgente:" 20 60 | Out-Null
$txtIn = New-MatrixTextBox 20 80 410
$btnIn = New-Object System.Windows.Forms.Button
$btnIn.Text = "Sfoglia"; $btnIn.Location = New-Object System.Drawing.Point(440, 80)
$btnIn.Size = New-Object System.Drawing.Size(120, 25)
$btnIn.FlatStyle = "Flat"; $btnIn.FlatAppearance.BorderColor = "Lime"; $btnIn.BackColor = "Black"; $btnIn.ForeColor = "Lime"
$form.Controls.Add($btnIn)

New-MatrixLabel "Destinazione (lascia vuoto per stessa cartella):" 20 120 | Out-Null
$txtOut = New-MatrixTextBox 20 140 410
$btnOut = New-Object System.Windows.Forms.Button
$btnOut.Text = "Sfoglia"; $btnOut.Location = New-Object System.Drawing.Point(440, 140)
$btnOut.Size = New-Object System.Drawing.Size(120, 25)
$btnOut.FlatStyle = "Flat"; $btnOut.FlatAppearance.BorderColor = "Lime"; $btnOut.BackColor = "Black"; $btnOut.ForeColor = "Lime"
$form.Controls.Add($btnOut)

# Motore
$gbEngine = New-Object System.Windows.Forms.GroupBox
$gbEngine.Text = " MOTORE DI CALCOLO "; $gbEngine.Location = New-Object System.Drawing.Point(20, 180)
$gbEngine.Size = New-Object System.Drawing.Size(540, 60); $gbEngine.ForeColor = "Lime"
$form.Controls.Add($gbEngine)

$rbCpu = New-Object System.Windows.Forms.RadioButton
$rbCpu.Text = "CPU (Multi-thread)"; $rbCpu.Location = New-Object System.Drawing.Point(20, 25); $rbCpu.Checked = $true; $rbCpu.AutoSize = $true; $rbCpu.ForeColor = "Lime"
$gbEngine.Controls.Add($rbCpu)

$rbCuda = New-Object System.Windows.Forms.RadioButton
$rbCuda.Text = "CUDA (GPU)"; $rbCuda.Location = New-Object System.Drawing.Point(300, 25); $rbCuda.AutoSize = $true; $rbCuda.ForeColor = "Lime"
$gbEngine.Controls.Add($rbCuda)

# Status & Progress
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Pronto."
$lblStatus.Location = New-Object System.Drawing.Point(20, 255)
$lblStatus.Size = New-Object System.Drawing.Size(540, 20)
$lblStatus.ForeColor = [System.Drawing.Color]::Yellow
$form.Controls.Add($lblStatus)

$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object System.Drawing.Point(20, 280)
$progress.Size = New-Object System.Drawing.Size(540, 20)
$form.Controls.Add($progress)

# Log
$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Multiline = $true; $txtLog.ScrollBars = "Vertical"; $txtLog.ReadOnly = $true
$txtLog.Location = New-Object System.Drawing.Point(20, 315)
$txtLog.Size = New-Object System.Drawing.Size(540, 160)
$txtLog.BackColor = [System.Drawing.Color]::FromArgb(10, 10, 10)
$txtLog.ForeColor = [System.Drawing.Color]::Lime
$txtLog.BorderStyle = "FixedSingle"
$form.Controls.Add($txtLog)

# Pulsanti
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = ">> AVVIA RESIZE <<"
$btnStart.Location = New-Object System.Drawing.Point(20, 495)
$btnStart.Size = New-Object System.Drawing.Size(300, 45)
$btnStart.FlatStyle = "Flat"; $btnStart.FlatAppearance.BorderColor = "Lime"; $btnStart.BackColor = [System.Drawing.Color]::FromArgb(0, 40, 0); $btnStart.ForeColor = "Lime"
$btnStart.Font = New-Object System.Drawing.Font("Consolas", 12, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($btnStart)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "TERMINATE"
$btnCancel.Location = New-Object System.Drawing.Point(340, 495)
$btnCancel.Size = New-Object System.Drawing.Size(220, 45)
$btnCancel.FlatStyle = "Flat"; $btnCancel.FlatAppearance.BorderColor = "Red"; $btnCancel.BackColor = [System.Drawing.Color]::FromArgb(40, 0, 0); $btnCancel.ForeColor = "Red"
$btnCancel.Font = New-Object System.Drawing.Font("Consolas", 12, [System.Drawing.FontStyle]::Bold)
$btnCancel.Visible = $false
$form.Controls.Add($btnCancel)

# ============================================
# EVENTI
# ============================================
$btnIn.Add_Click({ 
    $f = New-Object System.Windows.Forms.FolderBrowserDialog
    if($f.ShowDialog() -eq "OK"){ $txtIn.Text = $f.SelectedPath }
})

$btnOut.Add_Click({ 
    $f = New-Object System.Windows.Forms.FolderBrowserDialog
    if($f.ShowDialog() -eq "OK"){ $txtOut.Text = $f.SelectedPath }
})

$btnCancel.Add_Click({
    $script:isWorking = $false
    Write-Log "Richiesta annullamento dall'utente..." "WARNING"
    $lblStatus.Text = "Annullamento in corso..."
    $btnCancel.Enabled = $false
})

$btnStart.Add_Click({
    if ([string]::IsNullOrWhiteSpace($txtIn.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Seleziona una cartella sorgente!", "Errore")
        return
    }

    $src = $txtIn.Text
    $dst = if ([string]::IsNullOrWhiteSpace($txtOut.Text)) { $src } else { $txtOut.Text }
    $useCuda = $rbCuda.Checked

    if (-not (Test-Path -LiteralPath $src)) { 
        [System.Windows.Forms.MessageBox]::Show("La cartella sorgente non esiste!", "Errore")
        return 
    }
    if (-not (Test-Path -LiteralPath $dst)) { 
        New-Item -ItemType Directory -Path $dst -Force | Out-Null 
    }

    $script:isWorking = $true
    $btnStart.Enabled = $false
    $btnCancel.Visible = $true
    $btnCancel.Enabled = $true
    $txtLog.Clear()
    Start-Log -Folder $dst
    
    $modeText = if($useCuda) { "CUDA (GPU)" } else { "CPU (Multi-thread)" }
    Write-Log "Avvio resize in modalita: $modeText" "INFO"
    $lblStatus.Text = "Ricerca immagini in corso..."

    # Ricerca file (case-insensitive)
    $validExts = @(".jpg", ".jpeg", ".png")
    $files = Get-ChildItem -LiteralPath $src -File -Recurse | Where-Object { 
        $validExts -contains $_.Extension.ToLower() 
    }
    
    $total = $files.Count
    if ($total -eq 0) { 
        [System.Windows.Forms.MessageBox]::Show("Nessuna immagine trovata!", "Info")
        $btnStart.Enabled = $true; $btnCancel.Visible = $false; $script:isWorking = $false
        return 
    }

    Write-Log "Trovate $total immagini." "INFO"
    $progress.Maximum = $total
    $progress.Value = 0
    $current = 0
    $errors = 0
    $skipped = 0

    foreach ($file in $files) {
        if (-not $script:isWorking) { break }
        
        $current++
        $progress.Value = $current
        $lblStatus.Text = "Elaborazione $current di ${total}: $($file.Name)"
        [System.Windows.Forms.Application]::DoEvents()

        $outFile = Join-Path $dst $file.Name

        # Controlla risoluzione (leggiamo sia W che H)
        $ffProbeArgs = @("-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height", "-of", "csv=s=x:p=0", $file.FullName)
        $resRaw = & $script:ffprobePath @ffProbeArgs 2>&1
        
                if ($resRaw -match '(\d+)x(\d+)') {
            $w = [int]$matches[1]
            $h = [int]$matches[2]
            
            # Se l'immagine è già esattamente 1920x1080, la saltiamo (per non ricodificare inutilmente)
            if ($w -eq 1920 -and $h -eq 1080) {
                Write-Log "Saltata (gia' 1920x1080): $($file.Name)" "WARN"
                $skipped++
            } else {
                # Ridimensiona TUTTE le altre immagini (4K, 720p, verticali, ecc.)
                $vfFilter = "scale=1920:1080:flags=fast_bilinear"
                
                $ffArgs = @("-y")
                $cudaSuccess = $false
                
                if ($useCuda) {
                    $cudaFilter = "scale_cuda=1920:1080,hwdownload,format=nv12,format=yuv420p"
                    $cudaArgs = $ffArgs + @("-hwaccel", "cuda", "-i", $file.FullName, "-vf", $cudaFilter, "-q:v", "1", $outFile)
                    
                    try {
                        & $script:ffmpegPath @cudaArgs 2>&1 | Out-Null
                        if ($LASTEXITCODE -eq 0) { $cudaSuccess = $true }
                    } catch { $cudaSuccess = $false }
                    
                    if (-not $cudaSuccess) {
                        Write-Log "CUDA fallito, provo con CPU: $($file.Name)" "WARN"
                    }
                }
                
                if (-not $cudaSuccess) {
                    $cpuFilterSafe = "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2"
                    $cpuArgs = $ffArgs + @("-i", $file.FullName, "-vf", $cpuFilterSafe, "-q:v", "1", $outFile)
                    
                    & $script:ffmpegPath @cpuArgs 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Log "OK (CPU): $($file.Name) (${w}x${h} -> 1920x1080)" "OK"
                    } else {
                        Write-Log "Errore FFmpeg su: $($file.Name)" "ERROR"
                        $errors++
                    }
                } else {
                    Write-Log "OK (GPU): $($file.Name) (${w}x${h} -> 1920x1080)" "OK"
                }
            }
        } else {
            Write-Log "Impossibile leggere dimensioni di: $($file.Name)" "ERROR"
            $errors++
     
        }
    }

    $lblStatus.Text = "Operazione conclusa. Errori: $errors, Saltate: $skipped"
    Write-Log "Completato. Elaborate: $current, Errori: $errors, Saltate: $skipped" "INFO"
    [System.Windows.Forms.MessageBox]::Show("Operazione conclusa!`n`nElaborate: $current`nSaltate: $skipped`nErrori: $errors", "Fatto")
    
    $script:isWorking = $false
    $btnStart.Enabled = $true
    $btnCancel.Visible = $false
})

# ============================================
# AVVIO
# ============================================
if (-not (Initialize-FFmpeg)) { exit }
$form.ShowDialog() | Out-Null

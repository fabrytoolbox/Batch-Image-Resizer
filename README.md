# 🖼️ Batch Image Resizer

Ridimensiona in batch immagini (JPG/PNG) a 1080p (Full HD) con CPU o GPU.

## ✨ Feature

- ✅ **Resize a 1080p**: Porta tutte le immagini a 1920x1080.
- ✅ **Mantiene le proporzioni**: Aggiunge bande nere (letterbox) se l'immagine non è 16:9 in modalità CPU.
- ✅ **CPU o CUDA**: Scegli il motore di calcolo. Se CUDA fallisce, il tool passa automaticamente alla CPU.
- ✅ **Salta le immagini già grandi**: Se un'immagine è già >= 1080p, viene ignorata.
- ✅ **Auto-download FFmpeg**: Nessuna installazione manuale.
- ✅ **Log su file**: Traccia tutte le operazioni.
- ✅ **Pulsante Terminate**: Ferma il processo in qualsiasi momento.

## 📋 Requisiti

- **Windows 10 / 11**
- **PowerShell 7+** (scarica da https://aka.ms/powershell)
- **FFmpeg** (scaricato automaticamente al primo avvio)

## 🚀 Quick start

```powershell
git clone https://github.com/fabrytoolbox/Batch-Image-Resizer.git
cd Batch-Image-Resizer
Unblock-File .\Batch-Image-Resizer.ps1
.\Batch-Image-Resizer.ps1

Oppure doppio click su avvia.bat.

🎯 Casi d'uso
Preparare immagini per video: Uniforma le dimensioni dei frame prima di creare un video.

Ottimizzare per il web: Ridimensiona foto enormi a un formato standard.

Standardizzare librerie: Porta tutte le immagini di una cartella a 1080p.

⚙️ Come funziona
Seleziona la cartella sorgente (e, se vuoi, quella di destinazione).

Scegli il motore (CPU o CUDA).

Clicca "AVVIA RESIZE".

Nota: per immagini quadrate o non 16:9, la modalità CPU è consigliata perché aggiunge automaticamente le bande nere per mantenere le proporzioni. Se CUDA fallisce, il tool passa automaticamente alla CPU.

🐛 Problemi comuni
"FFmpeg non trovato"
Il tool chiede se scaricarlo. Se fallisce, scaricalo manualmente da https://www.gyan.dev/ffmpeg/builds/ e mettilo nella cartella dello script.

"L'immagine non è cambiata"
Se l'immagine era già >= 1080p, viene saltata. Controlla il log.

📜 Licenza
MIT (vedi LICENSE).

🙏 Crediti
FFmpeg per l'elaborazione immagini

Fabry Toolbox

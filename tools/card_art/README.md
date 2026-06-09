# Card art pipeline

How the 48 official trading-card images get from the mobile-app project into the
Roblox game. All 48 were wired on 2026-06-09; this is the reproducible path for
re-uploads or replacements.

## Where the art comes from
The finished cards are rendered in the **mobile-app** project, not this repo:

```
C:\Users\chris\Squishy-smash\squishy_smash\assets\cards\final_48\NNN_Name.webp
```

`assets/data/cards_manifest.json` there lists all 48 (card number → name → file).
The Roblox friend id is the lower-cased name part of the file (`003_Peach_Mochi`
→ `peach_mochi`), which matches `SquishyDefinitions` ids one-to-one.

## The environment gotcha (read this first)
This machine sits behind a **TLS-inspecting proxy** whose CA only **.NET** trusts —
`curl` and Python fail the handshake (`CERTIFICATE_VERIFY_FAILED`). So every Roblox
API call must go through **Windows PowerShell 5.1** (Invoke-RestMethod / HttpClient).
5.1 has no `Invoke-RestMethod -Form`, so the multipart upload uses
`System.Net.Http.MultipartFormDataContent`.

## Steps
1. **Convert WebP → PNG** (Roblox upload needs PNG; Pillow is installed):
   ```bash
   python -c "import glob,os,tempfile; from PIL import Image; \
   s=r'C:\\Users\\chris\\Squishy-smash\\squishy_smash\\assets\\cards\\final_48'; \
   d=os.path.join(tempfile.gettempdir(),'squishy_cards_png'); os.makedirs(d,exist_ok=True); \
   [Image.open(f).convert('RGBA').save(os.path.join(d,os.path.splitext(os.path.basename(f))[0]+'.png'),'PNG') for f in glob.glob(os.path.join(s,'*.webp'))]"
   ```
2. **Get an Open Cloud key** with **Assets: Write** (create.roblox.com → Credentials),
   IP `0.0.0.0/0`. Store it: `setx ROBLOX_OPEN_CLOUD_KEY "..."`. The upload script
   reads it from `HKCU:\Environment` (harness shells don't inherit a mid-session setx).
3. **Upload** (creator user id 7230402132):
   ```
   powershell -ExecutionPolicy Bypass -File tools\card_art\upload_cards.ps1 -Limit 1   # test one
   powershell -ExecutionPolicy Bypass -File tools\card_art\upload_cards.ps1            # the rest
   ```
   Resumable (skips succeeded), writes `upload_result.json` (friendId → **Decal** id).
4. **Resolve Decal → Image id** in Studio. The Assets API returns a *Decal* id;
   `ImageLabel.Image` needs the underlying *Image* id (decal ids render BLANK). Run
   in Studio (execute_luau) per id: `InsertService:LoadAsset(decalId)` →
   `Decal.Texture` → take the numeric id.
5. **Wire** the Image ids into `src/ReplicatedStorage/Shared/CardImageAssets.lua`
   (friend id → Image id). `SquishyData` merges them over the `REPLACE_ME` defaults.

## Files
- `upload_cards.ps1` — the uploader (PS 5.1 + HttpClient, resumable).
- `upload_result.json` — friendId → Decal id (raw upload record / provenance).
- Final Image ids live in `../../src/ReplicatedStorage/Shared/CardImageAssets.lua`.

## Replacing one card
Re-render it in `final_48`, convert that one PNG, upload it (the script skips
already-wired files, so temporarily remove it from the `$skip` list or upload it
ad-hoc), resolve the Decal, and drop the new Image id into `CardImageAssets.lua`.

# Mesh pipeline — overnight run state (2026-06-09/10)

## ⛔ FROZEN — ACCOUNT MODERATION (read before ANY Roblox API call)
2026-06-10: the batch FBX uploads triggered a FALSE-POSITIVE "Sexual Content"
strike on one auto-extracted UV texture atlas (image asset 73392967314447 —
scrambled pink kawaii texture islands misread by the classifier) → **7-day
account ban**, which is what the "User is moderated" 403s actually were (NOT a
velocity flag — earlier diagnosis corrected). Chris is appealing via
roblox.com/report-appeals (appeal text provided 2026-06-10 morning).
**RULES UNTIL CHRIS CONFIRMS RESOLUTION: make ZERO Roblox API calls — no
probes, no uploads, no LoadAsset. Do not reschedule probe wakeups.**
When cleared: resume uploads ONE asset at a time (a day apart initially),
visually checking each texture first; stop + appeal at the first flag; never
batch again. The 24 already-uploaded Model assets remain Approved in inventory.

Goal: card-faithful 3D meshes for all 48 launch friends via Meshy image-to-3D,
imported to Roblox, wired into SquishyModelFactory. Chris approved free rein.

## Proven pipeline (pilot: soft_dumpling DONE end-to-end)
1. Crop card hero art: `crops/<friendId>.png` (all 48 done; crop box (55,300,1030,925) of 1086x1448).
2. Meshy: POST https://api.meshy.ai/openapi/v1/image-to-3d
   body: { image_url: dataURI-png, enable_pbr:false, should_remesh:true,
   should_texture:true, topology:"triangle", target_polycount:12000,
   symmetry_mode:"auto" } -> {result: taskId}. ~3min, 30 credits/task.
   Poll GET .../image-to-3d/{id} until SUCCEEDED -> model_urls.fbx + thumbnail_url.
   Key: HKCU:\Environment MESHY_API_KEY. Balance started 2500; pilot used 30.
3. Download fbx + thumb -> `output/<friendId>.fbx|_thumb.png`.
4. Roblox upload: Open Cloud assets API, assetType "Model", content-type model/fbx,
   creator userId 7230402132, key HKCU ROBLOX_OPEN_CLOUD_KEY (Assets:Write).
   Poll operations/<opId> -> assetId. Pilot: 136074527893331 (Approved instantly).
   FBX EMBEDS textures -> imported Model contains MeshPart "Mesh_0" + SurfaceAppearance
   with ColorMap + NormalMap populated. No separate texture upload needed.
5. Studio (edit mode, execute_luau): InsertService:LoadAsset(assetId) -> MeshPart,
   rename "Body", scale to ~4 studs max-dim, Anchored, CanCollide=false, stash in
   ServerStorage.MeshBodies.<friendId>. RAW MESH FACES -Z (yaw 180 to face +Z/south).
6. Game wiring (planned): factory checks ServerStorage.MeshBodies first -> clone as
   Body with HatOffset attr (Size.Y/2+0.1) + model attr BakedFace=true; SquishFx
   skips billboard face when BakedFace; applyGolden on mesh = remove SurfaceAppearance
   + gold Color + sparkle. Spawn yaw 180 so faces point toward the southern spawns.

## Facing contract (learned from the Edit-mode preview, 2026-06-10 ~05:15)
Raw Meshy meshes face -Z; with PivotOffset = Angles(0,180), the PIVOT's +Z is
the face and the pivot's -Z is the BACK. So: PivotTo(CFrame.new(pos)) (pads) =
face points +Z/south toward spawns = CORRECT; any lookAt-style placement must
append `* CFrame.Angles(0, math.rad(180), 0)` (WeeklyService visitor already
fixed). workspace.PREVIEW_SoftDumpling is a temporary Edit-mode preview for
Chris — REMOVE before publish (it's inert but sits on the spawn path).

## Files
- manifest.json     friendId -> { taskId, status, fbx, thumb, credits } (generation)
- upload_result.json friendId -> { assetId } (Roblox Model ids)
- meshy_batch.ps1   resumable generation (submit/poll/download, concurrency 4)
- upload_meshes.ps1 resumable Roblox upload

## Status (updated 2026-06-10 ~00:45)
- [x] crops 48/48
- [x] pilot end-to-end (soft_dumpling -> stash OK)
- [x] batch generation 48/48, ZERO failures, 1440 credits used (1060 left)
- [x] thumbnail QC via contact sheet: ALL 48 read as their cards, no rerolls
- [x] Roblox uploads 24/48 (see upload_result.json for ids)
- [x] factory + SquishFx + BuddyService wiring (synced to place via rojo)
- [!] **PAUSED: Roblox account temporarily moderated** ("User is moderated",
      HTTP 403) after the ~24-upload burst. Affects Open Cloud uploads AND
      InsertService:LoadAsset of even OLD approved assets (account-wide).
      Wave-1 assets were all moderationState=Approved at creation — this is a
      velocity flag, not content. Stash holds only soft_dumpling (loaded
      pre-flag).
      PROBE LOG: 01:50 still 403 (both LoadAsset and an Open Cloud metadata
      GET). 04:42 still 403. 05:44 still 403. 06:45 still 403. 06:49 still 403.
      07:47 still 403 (via Open Cloud GET — STUDIO IS NOW CLOSED, so probes use
      PowerShell; the resolve steps will need Studio reopened on Squishy Smash
      when the flag clears). Continuing hourly single-probe
      checks. (If still blocked past ~24h, Chris may need to check
      create.roblox.com or Roblox support for an account notice.)
- [ ] RESUME PLAN: wait >=60 min of zero Roblox asset traffic; probe ONE
      LoadAsset (old decal 78485349787050). When clear:
      1) resolve the 24 uploaded ids into ServerStorage.MeshBodies (chunks of 8;
         recipe in README step 4; skip-if-present),
      2) upload remaining 24 fbx with SLOW spacing (>=30s gaps, batches of 5
         with multi-minute pauses) via upload_meshes.ps1 (it resumes itself),
      3) resolve those too, then playtest + screenshots + docs + push.
- Friends still needing upload: phantom_jelly_beast..wobble_kitty (the 24
  marked FAILED in upload_result.json).

# Cuts Roblox-ready marketing images out of Chris's live-play screenshots:
# crops chosen to exclude every HUD element, then resized to spec
# (thumbnail 1920x1080, icon 512x512).
import os
from PIL import Image

SRC = r"C:\Users\chris\Pictures\Screenshots"
DST = os.path.dirname(os.path.abspath(__file__))

def cut(src_name, box, size, out_name):
    im = Image.open(os.path.join(SRC, src_name))
    w, h = im.size
    l, t, r, b = box
    # clamp to image bounds just in case
    l, t = max(0, l), max(0, t)
    r, b = min(w, r), min(h, b)
    out = im.crop((l, t, r, b)).resize(size, Image.LANCZOS)
    out.save(os.path.join(DST, out_name), "PNG")
    print(f"{out_name}: from {src_name} {im.size} crop={l},{t},{r},{b} -> {size}")

shot = "Screenshot 2026-06-10 110023.png"  # avatar + Neon Dessert Blob close-up
# 16:9 thumbnail anchored LOW so the blob + avatar are fully in frame:
# clears pills (x>285), banner (y>78), People list (y>110), bottom buttons (y<860)
cut(shot, (320, 115, 1636, 855), (1920, 1080), "thumb_blob_buddy_1920x1080.png")
# icon A: the Neon Dessert Blob as the star
cut(shot, (305, 375, 785, 855), (512, 512), "icon_blob_512.png")
# icon B: avatar face + blob together
cut(shot, (430, 170, 1110, 850), (512, 512), "icon_blob_buddy_512.png")

shot2 = "Screenshot 2026-06-10 110145.png"  # avatar centered, galaxy dumpling right
cut(shot2, (310, 175, 1581, 890), (1920, 1080), "thumb_avatar_path_1920x1080.png")

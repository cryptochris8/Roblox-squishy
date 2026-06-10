# Crops the hero-art window out of each final_48 trading card so Meshy's
# image-to-3D sees the character, not the card frame/title/stat panel.
# Card layout is a fixed template (1086x1448): art window ~ (55,300)-(1030,925).
import glob
import os
from PIL import Image

SRC = r"C:\Users\chris\Squishy-smash\squishy_smash\assets\cards\final_48"
DST = os.path.join(os.path.dirname(os.path.abspath(__file__)), "crops")
CROP = (55, 300, 1030, 925)

os.makedirs(DST, exist_ok=True)
count = 0
for f in sorted(glob.glob(os.path.join(SRC, "*.webp"))):
    name = os.path.splitext(os.path.basename(f))[0]  # e.g. 001_Soft_Dumpling
    friend_id = "_".join(name.split("_")[1:]).lower()  # -> soft_dumpling
    out = os.path.join(DST, friend_id + ".png")
    im = Image.open(f).convert("RGB")
    im.crop(CROP).save(out, "PNG")
    count += 1
print(f"cropped {count} cards -> {DST}")

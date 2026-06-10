# Tiles every output/<friendId>_thumb.png into one labeled contact sheet, so the
# whole batch can be quality-checked in a single look.
import glob
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "work", "contact_sheet.png")
THUMBS = sorted(glob.glob(os.path.join(HERE, "output", "*_thumb.png")))

CELL = 192
COLS = 8
rows = (len(THUMBS) + COLS - 1) // COLS
sheet = Image.new("RGB", (COLS * CELL, rows * (CELL + 18)), (24, 24, 28))
draw = ImageDraw.Draw(sheet)

for i, path in enumerate(THUMBS):
    name = os.path.basename(path).replace("_thumb.png", "")
    im = Image.open(path).convert("RGB")
    im.thumbnail((CELL, CELL))
    x = (i % COLS) * CELL
    y = (i // COLS) * (CELL + 18)
    sheet.paste(im, (x + (CELL - im.width) // 2, y))
    draw.text((x + 4, y + CELL + 3), name[:26], fill=(230, 225, 235))

os.makedirs(os.path.dirname(OUT), exist_ok=True)
sheet.save(OUT)
print(f"{len(THUMBS)} thumbs -> {OUT}")

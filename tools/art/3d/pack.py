"""Pack rendered frames into sprite sheets + a preview GIF."""
import json, os, sys
from PIL import Image
d = sys.argv[1]
meta = json.load(open(os.path.join(d, "sprites.json")))
W, H = meta["frame_size"]
fr = os.path.join(d, "_frames")
for anim, a in meta["anims"].items():
    n = a["frames"]
    sheet = Image.new("RGBA", (W * n, H * 8), (0, 0, 0, 0))
    for di in range(8):
        for i in range(n):
            sheet.alpha_composite(Image.open(os.path.join(fr, "%s_%d_%02d.png" % (anim, di, i))), (i * W, di * H))
    sheet.save(os.path.join(d, anim + ".png"), optimize=True)
    print(anim, sheet.size)

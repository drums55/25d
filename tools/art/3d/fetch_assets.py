"""Download the CC0 assets soi_pbr.py builds with (not in the repo):
Poly Haven textures (jpg 1k: diff / nor_gl / rough) + a sky HDRI + glTF models,
and the KayKit City Builder Bits kit from itch.io (same free-download flow as
fetch_quaternius.py). Run: python3 fetch_assets.py <ASSETS dir>  -> <dir>/ph, <dir>/kits
"""
import http.cookiejar, json, os, re, shutil, sys, urllib.request, zipfile

TEXTURES = ["painted_plaster_wall", "concrete_floor_painted", "concrete_floor_02", "asphalt_02", "wood_planks_dirt",
            "corrugated_iron_02", "red_brick_03", "rusty_metal_02", "weathered_planks"]
HDRI = "kloppenheim_06_puresky"
MODELS = ["plastic_monobloc_chair_01", "potted_plant_01", "potted_plant_02", "planter_pot_clay", "old_tyre",
          "modular_electricity_poles", "street_lamp_01", "wooden_crate_01", "plastic_crate_01", "cardboard_box_01",
          "wooden_bucket_01", "wicker_basket_01", "trashbag", "utility_box_01", "metal_stool_01", "island_tree_01",
          "jacaranda_tree", "outdoor_table_chair_set_01", "modular_chainlink_fence"]
KITS = {"kaylousberg/city-builder-bits": "city-builder-bits"}
UA = {"User-Agent": "Mozilla/5.0"}   # dl.polyhaven.org answers 403 to the default python agent


def get(url, path):
    if os.path.exists(path):
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120) as src, open(path, "wb") as f:
        shutil.copyfileobj(src, f)


def polyhaven(out):
    ph = os.path.join(out, "ph")
    for t in TEXTURES:
        for m in ("diff", "nor_gl", "rough"):
            get("https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/%s/%s_%s_1k.jpg" % (t, t, m), os.path.join(ph, "%s_%s.jpg" % (t, m)))
        print("texture", t)
    get("https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/1k/%s_1k.hdr" % HDRI, os.path.join(ph, "sky.hdr"))
    for n in MODELS:
        files = json.load(urllib.request.urlopen(urllib.request.Request("https://api.polyhaven.com/files/" + n, headers=UA), timeout=60))
        g = files["gltf"]["1k"]["gltf"]
        d = os.path.join(ph, "models", n)
        get(g["url"], os.path.join(d, n + ".gltf"))
        for rel, info in g.get("include", {}).items():
            get(info["url"], os.path.join(d, rel))
        print("model", n)


def itch(out):
    op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
    op.addheaders = [("User-Agent", "Mozilla/5.0")]
    for spec, sub in KITS.items():
        owner, slug = spec.split("/")
        base = "https://%s.itch.io/%s" % (owner, slug)
        html = op.open(base, timeout=60).read().decode()
        csrf = re.search(r'name="csrf_token" value="([^"]+)"', html).group(1)
        req = urllib.request.Request(base + "/download_url", data=("csrf_token=" + csrf).encode(), method="POST")
        page = op.open(json.loads(op.open(req).read())["url"]).read().decode()
        csrf2 = re.search(r'name="csrf_token" value="([^"]+)"', page).group(1)
        for uid in re.findall(r'data-upload_id="(\d+)"', page):
            req = urllib.request.Request("%s/file/%s?source=game_download" % (base, uid), data=("csrf_token=" + csrf2).encode(), method="POST")
            d = os.path.join(out, "kits", sub)
            os.makedirs(d, exist_ok=True)
            path = os.path.join(d, uid + ".zip")
            with op.open(json.loads(op.open(req).read())["url"]) as src, open(path, "wb") as f:
                shutil.copyfileobj(src, f)
            zipfile.ZipFile(path).extractall(os.path.join(d, uid))
            os.remove(path)
            print("kit", spec, uid)


if __name__ == "__main__":
    polyhaven(sys.argv[1])
    itch(sys.argv[1])

"""Download + unpack the two free Quaternius CC0 kits char_q.py needs (itch.io
"download for free" flow). Run: python3 fetch_quaternius.py <QDIR>
then: QDIR=<QDIR> python3 char_q.py <name> <out_dir>  (needs `pip install bpy==4.2.0`)."""
import http.cookiejar
import json
import os
import re
import shutil
import sys
import urllib.request
import zipfile

KITS = {"universal-base-characters": "ubc", "modular-character-outfits-fantasy": "."}


def main(qdir):
    os.makedirs(qdir, exist_ok=True)
    op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
    op.addheaders = [("User-Agent", "Mozilla/5.0")]
    for game, sub in KITS.items():
        base = "https://quaternius.itch.io/" + game
        csrf = re.search(r'name="csrf_token" value="([^"]+)"', op.open(base).read().decode()).group(1)
        req = urllib.request.Request(base + "/download_url", data=("csrf_token=" + csrf).encode(), method="POST")
        page = op.open(json.loads(op.open(req).read())["url"]).read().decode()
        csrf2 = re.search(r'name="csrf_token" value="([^"]+)"', page).group(1)
        for uid, name in zip(re.findall(r'data-upload_id="(\d+)"', page), re.findall(r'class="name" title="([^"]+)"', page)):
            if "Standard" not in name:
                continue
            req = urllib.request.Request("%s/file/%s?source=game_download" % (base, uid),
                                         data=("csrf_token=" + csrf2).encode(), method="POST")
            path = os.path.join(qdir, name)
            with op.open(json.loads(op.open(req).read())["url"]) as src, open(path, "wb") as f:
                shutil.copyfileobj(src, f)
            zipfile.ZipFile(path).extractall(os.path.join(qdir, sub))
            os.remove(path)
            print("got", name)


if __name__ == "__main__":
    main(sys.argv[1])

"""Inspect the actual Moon archive; never publish it from this script."""
import pathlib, subprocess, zipfile, json
root=pathlib.Path(__file__).resolve().parent.parent
subprocess.run(['moon','package'],cwd=root,check=True)
path=max((root/'_build/publish').glob('*.zip'),key=lambda p:p.stat().st_mtime)
with zipfile.ZipFile(path) as z:
    names=z.namelist()
    for n in names:
        parts=pathlib.PurePosixPath(n).parts
        assert not any(x in {'work','artifacts','deliverables','.git','credentials.json','dist','engine.js'} for x in parts),n
    for suffix in ['LICENSE','planner.mbt','docs/SEMANTICS.md','examples/commute.json']:
        assert any(n.endswith(suffix) for n in names),suffix
print(json.dumps({'archive':path.name,'files':len(names),'clean':True,'published':False}))

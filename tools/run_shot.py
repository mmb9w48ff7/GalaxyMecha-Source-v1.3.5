import sys, os, json, glob
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE); import luart
from nvg_render import render
os.chdir(os.path.dirname(HERE)); st = luart.new()
code = '''package.path="scripts/?.lua;scripts/?/init.lua;"..package.path
local f,err=loadfile("tools/shot_ui.lua"); if not f then print("LOADERR",err) return end
local ok,e=xpcall(f, debug.traceback); if not ok then print("RUNTIME ERROR:\\n"..tostring(e)) end'''
print(luart.dostring(st, code))
os.makedirs('/home/claude/work/ui', exist_ok=True)
for p in sorted(glob.glob('/tmp/ui_*.json')):
    name = os.path.basename(p)[3:-5]
    if len(sys.argv) > 1 and name not in sys.argv[1:]: continue
    cmds = json.load(open(p)); render(cmds).convert('RGB').save('/home/claude/work/ui/%s.png' % name); print('渲染', name, len(cmds))

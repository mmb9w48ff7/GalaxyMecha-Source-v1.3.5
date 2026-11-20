import sys,os,json,subprocess; sys.path.insert(0,'/home/claude/work/port'); import luart
cfg=sys.argv[1] if len(sys.argv)>1 else '{}'
r=subprocess.run(['node','/home/claude/work/xpile/tests/battle_parity.js',cfg],capture_output=True,text=True,cwd='/home/claude/work/xpile/tests'); print(r.stdout.strip()[-300:], r.stderr.strip()[-300:])
os.chdir('/home/claude/work/GalaxyMecha'); os.environ['PCFG']=cfg
if os.path.exists('/tmp/lua_battle.json'): os.remove('/tmp/lua_battle.json')
st=luart.new()
ok,e=luart.dostring(st,'''local f,err=loadfile("/home/claude/work/xpile/tests/battle_parity.lua"); if not f then print("LOADERR",err) return end
local ok,e=xpcall(f, debug.traceback); if not ok then print("RUNTIME ERROR:\\n"..tostring(e)) end''')
if not os.path.exists('/tmp/lua_battle.json'): sys.exit('Lua 没有产出结果')
a=json.load(open('/tmp/js_battle.json')); b=json.load(open('/tmp/lua_battle.json'))
names=['帧','x','y','z','耐久','击破','等级','经验','敌人数','弹体数','信用点','镜头yaw','敌人']
first=None
for ra,rb in zip(a,b):
    diffs=[(names[i],ra[i],rb[i]) for i in range(1,len(ra)-1) if abs((ra[i] or 0)-(rb[i] or 0))>(0.02 if i in (1,2,3,4,11) else 0)]
    if diffs and first is None: first=(ra[0],diffs)
print('对比行数',len(a),len(b),' 完全一致' if first is None else ' 第一次出现差异：帧 %d %s'%first)
if first is not None:
    k=[i for i,(ra,rb) in enumerate(zip(a,b)) if ra[0]==first[0]][0]
    for ra,rb in list(zip(a,b))[max(0,k-1):k+1]: print('JS ',ra[0],ra[-1]); print('Lua',rb[0],rb[-1])

import sys,os,json; sys.path.insert(0,'/home/claude/work/port'); import luart
os.chdir('/home/claude/work/GalaxyMecha'); st=luart.new()
if os.path.exists('/tmp/lua_data.json'): os.remove('/tmp/lua_data.json')
ok,e=luart.dostring(st,'''local f,err=loadfile("/home/claude/work/xpile/tests/data_parity.lua"); if not f then print("LOADERR",err) return end
local ok,e=xpcall(f, debug.traceback); if not ok then print("RUNTIME ERROR:\\n"..tostring(e)) end''')
if os.path.exists('/tmp/lua_data.json'):
    a=json.load(open('/tmp/js_data.json')); b=json.load(open('/tmp/lua_data.json'))
    allok=True
    for k in a:
        if k in ('mechMul','evo'): continue
        same = json.dumps(a[k],sort_keys=True)==json.dumps(b.get(k),sort_keys=True); allok&=same
        print(k, '一致' if same else '不一致')
        if not same:
            if k=='cards':
                bad=[(x,y) for x,y in zip(a[k],b[k]) if x!=y][:3]; print('  示例差异',bad, len(a[k]),len(b[k]))
            else: print('  JS:',a[k]); print('  Lua:',b.get(k))
    print('全部一致' if allok else '有差异')

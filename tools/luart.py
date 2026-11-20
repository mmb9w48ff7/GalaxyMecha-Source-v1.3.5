# 用 ctypes 调用系统自带的 liblua5.4.so，做一个最小的 Lua 5.4 运行器（语法检查 + 运行测试脚本）
import ctypes, sys, os
L = ctypes.CDLL('liblua5.4.so.0')
L.luaL_newstate.restype = ctypes.c_void_p
for fn, args, res in [('luaL_openlibs',[ctypes.c_void_p],None),('luaL_loadfilex',[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_char_p],ctypes.c_int),
    ('luaL_loadstring',[ctypes.c_void_p,ctypes.c_char_p],ctypes.c_int),('lua_pcallk',[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_void_p,ctypes.c_void_p],ctypes.c_int),
    ('lua_tolstring',[ctypes.c_void_p,ctypes.c_int,ctypes.c_void_p],ctypes.c_char_p),('lua_settop',[ctypes.c_void_p,ctypes.c_int],None),('lua_gettop',[ctypes.c_void_p],ctypes.c_int)]:
    f=getattr(L,fn); f.argtypes=args; f.restype=res
def new():
    st=L.luaL_newstate(); L.luaL_openlibs(st); return st
def err(st): 
    s=L.lua_tolstring(st,-1,None); return s.decode('utf-8','replace') if s else '?'
def dostring(st, code):
    if L.luaL_loadstring(st, code.encode('utf-8'))!=0: return False, err(st)
    if L.lua_pcallk(st,0,0,0,None,None)!=0: return False, err(st)
    return True, ''
def dofile(st, path):
    if L.luaL_loadfilex(st, path.encode('utf-8'), None)!=0: return False, err(st)
    if L.lua_pcallk(st,0,0,0,None,None)!=0: return False, err(st)
    return True, ''
def check(path):
    st=new(); r=L.luaL_loadfilex(st, path.encode('utf-8'), None); return (r==0, '' if r==0 else err(st))
if __name__=='__main__':
    cmd=sys.argv[1]
    if cmd=='check':
        bad=0
        for p in sys.argv[2:]:
            ok,e=check(p)
            if not ok: bad+=1; print('SYNTAX ERROR', p, e)
        print('checked', len(sys.argv[2:]), 'files,', bad, 'errors'); sys.exit(1 if bad else 0)
    elif cmd=='run':
        st=new(); root=os.path.dirname(os.path.abspath(sys.argv[2]))
        paths=sys.argv[3] if len(sys.argv)>3 else root
        ok,e=dostring(st, 'package.path = "%s/?.lua;%s/?/init.lua;" .. package.path' % (paths, paths)); 
        ok,e=dofile(st, sys.argv[2]); print('OK' if ok else 'ERROR: '+e); sys.exit(0 if ok else 1)

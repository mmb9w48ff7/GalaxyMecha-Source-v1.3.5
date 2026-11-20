import sys, os
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE); import luart
os.chdir(os.path.dirname(HERE))
import subprocess
def gen(*a): return subprocess.run(['python3', 'tools/gen_codes.py', '--no-ledger'] + list(a), capture_output=True, text=True).stdout.strip().split('\n')[-1]
if os.path.exists('tools/author_secret.txt'):
    os.environ['TEST_DID'] = 'ZXCV1234'
    os.environ['TEST_CREDITS'] = gen('credits', '5000', '--id', '900001'); os.environ['TEST_CREDITS2'] = gen('credits', '5000', '--id', '900002'); os.environ['TEST_CREDITS3'] = gen('credits', '5000', '--id', '900003')
    os.environ['TEST_SRC'] = gen('src', '100', '--id', '900010'); os.environ['TEST_EXPIRED'] = gen('src', '10', '--id', '900011', '--expire', '2026-01-02')
    os.environ['TEST_DEV'] = gen('dev', 'ZXCV-1234'); os.environ['TEST_DEV_OTHER'] = gen('dev', 'AAAA-1111')
st = luart.new()
code = '''package.path="scripts/?.lua;scripts/?/init.lua;"..package.path
local f,err=loadfile("tools/mock_xp_test.lua"); if not f then print("LOADERR",err) return end
local ok,e=xpcall(f, debug.traceback); if not ok then print("RUNTIME ERROR:\\n"..tostring(e)) end'''
print(luart.dostring(st, code))

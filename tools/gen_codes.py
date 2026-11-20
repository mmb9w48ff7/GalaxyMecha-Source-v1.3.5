# -*- coding: utf-8 -*-
"""作者专用：生成兑换码 / 开发者解锁码（HMAC-SHA256 签名，游戏里只做校验）。
私钥保存在 tools/author_secret.txt —— 只有你有；不要把它和 tools/ 目录发给别人，也不会进入 UrhoX 发布包。

  python3 tools/gen_codes.py credits 5000                  生成 1 个“信用点 +5000”兑换码
  python3 tools/gen_codes.py src 100 --count 20            生成 20 个“星源 +100”兑换码（每个码每台设备只能用 1 次）
  python3 tools/gen_codes.py src 300 --expire 2026-12-31   带有效期
  python3 tools/gen_codes.py dev ABCD-1234                 为某台设备（设备码）生成开发者解锁码（只对这台设备有效）
  python3 tools/gen_codes.py list                          查看已发出的码
  python3 tools/gen_codes.py revoke 17                     作废编号 17（需要重新生成发布包才生效）
  python3 tools/gen_codes.py setkey                        更换私钥（旧码全部失效，必须重新生成发布包）
"""
import sys, os, json, hmac, hashlib, secrets, datetime, argparse
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEYFILE = os.path.join(ROOT, 'tools', 'author_secret.txt'); LEDGER = os.path.join(ROOT, 'tools', 'code_ledger.json')
LUAKEY = os.path.join(ROOT, 'scripts', 'cosmic', 'RedeemKey.lua'); JSKEY = os.path.join(ROOT, 'preview', 'src', 'cosmic_redeem_key.js')
ALPHA = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'; EPOCH = datetime.date(2026, 1, 1)
KINDS = {'credits': 1, 'src': 2, 'dev': 15}
def b32enc(b):
    bits = int.from_bytes(b, 'big'); n = len(b) * 8; pad = (5 - n % 5) % 5; bits <<= pad; n += pad
    return ''.join(ALPHA[(bits >> (n - 5 * (i + 1))) & 31] for i in range(n // 5))
def load_key():
    if not os.path.exists(KEYFILE): return None
    return bytes.fromhex(open(KEYFILE).read().strip())
def ledger():
    if os.path.exists(LEDGER): return json.load(open(LEDGER, encoding='utf-8'))
    return {'next': 1, 'issued': [], 'revoked': []}
def save_ledger(L): json.dump(L, open(LEDGER, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
def write_lua(key, L):
    A = secrets.token_bytes(len(key)); Bk = bytes(x ^ y for x, y in zip(key, A))
    rev = ', '.join('[%d] = true' % i for i in L['revoked'])
    open(JSKEY, 'w', encoding='utf-8').write('/* 由 tools/gen_codes.py 自动生成：校验兑换码与开发者码用的密钥（混淆存放）与作废列表（与 UrhoX 版 RedeemKey.lua 同一把密钥） */\nwindow.__RK = { A: [%s], B: [%s], revoked: {%s} };\n' % (', '.join(map(str, A)), ', '.join(map(str, Bk)), ', '.join('%d: true' % i for i in L['revoked'])))
    open(LUAKEY, 'w', encoding='utf-8').write('-- 由 tools/gen_codes.py 自动生成（setkey / revoke 会重写）：校验兑换码与开发者码用的密钥（混淆存放）与作废列表。\n'
        'local A = {%s}\nlocal B = {%s}\nlocal M = { revoked = {%s} }\nfunction M.key() local t = {}; for i = 1, #A do t[i] = string.char(A[i] ~ B[i]) end return table.concat(t) end\nreturn M\n'
        % (', '.join(map(str, A)), ', '.join(map(str, Bk)), rev))
def make_code(kind, amount, cid, exp_days, extra=b''):
    payload = bytes([kind]) + amount.to_bytes(3, 'big') + cid.to_bytes(3, 'big') + exp_days.to_bytes(2, 'big')
    sig = hmac.new(load_key(), payload + extra, hashlib.sha256).digest()[:6]
    s = b32enc(payload + sig); return '-'.join(s[i:i + 6] for i in range(0, 24, 6))
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('cmd'); ap.add_argument('arg', nargs='?'); ap.add_argument('--count', type=int, default=1); ap.add_argument('--expire'); ap.add_argument('--note', default=''); ap.add_argument('--id', type=int); ap.add_argument('--no-ledger', action='store_true')
    a = ap.parse_args(); L = ledger()
    if a.cmd == 'setkey':
        if load_key() and input('更换私钥会让所有旧码失效，确认？(yes) ') != 'yes': return
        key = secrets.token_bytes(32); open(KEYFILE, 'w').write(key.hex() + '\n'); L = {'next': 1, 'issued': [], 'revoked': []}; save_ledger(L); write_lua(key, L)
        print('已生成新私钥：', KEYFILE, '；已重写', LUAKEY, '。请重新生成发布包。'); return
    if not load_key(): sys.exit('还没有私钥：先运行  python3 tools/gen_codes.py setkey')
    if a.cmd == 'syncjs': write_lua(load_key(), L); print('已用当前私钥重写 RedeemKey.lua 与 cosmic_redeem_key.js'); return
    if a.cmd == 'list':
        for r in L['issued']: print(r['id'], r['kind'], r['amount'], r.get('expire') or '-', r['code'], r.get('note', ''), '【已作废】' if r['id'] in L['revoked'] else '')
        return
    if a.cmd == 'revoke':
        i = int(a.arg); L['revoked'].append(i) if i not in L['revoked'] else None; save_ledger(L); write_lua(load_key(), L); print('已作废', i, '；请重新生成发布包让作废生效'); return
    if a.cmd == 'dev':
        did = (a.arg or '').upper().replace('-', '').replace('O', '0').replace('I', '1').replace('L', '1')
        if len(did) != 8: sys.exit('设备码应为 8 位（游戏里 设置 -> 点版本号 7 次 -> 开发者 页面显示）')
        cid = int.from_bytes(hashlib.sha256(did.encode()).digest()[:3], 'big')
        print('开发者解锁码（仅对设备 %s 有效）：' % did); print(make_code(15, 0, cid, 0, did.encode())); return
    if a.cmd not in ('credits', 'src'): sys.exit(__doc__)
    amount = int(a.arg); exp = 0
    if a.expire: exp = (datetime.date.fromisoformat(a.expire) - EPOCH).days
    if not 0 < amount < 1 << 24: sys.exit('数额范围 1 ~ 16777215')
    for _ in range(a.count):
        if a.id is not None: cid = a.id + _
        else: cid = L['next']; L['next'] += 1
        code = make_code(KINDS[a.cmd], amount, cid, exp)
        if not a.no_ledger: L['issued'].append({'id': cid, 'kind': a.cmd, 'amount': amount, 'expire': a.expire, 'code': code, 'note': a.note, 'at': datetime.datetime.now().isoformat(timespec='seconds')})
        print(code)
    if not a.no_ledger: save_ledger(L)
if __name__ == '__main__': main()

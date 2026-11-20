#!/usr/bin/env node
// transpile.js —— 把网页版的 ES5 风格 JavaScript（cosmic_run.js / cosmic_data.js）逐节点转换成 Lua。
// 约定：
//  * 每个函数的第一个参数是 _this（调用时 f(nil, a, b)，方法调用 o:m(a, b)），与运行库 jsrt/JS.lua 一致
//  * 数组是 0 起始的 Lua 表，带 length 字段和 AMT 元表；对象是普通表；undefined / null 都是 nil
//  * 模块（IIFE）作用域内的变量与函数存放在表 S 里（避开 Lua 200 个局部变量上限）；函数内部的 var 变成 Lua 局部变量
// 用法：node transpile.js 输入.js 输出.lua --name=模块名 [--skip=函数1,函数2]  （skip 的函数由手写覆盖，不生成）
const acorn = require('acorn');
const fs = require('fs');
const [, , inFile, outFile, ...opts] = process.argv;
const OPT = {}; opts.forEach(o => { const m = o.match(/^--(\w+)=(.*)$/); if (m) OPT[m[1]] = m[2]; });
const SKIP = new Set((OPT.skip || '').split(',').filter(Boolean));
const SKIPLINES = (OPT.skiplines || '').split(';').filter(Boolean).map(r => r.split('-').map(Number));
const inSkipLines = n => SKIPLINES.some(r => n.loc.start.line >= r[0] && n.loc.start.line <= r[1]);
const src = fs.readFileSync(inFile, 'utf8');
const ast = acorn.parse(src, { ecmaVersion: 2020, locations: true });

const LUA_KW = new Set(['and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'goto', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then', 'true', 'until', 'while']);
const RESERVED = new Set(['S', 'JS', 'T', 'OR', 'AND', 'S2', 'LEN', 'MOD', 'typeof', 'smt', 'AMT', 'HOST', 'G', 'tonum', 'bor', 'band', 'bxor', 'shl', 'shr', 'ushr', 'self', 'string', 'table', 'math', 'type', 'pairs', 'ipairs', 'tostring', 'tonumber', 'select', 'error', 'pcall', 'next', 'require', 'os', 'io', 'print', 'rawget', 'rawset', 'setmetatable', 'getmetatable', 'unpack', 'Math_abs', 'Math_min', 'Math_max', 'Math_floor', 'Math_ceil', 'Math_round', 'Math_sqrt', 'Math_sin', 'Math_cos', 'Math_tan', 'Math_asin', 'Math_atan2', 'Math_exp', 'Math_hypot', 'Math_pow', 'Math_random', 'Math_PI', '_this', '_t', '_r', '_a', '_b', '_o', '_k']);
const MATH_FN = new Set(['abs', 'min', 'max', 'floor', 'ceil', 'round', 'sqrt', 'sin', 'cos', 'tan', 'asin', 'atan2', 'exp', 'hypot', 'pow', 'random']);
const HOST_GLOBALS = new Set(['window', 'document', 'localStorage', 'navigator', 'console', 'setTimeout', 'setInterval', 'clearTimeout', 'requestAnimationFrame', 'performance']);
const JS_GLOBALS = new Set(['Math', 'JSON', 'Object', 'Array', 'String', 'Number', 'Date', 'Boolean', 'parseInt', 'parseFloat', 'isNaN', 'isFinite', 'Infinity', 'NaN', 'Uint8Array', 'Float32Array', 'Error']);
const isIdent = s => /^[A-Za-z_][A-Za-z0-9_]*$/.test(s) && !LUA_KW.has(s);
const warn = [];
function fail(node, msg) { throw new Error(msg + ' @ line ' + (node.loc ? node.loc.start.line : '?')); }

// ------------------------------------------------------------ 作用域
class Scope {
  constructor(parent, isModule) { this.parent = parent; this.isModule = !!isModule; this.names = new Map(); this.big = false; }
  declare(n) { if (!this.names.has(n)) this.names.set(n, this.isModule ? null : luaName(n)); }
  lookup(n) { for (let s = this; s; s = s.parent) if (s.names.has(n)) return { scope: s, lua: s.names.get(n) }; return null; }
}
function luaName(n) { return (LUA_KW.has(n) || RESERVED.has(n) || /^_/.test(n) && n.length < 3) ? n + '_' : n; }
// 收集一个函数体里声明的 var / function / catch 参数（不进入内层函数）
function collect(node, scope) {
  if (!node || typeof node !== 'object') return;
  if (Array.isArray(node)) { node.forEach(n => collect(n, scope)); return; }
  switch (node.type) {
    case 'VariableDeclaration': node.declarations.forEach(d => { scope.declare(d.id.name); collect(d.init, scope); }); return;
    case 'FunctionDeclaration': scope.declare(node.id.name); return;
    case 'FunctionExpression': return;
    case 'CatchClause': scope.declare(node.param.name); collect(node.body, scope); return;
  }
  for (const k in node) { if (k === 'loc') continue; const v = node[k]; if (v && typeof v === 'object') collect(v, scope); }
}

// ------------------------------------------------------------ 代码生成
let tmpN = 0, labelN = 0;
function pure(n) {   // 没有副作用、可以重复求值的表达式
  if (!n) return true;
  switch (n.type) {
    case 'Identifier': case 'Literal': case 'ThisExpression': return true;
    case 'MemberExpression': return pure(n.object) && (!n.computed || pure(n.property));
    case 'UnaryExpression': return n.operator !== 'delete' && pure(n.argument);
    case 'BinaryExpression': case 'LogicalExpression': return pure(n.left) && pure(n.right);
    case 'ConditionalExpression': return pure(n.test) && pure(n.consequent) && pure(n.alternate);
    case 'ArrayExpression': return n.elements.every(pure);
    case 'ObjectExpression': return n.properties.every(p => pure(p.value));
    default: return false;
  }
}
const isStr = n => n.type === 'Literal' && typeof n.value === 'string';
class Gen {
  constructor() { this.out = []; this.scope = null; this.fnDepth = 0; this.loopStack = []; this.tryStack = []; }
  // ---- 标识符
  ident(name, node) {
    const r = this.scope.lookup(name);
    if (r) return r.scope.isModule ? (isIdent(name) ? 'S.' + name : 'S["' + name + '"]') : r.lua;
    if (name === 'undefined') return 'nil';
    if (name === 'NaN') return '(0/0)';
    if (name === 'Infinity') return 'math.huge';
    if (HOST_GLOBALS.has(name)) return 'HOST.' + name;
    if (JS_GLOBALS.has(name)) return 'G.' + name;
    warn.push('未知全局标识符 ' + name + ' @ line ' + (node && node.loc ? node.loc.start.line : '?'));
    return 'HOST.' + name;
  }
  prop(name) { return isIdent(name) ? '.' + name : '["' + name + '"]'; }
  str(s) { return JSON.stringify(s).replace(/\u2028/g, '\\u2028').replace(/\u2029/g, '\\u2029').replace(/\\u([0-9a-fA-F]{4})/g, (m, h) => { const c = parseInt(h, 16); return c < 128 ? String.fromCharCode(c) : String.fromCodePoint(c); }); }
  // ---- 条件（返回 Lua 布尔表达式）
  cond(n) {
    switch (n.type) {
      case 'Literal': return n.value === null ? 'false' : (n.value === true ? 'true' : n.value === false ? 'false' : (n.value === 0 || n.value === '' ? 'false' : 'true'));
      case 'UnaryExpression': if (n.operator === '!') return '(not ' + this.cond(n.argument) + ')'; break;
      case 'LogicalExpression': return '(' + this.cond(n.left) + (n.operator === '&&' ? ' and ' : ' or ') + this.cond(n.right) + ')';
      case 'BinaryExpression': if (['==', '===', '!=', '!==', '<', '>', '<=', '>=', 'in', 'instanceof'].includes(n.operator)) return this.expr(n).c; break;
      case 'ObjectExpression': case 'ArrayExpression': case 'FunctionExpression': return 'true';
    }
    const e = this.expr(n);
    if (e.t === 'bool') return e.c;
    if (e.t === 'obj') return '(' + e.c + ' ~= nil)';
    return 'T(' + e.c + ')';
  }
  // ---- 表达式：返回 { c: 代码, t: 'num'|'str'|'bool'|'obj'|'fn'|'any' }
  expr(n) {
    const R = (c, t) => ({ c, t: t || 'any' });
    switch (n.type) {
      case 'Literal':
        if (n.regex) fail(n, '不支持正则');
        if (n.value === null) return R('nil');
        if (typeof n.value === 'string') return R(this.str(n.value), 'str');
        if (typeof n.value === 'boolean') return R(String(n.value), 'bool');
        { let r = n.raw; if (/^0[xX]/.test(r)) return R(r, 'num'); const v = n.value; if (Number.isInteger(v) && Math.abs(v) < 1e15) return R(String(v), 'num'); return R(String(v).replace(/e\+/, 'e'), 'num'); }
      case 'Identifier': return R(this.ident(n.name, n));
      case 'ThisExpression': return R('_this');
      case 'MemberExpression': return this.member(n);
      case 'CallExpression': return this.call(n);
      case 'NewExpression': return this.newx(n);
      case 'ArrayExpression': {
        const el = n.elements.map(e => this.expr(e).c); const len = el.length;
        if (!len) return R('smt({length=0},AMT)', 'obj');
        return R('smt({[0]=' + el.join(',') + ',length=' + len + '},AMT)', 'obj');
      }
      case 'ObjectExpression': {
        if (!n.properties.length) return R('JS.dict()', 'obj');
        const parts = n.properties.map(p => {
          if (p.kind !== 'init') fail(p, '不支持 getter/setter');
          const k = p.key.type === 'Identifier' ? p.key.name : (typeof p.key.value === 'number' ? p.key.value : String(p.key.value));
          const key = typeof k === 'number' ? '[' + k + ']' : (isIdent(k) ? k : '[' + this.str(k) + ']');
          return key + '=' + this.expr(p.value).c;
        });
        if (this.scope.isModule && this.orderedObj) return R('JS.odict({' + parts.join(',') + '},{' + n.properties.map(p => this.str(p.key.type === 'Identifier' ? p.key.name : String(p.key.value))).join(',') + '})', 'obj');
        return R('{' + parts.join(',') + '}', 'obj');
      }
      case 'FunctionExpression': return R(this.func(n), 'fn');
      case 'UnaryExpression': return this.unary(n);
      case 'UpdateExpression': return this.update(n, true);
      case 'BinaryExpression': return this.binary(n);
      case 'LogicalExpression': return this.logical(n);
      case 'ConditionalExpression': {
        const a = this.expr(n.consequent), b = this.expr(n.alternate), c = this.cond(n.test);
        if (['num', 'str', 'obj', 'fn'].includes(a.t)) return R('(' + c + ' and ' + a.c + ' or ' + b.c + ')', a.t === b.t ? a.t : 'any');
        return R('(function() if ' + c + ' then return ' + a.c + ' else return ' + b.c + ' end end)()');
      }
      case 'AssignmentExpression': return this.assignExpr(n);
      case 'SequenceExpression': {
        const last = n.expressions[n.expressions.length - 1]; const pre = n.expressions.slice(0, -1).map(e => this.exprStmt(e)).join(' ');
        return R('(function() ' + pre + ' return ' + this.expr(last).c + ' end)()');
      }
    }
    fail(n, '不支持的表达式类型 ' + n.type);
  }
  member(n) {
    const o = this.expr(n.object);
    const oc = (n.object.type === 'Identifier' || n.object.type === 'MemberExpression' || n.object.type === 'CallExpression' || n.object.type === 'ThisExpression') ? o.c : '(' + o.c + ')';
    if (!n.computed) {
      const name = n.property.name;
      if (name === 'length') return { c: 'LEN(' + o.c + ')', t: 'num' };
      if (n.object.type === 'Identifier' && n.object.name === 'Math' && !this.scope.lookup('Math')) {
        if (name === 'PI') return { c: 'Math_PI', t: 'num' };
        if (name === 'E') return { c: '2.718281828459045', t: 'num' };
      }
      return { c: oc + this.prop(name), t: 'any' };
    }
    return { c: oc + '[' + this.expr(n.property).c + ']', t: 'any' };
  }
  args(list) { return list.map(a => this.expr(a).c); }
  call(n) {
    const cal = n.callee;
    if (cal.type === 'MemberExpression') {
      if (!cal.computed && cal.object.type === 'Identifier' && cal.object.name === 'Math' && !this.scope.lookup('Math') && MATH_FN.has(cal.property.name))
        return { c: 'Math_' + cal.property.name + '(' + this.args(n.arguments).join(',') + ')', t: 'num' };
      const o = this.expr(cal.object); const oc = (/^[A-Za-z_]/.test(o.c) && /^[A-Za-z0-9_.\[\]"]+$/.test(o.c.replace(/\([^()]*\)/g, ''))) || o.c.startsWith('(') ? o.c : '(' + o.c + ')';
      const a = this.args(n.arguments);
      if (!cal.computed) {
        const name = cal.property.name; let t = 'any';
        if (['join', 'toFixed', 'toString', 'toLocaleString', 'substr', 'trim', 'replace'].includes(name)) t = 'str';
        if (name === 'indexOf' || name === 'charCodeAt') t = 'num';
        if (isIdent(name)) return { c: (o.t === 'str' && !/^\(/.test(oc) ? '(' + oc + ')' : oc) + ':' + name + '(' + a.join(',') + ')', t };
        return { c: 'JS.callk(' + o.c + ',' + this.str(name) + (a.length ? ',' + a.join(',') : '') + ')', t };
      }
      return { c: 'JS.callk(' + o.c + ',' + this.expr(cal.property).c + (a.length ? ',' + a.join(',') : '') + ')', t: 'any' };
    }
    // 直接调用 String(x) / Number(x) / Boolean(x)
    const f = this.expr(cal); const a = this.args(n.arguments);
    const t = cal.type === 'Identifier' && !this.scope.lookup(cal.name) ? ({ String: 'str', Number: 'num', parseInt: 'num', parseFloat: 'num', Boolean: 'bool', isNaN: 'bool' })[cal.name] || 'any' : 'any';
    const fc = (cal.type === 'FunctionExpression') ? '(' + f.c + ')' : f.c;
    return { c: fc + '(nil' + (a.length ? ',' + a.join(',') : '') + ')', t };
  }
  newx(n) {
    const cal = n.callee; const a = this.args(n.arguments);
    if (cal.type === 'Identifier' && !this.scope.lookup(cal.name)) return { c: 'G.new_' + cal.name + '(' + a.join(',') + ')', t: 'obj' };
    fail(n, '不支持的 new 表达式');
  }
  unary(n) {
    const op = n.operator;
    if (op === '!') return { c: this.cond(n), t: 'bool' };
    if (op === '-') { const a = this.expr(n.argument); return { c: '(-' + a.c + ')', t: 'num' }; }
    if (op === '+') { const a = this.expr(n.argument); return a.t === 'num' ? a : { c: 'tonum(' + a.c + ')', t: 'num' }; }
    if (op === 'typeof') return { c: 'typeof(' + this.expr(n.argument).c + ')', t: 'str' };
    if (op === 'void') return { c: 'nil', t: 'any' };
    if (op === '~') return { c: 'bxor(' + this.expr(n.argument).c + ',-1)', t: 'num' };
    if (op === 'delete') { fail(n, '不支持 delete'); }
    fail(n, '不支持的一元运算 ' + op);
  }
  binary(n) {
    const op = n.operator;
    if (op === 'in') return { c: '(' + this.expr(n.right).c + '[' + this.expr(n.left).c + '] ~= nil)', t: 'bool' };
    if (op === 'instanceof') fail(n, '不支持 instanceof');
    const l = this.expr(n.left), r = this.expr(n.right);
    const cmpNil = (n.right.type === 'Literal' && n.right.value === null) || (n.right.type === 'Identifier' && n.right.name === 'undefined');
    switch (op) {
      case '===': case '==': return { c: '(' + l.c + ' == ' + (cmpNil ? 'nil' : r.c) + ')', t: 'bool' };
      case '!==': case '!=': return { c: '(' + l.c + ' ~= ' + (cmpNil ? 'nil' : r.c) + ')', t: 'bool' };
      case '<': case '>': case '<=': case '>=': return { c: '(' + l.c + ' ' + op + ' ' + r.c + ')', t: 'bool' };
      case '+':
        if (l.t === 'str' || r.t === 'str') {
          const piece = e => e.t === 'str' ? e.c : 'S2(' + e.c + ')';
          // 展开连续的字符串连接
          return { c: '(' + piece(l) + ' .. ' + piece(r) + ')', t: 'str' };
        }
        return { c: '(' + l.c + ' + ' + r.c + ')', t: l.t === 'num' && r.t === 'num' ? 'num' : 'any' };
      case '-': case '*': return { c: '(' + l.c + ' ' + op + ' ' + r.c + ')', t: 'num' };
      case '/': return { c: '(' + l.c + ' / ' + r.c + ')', t: 'num' };
      case '%': return { c: 'MOD(' + l.c + ',' + r.c + ')', t: 'num' };
      case '|': return { c: 'bor(' + l.c + ',' + r.c + ')', t: 'num' };
      case '&': return { c: 'band(' + l.c + ',' + r.c + ')', t: 'num' };
      case '^': return { c: 'bxor(' + l.c + ',' + r.c + ')', t: 'num' };
      case '<<': return { c: 'shl(' + l.c + ',' + r.c + ')', t: 'num' };
      case '>>': return { c: 'shr(' + l.c + ',' + r.c + ')', t: 'num' };
      case '>>>': return { c: 'ushr(' + l.c + ',' + r.c + ')', t: 'num' };
    }
    fail(n, '不支持的二元运算 ' + op);
  }
  logical(n) {
    const l = this.expr(n.left), r = this.expr(n.right);
    const lb = l.t === 'bool', pl = pure(n.left);
    if (n.operator === '||') {
      if (lb) return { c: '(' + l.c + ' or ' + r.c + ')', t: r.t === 'bool' ? 'bool' : 'any' };
      if (pl) return { c: '(T(' + l.c + ') and ' + l.c + ' or ' + r.c + ')', t: l.t === r.t ? l.t : 'any' };
      return { c: '(function() local _t = ' + l.c + '; if T(_t) then return _t end; return ' + r.c + ' end)()', t: 'any' };
    }
    if (lb) return { c: '(' + l.c + ' and ' + r.c + ')', t: r.t === 'bool' ? 'bool' : 'any' };
    if (r.t === 'bool') return { c: '(T(' + l.c + ') and ' + r.c + ')', t: 'bool' };
    if (pl && ['num', 'str', 'obj', 'fn'].includes(r.t)) return { c: '(T(' + l.c + ') and ' + r.c + ' or ' + l.c + ')', t: 'any' };
    return { c: '(function() local _t = ' + l.c + '; if not T(_t) then return _t end; return ' + r.c + ' end)()', t: 'any' };
  }
  // 赋值目标：返回 {get, set(valueCode) -> 语句, setup}
  target(t) {
    if (t.type === 'Identifier') { const c = this.ident(t.name, t); return { get: c, set: v => c + ' = ' + v, pre: '' }; }
    if (t.type === 'MemberExpression') {
      if (!t.computed && t.property.name === 'length') { const o = this.expr(t.object).c; return { get: 'LEN(' + o + ')', set: v => 'JS.setlen(' + o + ',' + v + ')', pre: '' }; }
      if (pure(t)) { const m = this.member(t).c; return { get: m, set: v => m + ' = ' + v, pre: '' }; }
      const tn = '_o' + (++tmpN), tk = '_k' + tmpN; const o = this.expr(t.object).c; const k = t.computed ? this.expr(t.property).c : this.str(t.property.name);
      return { get: tn + '[' + tk + ']', set: v => tn + '[' + tk + '] = ' + v, pre: 'local ' + tn + ', ' + tk + ' = ' + o + ', ' + k + '; ' };
    }
    fail(t, '不支持的赋值目标 ' + t.type);
  }
  compound(op, getc, rhsNode) {
    const r = this.expr(rhsNode);
    const bin = { '+=': '+', '-=': '-', '*=': '*', '/=': '/', '%=': '%', '|=': '|', '&=': '&', '^=': '^', '<<=': '<<', '>>=': '>>', '>>>=': '>>>' }[op];
    const fake = { type: 'BinaryExpression', operator: bin, left: { type: '_raw', c: getc }, right: rhsNode, loc: rhsNode.loc };
    return this.expr(fake).c;
  }
  rawGet(n) { return n; }
  assignExpr(n) {
    const t = this.target(n.left);
    const val = n.operator === '=' ? this.expr(n.right).c : this.compound(n.operator, t.get, n.right);
    return { c: '(function() ' + t.pre + t.set(val) + '; return ' + t.get + ' end)()', t: 'any' };
  }
  update(n, asExpr) {
    const t = this.target(n.argument); const d = n.operator === '++' ? ' + 1' : ' - 1';
    if (!asExpr) return { c: t.pre + t.set(t.get + d) };
    if (n.prefix) return { c: '(function() ' + t.pre + t.set(t.get + d) + '; return ' + t.get + ' end)()', t: 'num' };
    return { c: '(function() ' + t.pre + 'local _r = ' + t.get + '; ' + t.set(t.get + d) + '; return _r end)()', t: 'num' };
  }
  // ---- 函数
  func(n, declName) {
    const sc = new Scope(this.scope, false); const saved = this.scope, savedLoop = this.loopStack, savedTry = this.tryStack; this.loopStack = []; this.tryStack = []; this.scope = sc;
    const params = n.params.map(p => { if (p.type !== 'Identifier') fail(p, '不支持的参数形式'); sc.declare(p.name); return sc.names.get(p.name); });
    const paramSet = new Set(n.params.map(p => p.name));
    collect(n.body.body, sc);
    const locals = [...sc.names.keys()].filter(k => !paramSet.has(k));
    let big = locals.length > 150; const L = [];
    if (big) { warn.push('函数局部变量过多，已改用表 V：' + (declName || '(匿名)') + ' @ line ' + n.loc.start.line); locals.forEach(k => sc.names.set(k, 'V.' + (isIdent(k) ? k : '["' + k + '"]'))); L.push('local V = {};'); }
    else if (locals.length) L.push('local ' + locals.map(k => sc.names.get(k)).join(', ') + ';');
    // 内层函数声明先于其他语句（提升）
    const hoist = n.body.body.filter(s => s.type === 'FunctionDeclaration'); const rest = n.body.body.filter(s => s.type !== 'FunctionDeclaration');
    hoist.forEach(f => { L.push(this.ident(f.id.name, f) + ' = ' + this.func(f, f.id.name) + ';'); });
    rest.forEach(s => L.push(this.stmt(s)));
    this.scope = saved; this.loopStack = savedLoop; this.tryStack = savedTry;
    return 'function(_this' + (params.length ? ', ' + params.join(', ') : '') + ')\n' + L.join('\n') + '\nend';
  }
  // ---- 语句
  exprStmt(e) {
    if (e.type === 'AssignmentExpression') {
      const t = this.target(e.left); const val = e.operator === '=' ? this.expr(e.right).c : this.compound(e.operator, t.get, e.right);
      return (t.pre ? 'do ' + t.pre + t.set(val) + ' end' : t.set(val)) + ';';
    }
    if (e.type === 'UpdateExpression') { const u = this.update(e, false).c; return (/^local /.test(u) ? 'do ' + u + ' end' : u) + ';'; }
    if (e.type === 'SequenceExpression') return e.expressions.map(x => this.exprStmt(x)).join(' ');
    if (e.type === 'CallExpression') { const c = this.call(e).c; return /^\(/.test(c) ? ';' + c + ';' : c + ';'; }
    if (e.type === 'UnaryExpression' && e.operator === 'void') return '';
    if (e.type === 'Literal') return '';
    if (e.type === 'LogicalExpression' && (e.operator === '&&' || e.operator === '||')) {   // a && b() 形式的语句
      return 'if ' + (e.operator === '&&' ? this.cond(e.left) : '(not ' + this.cond(e.left) + ')') + ' then ' + this.exprStmt(e.right) + ' end;';
    }
    if (e.type === 'ConditionalExpression') return 'if ' + this.cond(e.test) + ' then ' + this.exprStmt(e.consequent) + ' else ' + this.exprStmt(e.alternate) + ' end;';
    return 'local _ = ' + this.expr(e).c + ';';
  }
  block(b) { return (b.type === 'BlockStatement' ? b.body : [b]).map(s => this.stmt(s)).join('\n'); }
  stmt(n) {
    switch (n.type) {
      case 'ExpressionStatement': return this.exprStmt(n.expression);
      case 'VariableDeclaration': return n.declarations.filter(d => d.init).map(d => {
        const tgt = this.ident(d.id.name, d); this.orderedObj = this.scope.isModule && d.init.type === 'ObjectExpression'; const v = this.expr(d.init).c; this.orderedObj = false; return tgt + ' = ' + v + ';'; }).join(' ');
      case 'FunctionDeclaration': return this.ident(n.id.name, n) + ' = ' + this.func(n, n.id.name) + ';';
      case 'ReturnStatement': { const v = n.argument ? this.expr(n.argument).c : 'nil'; if (this.tryStack.length) return 'do return "R", ' + v + ' end;'; return 'do return' + (n.argument ? ' ' + v : '') + ' end;'; }
      case 'IfStatement': {
        let s = 'if ' + this.cond(n.test) + ' then\n' + this.block(n.consequent);
        let alt = n.alternate;
        while (alt && alt.type === 'IfStatement') { s += '\nelseif ' + this.cond(alt.test) + ' then\n' + this.block(alt.consequent); alt = alt.alternate; }
        if (alt) s += '\nelse\n' + this.block(alt);
        return s + '\nend;';
      }
      case 'BlockStatement': return 'do\n' + this.block(n) + '\nend;';
      case 'ForStatement': {
        const id = ++labelN; this.loopStack.push({ id, hasContinue: false });
        const init = n.init ? (n.init.type === 'VariableDeclaration' ? this.stmt(n.init) : this.exprStmt(n.init)) : '';
        const test = n.test ? this.cond(n.test) : 'true'; const body = this.block(n.body); const upd = n.update ? this.exprStmt(n.update) : '';
        const lp = this.loopStack.pop();
        return 'do ' + init + '\nwhile ' + test + ' do\ndo\n' + body + '\nend\n' + (lp.hasContinue ? '::cont' + id + '::\n' : '') + upd + '\nend end;';
      }
      case 'WhileStatement': {
        const id = ++labelN; this.loopStack.push({ id, hasContinue: false });
        const body = this.block(n.body); const lp = this.loopStack.pop();
        return 'while ' + this.cond(n.test) + ' do\ndo\n' + body + '\nend\n' + (lp.hasContinue ? '::cont' + id + '::\n' : '') + 'end;';
      }
      case 'ForInStatement': {
        const id = ++labelN; this.loopStack.push({ id, hasContinue: false });
        const v = n.left.type === 'VariableDeclaration' ? this.ident(n.left.declarations[0].id.name, n) : this.ident(n.left.name, n);
        const body = this.block(n.body); const lp = this.loopStack.pop();
        return 'for _, _k in ipairs(JS.keys(' + this.expr(n.right).c + ')) do ' + v + ' = _k\ndo\n' + body + '\nend\n' + (lp.hasContinue ? '::cont' + id + '::\n' : '') + 'end;';
      }
      case 'BreakStatement': { const tr = this.tryStack[this.tryStack.length - 1]; if (tr && tr.loopDepth === this.loopStack.length) { tr.usesB = true; return 'do return "B" end;'; } return 'break;'; }
      case 'ContinueStatement': { const lp = this.loopStack[this.loopStack.length - 1]; lp.hasContinue = true; const tr = this.tryStack[this.tryStack.length - 1]; if (tr && tr.loopDepth === this.loopStack.length) { tr.usesC = lp.id; return 'do return "C" end;'; } return 'goto cont' + lp.id + ';'; }
      case 'TryStatement': {
        if (!n.handler || n.finalizer) fail(n, '只支持 try/catch');
        const p = this.ident(n.handler.param.name, n);
        const tr = { loopDepth: this.loopStack.length, usesB: false, usesC: null }; this.tryStack.push(tr);
        const body = this.block(n.block); this.tryStack.pop();
        let after = '';
        const outerTry = this.tryStack.length > 0;
        after += 'elseif _f == "R" then ' + (outerTry ? 'do return "R", _v end' : 'do return _v end') + ' ';
        if (tr.usesB) after += 'elseif _f == "B" then break ';
        if (tr.usesC) { const lp = this.loopStack[this.loopStack.length - 1]; lp.hasContinue = true; after += 'elseif _f == "C" then goto cont' + lp.id + ' '; }
        return 'do local _ok, _f, _v = pcall(function()\n' + body + '\nend)\nif not _ok then ' + p + ' = _f\n' + this.block(n.handler.body) + '\n' + after + 'end end;';
      }
      case 'EmptyStatement': return '';
      case 'ThrowStatement': return 'error(' + this.expr(n.argument).c + ', 0);';
    }
    fail(n, '不支持的语句类型 ' + n.type);
  }
}
// 让 '_raw' 节点可被 expr() 识别
const origExpr = Gen.prototype.expr;
Gen.prototype.expr = function (n) { if (n.type === '_raw') return { c: n.c, t: 'any' }; return origExpr.call(this, n); };
const origCond = Gen.prototype.cond;

// ------------------------------------------------------------ 模块
const iifes = [];
function findModule(ast) {
  for (const st of ast.body) {
    if (st.type === 'ExpressionStatement') {
      let e = st.expression;
      if (e.type === 'UnaryExpression') e = e.argument;
      if (e.type === 'CallExpression' && e.callee.type === 'FunctionExpression') iifes.push(e.callee);
    }
  }
  return iifes.length ? iifes[0].body.body : ast.body;
}
const mod = findModule(ast);
const g = new Gen(); const modScope = new Scope(null, true); g.scope = modScope;
collect(mod, modScope);
const funcs = mod.filter(s => s.type === 'FunctionDeclaration' && !SKIP.has(s.id.name) && !inSkipLines(s)); const others = mod.filter(s => s.type !== 'FunctionDeclaration' && !inSkipLines(s));
const lines = [];
lines.push('-- 由 xpile/transpile.js 从 ' + inFile.split('/').pop() + ' 自动生成，请勿手改。\n-- 转换规则见 transpile.js 头部注释；运行库见 jsrt/JS.lua。');
lines.push('local JS = require("jsrt.JS")');
lines.push('local G, T, OR, AND, S2, LEN, MOD, typeof, tonum, smt, AMT = JS.G, JS.T, JS.OR, JS.AND, JS.S, JS.len, JS.mod, JS.typeof, JS.tonum, setmetatable, JS.AMT');
lines.push('local bor, band, bxor, shl, shr, ushr = JS.bor, JS.band, JS.bxor, JS.shl, JS.shr, JS.ushr');
lines.push('local Math_abs, Math_min, Math_max, Math_floor, Math_ceil, Math_round, Math_sqrt, Math_sin, Math_cos, Math_tan, Math_asin, Math_atan2, Math_exp, Math_hypot, Math_pow, Math_random, Math_PI = JS.Math_abs, JS.Math_min, JS.Math_max, JS.Math_floor, JS.Math_ceil, JS.Math_round, JS.Math_sqrt, JS.Math_sin, JS.Math_cos, JS.Math_tan, JS.Math_asin, JS.Math_atan2, JS.Math_exp, JS.Math_hypot, JS.Math_pow, JS.Math_random, math.pi');
lines.push('return function(HOST)\nlocal S = {}');
funcs.forEach(f => { lines.push('S' + (isIdent(f.id.name) ? '.' + f.id.name : '["' + f.id.name + '"]') + ' = ' + g.func(f, f.id.name) + ';'); });
others.forEach(s => {
  if (s.type === 'ReturnStatement') { lines.push('do return S end;'); return; }
  lines.push(g.stmt(s));
});
// 其余顶层 IIFE（各自独立作用域）依次执行
iifes.slice(1).forEach(f => { g.scope = new Scope(null, false); lines.push('(' + g.func(f, '(iife)') + ')(nil);'); });
lines.push('return S\nend');
fs.writeFileSync(outFile, lines.join('\n') + '\n');
console.log('已生成', outFile, '函数', funcs.length, '跳过', [...SKIP].join(',') || '无');
if (warn.length) console.log('提示：\n  ' + [...new Set(warn)].join('\n  '));

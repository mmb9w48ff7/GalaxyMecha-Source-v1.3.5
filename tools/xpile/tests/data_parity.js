// 在网页版里计算一组确定性结果，写成 JSON 供 Lua 版对比
const { chromium } = require('/opt/npm-tools/node_modules/playwright');
(async () => {
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1243/chrome-linux64/chrome', args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const pg = await b.newPage(); await pg.goto('file:///home/claude/work/GalaxyMecha/preview/index.html'); await pg.waitForTimeout(1000);
  const out = await pg.evaluate(() => {
    const C = window.Cosmic; const res = {};
    const V = C.VARIANTS; const cards = [];
    C.MOD_FORMS.forEach(f => C.ELEMENTS.forEach(e => { for (let t = 0; t < 4; t++) for (let v = 0; v < V[t]; v++) { const m = C.makeModule(t, f.k, e.k, v); cards.push([m.id, m.name, (m.tags || []).join('|'), m.tier, m.v]); } }));
    res.cards = cards;
    const dc = C.dailyChallenge(); res.dc = { day: dc.day, chapter: dc.chapter, mods: dc.mods, danger: dc.danger };
    res.costs = [0, 1, 5, 20, 60, 100].map(n => [C.CHIP_COST(n), C.MOD_COST(n)]);
    res.mechMul = C.MECHS.map(m => C.mechMul ? C.mechMul(m.id) : null);
    res.evo = Object.keys(C.EVO).map(k => k + ':' + C.EVO[k].n);
    res.lv = [1, 2, 3, 5].map(l => C.modLvMult({ lvl: l }));
    // 芯片属性汇总：造 3 枚固定芯片
    C.save.chips = [{ id: 'a', tier: 3, lvl: 3, aff: [{ k: 'atk', v: 8 }, { k: 'regen', v: 0.5 }, { k: 'crit', v: 4 }], trait: 'revive' }, { id: 'b', tier: 1, lvl: 1, aff: [{ k: 'hp', v: 7 }, { k: 'luck', v: 1.2 }] }];
    C.save.chipEq = ['a', 'b']; C.save.pilot = 'char_chiyan'; const cs = C.chipStats(); const keys = Object.keys(cs).filter(k => k !== 'traits').sort(); res.chip = keys.map(k => k + '=' + Math.round(cs[k] * 1e6) / 1e6); res.traits = Object.keys(cs.traits || {});
    return res;
  });
  require('fs').writeFileSync('/tmp/js_data.json', JSON.stringify(out)); console.log('网页版：卡牌', out.cards.length, 'dc', JSON.stringify(out.dc), '芯片', out.chip.slice(0, 3).join(','));
  await b.close();
})();

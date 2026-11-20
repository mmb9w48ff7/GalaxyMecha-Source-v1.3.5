const { chromium } = require('/opt/npm-tools/node_modules/playwright'); const fs = require('fs');
const cfg = JSON.parse(process.argv[2] || '{}'); const mech = cfg.mech || 'mech_azure', ch = cfg.ch || 1, N = cfg.frames || 600, seed = cfg.seed || 12345, every = cfg.every || 30;
(async () => {
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1243/chrome-linux64/chrome', args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const pg = await b.newPage({ viewport: { width: 1280, height: 720 } });
  await pg.addInitScript("window.requestAnimationFrame=function(cb){return 0;}; window.setTimeout0=window.setTimeout;");
  await pg.goto('file://' + (process.env.PAGE || '/home/claude/work/GalaxyMecha/preview/index.html')); await pg.waitForTimeout(800);
  const out = await pg.evaluate(([mech, ch, N, seed, every, cfgOpt, cfgSector]) => {
    let s = seed; window.__rc = 0; Math.random = function () { window.__rc++; s = (s * 1664525 + 1013904223) % 4294967296; return s / 4294967296; };
    const C = window.Cosmic; C.save.mech = mech; C.save.pilot = C.mech(mech).match; C.save.tutorialDone = true; C.save.modEq = []; C.save.modules = [];
    const cards = [C.makeModule(0, 'homing', 'fire', 0), C.makeModule(0, 'nova', 'ice', 0), C.makeModule(1, 'orbit', 'poison', 0)]; cards.forEach(c => C.save.modules.push(c)); C.save.modEq = cards.map(c => c.id);
    C.save.chips = []; C.save.chipEq = []; C.save.settings.fx = 'high';
    window.__tr = []; const RUN = window.CosmicRun; RUN.start(ch, cfgOpt || {}); const D = RUN.debug; let R = D.run(); if (cfgSector) { D.sector(cfgSector); }
    const rows = []; { const ev = R.event; rows.push([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'init ev=' + (ev ? ev.type + ':' + ev.x.toFixed(2) + ',' + ev.z.toFixed(2) : '-') + ' gate=' + R.gate.x.toFixed(2) + ',' + R.gate.z.toFixed(2) + ' decor=' + R.decor.length + ' nodes=' + R.nodes.length + ' rc=' + window.__rc + ' rnd=' + Math.random().toFixed(6)]); }
    for (let i = 0; i < N; i++) {
      D.move(Math.sin(i / 25) * 0.8, 0.6 + 0.4 * Math.cos(i / 40)); 
      if (i === 40 || i === 200 || i === 400) D.cast(); if (i === 90 || i === 300) D.dodge();
      D.step(1);
      if ((i + 1) % every === 0) rows.push([i + 1, +R.px.toFixed(3), +R.py.toFixed(3), +R.pz.toFixed(3), +R.hull.toFixed(3), R.kills, R.level, +R.xp.toFixed(2), R.enemies.length, R.shots.length, R.credits, +R.camYaw.toFixed(3), (' N=' + R.nums.map(n => n.v).join(',') + ' ') + ('S' + R.sched.length + ' B' + R.beams.length + ' cd' + R.activeCd.toFixed(2) + ' ') + R.enemies.map(e => e.type + ':' + e.hp.toFixed(4) + '@' + e.x.toFixed(1) + ',' + e.z.toFixed(1)).join(' ')]);
    }
    rows.push([-1, 0,0,0,0,0,0,0,0,0,0,0, JSON.stringify(window.__tr)]); return rows;
  }, [mech, ch, N, seed, every, cfg.opt || null, cfg.sector || 0]);
  fs.writeFileSync('/tmp/js_battle.json', JSON.stringify(out)); console.log('网页版：记录', out.length, '行；末行', JSON.stringify(out[out.length - 1])); await b.close();
})();

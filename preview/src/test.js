/* 宇宙银河玩家 · 测试面板（只打包进测试版 HTML） */
(function () {
  'use strict';
  var g = window.__game, CX = window.Cosmic;
  if (!g || !CX) return;
  var box = document.createElement('div');
  box.innerHTML = '<button id="tp-btn" aria-expanded="false" aria-controls="tp">测试面板</button><div id="tp-fps" hidden></div><div id="tp" hidden>' +
    '<p class="tp-h">机库</p><div class="tp-row"><button data-a="cr">信用点 +10000</button><button data-a="src">星源 +100</button><button data-a="frag">全部碎片 +40</button></div>' +
    '<div class="tp-row"><button data-a="mod10">研发 10 个模块</button><button data-a="chip10">研发 10 个芯片</button><button data-a="leg">送 1 个传说模块</button></div><div class="tp-row"><button data-a="mlv">出战机甲 +5 级</button><button data-a="all">解锁全部机甲与驾驶员</button><button data-a="ch">解锁全部章节</button><button data-a="idle">巡航收益 +8 小时</button><button data-a="day">重置每日</button></div>' +
    '<p class="tp-h">远征中</p><div class="tp-row"><button data-a="god">无敌：关</button><button data-a="lv">立即升级</button><button data-a="gate">完成目标并到星门</button><button data-a="clear">清屏</button></div>' +
    '<div class="tp-row"><button data-a="s3">跳到星域 3（精英）</button><button data-a="s4">跳到星域 4（商人）</button><button data-a="s6">跳到星域 6（首领）</button></div>' +
    '<p class="tp-h">第三人称相机（远征中）</p><div class="tp-row"><button data-a="camhigh">远景</button><button data-a="camchase">标准（默认）</button><button data-a="camlow">近景</button></div>' +
    '<p class="tp-h">其他</p><div class="tp-row"><button data-a="fps">显示帧率</button><button data-a="full">全屏</button><button data-a="reset" class="warn">重置存档</button></div>' +
    '<p class="tp-note">拖动屏幕移动，武器自动开火，右下按钮（电脑空格）放驾驶员技能。跟着箭头完成目标，飞进星门进入下一个星域。</p></div>';
  document.getElementById('app').appendChild(box);
  var btn = document.getElementById('tp-btn'), panel = document.getElementById('tp'), fpsEl = document.getElementById('tp-fps');
  btn.onclick = function () { panel.hidden = !panel.hidden; btn.setAttribute('aria-expanded', !panel.hidden); };
  function run() { var R = window.CosmicRun.debug.run(); if (!R) g.toast('请先出发远征'); return R; }
  function refresh() { CX.write(); if (g.mode() === 'cosmic-hub') window.CosmicHub.render(); }
  var fpsOn = false;
  setInterval(function () { if (fpsOn) fpsEl.textContent = Math.round(window.__fps || 0) + ' 帧/秒'; }, 500);
  var actions = {
    cr: function () { CX.save.credits += 10000; refresh(); g.toast('信用点 +10000'); },
    src: function () { CX.save.src += 100; refresh(); g.toast('星源 +100'); },
    frag: function () { CX.CHARS.forEach(function (c) { CX.save.frags[c.id] = (CX.save.frags[c.id] || 0) + 40; }); refresh(); g.toast('全部碎片 +40'); },
    mod10: function () { CX.save.credits += 30000; for (var i = 0; i < 10; i++) CX.buyModule(); refresh(); g.toast('已研发 10 个技能模块'); },
    chip10: function () { CX.save.credits += 20000; for (var i = 0; i < 10; i++) CX.buyChip(); refresh(); g.toast('已研发 10 个天赋芯片'); },
    leg: function () { var m = CX.makeModule(3); CX.save.modules.push(m); refresh(); g.toast('获得传说模块：' + m.name); },
    mlv: function () { var id = CX.save.mech; CX.save.mechs[id].lv = Math.min(CX.MECH_MAX, CX.save.mechs[id].lv + 5); refresh(); g.toast(CX.mech(id).name + ' Lv ' + CX.save.mechs[id].lv); },
    all: function () { CX.CHARS.forEach(function (c) { if (!CX.save.chars[c.id]) CX.save.chars[c.id] = { star: 1 }; }); refresh(); g.toast('已解锁全部机甲与驾驶员'); },
    ch: function () { CX.save.chapter = CX.CHAPTERS.length; refresh(); g.toast('已解锁全部章节'); },
    idle: function () { CX.save.idleT = Date.now() - 8 * 3600000; refresh(); g.toast('巡航收益已积累 8 小时'); },
    day: function () { var d = CX.save.daily.day; CX.save.daily = { day: d, ads: 0, free: 0, supply: 0, runs: 0, kills: 0, pulls: 0, claimed: {} }; refresh(); g.toast('每日数据已重置'); },
    god: function (b) { var R = run(); if (!R) return; R.god = !R.god; b.textContent = '无敌：' + (R.god ? '开' : '关'); b.classList.toggle('on', R.god); },
    lv: function () { if (run()) window.CosmicRun.debug.levelUp(); },
    gate: function () { if (run()) window.CosmicRun.debug.toGate(); },
    clear: function () { if (run()) window.CosmicRun.debug.clear(); },
    s3: function () { if (run()) window.CosmicRun.debug.sector(3); },
    s4: function () { if (run()) window.CosmicRun.debug.sector(4); },
    s6: function () { if (run()) window.CosmicRun.debug.sector(6); },
    camhigh: function () { window.CosmicRun.debug.cam('high'); }, camchase: function () { window.CosmicRun.debug.cam('chase'); }, camlow: function () { window.CosmicRun.debug.cam('mid'); },
    fps: function (b) { fpsOn = !fpsOn; fpsEl.hidden = !fpsOn; b.classList.toggle('on', fpsOn); },
    full: function () {
      var d = document.documentElement;
      if (document.fullscreenElement) document.exitFullscreen();
      else if (d.requestFullscreen) d.requestFullscreen().then(function () { if (screen.orientation && screen.orientation.lock) screen.orientation.lock('landscape').catch(function () {}); }).catch(function () { g.toast('当前浏览器不支持全屏'); });
      else g.toast('当前浏览器不支持全屏');
    },
    reset: function () { if (!confirm('确定清空存档并重新开始吗？')) return; CX.reset(); window.CosmicHub.open(); g.toast('存档已重置'); }
  };
  panel.querySelectorAll('button[data-a]').forEach(function (b) { b.onclick = function () { actions[b.dataset.a](b); }; });
})();

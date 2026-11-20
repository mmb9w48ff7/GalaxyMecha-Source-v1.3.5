/* 宇宙银河机甲 · 启动与公共服务
 * 分辨率适配（1920x1080 设计）、提示、像素图标、主循环、自动画质。
 */
(function () {
  'use strict';
  var E = window.VoxEngine, C = window.Cosmic;
  if (!E) return;
  var CATALOG = window.VOX_CATALOG, SC = window.VOX_SCENES, DEG = Math.PI / 180, DESIGN_W = 1920, DESIGN_H = 1080;
  var app = document.getElementById('app'), stage = document.getElementById('stage'), ui = document.getElementById('ui');
  var hud2d = document.getElementById('hud2d'), probe = document.getElementById('safe-probe');
  var mode = 'cosmic-hub', view = { w: 1, h: 1, s: 1, safe: [0, 0, 0, 0], dpr: 1 };
  var mobile = /Android|iPhone|iPad|Mobile/i.test(navigator.userAgent) || (navigator.maxTouchPoints > 1 && Math.min(screen.width, screen.height) < 900);

  function byId(list, id) { for (var i = 0; i < list.length; i++) if (list[i].id === id) return list[i]; return null; }
  var B36 = '0123456789abcdefghijklmnopqrstuvwxyz';
  function iconSVG(ic, px) {
    var w = ic.w, h = ic.h, out = '<svg class="pix" viewBox="0 0 ' + w + ' ' + h + '" width="' + px + '" height="' + (px * h / w) + '" shape-rendering="crispEdges" aria-hidden="true">';
    for (var j = 0; j < h; j++) for (var i = 0; i < w; i++) { var ch = ic.px[j * w + i]; if (ch === '.') continue; out += '<rect x="' + i + '" y="' + j + '" width="1.02" height="1.02" fill="' + ic.pal[B36.indexOf(ch)] + '"/>'; }
    return out + '</svg>';
  }
  function catIcon(id, px) { var c = byId(CATALOG.items, id); return c ? iconSVG(c.icon, px) : ''; }
  function resIcon(id, px) { return iconSVG(SC.resIcons[id], px); }
  function fitFov(fov, aspect) { var a = DESIGN_W / DESIGN_H; return aspect >= a ? fov : 2 * Math.atan(Math.tan(fov * DEG / 2) * a / aspect) / DEG; }
  var toastTimer = null;
  function toast(msg) { var t = document.getElementById('toast'); t.textContent = msg; t.hidden = false; clearTimeout(toastTimer); toastTimer = setTimeout(function () { t.hidden = true; }, 2600); }

  // ------------------------------------------------------------------ 画质：高 / 流畅 / 自动
  var lowNow = false;
  function quality() { return (C.save && C.save.settings && C.save.settings.quality) || 'auto'; }
  function applyQuality() {
    var q = quality(), low = q === 'low' || (q === 'auto' && lowNow) || !!(C.save && C.save.settings && C.save.settings.saver);
    E.setBloomPasses(low ? 1 : 3);
    view.dprCap = low ? 1 : (mobile ? 1.5 : 2);
    layout(true);
  }
  function layout(force) {
    var w = app.clientWidth, h = app.clientHeight, cs = getComputedStyle(probe);
    var safe = [parseFloat(cs.paddingLeft) || 0, parseFloat(cs.paddingRight) || 0, parseFloat(cs.paddingTop) || 0, parseFloat(cs.paddingBottom) || 0];
    stage.style.width = w + 'px'; stage.style.height = h + 'px';
    var s = Math.min(w / DESIGN_W, h / DESIGN_H);
    view.w = w; view.h = h; view.s = s; view.safe = safe;
    ui.style.width = (w / s) + 'px'; ui.style.height = (h / s) + 'px'; ui.style.transform = 'scale(' + s + ')';
    ui.style.setProperty('--safe-l', (safe[0] / s) + 'px'); ui.style.setProperty('--safe-r', (safe[1] / s) + 'px');
    ui.style.setProperty('--safe-t', (safe[2] / s) + 'px'); ui.style.setProperty('--safe-b', (safe[3] / s) + 'px');
    var dpr = Math.min(window.devicePixelRatio || 1, view.dprCap || 2);
    E.resize(Math.max(1, Math.round(w * dpr)), Math.max(1, Math.round(h * dpr)), force);
    E.canvas.style.width = w + 'px'; E.canvas.style.height = h + 'px';
    hud2d.width = Math.round(w * dpr); hud2d.height = Math.round(h * dpr); hud2d.style.width = w + 'px'; hud2d.style.height = h + 'px';
    view.dpr = dpr;
  }
  window.addEventListener('resize', function () { layout(); });
  new ResizeObserver(function () { layout(); }).observe(app);

  // ------------------------------------------------------------------ 主循环（含自动画质：帧率持续偏低时降级一次）
  var lastT = performance.now(), fpsAcc = 0, fpsN = 0, fpsWin = 0, fpsLow = 0;
  function loop(now) {
    requestAnimationFrame(loop);
    if (C.save && C.save.settings && C.save.settings.saver && mode === 'cosmic-run' && now - lastT < 30) return;   // 省电模式：限制 30 帧
    var dt = Math.min(0.05, (now - lastT) / 1000); lastT = now;
    fpsAcc += dt; fpsN++;
    if (fpsAcc >= 1) {
      var fps = fpsN / fpsAcc; fpsAcc = 0; fpsN = 0;
      if (quality() === 'auto' && !lowNow && mode === 'cosmic-run') { fpsWin = fps < 40 ? fpsWin + 1 : 0; if (fpsWin >= 4) { lowNow = true; applyQuality(); toast('检测到帧率偏低，已自动切换到流畅画质'); } }
      window.__fps = fps;
      if (mode === 'cosmic-run') { fpsLow = fps < 30 ? fpsLow + 1 : fps < 42 ? fpsLow + 0.5 : Math.max(0, fpsLow - 1); window.__perf = fpsLow >= 4 ? 0.5 : fpsLow >= 2 ? 0.7 : 1; } else { fpsLow = 0; window.__perf = 1; }
    }
    if (mode === 'cosmic-hub') window.CosmicHub.frame(dt);
    else if (mode === 'cosmic-run') window.CosmicRun.frame(dt);
  }
  // 首次触摸时解锁音频
  window.addEventListener('pointerdown', function () { if (C.unlockAudio) C.unlockAudio(); }, { once: false, passive: true });

  var api = {
    save: function () { return C.save; }, writeSave: function () { C.write(); }, toast: toast,
    iconSVG: iconSVG, catIcon: catIcon, resIcon: resIcon, byId: byId, fitFov: fitFov,
    view: function () { return view; }, mode: function () { return mode; }, setMode: function (m) { mode = m; }, showTitle: function () { window.CosmicHub.open(); },
    applyQuality: applyQuality, isMobile: mobile
  };
  window.CosmicHub.init(api); window.CosmicRun.init(api);
  applyQuality();
  window.CosmicHub.open();
  requestAnimationFrame(loop);
  window.__game = { toast: toast, writeSave: function () { C.write(); }, refreshStation: function () {}, mode: function () { return mode; }, api: api };
})();

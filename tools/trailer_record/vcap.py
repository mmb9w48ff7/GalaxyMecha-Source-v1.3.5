# 逐帧录制：接管 requestAnimationFrame，用固定步长驱动游戏，再逐帧截图
import asyncio, sys, os, time, json
from playwright.async_api import async_playwright
URL='file:///home/claude/work/GalaxyMecha/preview/index.html'
INIT = """
window.__raf=[]; window.__t=performance.now(); window.requestAnimationFrame=function(cb){ window.__raf.push(cb); return window.__raf.length; };
window.__tick=function(ms){ window.__t+=ms; var q=window.__raf; window.__raf=[]; for(var i=0;i<q.length;i++){ try{ q[i](window.__t); }catch(e){ console.error(e); } } };
"""
SETUP="""async ([mid, orb, cam, chap]) => { const C=window.Cosmic; C.CHARS.forEach(c=>{ if(!C.save.chars[c.id]) C.save.chars[c.id]={star:1}; }); C.MECHS.forEach(m=>{ if(!C.save.mechs[m.id]) C.save.mechs[m.id]={lv:1,star:1}; });
  C.save.credits=999999; for(let i=0;i<60;i++) C.buyModule(); C.save.modEq=C.save.modules.slice(0,3).map(m=>m.id); C.save.mech=mid; C.save.pilot=C.mech(mid).match; C.save.tutorialDone=true; C.save.runs=9; C.save.settings.music=false; C.save.settings.sound=false;
  window.CosmicRun.start(chap||1); const D=window.CosmicRun.debug, R=D.run(); D.god(true); R.nodes.forEach(n=>n.objs=[]); R.event=null; R.nodes=R.nodes.filter(n=>n.type==='gate'); R.gate.state='hidden'; R.gate.x=0;R.gate.y=150;R.gate.z=140; R.activeCd=0; D.orbit(orb); D.cam(cam);
  window.__tick(16); window.__tick(16); R.enemies=[]; D.step(3); document.head.insertAdjacentHTML('beforeend','<style id="__h">#ui{display:none!important}</style>'); return true; }"""
async def record(name, mid, orb, cam, frames, setup_js, frame_js, w=1920, h=1080, fps=30, chap=1, start=0):
    out=f'vid/{name}'; os.makedirs(out, exist_ok=True)
    async with async_playwright() as p:
        b = await p.chromium.launch(executable_path='/opt/pw-browsers/chromium-1243/chrome-linux64/chrome', args=['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist','--no-sandbox'])
        pg = await b.new_page(viewport={'width':w,'height':h}); logs=[]
        pg.on('pageerror', lambda e: logs.append(str(e)))
        await pg.add_init_script(INIT); await pg.goto(URL); await pg.wait_for_timeout(1500)
        for _ in range(5): await pg.evaluate("() => window.__tick(16)")
        await pg.evaluate(SETUP, [mid, orb, cam, chap]); await pg.evaluate(setup_js)
        t0=time.time()
        for i in range(frames):
            await pg.evaluate("([i, ms, fjs]) => { const D=window.CosmicRun.debug, R=D.run(); const f=new Function('i','D','R', fjs); f(i,D,R); window.__tick(ms); }", [i, 1000.0/fps, frame_js])
            await pg.screenshot(path=f'{out}/f{i+start:05d}.jpg', type='jpeg', quality=92)
            if i==4: print(name,'5 frames in %.1fs'%(time.time()-t0), flush=True)
        print(name,'done',frames,'frames %.0fs'%(time.time()-t0), logs[:2], flush=True)
        await b.close()
if __name__=='__main__':
    asyncio.run(record('test','mech_forge',40,'chase',12,"() => { const D=window.CosmicRun.debug, R=D.run(); }", "if(i===0) D.move(0,1);", w=int(sys.argv[1]), h=int(sys.argv[2])))

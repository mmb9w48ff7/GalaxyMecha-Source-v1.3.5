import asyncio, sys
from vcap import record
H = """const T=['grunt','crawler','inter','guard','phantom','bomber','splitter','sniper','heavy','crawler'];
const sp=(k)=>{ const a=Math.sin(k*12.9898)*43758.5453; const r=a-Math.floor(a); const lat=(r-0.5)*56; const h=(((r*7)%1)-0.5)*16; D.spawn(T[k%T.length], R.px+lat, R.py+h, R.pz+50); };
const t=i/30; R.bubbles=[]; """
def action(orb0, orb1, N, cast=14, spawn_every=6, sway=0.5, nitro=None):
    s = H + f"D.move({sway}*Math.sin(t*2.2), 0.78); D.orbit({orb0}+({orb1}-({orb0}))*i/{N}); D.camset({{dist: 9.2-2.6*i/{N}, h: 3.6-0.9*i/{N}, fov: 62}}); "
    s += f"if(i===0){{ for(let k=0;k<7;k++) sp(k); }} if(i%{spawn_every}===0 && i>0) sp(i); if(i==={cast}) {{ R.activeCd=0; D.cast(); }} "
    if nitro is not None: s += f"if(i==={nitro}) D.dodge(); "
    return s
SC = {
 'a_intro': dict(mid='mech_azure', orb=85, cam='chase', frames=90, setup="()=>{}", fjs=H+"D.move(0.25*Math.sin(t*1.5),0.85); D.orbit(85-60*i/90); D.camset({dist:11-3*i/90,h:3.6,fov:62}); if(i===40){R.activeCd=0; D.cast();}"),
 'm1_azure': dict(mid='mech_azure', orb=70, cam='chase', frames=72, setup="()=>{}", fjs=action(70,20,72)),
 'm2_blaze': dict(mid='mech_blaze', orb=-60, cam='chase', frames=72, setup="()=>{}", fjs=action(-60,-10,72,cast=12,spawn_every=5)),
 'm3_halo': dict(mid='mech_halo', orb=25, cam='high', frames=72, setup="()=>{}", fjs=action(25,75,72)),
 'm4_frost': dict(mid='mech_frost', orb=-30, cam='chase', frames=72, setup="()=>{}", fjs=action(-30,30,72,cast=10)),
 'm5_starfall': dict(mid='mech_starfall', orb=80, cam='chase', frames=72, setup="()=>{}", fjs=action(80,30,72,cast=10)),
 'm6_forge': dict(mid='mech_forge', orb=-20, cam='chase', frames=72, setup="()=>{}", fjs=action(-20,-70,72,cast=8,spawn_every=5)),
 'c_boss': dict(mid='mech_blaze', orb=48, cam='high', frames=105, chap=1, setup="""() => { const D=window.CosmicRun.debug, R=D.run(); D.sector(6); D.step(120); R.activeCd=99; const bs=R.boss; R.px=bs.x+6; R.py=bs.y+2; R.pz=bs.z-40; R.enemies=[bs]; bs.hp=bs.max*0.3; D.step(3); bs.lcd=0; bs.laser=null; D.step(2); R.hull=99999; D.orbit(48); D.cam('high'); }""",
   fjs="const D2=D; const bs=R.boss; const t=i/30; D.orbit(48-70*i/105); D.camset({dist:24-6*i/105,h:7-1.5*i/105,fov:62}); if(bs){ if(i<3){ bs.lcd=0; } R.px=bs.x+6+4*Math.sin(t*2); R.pz=bs.z-40; R.py=bs.y+2; } if(i===44) D.dodge(); D.move(0.9,0);"),
 'd_swarm': dict(mid='mech_halo', orb=0, cam='high', frames=90, chap=2, setup="""() => { const D=window.CosmicRun.debug, R=D.run(), C=window.Cosmic; R.mods=[{m:C.makeModule(2,'nova','thunder',0),lv:4,t:0,i:0,tint:[1,1,0.4]},{m:C.makeModule(2,'nova','fire',0),lv:4,t:0.5,i:1,tint:[1,0.5,0.2]},{m:C.makeModule(2,'homing','ice',0),lv:4,t:0.2,i:2,tint:[0.5,0.8,1.5]}]; for(let k=0;k<44;k++){ const a=k*0.7, r=14+(k%5)*5; D.spawn(['grunt','crawler','inter','guard','phantom','bomber','splitter','sniper','crawler','heavy'][k%10], R.px+Math.sin(a)*r, R.py+((k%4)-1.5)*3, R.pz+Math.cos(a)*r+10); } }""",
   fjs="const t=i/30; D.move(0.3*Math.sin(t*1.8),0.1); D.orbit(-10+80*i/90); D.camset({dist:24-5*i/90,h:8,fov:62}); if(i===10||i===55){R.activeCd=0; D.cast();} R.enemies.forEach((e,k)=>{ if(e.d && !e.d.boss && i%12===0 && k%3===i/12%3){ e.slowT=3; if(k%2) e.poison={dps:2,t:3}; } });"),
 'f_outro': dict(mid='mech_forge', orb=25, cam='chase', frames=90, setup="()=>{}", fjs=action(25,-45,90,cast=18,spawn_every=5)),
}
async def main():
    for name in sys.argv[1:]:
        c=SC[name]; await record(name, c['mid'], c['orb'], c['cam'], c['frames'], c['setup'], c['fjs'], chap=c.get('chap',1))
asyncio.run(main())

# -*- coding: utf-8 -*-
"""离线渲染全部音效与 3 首背景音乐 -> assets/audio/*.ogg（Vorbis），并生成 preview/data/audio.js（base64，HTML 单文件内嵌用）。
用法：python3 tools/build_audio.py     需要 numpy / scipy / ffmpeg(libvorbis)。"""
import os, base64, json, subprocess, tempfile, wave
import numpy as np
from scipy.signal import lfilter, butter

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'audio')
rng = np.random.default_rng(7)


def osc(kind, f0, f1, dur):
    n = int(SR * dur); t = np.arange(n) / SR
    f = f0 * (max(f1, 20) / f0) ** (t / dur) if f1 != f0 else np.full(n, float(f0))
    ph = np.cumsum(f) / SR
    if kind == 'sine': return np.sin(2 * np.pi * ph)
    if kind == 'square': return np.sign(np.sin(2 * np.pi * ph))
    if kind == 'sawtooth': return 2 * (ph % 1) - 1
    if kind == 'triangle': return 2 * np.abs(2 * (ph % 1) - 1) - 1
    raise ValueError(kind)


def env_exp(n, vol, end=0.0008):
    return vol * (end / vol) ** (np.arange(n) / n)


def lp(x, fc):
    b, a = butter(2, min(fc, SR / 2 - 100) / (SR / 2), 'low'); return lfilter(b, a, x)


def hp(x, fc):
    b, a = butter(2, fc / (SR / 2), 'high'); return lfilter(b, a, x)


def tone(kind, f0, f1, dur, vol):
    x = osc(kind, f0, f1, dur); return x * env_exp(len(x), vol)


def noise(dur, vol, cutoff, power=1.0):
    n = int(SR * dur); x = rng.uniform(-1, 1, n) * (1 - np.arange(n) / n) ** power
    return lp(x, cutoff) * vol


def mix(parts, total):
    out = np.zeros(int(SR * total))
    for delay, x in parts:
        a = int(SR * delay); b = min(len(out), a + len(x)); out[a:b] += x[:b - a]
    return out


def sfx_bank():
    S = {}
    S['shoot'] = tone('square', 900, 420, 0.05, 0.025)
    S['pop'] = noise(0.08, 0.06, 1400)
    S['boom'] = mix([(0, noise(0.45, 0.22, 600)), (0, tone('sine', 120, 40, 0.4, 0.2))], 0.5)
    S['pick'] = tone('sine', 1100, 1700, 0.06, 0.04)
    S['hurt'] = tone('square', 220, 90, 0.12, 0.06)
    S['level'] = mix([(i * 0.07, tone('triangle', f, f, 0.12, 0.07)) for i, f in enumerate([523, 659, 784, 1046])], 0.5)
    S['skill'] = mix([(0, tone('sawtooth', 200, 900, 0.25, 0.05)), (0, noise(0.2, 0.05, 2500))], 0.3)
    S['warp'] = tone('sine', 300, 1300, 0.5, 0.07)
    S['gate'] = mix([(0, tone('triangle', 660, 660, 0.35, 0.06)), (0.08, tone('triangle', 990, 990, 0.35, 0.05))], 0.5)
    S['boss'] = tone('sawtooth', 110, 70, 0.9, 0.09)
    S['win'] = mix([(i * 0.1, tone('triangle', f, f, 0.2, 0.08)) for i, f in enumerate([523, 659, 784, 1046, 1318])], 0.8)
    S['click'] = tone('sine', 700, 500, 0.04, 0.04)
    S['dash'] = mix([(0, tone('sine', 500, 1500, 0.12, 0.05)), (0, noise(0.1, 0.04, 3000))], 0.15)
    # 氮气：低频起爆 + 高频喷流
    # 柔和版氮气：低频起爆 + 低通气流声（缓起缓收，无锯齿高频），避免刺耳
    n = int(SR * 0.42); tt = np.arange(n) / SR
    air = lp(lp(rng.uniform(-1, 1, n), 1600), 1600) * np.minimum(1, tt / 0.05) * np.exp(-tt * 5.5) * 0.22
    thump = np.sin(2 * np.pi * np.cumsum(150 * (55 / 150) ** np.minimum(1, tt / 0.3)) / SR) * np.exp(-tt * 9) * 0.16
    rise = np.sin(2 * np.pi * np.cumsum(180 + 260 * np.minimum(1, tt / 0.3)) / SR) * np.minimum(1, tt / 0.06) * np.exp(-tt * 7) * 0.05
    S['nitro'] = air + thump + rise
    # 命中音：短促轻柔的“嗒”，暴击为两声上扬
    S['hit'] = mix([(0, tone('sine', 520, 300, 0.035, 0.05)), (0, noise(0.03, 0.03, 1800))], 0.05)
    S['crit'] = mix([(0, tone('triangle', 700, 760, 0.05, 0.05)), (0.045, tone('triangle', 1050, 1100, 0.07, 0.045))], 0.15)
    return S


NOTE = lambda n: 440 * 2 ** ((n - 69) / 12)
SONGS = {
    'hub': dict(bpm=84, chords=[[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]], bass=False, drums=0, arp=[0, 1, 2, 1, 0, 2, 1, 2], lead=None, pad=True),
    'battle': dict(bpm=132, chords=[[57, 60, 64], [53, 57, 60], [55, 59, 62], [52, 55, 59]], bass=True, drums=1, arp=[0, 2, 1, 2, 0, 2, 1, 2],
                   lead=[12, None, 15, 12, 19, None, 17, 15, 12, None, 10, 12, 15, None, None, None], pad=False),
    'boss': dict(bpm=150, chords=[[50, 53, 57], [46, 50, 53], [48, 52, 55], [45, 49, 52]], bass=True, drums=2, arp=[0, 1, 2, 1, 0, 1, 2, 1],
                 lead=[12, 12, 15, None, 13, None, 12, 10, 12, None, 15, 17, 19, None, 17, 15], pad=False),
}


def note(buf, kind, freq, t, dur, vol, cutoff=None):
    n = int(SR * (dur + 0.05)); x = osc(kind, freq, freq, dur + 0.05)
    a = int(SR * 0.01); e = np.full(n, 0.0001)
    e[:a] = np.linspace(0.0001, vol, a); e[a:] = vol * (0.0001 / vol) ** (np.arange(n - a) / max(1, int(SR * dur) - a)); e = np.maximum(e, 0)
    x = x * e
    if cutoff: x = lp(x, cutoff)
    i = int(SR * t); j = min(len(buf), i + n); buf[i:j] += x[:j - i]


def render_song(S):
    sx = 60 / S['bpm'] / 4; steps = 128; total = steps * sx + 1.0
    buf = np.zeros(int(SR * total))
    for st in range(steps):
        t = st * sx; bar = (st // 16) % 8; chord = S['chords'][(bar // 2) % 4]; pos = st % 16
        if S['pad'] and pos == 0 and bar % 2 == 0:
            for nn in chord:
                note(buf, 'sawtooth', NOTE(nn), t, sx * 30, 0.025, 900); note(buf, 'sawtooth', NOTE(nn) * 1.004, t, sx * 30, 0.02, 900)
        if pos % 2 == 0:
            a = S['arp'][(pos // 2) % len(S['arp'])]; note(buf, 'triangle', NOTE(chord[a] + 12), t, sx * 1.8, 0.05 if S['pad'] else 0.04)
        if S['bass'] and pos % 2 == 0: note(buf, 'sawtooth' if S['drums'] == 2 else 'square', NOTE(chord[0] - 24), t, sx * 1.7, 0.07, 700)
        if S['lead']:
            ln = S['lead'][(pos + (bar % 2) * 16) % len(S['lead'])]
            if ln is not None and bar >= 2: note(buf, 'square', NOTE(chord[0] + ln), t, sx * 1.9, 0.03, 2600)
        if S['drums']:
            def add(x):
                i = int(SR * t); j = min(len(buf), i + len(x)); buf[i:j] += x[:j - i]
            if pos % 4 == 0 and (S['drums'] == 2 or pos % 8 == 0):
                n = int(SR * 0.2); tt = np.arange(n) / SR; f = 140 * (40 / 140) ** np.minimum(1, tt / 0.12); add(np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.5 * np.exp(-tt * 18))
            if pos in (4, 12):
                n = int(SR * 0.15); add(hp(rng.uniform(-1, 1, n) * (1 - np.arange(n) / n) ** 3, 900) * 0.12)
            if pos % 2 == 0:
                n = int(SR * 0.04); add(hp(rng.uniform(-1, 1, n) * (1 - np.arange(n) / n) ** 3, 6000) * (0.05 if S['drums'] == 2 else 0.035))
    # 无缝循环：把尾部余音叠回开头，再截成整 8 小节
    loop = int(steps * sx * SR); tail = buf[loop:]; out = buf[:loop].copy(); out[:len(tail)] += tail[:loop]
    return out * 0.55


def to_ogg(x, path, q=3):
    x = np.clip(x, -1, 1); pcm = (x * 32767).astype('<i2')
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f: tmp = f.name
    with wave.open(tmp, 'wb') as w: w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', tmp, '-c:a', 'libvorbis', '-q:a', str(q), path], check=True); os.remove(tmp)


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True); data = {}
    for name, x in sfx_bank().items():
        p = os.path.join(OUT, 'sfx_' + name + '.ogg'); to_ogg(x, p, 4); data['sfx_' + name] = base64.b64encode(open(p, 'rb').read()).decode()
    for name, S in SONGS.items():
        p = os.path.join(OUT, 'bgm_' + name + '.ogg'); to_ogg(render_song(S), p, 3); data['bgm_' + name] = base64.b64encode(open(p, 'rb').read()).decode()
    with open(os.path.join(ROOT, 'preview', 'data', 'audio.js'), 'w') as f:
        f.write('window.OGG_AUDIO=' + json.dumps(data, separators=(',', ':')) + ';\n')
    for fn in sorted(os.listdir(OUT)): print(fn, os.path.getsize(os.path.join(OUT, fn)))

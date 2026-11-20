/* 陨星银河 · 体素渲染器（WebGL2，左手坐标系，与 UrhoX 一致） */
(function () {
  'use strict';
  var DEG = Math.PI / 180;
  var MODELS = window.VOX_MODELS;
  // ------------------------------------------------------------------ 数学
  function v3sub(a, b) { return [a[0] - b[0], a[1] - b[1], a[2] - b[2]]; }
  function v3cross(a, b) { return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]; }
  function v3dot(a, b) { return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]; }
  function v3norm(a) { var l = Math.hypot(a[0], a[1], a[2]) || 1; return [a[0] / l, a[1] / l, a[2] / l]; }
  function m4() { var m = new Float32Array(16); m[0] = m[5] = m[10] = m[15] = 1; return m; }
  function m4mul(a, b) {
    var o = new Float32Array(16);
    for (var c = 0; c < 4; c++) for (var r = 0; r < 4; r++) {
      o[c * 4 + r] = a[r] * b[c * 4] + a[4 + r] * b[c * 4 + 1] + a[8 + r] * b[c * 4 + 2] + a[12 + r] * b[c * 4 + 3];
    }
    return o;
  }
  // 左手系透视（与 UrhoX/D3D 一致：视空间 +Z 朝屏幕内）
  function perspLH(fovY, aspect, n, f) {
    var m = new Float32Array(16), ys = 1 / Math.tan(fovY / 2);
    m[0] = ys / aspect; m[5] = ys; m[10] = (f + n) / (f - n); m[11] = 1; m[14] = -2 * f * n / (f - n);
    return m;
  }
  function orthoLH(hw, hh, n, f) {
    var m = new Float32Array(16);
    m[0] = 1 / hw; m[5] = 1 / hh; m[10] = 2 / (f - n); m[14] = -(f + n) / (f - n); m[15] = 1;
    return m;
  }
  function lookAtLH(eye, target, up) {
    var z = v3norm(v3sub(target, eye)), x = v3norm(v3cross(up, z)), y = v3cross(z, x), m = new Float32Array(16);
    m[0] = x[0]; m[4] = x[1]; m[8] = x[2]; m[12] = -v3dot(x, eye);
    m[1] = y[0]; m[5] = y[1]; m[9] = y[2]; m[13] = -v3dot(y, eye);
    m[2] = z[0]; m[6] = z[1]; m[10] = z[2]; m[14] = -v3dot(z, eye);
    m[15] = 1;
    return m;
  }
  // T * Ry(yaw) * Rx(pitch) * Rz(roll) * S —— 对应 UrhoX 的 Quaternion(pitch, yaw, roll)
  function trs(p, yaw, pitch, roll, s) {
    var cy = Math.cos(yaw * DEG), sy = Math.sin(yaw * DEG), cx = Math.cos(pitch * DEG), sx = Math.sin(pitch * DEG),
      cz = Math.cos(roll * DEG), sz = Math.sin(roll * DEG);
    // R = Ry*Rx*Rz（行主序推导后写入列主序）
    var r00 = cy * cz + sy * sx * sz, r01 = -cy * sz + sy * sx * cz, r02 = sy * cx;
    var r10 = cx * sz, r11 = cx * cz, r12 = -sx;
    var r20 = -sy * cz + cy * sx * sz, r21 = sy * sz + cy * sx * cz, r22 = cy * cx;
    var m = new Float32Array(16);
    m[0] = r00 * s; m[1] = r10 * s; m[2] = r20 * s;
    m[4] = r01 * s; m[5] = r11 * s; m[6] = r21 * s;
    m[8] = r02 * s; m[9] = r12 * s; m[10] = r22 * s;
    m[12] = p[0]; m[13] = p[1]; m[14] = p[2]; m[15] = 1;
    return m;
  }
  function srgb2lin(c) { return Math.pow(c, 2.2); }

  // ------------------------------------------------------------------ WebGL
  var canvas = document.getElementById('gl');
  var gl = canvas.getContext('webgl2', { antialias: false, alpha: false, powerPreference: 'high-performance' });
  if (!gl) {
    document.getElementById('nogl').hidden = false;
    window.VoxEngine = null;
    return;
  }
  var hdr = !!gl.getExtension('EXT_color_buffer_float');

  function compile(vs, fs) {
    function sh(type, src) {
      var s = gl.createShader(type); gl.shaderSource(s, '#version 300 es\nprecision highp float;\n' + src); gl.compileShader(s);
      if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(s));
      return s;
    }
    var p = gl.createProgram();
    gl.attachShader(p, sh(gl.VERTEX_SHADER, vs)); gl.attachShader(p, sh(gl.FRAGMENT_SHADER, fs)); gl.linkProgram(p);
    if (!gl.getProgramParameter(p, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(p));
    var u = {}, n = gl.getProgramParameter(p, gl.ACTIVE_UNIFORMS);
    for (var i = 0; i < n; i++) { var info = gl.getActiveUniform(p, i); u[info.name.replace('[0]', '')] = gl.getUniformLocation(p, info.name); }
    return { p: p, u: u };
  }

  var MAIN_VS = [
    'layout(location=0) in vec3 aPos; layout(location=1) in vec3 aNor; layout(location=2) in vec3 aCol; layout(location=3) in vec3 aMat;',
    'uniform mat4 uModel, uVP, uLightVP; uniform float uScale;',
    'out vec3 vWorld, vNor, vCol0, vMat; out vec4 vLight;',
    'void main(){ vec4 w = uModel*vec4(aPos,1.0); vWorld=w.xyz; vNor = mat3(uModel)*aNor/uScale; vCol0=aCol; vMat=aMat;',
    ' vLight = uLightVP*w; gl_Position = uVP*w; }'].join('\n');
  var MAIN_FS = [
    'in vec3 vWorld, vNor, vCol0, vMat; in vec4 vLight; out vec4 o;',
    'uniform vec3 uKeyDir, uKeyCol, uFillDir, uFillCol, uAmb, uBg, uCam; uniform vec2 uFog;',
    'uniform sampler2D uShadow; uniform float uShadowOn, uShadowTexel; uniform vec4 uTint;',
    'float shadow(){ if(uShadowOn<0.5) return 1.0; vec3 c = vLight.xyz/vLight.w*0.5+0.5;',
    ' if(c.x<0.0||c.x>1.0||c.y<0.0||c.y>1.0||c.z>1.0) return 1.0; float s=0.0;',
    ' for(int i=-1;i<=1;i++) for(int j=-1;j<=1;j++){ float d=texture(uShadow, c.xy+vec2(i,j)*uShadowTexel).r; s += (c.z-0.0025>d)?0.0:1.0; }',
    ' return mix(0.35,1.0,s/9.0); }',
    'void main(){ vec3 N=normalize(vNor); float metal=vMat.x, rough=vMat.y, emi=vMat.z; vec3 vCol = mix(vCol0, uTint.rgb, uTint.a);',
    ' if(emi<-1.5){ o=vec4(vCol*0.8,1.0); return; }\n if(emi<-0.5){ o=vec4(vCol*1.6,1.0); return; }',
    ' float sh=shadow(); vec3 L1=-normalize(uKeyDir), L2=-normalize(uFillDir);',
    ' float d1=max(dot(N,L1),0.0), d2=max(dot(N,L2),0.0); float hemi=0.62+0.38*N.y;',
    ' vec3 diff = vCol*(uAmb*hemi + uKeyCol*d1*sh + uFillCol*d2) * (1.0-metal*0.45);',
    ' vec3 V=normalize(uCam-vWorld); vec3 H=normalize(L1+V); float shin=mix(90.0,6.0,rough);',
    ' float sp=pow(max(dot(N,H),0.0),shin)*(1.0-rough)*0.9; vec3 sc=mix(vec3(0.05),vCol,metal);',
    ' vec3 col = diff + sc*sp*uKeyCol*sh + vCol*emi;',
    ' float f=clamp((length(uCam-vWorld)-uFog.x)/(uFog.y-uFog.x),0.0,1.0); col=mix(col,uBg,f*f);',
    ' o=vec4(col,1.0); }'].join('\n');
  var DEPTH_VS = 'layout(location=0) in vec3 aPos; uniform mat4 uModel, uLightVP; void main(){ gl_Position=uLightVP*uModel*vec4(aPos,1.0); }';
  var DEPTH_FS = 'out vec4 o; void main(){ o=vec4(1.0); }';
  var FS_VS = 'out vec2 vUv; void main(){ vec2 p=vec2((gl_VertexID<<1)&2, gl_VertexID&2); vUv=p; gl_Position=vec4(p*2.0-1.0,0.0,1.0); }';
  var BRIGHT_FS = 'in vec2 vUv; out vec4 o; uniform sampler2D uTex; uniform float uThr; void main(){ vec3 c=texture(uTex,vUv).rgb; float l=max(c.r,max(c.g,c.b)); o=vec4(c*smoothstep(uThr,uThr+1.2,l),1.0); }';
  var BLUR_FS = 'in vec2 vUv; out vec4 o; uniform sampler2D uTex; uniform vec2 uDir; void main(){ vec3 c=texture(uTex,vUv).rgb*0.227;' +
    ' c+=texture(uTex,vUv+uDir*1.385).rgb*0.316; c+=texture(uTex,vUv-uDir*1.385).rgb*0.316;' +
    ' c+=texture(uTex,vUv+uDir*3.231).rgb*0.07; c+=texture(uTex,vUv-uDir*3.231).rgb*0.07; o=vec4(c,1.0); }';
  var COMP_FS = 'in vec2 vUv; out vec4 o; uniform sampler2D uTex, uBloom; uniform float uMix;' +
    ' vec3 aces(vec3 x){ return clamp((x*(2.51*x+0.03))/(x*(2.43*x+0.59)+0.14),0.0,1.0); }' +
    ' void main(){ vec3 c=texture(uTex,vUv).rgb + texture(uBloom,vUv).rgb*uMix; c=aces(c*1.05);' +
    ' c=pow(c,vec3(1.0/2.2)); vec2 d=vUv-0.5; c*=1.0-dot(d,d)*0.55; o=vec4(c,1.0); }';

  var progMain = compile(MAIN_VS, MAIN_FS), progDepth = compile(DEPTH_VS, DEPTH_FS),
    progBright = compile(FS_VS, BRIGHT_FS), progBlur = compile(FS_VS, BLUR_FS), progComp = compile(FS_VS, COMP_FS);
  var emptyVAO = gl.createVertexArray();

  // ------------------------------------------------------------------ 体素网格（四边形展开）
  var meshCache = {};
  function getMesh(id) {
    if (meshCache[id]) return meshCache[id];
    var md = MODELS[id]; if (!md) return null;
    var sc = md.scale, o = md.origin, nq = 0, mi, k;
    for (mi = 0; mi < md.mats.length; mi++) nq += md.mats[mi].q.length / 6;
    var data = new Float32Array(nq * 6 * 12), w = 0;
    var corner = [[0, 0], [1, 0], [1, 1], [0, 0], [1, 1], [0, 1]];
    for (mi = 0; mi < md.mats.length; mi++) {
      var mt = md.mats[mi], q = mt.q, col = [srgb2lin(mt.c[0]), srgb2lin(mt.c[1]), srgb2lin(mt.c[2])];
      for (k = 0; k < q.length; k += 6) {
        var face = q[k], axis = face >> 1, sign = (face & 1) ? -1 : 1, pl = q[k + 1];
        var u = (axis + 1) % 3, v = (axis + 2) % 3, uu = [q[k + 2], q[k + 4]], vv = [q[k + 3], q[k + 5]];
        var n = [0, 0, 0]; n[axis] = sign;
        for (var c = 0; c < 6; c++) {
          var pos = [0, 0, 0];
          pos[axis] = pl; pos[u] = uu[corner[c][0]]; pos[v] = vv[corner[c][1]];
          data[w++] = (pos[0] - o[0]) * sc; data[w++] = (pos[1] - o[1]) * sc; data[w++] = (pos[2] - o[2]) * sc;
          data[w++] = n[0]; data[w++] = n[1]; data[w++] = n[2];
          data[w++] = col[0]; data[w++] = col[1]; data[w++] = col[2];
          data[w++] = mt.m; data[w++] = mt.r; data[w++] = mt.e;
        }
      }
    }
    var mesh = createVAO(data);
    mesh.radius = 0.5 * Math.hypot(md.size[0], md.size[1], md.size[2]) * sc;
    mesh.height = md.size[1] * sc;
    meshCache[id] = mesh;
    return mesh;
  }
  function createVAO(data) {
    var vao = gl.createVertexArray(), buf = gl.createBuffer();
    gl.bindVertexArray(vao); gl.bindBuffer(gl.ARRAY_BUFFER, buf); gl.bufferData(gl.ARRAY_BUFFER, data, gl.STATIC_DRAW);
    var st = 48;
    gl.enableVertexAttribArray(0); gl.vertexAttribPointer(0, 3, gl.FLOAT, false, st, 0);
    gl.enableVertexAttribArray(1); gl.vertexAttribPointer(1, 3, gl.FLOAT, false, st, 12);
    gl.enableVertexAttribArray(2); gl.vertexAttribPointer(2, 3, gl.FLOAT, false, st, 24);
    gl.enableVertexAttribArray(3); gl.vertexAttribPointer(3, 3, gl.FLOAT, false, st, 36);
    gl.bindVertexArray(null);
    return { vao: vao, count: data.length / 12 };
  }
  // 星空：小立方体，不受光照（emissive = -1 标记）
  function buildStars(st) {
    var d = st.data, n = d.length / 5, data = new Float32Array(n * 36 * 12), w = 0;
    var faces = [[0, 1], [0, -1], [1, 1], [1, -1], [2, 1], [2, -1]], corner = [[0, 0], [1, 0], [1, 1], [0, 0], [1, 1], [0, 1]];
    for (var i = 0; i < n; i++) {
      var cx = d[i * 5], cy = d[i * 5 + 1], cz = d[i * 5 + 2], hs = d[i * 5 + 3] / 2, cc = st.colors[d[i * 5 + 4]];
      for (var f = 0; f < 6; f++) {
        var axis = faces[f][0], sg = faces[f][1], u = (axis + 1) % 3, v = (axis + 2) % 3;
        for (var c = 0; c < 6; c++) {
          var p = [0, 0, 0]; p[axis] = sg * hs; p[u] = corner[c][0] ? hs : -hs; p[v] = corner[c][1] ? hs : -hs;
          data[w++] = cx + p[0]; data[w++] = cy + p[1]; data[w++] = cz + p[2];
          data[w++] = 0; data[w++] = 1; data[w++] = 0;
          data[w++] = srgb2lin(cc[0]); data[w++] = srgb2lin(cc[1]); data[w++] = srgb2lin(cc[2]);
          data[w++] = 0; data[w++] = 1; data[w++] = -2;
        }
      }
    }
    return createVAO(data);
  }

  // ------------------------------------------------------------------ 渲染目标
  var RT = {};
  var SHADOW_SIZE = 2048;
  var shadowTex = gl.createTexture();
  gl.bindTexture(gl.TEXTURE_2D, shadowTex);
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.DEPTH_COMPONENT24, SHADOW_SIZE, SHADOW_SIZE, 0, gl.DEPTH_COMPONENT, gl.UNSIGNED_INT, null);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
  var shadowFBO = gl.createFramebuffer();
  gl.bindFramebuffer(gl.FRAMEBUFFER, shadowFBO);
  gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.TEXTURE_2D, shadowTex, 0);
  var shadowColor = gl.createRenderbuffer();
  gl.bindRenderbuffer(gl.RENDERBUFFER, shadowColor); gl.renderbufferStorage(gl.RENDERBUFFER, gl.RGBA8, SHADOW_SIZE, SHADOW_SIZE);
  gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.RENDERBUFFER, shadowColor);
  gl.bindFramebuffer(gl.FRAMEBUFFER, null);

  function colorTex(w, h) {
    var t = gl.createTexture(); gl.bindTexture(gl.TEXTURE_2D, t);
    gl.texImage2D(gl.TEXTURE_2D, 0, hdr ? gl.RGBA16F : gl.RGBA8, w, h, 0, gl.RGBA, hdr ? gl.HALF_FLOAT : gl.UNSIGNED_BYTE, null);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    var f = gl.createFramebuffer(); gl.bindFramebuffer(gl.FRAMEBUFFER, f);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, t, 0);
    return { tex: t, fbo: f, w: w, h: h };
  }
  function freeRT() {
    ['scene', 'bright', 'b1', 'b2'].forEach(function (k) { if (RT[k]) { gl.deleteTexture(RT[k].tex); gl.deleteFramebuffer(RT[k].fbo); } });
    if (RT.ms) { gl.deleteFramebuffer(RT.ms.fbo); gl.deleteRenderbuffer(RT.ms.col); gl.deleteRenderbuffer(RT.ms.dep); }
    RT = {};
  }
  function setupRT(w, h) {
    freeRT();
    RT.scene = colorTex(w, h);
    var samples = Math.min(4, gl.getParameter(gl.MAX_SAMPLES));
    var ms = { fbo: gl.createFramebuffer(), col: gl.createRenderbuffer(), dep: gl.createRenderbuffer() };
    gl.bindFramebuffer(gl.FRAMEBUFFER, ms.fbo);
    gl.bindRenderbuffer(gl.RENDERBUFFER, ms.col);
    gl.renderbufferStorageMultisample(gl.RENDERBUFFER, samples, hdr ? gl.RGBA16F : gl.RGBA8, w, h);
    gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.RENDERBUFFER, ms.col);
    gl.bindRenderbuffer(gl.RENDERBUFFER, ms.dep);
    gl.renderbufferStorageMultisample(gl.RENDERBUFFER, samples, gl.DEPTH_COMPONENT24, w, h);
    gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.RENDERBUFFER, ms.dep);
    if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) !== gl.FRAMEBUFFER_COMPLETE) console.warn('MSAA 帧缓冲不可用');
    RT.ms = ms;
    RT.bright = colorTex(Math.max(1, w >> 1), Math.max(1, h >> 1));
    RT.b1 = colorTex(Math.max(1, w >> 2), Math.max(1, h >> 2));
    RT.b2 = colorTex(Math.max(1, w >> 2), Math.max(1, h >> 2));
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    RT.w = w; RT.h = h;
  }


  // ------------------------------------------------------------------ 帧渲染
  // f = { env, eye, target, up, fov(度), aspect, near, far, draws:[{mesh,m,s}], stars:VAO|null, shadow:{range,center}|null }
  function render(f) {
    var env = f.env;
    var P = perspLH(f.fov * DEG, f.aspect, f.near || 0.1, f.far || 800), V = lookAtLH(f.eye, f.target, f.up || [0, 1, 0]), VP = m4mul(P, V);
    var kd = v3norm(env.key.dir), lightVP = m4(), shadowOn = f.shadow ? 1 : 0, i;
    var draws = f.draws;
    if (shadowOn) {
      var R = f.shadow.range, tgt = f.shadow.center, lpos = [tgt[0] - kd[0] * 60, tgt[1] - kd[1] * 60, tgt[2] - kd[2] * 60];
      var up = Math.abs(kd[1]) > 0.95 ? [0, 0, 1] : [0, 1, 0];
      lightVP = m4mul(orthoLH(R, R, 1, 140), lookAtLH(lpos, tgt, up));
      gl.bindFramebuffer(gl.FRAMEBUFFER, shadowFBO); gl.viewport(0, 0, SHADOW_SIZE, SHADOW_SIZE);
      gl.enable(gl.DEPTH_TEST); gl.disable(gl.CULL_FACE); gl.clear(gl.DEPTH_BUFFER_BIT | gl.COLOR_BUFFER_BIT);
      gl.useProgram(progDepth.p); gl.uniformMatrix4fv(progDepth.u.uLightVP, false, lightVP);
      for (i = 0; i < draws.length; i++) {
        gl.uniformMatrix4fv(progDepth.u.uModel, false, draws[i].m);
        gl.bindVertexArray(draws[i].mesh.vao); gl.drawArrays(gl.TRIANGLES, 0, draws[i].mesh.count);
      }
    }
    gl.bindFramebuffer(gl.FRAMEBUFFER, RT.ms.fbo); gl.viewport(0, 0, RT.w, RT.h);
    var bg = env.bg.map(srgb2lin);
    gl.clearColor(bg[0], bg[1], bg[2], 1); gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    gl.enable(gl.DEPTH_TEST); gl.disable(gl.CULL_FACE);
    var u = progMain.u; gl.useProgram(progMain.p);
    gl.uniformMatrix4fv(u.uVP, false, VP); gl.uniformMatrix4fv(u.uLightVP, false, lightVP);
    gl.uniform3fv(u.uKeyDir, kd); gl.uniform3fv(u.uFillDir, v3norm(env.fill.dir));
    gl.uniform3fv(u.uKeyCol, env.key.color.map(function (x) { return x * env.key.brightness; }));
    gl.uniform3fv(u.uFillCol, env.fill.color.map(function (x) { return x * env.fill.brightness; }));
    gl.uniform3fv(u.uAmb, env.ambient); gl.uniform3fv(u.uBg, bg); gl.uniform3fv(u.uCam, f.eye);
    gl.uniform2fv(u.uFog, env.fog || [5000, 9000]);
    gl.uniform1f(u.uShadowOn, shadowOn); gl.uniform1f(u.uShadowTexel, 1 / SHADOW_SIZE);
    gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D, shadowTex); gl.uniform1i(u.uShadow, 0);
    if (f.stars) {
      var sm = m4(); sm[12] = f.eye[0]; sm[13] = f.eye[1]; sm[14] = f.eye[2];
      gl.uniformMatrix4fv(u.uModel, false, sm); gl.uniform1f(u.uScale, 1);
      gl.bindVertexArray(f.stars.vao); gl.drawArrays(gl.TRIANGLES, 0, f.stars.count);
    }
    gl.uniform4f(u.uTint, 0, 0, 0, 0);
    for (i = 0; i < draws.length; i++) {
      var tn = draws[i].tint; if (tn) gl.uniform4f(u.uTint, tn[0], tn[1], tn[2], 1); else if (draws[i - 1] && draws[i - 1].tint) gl.uniform4f(u.uTint, 0, 0, 0, 0);
      gl.uniformMatrix4fv(u.uModel, false, draws[i].m); gl.uniform1f(u.uScale, draws[i].s);
      gl.bindVertexArray(draws[i].mesh.vao); gl.drawArrays(gl.TRIANGLES, 0, draws[i].mesh.count);
    }
    gl.bindFramebuffer(gl.READ_FRAMEBUFFER, RT.ms.fbo); gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER, RT.scene.fbo);
    gl.blitFramebuffer(0, 0, RT.w, RT.h, 0, 0, RT.w, RT.h, gl.COLOR_BUFFER_BIT, gl.NEAREST);
    gl.disable(gl.DEPTH_TEST);
    gl.bindFramebuffer(gl.FRAMEBUFFER, RT.bright.fbo); gl.viewport(0, 0, RT.bright.w, RT.bright.h);
    gl.useProgram(progBright.p); gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D, RT.scene.tex);
    gl.uniform1i(progBright.u.uTex, 0); gl.uniform1f(progBright.u.uThr, 1.0 + env.bloom.threshold * 0.6); drawFS();
    gl.useProgram(progBlur.p); gl.uniform1i(progBlur.u.uTex, 0);
    var src = RT.bright;
    for (var pass = 0; pass < bloomPasses; pass++) {
      gl.bindFramebuffer(gl.FRAMEBUFFER, RT.b1.fbo); gl.viewport(0, 0, RT.b1.w, RT.b1.h);
      gl.bindTexture(gl.TEXTURE_2D, src.tex); gl.uniform2f(progBlur.u.uDir, 1.6 / RT.b1.w, 0); drawFS();
      gl.bindFramebuffer(gl.FRAMEBUFFER, RT.b2.fbo);
      gl.bindTexture(gl.TEXTURE_2D, RT.b1.tex); gl.uniform2f(progBlur.u.uDir, 0, 1.6 / RT.b1.h); drawFS();
      src = RT.b2;
    }
    gl.bindFramebuffer(gl.FRAMEBUFFER, null); gl.viewport(0, 0, canvas.width, canvas.height);
    gl.useProgram(progComp.p);
    gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D, RT.scene.tex); gl.uniform1i(progComp.u.uTex, 0);
    gl.activeTexture(gl.TEXTURE1); gl.bindTexture(gl.TEXTURE_2D, RT.b2.tex); gl.uniform1i(progComp.u.uBloom, 1);
    gl.uniform1f(progComp.u.uMix, env.bloom.mix); drawFS();
    gl.activeTexture(gl.TEXTURE0);
    return VP;
  }
  function drawFS() { gl.bindVertexArray(emptyVAO); gl.drawArrays(gl.TRIANGLES, 0, 3); }
  var bloomPasses = 3;
  function resize(pw, ph, force) {
    if (force || canvas.width !== pw || canvas.height !== ph || !RT.scene) { canvas.width = pw; canvas.height = ph; setupRT(pw, ph); }
  }
  // 世界坐标 -> 屏幕像素（CSS 像素），在相机后方返回 null
  function project(VP, p, w, h) {
    var x = VP[0] * p[0] + VP[4] * p[1] + VP[8] * p[2] + VP[12];
    var y = VP[1] * p[0] + VP[5] * p[1] + VP[9] * p[2] + VP[13];
    var ww = VP[3] * p[0] + VP[7] * p[1] + VP[11] * p[2] + VP[15];
    if (ww <= 0.01) return null;
    return [(x / ww * 0.5 + 0.5) * w, (1 - (y / ww * 0.5 + 0.5)) * h, ww];
  }
  window.VoxEngine = { setBloomPasses: function (n) { bloomPasses = n; }, gl: gl, canvas: canvas, getMesh: getMesh, buildStars: buildStars, render: render, resize: resize,
    project: project, trs: trs, m4: m4, m4mul: m4mul, v3norm: v3norm, v3cross: v3cross, v3dot: v3dot, v3sub: v3sub, DEG: DEG };
})();

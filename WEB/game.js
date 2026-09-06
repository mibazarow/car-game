/* =====================================================================
   Patrol Rush — web version (HTML5 Canvas, vanilla JS).
   Faithful adaptation of the Godot original: 4-lane top-down police
   chase, traffic, nitro, rockets, win by hitting the fleeing car.
   Self-contained: drop this folder on any static host / iframe.
   ===================================================================== */
"use strict";

(function () {
  // ---------- canvas ----------
  const canvas = document.getElementById("game");
  const ctx = canvas.getContext("2d");
  const W = canvas.width, H = canvas.height;

  // ---------- DOM refs ----------
  const el = (id) => document.getElementById(id);
  const ui = {
    score: el("score"), best: el("best"),
    indNitro: el("ind-nitro"), indRocket: el("ind-rocket"),
    menu: el("menu"), paused: el("paused"), over: el("over"),
    menuBest: el("menu-best"),
    overTitle: el("over-title"), overScore: el("over-score"), overBest: el("over-best"),
  };

  // ---------- layout ----------
  const LANE_X = [120, 220, 320, 420];
  const ROAD_L = 70, ROAD_W = 400, ROAD_R = ROAD_L + ROAD_W;
  const DIVIDERS = [170, 270, 370];
  const PLAYER_Y = 850;
  const ENEMY_Y = 150;
  const SPAWN_Y = -160;
  const DANGER_TOP = 620, DANGER_BOT = 905;

  // ---------- tuning ----------
  const BASE_SPEED = 250;
  const SPEED_CAP = 450;
  const SPEED_PER_LEVEL = 26;
  const LEVEL_EVERY = 20;
  const NITRO_EVERY = 15;
  const ROCKET_AFTER = 4;
  const NITRO_TIME = 2.0;
  const NITRO_BOOST = 1.3;
  const ROCKET_SPEED = 800;
  const SPAWN_EVERY = 0.45;
  const MAX_PER_LANE = 2;
  const SPAWN_GAP = 170;

  const SIZE = {
    police: { w: 58, hw: 27, hl: 58 },
    sedan: { w: 56, hw: 26, hl: 55 },
    truck: { w: 76, hw: 38, hl: 105 },
  };
  const SEDAN_IMGS = ["car_blue.png", "car_yellow.png", "car_green.png"];
  const TRUCK_IMGS = ["truck_red.png", "truck_white.png"];
  const FORWARD = { sedan: [60, 150], truck: [15, 60] };

  // ---------- state ----------
  const G = {
    state: "loading",
    win: false,
    speed: BASE_SPEED,
    scroll: 0,
    score: 0,
    best: +(localStorage.getItem("patrol_best") || 0),
    level: 0,
    passed: 0,
    rocketArmed: false,
    rocketPassed: 0,
    nitroReady: false,
    nitroTime: 0,
    rocketReady: false,
    nitroActive: null,
    rocketActive: null,
    t: 0,
  };

  // ---------- entities ----------
  let player = null, enemy = null;
  const traffic = [], rockets = [], pickups = [], parts = [], trails = [];

  // ---------- assets ----------
  const IMG = {};
  function loadImage(src) {
    return new Promise((res, rej) => {
      const i = new Image();
      i.onload = () => res(i);
      i.onerror = rej;
      i.src = src;
    });
  }
  const IMAGE_FILES = [
    "car_police.png", "car_beige.png", "car_blue.png", "car_yellow.png",
    "car_green.png", "truck_red.png", "truck_white.png", "NITRO.png", "missle.png",
  ];

  const AUDIO = { ctx: null, engine: null };
  function setupAudio() {
    const AC = window.AudioContext || window.webkitAudioContext;
    if (AC) AUDIO.ctx = new AC();
    const eng = new Audio("assets/toyota-supra-turbo-car.mp3");
    eng.loop = true; eng.volume = 0.32; AUDIO.engine = eng;
  }
  function unlockAudio() {
    if (AUDIO.ctx && AUDIO.ctx.state === "suspended") AUDIO.ctx.resume();
  }
  function playNitro() {
    if (!AUDIO.ctx) return;
    const req = new XMLHttpRequest();
    req.open("GET", "assets/nitro.wav", true);
    req.responseType = "arraybuffer";
    req.onload = () => {
      AUDIO.ctx.decodeAudioData(req.response, (buf) => {
        const s = AUDIO.ctx.createBufferSource();
        s.buffer = buf;
        const g = AUDIO.ctx.createGain(); g.gain.value = 0.5;
        s.connect(g); g.connect(AUDIO.ctx.destination); s.start();
      }, () => {});
    };
    req.send();
  }

  // ---------- helpers ----------
  function rand(a, b) { return a + Math.random() * (b - a); }
  function lerp(a, b, t) { return a + (b - a) * t; }
  function clamp(v, a, b) { return v < a ? a : v > b ? b : v; }
  function closestLane(x) {
    let bi = 0, bd = 1e9;
    for (let i = 0; i < LANE_X.length; i++) {
      const d = Math.abs(LANE_X[i] - x);
      if (d < bd) { bd = d; bi = i; }
    }
    return bi;
  }

  // ---------- car factory ----------
  function makeCar(lane, kind, imgKey, x, y, vy, down) {
    const s = SIZE[kind];
    return {
      lane, kind, img: IMG[imgKey] || null,
      x, y, vy, down,
      hw: s.hw, hl: s.hl,
      curX: x, targetX: x, bank: 0, yaw: 0, surge: 0, counted: false, timer: 0,
    };
  }

  // ---------- state / screens ----------
  function setState(s) {
    G.state = s;
    ui.menu.classList.toggle("hidden", s !== "menu");
    ui.paused.classList.toggle("hidden", s !== "paused");
    ui.over.classList.toggle("hidden", s !== "over");
    if (AUDIO.engine) {
      const want = (s === "playing" || s === "paused");
      if (want && AUDIO.engine.paused) AUDIO.engine.play().catch(() => {});
      if (!want && !AUDIO.engine.paused) AUDIO.engine.pause();
    }
  }

  function startGame() {
    G.win = false;
    G.score = 0; G.speed = BASE_SPEED; G.level = 0; G.scroll = 0;
    G.passed = 0; G.rocketArmed = false; G.rocketPassed = 0;
    G.nitroReady = false; G.nitroTime = 0; G.rocketReady = false;
    G.nitroActive = null; G.rocketActive = null;
    traffic.length = 0; rockets.length = 0; pickups.length = 0; parts.length = 0; trails.length = 0;

    player = makeCar(1, "police", "car_police.png", LANE_X[1], PLAYER_Y, 0, false);
    enemy = makeCar(1, "sedan", "car_beige.png", LANE_X[1], ENEMY_Y, 0, false);
    enemy.lane = 1; enemy.timer = rand(0.5, 1.4);
    ui.score.textContent = "Score: 0";
    setState("playing");
  }

  function goMenu() {
    traffic.length = 0; rockets.length = 0; pickups.length = 0; parts.length = 0; trails.length = 0;
    setState("menu");
    ui.menuBest.textContent = G.best > 0 ? "Рекорд: " + G.best : "";
  }
  function pauseGame() { if (G.state === "playing") setState("paused"); }
  function resumeGame() { if (G.state === "paused") setState("playing"); }

  function endGame(win) {
    if (G.state !== "playing") return;
    G.win = win;
    if (win) boom(enemy.x, enemy.y);
    if (G.score > G.best) { G.best = G.score; localStorage.setItem("patrol_best", String(G.best)); }
    ui.overTitle.innerHTML = win ? "ПОБЕДА!<br>Поздравляем, вы победили!" : "GAME OVER";
    ui.overTitle.style.color = win ? "#ffd23f" : "#ff5b4d";
    ui.overScore.textContent = "Score: " + G.score;
    ui.overBest.textContent = "Best: " + G.best;
    setState("over");
  }

  // ---------- score / item economy ----------
  function addScore() {
    G.score++;
    ui.score.textContent = "Score: " + G.score;
    const lvl = Math.floor(G.score / LEVEL_EVERY);
    if (lvl > G.level) { G.level = lvl; G.speed = Math.min(G.speed + SPEED_PER_LEVEL, SPEED_CAP); }
    G.passed++;
    if (G.passed >= NITRO_EVERY) {
      G.passed = 0;
      spawnPickup("nitro");
      G.rocketArmed = true; G.rocketPassed = 0;
    } else if (G.rocketArmed) {
      G.rocketPassed++;
      if (G.rocketPassed >= ROCKET_AFTER) { G.rocketArmed = false; spawnPickup("rocket"); }
    }
  }

  function spawnPickup(kind) {
    const lane = (Math.random() * 4) | 0;
    if (kind === "nitro") {
      if (G.nitroActive) return;
      const p = { kind, lane, x: LANE_X[lane], y: -90, img: IMG["NITRO.png"] };
      pickups.push(p); G.nitroActive = p;
    } else {
      if (G.rocketActive) return;
      const p = { kind, lane, x: LANE_X[lane], y: -90, img: IMG["missle.png"] };
      pickups.push(p); G.rocketActive = p;
    }
  }

  // ---------- explosion ----------
  function boom(x, y) {
    const cols = ["#fff2a0", "#ffb347", "#ff6a3d", "#ff2e2e", "#ffffff"];
    for (let i = 0; i < 80; i++) {
      const a = Math.random() * Math.PI * 2;
      const sp = 50 + Math.random() * 260;
      parts.push({ x, y, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 70,
                   life: rand(0.5, 1.4), max: 1.4, size: rand(2, 7),
                   col: cols[(Math.random() * cols.length) | 0] });
    }
  }

  // ---------- traffic ----------
  let spawnAcc = 0;
  function trySpawn(dt) {
    spawnAcc += dt;
    if (spawnAcc < SPAWN_EVERY || G.state !== "playing") return;
    spawnAcc = 0;
    for (let t = 0; t < 5; t++) {
      const lane = (Math.random() * 4) | 0;
      const inLane = traffic.filter((c) => c.lane === lane);
      if (inLane.length >= MAX_PER_LANE) continue;
      let leader = null;
      for (const c of inLane) if (!leader || c.y > leader.y) leader = c;
      if (leader && leader.y < SPAWN_Y + SPAWN_GAP) continue;
      const isTruck = Math.random() < 0.3;
      const img = isTruck ? TRUCK_IMGS[(Math.random() * 2) | 0] : SEDAN_IMGS[(Math.random() * 3) | 0];
      const kind = isTruck ? "truck" : "sedan";
      const fwd = rand(FORWARD[kind][0], FORWARD[kind][1]);
      const boost = G.nitroTime > 0 ? NITRO_BOOST : 1;
      const vy = leader ? leader.vy : Math.max(30, G.speed * boost - fwd);
      traffic.push(makeCar(lane, kind, img, LANE_X[lane], SPAWN_Y, vy, true));
      return;
    }
  }

  function moveTraffic(dt) {
    traffic.sort((a, b) => b.y - a.y); // front-most (largest y) first
    for (let i = 0; i < traffic.length; i++) {
      const c = traffic[i];
      let nextY = c.y + c.vy * dt;
      const ahead = traffic.find((o) => o !== c && o.lane === c.lane && o.y > c.y);
      if (ahead) {
        const maxY = ahead.y - (c.hl + ahead.hl) - 14;
        if (nextY > maxY) nextY = maxY;
      }
      if (c.y < DANGER_TOP && nextY >= DANGER_TOP) {
        const band = traffic.filter((o) => o !== c && o.y >= DANGER_TOP && o.y <= DANGER_BOT);
        const cnt = band.length;
        const adj = band.some((o) => Math.abs(o.lane - c.lane) === 1);
        if (cnt >= 2 || adj) nextY = DANGER_TOP - 1;
      }
      c.y = Math.max(nextY, c.y);
      if (c.y - c.hl > PLAYER_Y + 24 && !c.counted) { c.counted = true; addScore(); }
    }
    for (let i = traffic.length - 1; i >= 0; i--) {
      if (traffic[i].y - traffic[i].hl > H + 80) traffic.splice(i, 1);
    }
  }

  // ---------- enemy AI ----------
  function enemyBlocked(lane) {
    return traffic.some((c) => c.lane === lane &&
      c.y > ENEMY_Y - 80 && c.y < ENEMY_Y + 150 && Math.abs(c.x - LANE_X[lane]) < 30);
  }
  function enemyPick(avoid) {
    const free = [];
    for (let i = 0; i < 4; i++) { if (!(avoid && i === enemy.lane) && !enemyBlocked(i)) free.push(i); }
    return free.length ? free[(Math.random() * free.length) | 0] : enemy.lane;
  }
  function moveEnemy(dt) {
    if (enemyBlocked(enemy.lane)) {
      enemy.lane = enemyPick(true);
      enemy.timer = rand(0.6, 1.4);
    } else {
      enemy.timer -= dt;
      if (enemy.timer <= 0) { enemy.lane = enemyPick(false); enemy.timer = rand(1.2, 2.6); }
    }
    const tx = LANE_X[enemy.lane];
    enemy.curX = lerp(enemy.curX, tx, 1 - Math.exp(-7 * dt));
    const d = tx - enemy.curX;
    enemy.x = enemy.curX;
    enemy.bank = clamp(d * 0.01, -0.35, 0.35);
  }

  // ---------- player ----------
  function fireRocket() {
    if (!G.rocketReady) return;
    G.rocketReady = false;
    ui.indRocket.classList.remove("on");
    rockets.push({ x: player.x, y: player.y - 60, img: IMG["missle.png"] });
  }
  function moveRockets(dt) {
    for (let i = rockets.length - 1; i >= 0; i--) {
      const r = rockets[i];
      r.y -= 800 * dt;
      r.x += Math.sin(G.t * 40 + i * 2) * 2;
      let dead = r.y < -160;
      if (!dead && Math.abs(r.x - enemy.x) < 34 && Math.abs(r.y - enemy.y) < 60) {
        endGame(true);
        return;
      }
      if (!dead) {
        for (const c of traffic) {
          if (Math.abs(c.x - r.x) < c.hw + 14 && r.y > c.y - 40 && r.y < c.y + 40) { dead = true; break; }
        }
      }
      if (dead) rockets.splice(i, 1);
    }
  }

  function movePickups(dt) {
    const scroll = G.speed * (G.nitroTime > 0 ? NITRO_BOOST : 1);
    for (const p of pickups) p.y += scroll * dt;
    for (let i = pickups.length - 1; i >= 0; i--) {
      const p = pickups[i];
      if (p.y > H + 80) { pickups.splice(i, 1); if (G.nitroActive === p) G.nitroActive = null; if (G.rocketActive === p) G.rocketActive = null; continue; }
      if (Math.abs(p.y - PLAYER_Y) < 50 && Math.abs(p.x - player.x) < 44) {
        pickups.splice(i, 1);
        if (p.kind === "nitro") { G.nitroReady = true; G.nitroActive = null; }
        else { G.rocketReady = true; G.rocketActive = null; }
      }
    }
    ui.indNitro.classList.toggle("on", G.nitroReady);
    ui.indRocket.classList.toggle("on", G.rocketReady);
  }

  function movePlayer(dt) {
    if (wantLeft) player.targetX = LANE_X[Math.max(0, player.lane - 1)];
    if (wantRight) player.targetX = LANE_X[Math.min(3, player.lane + 1)];
    player.lane = closestLane(player.targetX);

    if (wantNitro && G.nitroReady) {
      G.nitroReady = false; G.nitroTime = NITRO_TIME;
      playNitro(); ui.indNitro.classList.remove("on");
    }
    wantNitro = false;
    if (wantFire) { fireRocket(); wantFire = false; }

    if (G.nitroTime > 0) { G.nitroTime -= dt; trails.push({ x: player.x + rand(-26, 26), y: player.y + 20, life: 0.4 }); }

    const oldX = player.x;
    player.curX = lerp(player.curX, player.targetX, 1 - Math.exp(-11 * dt));
    player.x = player.curX;
    const latV = (player.x - oldX) / Math.max(dt, 1e-4);
    player.bank = clamp(-latV * 0.0009, -0.16, 0.16);
    player.yaw = clamp(latV * 0.00055, -0.5, 0.5);
    player.surge = lerp(player.surge, G.nitroTime > 0 ? -46 : 0, 1 - Math.exp(-2.5 * dt));

    if (G.nitroTime > 0) trails.forEach((tr) => {});
    // crash
    for (const c of traffic) {
      if (Math.abs(c.x - player.x) < c.hw + player.hw &&
          Math.abs((c.y) - (player.y + player.surge)) < c.hl + player.hl) {
        endGame(false);
        return;
      }
    }
  }

  // ---------- input ----------
  let wantLeft = false, wantRight = false, wantFire = false, wantNitro = false;
  function down(e) {
    unlockAudio();
    const k = e.code;
    if (["ArrowLeft", "ArrowRight", "Space", "Enter"].includes(k)) e.preventDefault();
    if (G.state === "menu") { if (k === "Enter" || k === "Space") startGame(); return; }
    if (G.state === "playing") {
      if (k === "ArrowLeft" || k === "KeyA") wantLeft = true;
      else if (k === "ArrowRight" || k === "KeyD") wantRight = true;
      else if (k === "Space") wantNitro = true;
      else if (k === "Enter") wantFire = true;
      else if (k === "KeyP" || k === "Escape") pauseGame();
    } else if (G.state === "paused") {
      if (k === "KeyP" || k === "Escape" || k === "Enter") resumeGame();
      else if (k === "KeyR") startGame();
    } else if (G.state === "over") {
      if (k === "Enter" || k === "KeyR") startGame();
    }
  }
  function up(e) {
    const k = e.code;
    if (k === "ArrowLeft" || k === "KeyA") wantLeft = false;
    else if (k === "ArrowRight" || k === "KeyD") wantRight = false;
    else if (k === "Space") wantNitro = false;
    else if (k === "Enter") wantFire = false;
  }
  window.addEventListener("keydown", down);
  window.addEventListener("keyup", up);
  window.addEventListener("pointerdown", unlockAudio);
  el("btn-play").onclick = () => { unlockAudio(); startGame(); };
  el("btn-resume").onclick = resumeGame;
  el("btn-restart-p").onclick = startGame;
  el("btn-restart").onclick = startGame;
  el("btn-menu").onclick = goMenu;

  // ---------- responsive ----------
  function fit() {
    const s = Math.min(window.innerWidth / 540, window.innerHeight / 960, 1);
    el("frame").style.transform = "scale(" + s + ")";
  }
  window.addEventListener("resize", fit);

  // ---------- drawing ----------
  function drawRoad() {
    if (G.state === "playing") {
      const boost = G.nitroTime > 0 ? NITRO_BOOST : 1;
      G.scroll += G.speed * boost * dt;
    }

    ctx.fillStyle = "#1e2f1a"; ctx.fillRect(0, 0, W, H);
    ctx.fillStyle = "#22361e";
    for (let x = 8; x < ROAD_L - 22; x += 26) ctx.fillRect(x, 0, 9, H);
    for (let x = ROAD_R + 16; x < W - 10; x += 26) ctx.fillRect(x, 0, 9, H);

    ctx.fillStyle = "#2b2b2e"; ctx.fillRect(ROAD_L, 0, ROAD_W, H);
    // moving asphalt bands
    ctx.fillStyle = "rgba(0,0,0,0.10)";
    const band = 130, bk = G.scroll % band;
    for (let y = bk - band; y < H + band; y += band) ctx.fillRect(ROAD_L, y, ROAD_W, 24);

    // dashed dividers
    ctx.fillStyle = "rgba(255,255,255,0.8)";
    const period = 110, len = 46, off = G.scroll % period;
    for (const dx of DIVIDERS)
      for (let y = off - period; y < H + period; y += period) ctx.fillRect(dx - 1.5, y, 3, len);

    // yellow edges
    ctx.fillStyle = "#cfb520";
    ctx.fillRect(ROAD_L - 2, 0, 3, H);
    ctx.fillRect(ROAD_R - 1, 0, 3, H);
  }

  function drawCar(c, extra) {
    if (!c.img) return;
    const s = SIZE[c.kind];
    const h = s.w * (c.img.height / c.img.width);
    ctx.save();
    ctx.translate(c.x, c.y);
    const ang = (extra && extra.ang) || 0;
    if (ang) ctx.rotate(ang);
    // NOTE: no manual flip/rotation here — sprites are supplied already oriented.
    ctx.drawImage(c.img, -s.w / 2, -h / 2, s.w, h);
    ctx.restore();
  }

  function draw() {
    drawRoad();

    for (const p of pickups) {
      if (!p.img) continue;
      if (p.kind === "nitro") {
        ctx.drawImage(p.img, p.x - 22, p.y - 22, 44, 44);
      } else {
        const a = p.img.height / p.img.width, w = 26, h = w * a;
        ctx.drawImage(p.img, p.x - w / 2, p.y - h / 2, w, h);
      }
    }

    for (const c of traffic) drawCar(c);
    if (enemy) drawCar(enemy, { ang: enemy.bank });
    if (player) {
      const s = SIZE.police;
      const h = s.w * (player.img.height / player.img.width);
      ctx.save();
      ctx.translate(player.x, player.y + player.surge);
      if (G.nitroTime > 0) {
        ctx.globalAlpha = 0.5; ctx.fillStyle = "#ffd23f";
        ctx.beginPath(); ctx.arc(0, 30, 20, 0, Math.PI * 2); ctx.fill(); ctx.globalAlpha = 1;
      }
      ctx.rotate(player.bank + player.yaw);
      ctx.drawImage(player.img, -s.w / 2, -h / 2, s.w, h);
      ctx.restore();
    }

    // rockets
    for (const r of rockets) if (r.img) ctx.drawImage(r.img, r.x - 20, r.y - 44, 40, 88);

    // nitro trails
    for (let i = trails.length - 1; i >= 0; i--) {
      const tr = trails[i];
      tr.life -= dt; tr.y += 240 * dt;
      if (tr.life <= 0) { trails.splice(i, 1); continue; }
      ctx.globalAlpha = tr.life * 0.8; ctx.strokeStyle = "#ffd23f"; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(tr.x, tr.y); ctx.lineTo(tr.x, tr.y + 24); ctx.stroke();
    }
    ctx.globalAlpha = 1;

    // explosion
    for (let i = parts.length - 1; i >= 0; i--) {
      const p = parts[i];
      p.life -= dt;
      if (p.life <= 0) { parts.splice(i, 1); continue; }
      p.x += p.vx * dt; p.y += p.vy * dt; p.vy += 240 * dt;
      ctx.globalAlpha = clamp(p.life / p.max, 0, 1);
      ctx.fillStyle = p.col;
      ctx.beginPath(); ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2); ctx.fill();
    }
    ctx.globalAlpha = 1;
  }

  // ---------- loop ----------
  let last = 0, dt = 1 / 60;
  function frame(now) {
    requestAnimationFrame(frame);
    dt = Math.min(0.033, ((now || 0) - last) / 1000 || 1 / 60);
    last = now || 0;
    G.t += dt;
    if (G.state === "playing") {
      movePlayer(dt);
      if (G.state === "playing") {
        trySpawn(dt);
        moveTraffic(dt);
        moveEnemy(dt);
        movePickups(dt);
        moveRockets(dt);
        ui.best.textContent = "Best: " + G.best;
      }
    }
    draw();
  }

  // ---------- boot ----------
  async function boot() {
    for (const f of IMAGE_FILES) {
      try { IMG[f] = await loadImage("assets/" + f); } catch (e) { console.warn("no image", f); }
    }
    setupAudio();
    fit();
    goMenu();
    requestAnimationFrame(frame);
  }
  boot();
})();

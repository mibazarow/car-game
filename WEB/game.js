/* =====================================================================
   Patrol Rush — web version (HTML5 Canvas, vanilla JS).
   Faithful adaptation of the Godot original: 4-lane top-down police
   chase, traffic, nitro, rockets, win by hitting the fleeing car.
   Self-contained: drop this folder on any static host / iframe.

   ASSET RULES (see WEB/README.md):
   - Sprites are supplied ALREADY ORIENTED; the code never flips/rotates
     cars manually.
   - Hitbox of each vehicle is derived from its PNG size: all cars share a
     lane-fitting width, but length comes from the PNG aspect (a truck is
     longer -> its hitbox is longer), so a small car's hitbox can never be
     applied to a truck's rear.
   - Player = police_topdown.png (fixed). The fleeing enemy is a RANDOM
     passenger car each run (never a truck), and that car is excluded from
     traffic for that run.
   ===================================================================== */
"use strict";

(function () {
  const canvas = document.getElementById("game");
  const ctx = canvas.getContext("2d");
  const W = canvas.width, H = canvas.height;

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
  const BASE_SPEED = 200, SPEED_CAP = 400, SPEED_PER_LEVEL = 9, LEVEL_EVERY = 7, SPEED_RAMP = 0.6;
  const NITRO_EVERY = 15, ROCKET_AFTER = 4, NITRO_TIME = 2.0, NITRO_BOOST = 1.3;
  const ROCKET_SPEED = 800;
  const SPAWN_EVERY = 0.78, MAX_PER_LANE = 2, SPAWN_GAP = 200;

  // ---------- assets / mapping ----------
  const POLICE_FILE = "police_topdown.png";
  const CAR_FILES = ["car_blue_sedan.png", "car_yellow_compact.png", "car_red_sports.png", "car_black_suv.png"];
  const TRUCK_FILES = ["truck_topdown.png", "truck2_topdown.png"];
  const NITRO_FILE = "nitro.png";
  const ROCKET_FILE = "rocket.png";

  // render width (px) per sprite so all fit a lane; length comes from aspect
  const FILE_W = {
    "police_topdown.png": 60,
    "car_blue_sedan.png": 56, "car_yellow_compact.png": 56,
    "car_red_sports.png": 56, "car_black_suv.png": 62,
    "truck_topdown.png": 86, "truck2_topdown.png": 86,
  };
  const TRUCK_FWD = [15, 60], CAR_FWD = [60, 150];

  // ---------- state ----------
  const G = {
    state: "loading", win: false,
    speed: BASE_SPEED, speedTarget: BASE_SPEED, scroll: 0, score: 0,
    best: +(localStorage.getItem("patrol_best") || 0),
    level: 0, passed: 0, rocketArmed: false, rocketPassed: 0,
    nitroReady: false, nitroTime: 0, rocketReady: false,
    nitroActive: null, rocketActive: null,
    enemyFile: CAR_FILES[0], t: 0,
  };

  // ---------- entities ----------
  let player = null, enemy = null;
  const traffic = [], rockets = [], pickups = [], parts = [], trails = [];

  // ---------- image loading ----------
  const IMG = {};
  let asphalt = null;   // road texture tile (optional)
  const LOAD_FILES = [POLICE_FILE, NITRO_FILE, ROCKET_FILE].concat(CAR_FILES, TRUCK_FILES);
  function loadImage(src) {
    return new Promise((res, rej) => {
      const i = new Image();
      i.onload = () => res(i);
      i.onerror = rej;
      i.src = src;
    });
  }

  // ---------- audio ----------
  const AUDIO = { ctx: null, engine: null };
  function setupAudio() {
    const AC = window.AudioContext || window.webkitAudioContext;
    if (AC) AUDIO.ctx = new AC();
    const eng = new Audio("assets/toyota-supra-turbo-car.mp3");
    eng.loop = true; eng.volume = 0.32; AUDIO.engine = eng;
  }
  function unlockAudio() { if (AUDIO.ctx && AUDIO.ctx.state === "suspended") AUDIO.ctx.resume(); }
  function playNitro() {
    if (!AUDIO.ctx) return;
    const req = new XMLHttpRequest();
    req.open("GET", "assets/nitro.wav", true); req.responseType = "arraybuffer";
    req.onload = () => AUDIO.ctx.decodeAudioData(req.response, (buf) => {
      const s = AUDIO.ctx.createBufferSource(); s.buffer = buf;
      const g = AUDIO.ctx.createGain(); g.gain.value = 0.5;
      s.connect(g); g.connect(AUDIO.ctx.destination); s.start();
    }, () => {});
    req.send();
  }

  // ---------- helpers ----------
  const rand = (a, b) => a + Math.random() * (b - a);
  const lerp = (a, b, t) => a + (b - a) * t;
  const clamp = (v, a, b) => v < a ? a : v > b ? b : v;
  function closestLane(x) {
    let bi = 0, bd = 1e9;
    for (let i = 0; i < LANE_X.length; i++) { const d = Math.abs(LANE_X[i] - x); if (d < bd) { bd = d; bi = i; } }
    return bi;
  }

  // ---------- vehicle factory (hitbox from PNG size) ----------
  function vehicle(lane, file, x, y, vy, down) {
    const img = IMG[file];
    const rw = FILE_W[file] || 56;
    const aspect = img ? img.height / img.width : 2;
    const h = rw * aspect;
    return {
      lane, file, img, x, y, vy, down, rw,
      hw: rw * 0.44, hl: h * 0.49,   // hitbox derived from PNG
      curX: x, targetX: x, bank: 0, yaw: 0, turn: 0, surge: 0,
      counted: false, timer: 0,
    };
  }
  function aspectOf(file) {
    const img = IMG[file];
    return img ? img.height / img.width : 2;
  }

  // ---------- screens / state ----------
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
    G.score = 0; G.speed = BASE_SPEED; G.speedTarget = BASE_SPEED; G.level = 0; G.scroll = 0;
    G.passed = 0; G.rocketArmed = false; G.rocketPassed = 0;
    G.nitroReady = false; G.nitroTime = 0; G.rocketReady = false;
    G.nitroActive = null; G.rocketActive = null;
    traffic.length = 0; rockets.length = 0; pickups.length = 0; parts.length = 0; trails.length = 0;

    // random enemy this run (a passenger car, never a truck)
    G.enemyFile = CAR_FILES[(Math.random() * CAR_FILES.length) | 0];

    player = vehicle(1, POLICE_FILE, LANE_X[1], PLAYER_Y, 0, false);
    enemy = vehicle(1, G.enemyFile, LANE_X[1], ENEMY_Y, 0, false);
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

  // ---------- score / economy ----------
  function addScore() {
    G.score++;
    ui.score.textContent = "Score: " + G.score;
    const lvl = Math.floor(G.score / LEVEL_EVERY);
    if (lvl > G.level) {
      G.level = lvl;
      G.speedTarget = Math.min(G.speedTarget + SPEED_PER_LEVEL, SPEED_CAP); // smooth toward this later
    }
    G.passed++;
    if (G.passed >= NITRO_EVERY) { G.passed = 0; spawnPickup("nitro"); G.rocketArmed = true; G.rocketPassed = 0; }
    else if (G.rocketArmed) { G.rocketPassed++; if (G.rocketPassed >= ROCKET_AFTER) { G.rocketArmed = false; spawnPickup("rocket"); } }
  }

  function spawnPickup(kind) {
    const lane = (Math.random() * 4) | 0;
    if (kind === "nitro") {
      if (G.nitroActive) return;
      pickups.push({ kind, lane, x: LANE_X[lane], y: -90, file: NITRO_FILE, img: IMG[NITRO_FILE] });
      G.nitroActive = pickups[pickups.length - 1];
    } else {
      if (G.rocketActive) return;
      pickups.push({ kind, lane, x: LANE_X[lane], y: -90, file: ROCKET_FILE, img: IMG[ROCKET_FILE] });
      G.rocketActive = pickups[pickups.length - 1];
    }
  }

  // ---------- explosion ----------
  function boom(x, y) {
    const cols = ["#fff2a0", "#ffb347", "#ff6a3d", "#ff2e2e", "#ffffff"];
    for (let i = 0; i < 80; i++) {
      const a = Math.random() * Math.PI * 2, sp = 50 + Math.random() * 260;
      parts.push({ x, y, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 70,
                   life: rand(0.5, 1.4), max: 1.4, size: rand(2, 7),
                   col: cols[(Math.random() * cols.length) | 0] });
    }
  }

  // ---------- traffic ----------
  let spawnAcc = 0;
  let lastTraffic = null;      // avoid the same model twice in a row
  const TRUCK_CHANCE = 0.13;   // fraction of spawns that are trucks
  function trafficChoice() {
    const cars = CAR_FILES.filter((f) => f !== G.enemyFile); // exclude this run's enemy
    for (let t = 0; t < 3; t++) {
      const truck = Math.random() < TRUCK_CHANCE;
      const f = truck
        ? TRUCK_FILES[(Math.random() * TRUCK_FILES.length) | 0]
        : cars[(Math.random() * cars.length) | 0];
      if (f !== lastTraffic) { lastTraffic = f; return f; }
    }
    const truck = Math.random() < TRUCK_CHANCE;
    return truck ? TRUCK_FILES[(Math.random() * TRUCK_FILES.length) | 0]
                 : cars[(Math.random() * cars.length) | 0];
  }
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
      const file = trafficChoice();
      const isTruck = TRUCK_FILES.includes(file);
      const fwd = rand((isTruck ? TRUCK_FWD : CAR_FWD)[0], (isTruck ? TRUCK_FWD : CAR_FWD)[1]);
      const boost = G.nitroTime > 0 ? NITRO_BOOST : 1;
      const vy = leader ? leader.vy : Math.max(30, G.speed * boost - fwd);
      traffic.push(vehicle(lane, file, LANE_X[lane], SPAWN_Y, vy, true));
      return;
    }
  }

  function moveTraffic(dt) {
    traffic.sort((a, b) => b.y - a.y);
    for (let i = 0; i < traffic.length; i++) {
      const c = traffic[i];
      let nextY = c.y + c.vy * dt;
      const ahead = traffic.find((o) => o !== c && o.lane === c.lane && o.y > c.y);
      if (ahead) { const maxY = ahead.y - (c.hl + ahead.hl) - 14; if (nextY > maxY) nextY = maxY; }
      if (c.y < DANGER_TOP && nextY >= DANGER_TOP) {
        // Anti-wall: at most ONE car near the player row at a time, so there is
        // always a free lane to dodge into (no side-by-side/stacked wall).
        const band = traffic.filter((o) => o !== c && o.y >= DANGER_TOP && o.y <= DANGER_BOT);
        if (band.length >= 1) nextY = DANGER_TOP - 1;
      }
      c.y = Math.max(nextY, c.y);
      if (c.y - c.hl > PLAYER_Y + 24 && !c.counted) { c.counted = true; addScore(); }
    }
    for (let i = traffic.length - 1; i >= 0; i--)
      if (traffic[i].y - traffic[i].hl > H + 80) traffic.splice(i, 1);
  }

  // ---------- enemy AI (never overlaps traffic) ----------
  // Free horizontal distance (px) from the enemy row to the nearest traffic car
  // in a lane. 1e6 = lane empty nearby.
  function laneClearance(lane) {
    let best = 1e6, found = false;
    for (const c of traffic) {
      if (c.lane !== lane) continue;
      const top = c.y - c.hl, bot = c.y + c.hl;
      let d;
      if (bot < ENEMY_Y - 24) d = ENEMY_Y - bot;        // above, approaching
      else if (top > ENEMY_Y + 24) d = top - ENEMY_Y;   // below, already passed
      else d = 0;                                        // overlapping the row now
      best = Math.min(best, d); found = true;
    }
    return found ? best : 1e6;
  }
  function bestLane() {
    let li = 0, bv = -1;
    for (let i = 0; i < 4; i++) { const v = laneClearance(i); if (v > bv) { bv = v; li = i; } }
    return li;
  }
  function moveEnemy(dt) {
    const EMERGENCY = 200; // dodge when a car is within this many px (above) of the enemy row
    if (laneClearance(enemy.lane) < EMERGENCY) {
      enemy.lane = bestLane();
      enemy.timer = rand(0.5, 1.2);
    } else {
      enemy.timer -= dt;
      if (enemy.timer <= 0) {
        // wander to a roomy lane different from the current one
        const cand = [];
        for (let i = 0; i < 4; i++) if (i !== enemy.lane && laneClearance(i) > 240) cand.push(i);
        if (cand.length) enemy.lane = cand[(Math.random() * cand.length) | 0];
        enemy.timer = rand(1.2, 2.6);
      }
    }
    const tx = LANE_X[enemy.lane];
    enemy.curX = lerp(enemy.curX, tx, 1 - Math.exp(-7 * dt));
    enemy.x = enemy.curX;
    enemy.bank = clamp((tx - enemy.curX) * 0.01, -0.35, 0.35);
  }

  // ---------- rockets ----------
  function fireRocket() {
    if (!G.rocketReady) return;
    G.rocketReady = false;
    ui.indRocket.classList.remove("on");
    rockets.push({ x: player.x, y: player.y - 50, file: ROCKET_FILE, img: IMG[ROCKET_FILE] });
  }
  function moveRockets(dt) {
    for (let i = rockets.length - 1; i >= 0; i--) {
      const r = rockets[i];
      r.y -= ROCKET_SPEED * dt;
      r.x += Math.sin(G.t * 40 + i * 2) * 2;
      let dead = r.y < -160;
      if (!dead && Math.abs(r.x - enemy.x) < enemy.hw + 6 &&
          Math.abs(r.y - enemy.y) < enemy.hl) { endGame(true); return; }
      if (!dead) {
        for (const c of traffic)
          if (Math.abs(c.x - r.x) < c.hw + 10 && r.y > c.y - 60 && r.y < c.y + 60) { dead = true; break; }
      }
      if (dead) rockets.splice(i, 1);
    }
  }

  function movePickups(dt) {
    const scroll = G.speed * (G.nitroTime > 0 ? NITRO_BOOST : 1);
    for (const p of pickups) p.y += scroll * dt;
    for (let i = pickups.length - 1; i >= 0; i--) {
      const p = pickups[i];
      if (p.y > H + 80) {
        pickups.splice(i, 1);
        if (G.nitroActive === p) G.nitroActive = null;
        if (G.rocketActive === p) G.rocketActive = null;
        continue;
      }
      if (Math.abs(p.y - PLAYER_Y) < 60 && Math.abs(p.x - player.x) < 46) {
        pickups.splice(i, 1);
        if (p.kind === "nitro") { G.nitroReady = true; G.nitroActive = null; }
        else { G.rocketReady = true; G.rocketActive = null; }
      }
    }
    ui.indNitro.classList.toggle("on", G.nitroReady);
    ui.indRocket.classList.toggle("on", G.rocketReady);
  }

  // ---------- player ----------
  function movePlayer(dt) {
    player.targetX = LANE_X[player.lane];

    if (wantNitro && G.nitroReady) { G.nitroReady = false; G.nitroTime = NITRO_TIME; playNitro(); ui.indNitro.classList.remove("on"); }
    wantNitro = false;
    if (wantFire) { fireRocket(); wantFire = false; }

    if (G.nitroTime > 0) { G.nitroTime -= dt; trails.push({ x: player.x + rand(-26, 26), y: player.y + 20, life: 0.4 }); }

    const oldX = player.x;
    player.curX = lerp(player.curX, player.targetX, 1 - Math.exp(-11 * dt));
    player.x = player.curX;
    const latV = (player.x - oldX) / Math.max(dt, 1e-4);
    // Smooth, readable nose turn into the lane change (no harsh wobble).
    const turnTarget = clamp(latV * 0.0007, -0.3, 0.3);
    player.turn = lerp(player.turn, turnTarget, 1 - Math.exp(-8 * dt));
    player.surge = lerp(player.surge, G.nitroTime > 0 ? -50 : 0, 1 - Math.exp(-2.5 * dt));

    for (const c of traffic) {
      if (Math.abs(c.x - player.x) < c.hw + player.hw &&
          Math.abs(c.y - (player.y + player.surge)) < c.hl + player.hl) { endGame(false); return; }
    }
  }

  // ---------- input ----------
  // Discrete lane change: one press = one lane. Auto-repeat is ignored so
  // holding a key can't skip two lanes at once.
  let wantFire = false, wantNitro = false;
  function down(e) {
    unlockAudio();
    const k = e.code;
    if (["ArrowLeft", "ArrowRight", "Space", "Enter"].includes(k)) e.preventDefault();
    if (G.state === "menu") { if (k === "Enter" || k === "Space") startGame(); return; }
    if (G.state === "playing") {
      if ((k === "ArrowLeft" || k === "KeyA") && !e.repeat) player.lane = Math.max(0, player.lane - 1);
      else if ((k === "ArrowRight" || k === "KeyD") && !e.repeat) player.lane = Math.min(3, player.lane + 1);
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
    if (k === "Space") wantNitro = false;
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
    if (G.state === "playing") { G.scroll += G.speed * (G.nitroTime > 0 ? NITRO_BOOST : 1) * dt; }
    // grass around
    ctx.fillStyle = "#1e2f1a"; ctx.fillRect(0, 0, W, H);
    ctx.fillStyle = "#22361e";
    for (let x = 8; x < ROAD_L - 22; x += 26) ctx.fillRect(x, 0, 9, H);
    for (let x = ROAD_R + 16; x < W - 10; x += 26) ctx.fillRect(x, 0, 9, H);

    // asphalt: tiled texture, ~15 tiles across the road, filled via repeat
    if (asphalt) {
      const aspect = asphalt.height / asphalt.width;
      const tw = ROAD_W / 15;              // ~15 tiles per line
      const th = tw * aspect;
      const off = (G.scroll) % th;         // scrolls downward
      ctx.save();
      ctx.beginPath(); ctx.rect(ROAD_L - 1, -1, ROAD_W + 2, H + 2); ctx.clip();
      for (let y = off - th; y < H + th; y += th)
        for (let x = ROAD_L; x <= ROAD_R; x += tw)
          ctx.drawImage(asphalt, x, y, tw + 1, th + 1); // +1 to hide seams
      ctx.restore();
    } else {
      ctx.fillStyle = "#3a3a3d"; ctx.fillRect(ROAD_L, 0, ROAD_W, H);
    }

    // dashed lane dividers
    ctx.fillStyle = "rgba(255,255,255,0.8)";
    const period = 110, len = 46, off2 = (G.scroll) % period;
    for (const dx of DIVIDERS) for (let y = off2 - period; y < H + period; y += period) ctx.fillRect(dx - 1.5, y, 3, len);

    // yellow edge lines
    ctx.fillStyle = "#cfb520";
    ctx.fillRect(ROAD_L - 2, 0, 3, H);
    ctx.fillRect(ROAD_R - 1, 0, 3, H);
  }

  // draw a vehicle upright at its size (rw width, height from PNG aspect)
  function drawVehicle(v, ang) {
    if (!v.img) return;
    const h = v.rw * (v.img.height / v.img.width);
    ctx.save();
    ctx.translate(v.x, v.y);
    if (ang) ctx.rotate(ang);
    ctx.drawImage(v.img, -v.rw / 2, -h / 2, v.rw, h);
    ctx.restore();
  }

  function draw() {
    drawRoad();

    // pickups (icons on the road, drawn to natural aspect)
    for (const p of pickups) {
      if (!p.img) continue;
      const a = p.img.height / p.img.width;
      const w = p.kind === "nitro" ? 30 : 24;
      const h = w * a;
      ctx.drawImage(p.img, p.x - w / 2, p.y - h / 2, w, h);
    }

    for (const c of traffic) drawVehicle(c, 0);
    if (enemy) drawVehicle(enemy, enemy.bank);

    // player (police)
    if (player) {
      const h = player.rw * (player.img.height / player.img.width);
      ctx.save();
      ctx.translate(player.x, player.y + player.surge);
      if (G.nitroTime > 0) {
        ctx.globalAlpha = 0.5; ctx.fillStyle = "#ffd23f";
        ctx.beginPath(); ctx.arc(0, 26, 18, 0, Math.PI * 2); ctx.fill(); ctx.globalAlpha = 1;
      }
      ctx.rotate(player.turn);
      ctx.drawImage(player.img, -player.rw / 2, -h / 2, player.rw, h);
      ctx.restore();
    }

    // rockets (projectiles)
    for (const r of rockets) {
      if (!r.img) continue;
      const a = r.img.height / r.img.width, w = 28, h = w * a;
      ctx.drawImage(r.img, r.x - w / 2, r.y - h / 2, w, h);
    }

    // nitro trails
    for (let i = trails.length - 1; i >= 0; i--) {
      const tr = trails[i];
      tr.life -= dt; tr.y += 240 * dt;
      if (tr.life <= 0) { trails.splice(i, 1); continue; }
      ctx.globalAlpha = tr.life * 0.8; ctx.strokeStyle = "#ffd23f"; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(tr.x, tr.y); ctx.lineTo(tr.x, tr.y + 24); ctx.stroke();
    }
    ctx.globalAlpha = 1;

    // explosion particles
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
      // Smooth, predictable difficulty: actual speed eases toward the target
      // (no abrupt jumps), so it feels like a steady, growing ramp.
      G.speed = lerp(G.speed, G.speedTarget, 1 - Math.exp(-SPEED_RAMP * dt));
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
    for (const f of LOAD_FILES) { try { IMG[f] = await loadImage("assets/" + f); } catch (e) { console.warn("no image", f); } }
    try { asphalt = await loadImage("assets/asphalt.png"); } catch (e) { console.warn("no asphalt"); }
    setupAudio();
    fit();
    goMenu();
    requestAnimationFrame(frame);
  }
  boot();
})();

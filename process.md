# process.md — Контекст разработки (для новых сессий)

> Этот файл — **компактный слепок состояния разработки игры**. Сюда пишем, что сделано, что в процессе, что дальше.
> Обновляй его в КАЖДОЙ сессии (дописывай по ходу). Только значимое — без мелочей. Новая сессия должна по этому файлу быстро понять, где мы и к чему приступать.
> Правила ведения — см. `AGENTS.md` → раздел про process.md.

---

## Проект
- **Игра:** «Patrol Rush» — топ-даун погоня полицейского за убегающей машиной (Godot 4.x, macOS, оконный режим, узкое высокое окно ~480×800, 4 полосы).
- **ТЗ:** `CAR_GAME.md`.
- **Ориентация моделей:** верх +Y, перед (нос) −Z, смена полосы по X (см. CAR_GAME.md §6.2).
- **Godot установлен:** 4.7.2 (`/opt/homebrew/bin/godot`), рендер GL Compatibility.

## Текущий статус (кратко)
- MVP (милстоун 1) готов. Добавлены визуальные заглушки всех сущностей: жёлтый игрок, фиолетовый трафик, синяя убегающая машина. Верифицировано headless, игра запущена.

## ✅ СДЕЛАНО
- **Скелет проекта:** `project.godot` (окно 480×800, окно, portrait, gl_compatibility), autoload `GameState` (`autoload/GameState.gd` — регистрирует `move_left`/`move_right`, переменные speed/score/best/state), `.gitignore` + `.godot/`.
- **RoadGenerator** (`scripts/road/road_generator.gd` + `scenes/RoadGenerator.tscn`): бесконечная 4-полосная дорога, процедурная, скролл по +Z со скоростью `GameState.speed`, рециклинг сегментов (покрытие Z ≈ +13..−13).
- **PlayerCar** (`scripts/player/player_car.gd` + `scenes/PlayerCar.tscn`): заглушка-бокс (BoxMesh 1.7×0.9×2.8, нос −Z, без поворота!), движение по полосам X ∈ {-3,-1,1,3}, плавное сглаживание, косметический крен (banking, rotation.z на Body), фикс на Z=8.
- **Main.tscn:** камера орто (projection=1, size=11, current=true, y=25, rotation.x=-90°) + DirectionalLight (иначе плоские материалы чёрные) + RoadGenerator + PlayerCar.
- **Верификация:** `godot --headless --quit-after` и `--scene Main --verbose` — ошибок нет.

### Визуальные заглушки сущностей (цветовое кодирование)
- **Игрок (герой)** — жёлтый (`scenes/PlayerCar.tscn`, материал ярко-жёлтый).
- **Трафик (враги)** — фиолетовый: `scripts/traffic/traffic_car.gd` + `scenes/TrafficCar.tscn`, `traffic_spawner.gd` + `scenes/TrafficSpawner.tscn`. Спавн сверху (z=-12), движение +Z по модели `speed_z = GameState.speed - forward_speed` (forward_speed 3..7), рециклинг за игроком (z>14), пулинг, лимит 12.
- **Убегающая машина (цель)** — синяя: `scripts/fleeing/fleeing_car.gd` + `scenes/FleeingCar.tscn`. Закреплена сверху (z=-10), автосмена полос каждые 1.5-3.5с.
- `Main.tscn` подключён: RoadGenerator, PlayerCar, TrafficSpawner, FleeingCar + орто-камера + свет.

## 🔄 В ПРОЦЕССЕ
- MVP готов; следующий блок — милстоун 2 (погоня + трафик).

## ⏭ ДАЛЬШЕ / ПЛАН
1. **Милстоун 2:** убегающая машина сверху (AI, всегда в кадре), спавн трафика (TrafficSpawner + пулинг), столкновение с трафиком = game over, очки за поимку.
2. Потом: модели GLB из `MODELS/` (импортировать и проверить ориентацию носа −Z!), рост сложности, UI/состояния (меню/пауза/game-over/рекорд), полировка, экспорт macOS.

## ⚠️ Открытые вопросы / грабли
- **Ориентация моделей GLB** — проверить каждую в Godot при импорте (нос −Z, glTF по умолчанию +Z), см. CAR_GAME.md §6.2.
- Крен банкинга на `Body` захватывает и `CollisionShape3D` внутри Body — коллизий пока нет, но позже при коллайдерах банк должен быть только косметическим (вынести коллайдер из Body или учесть).
- `traffic_spawner.gd`: сигнал `recycled` подключается заново при каждом спавне (строка 44) → счётчик `_active_count` дрейфует (кламп в 0). Для заглушки ОК, но починить при вводе коллизий (подключать сигнал 1 раз при создании).
- Модели `MODELS/*.glb` НЕ в git (игнорятся), `MODELS` лежит локально.
- Метаlness-варнинг при импорте — безвредный, от импорта glb/.blend.

## 📦 Артефакты / где что лежит
- Модели машинок: `MODELS/` (7 шт: 1 police hero, 4 city_car, 2 semi_truck; есть .glb).
- Документы: `CAR_GAME.md`, `AGENTS.md`, `process.md`.
- Код: `scenes/` (Main, PlayerCar, RoadGenerator), `scripts/` (player, road), `autoload/GameState.gd`.

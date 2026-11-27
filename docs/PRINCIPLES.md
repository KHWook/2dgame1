# 개발 원칙: 프롬프트가 아니라 결정론으로

> 목표: **같은 입력이면 같은 게임, 같은 규칙이면 같은 코드.** 규칙은 글이 아니라 실행되는 검사로 지킨다.
> `../pixelfx-starter/docs/PRINCIPLES.md`를 Godot에 맞게 옮긴 것이다. 바꿀 때는 `docs/DECISIONS.md`에 이유를 남긴다.

## 0. 신뢰의 위계
| 순위 | 층 | 예 |
|---|---|---|
| 1 | 설계 | 시뮬레이션은 노드가 아닌 순수 데이터(`RefCounted`)라서 엔진 입력·시계·물리에 손댈 수 없다 |
| 2 | 실행되는 검사 | `tools/checks.gd` 규칙, 리플레이 테스트, 훅 |
| 3 | 글 | `CLAUDE.md`, 이 문서 |

새 규칙은 1 → 2 → 3 순서로 둘 곳을 찾는다. 같은 실수가 두 번 나오면 검사가 없는 문제다.

## 1. 구조
- `src/sim/`: 시뮬레이션. `World.step(input_frame)` 한 번이 고정 스텝 하나다. 노드도, 엔진 입력도, 시계도 없다.
- `src/main.gd`: 엔진과 시뮬레이션 사이의 유일한 다리. 키 이벤트를 `InputFrame`으로 바꾸고, `_physics_process`(60 Hz)마다 `world.step`을 부르고, `_draw`에서 월드를 읽어서 그린다. 판마다 쓸 시드도 여기서 정한다(`fresh_seed`: 시계 둘을 섞은 1~999999. `--seed=N`이나 봇이면 정해진 시드). 시뮬레이션은 시드를 받기만 한다.
- `src/art/`: 그림. `sprites.gd`는 글자 격자로 그린 스프라이트(글자 하나가 픽셀 하나), `painter.gd`는 월드를 읽어서 어떤 그림을 어디에 그릴지 정한다. `effects.gd`는 `world.events`를 읽어 잠깐 보이는 이펙트를 띄운다. `looks.gd`는 적 종류와 강화의 생김새 표다. `ground.gdshader`는 땅을 크레용 결로 그리는 셰이더로, 픽셀 아트가 아닌 것은 이것 하나다(`main.gd`가 필드 밑에 깔고, 색은 `Painter.ground_map()`에서 읽는다).
- `src/ui.gd`: 화면의 글자(Label)와 그 움직임. 강화 카드, HUD 글자, 안내, 일시정지·끝 화면. 월드를 읽기만 하고, 움직임은 실제 시간으로 돌아서 월드를 멈추지 않는다. `main.gd`가 만들고 부른다.
- `src/touch.gd`: 휴대폰의 터치 조작(조이스틱, 칼·돌진·일시정지 버튼, 누르면 다시 하기). 버튼은 키와 같은 동작 이름으로, 조이스틱은 방향 번호(`InputFrame.stick`, 정수라 리플레이가 정확하다)로 바꿔 `main.gd`에 넘긴다. 시뮬레이션은 화면을 읽지 않는다.
- `src/guide.gd`: 첫 화면 안내의 상태와 입력이 하는 일(쪽 넘기기, 시작 버튼으로만 닫기, 열린 뒤 잠깐 받지 않기). `src/coach.gd`: 첫 밤의 화살표 안내. 둘 다 그리기는 `ui.gd`가 한다. 웹·모바일의 화면 배율(`stretch_for`)도 여기서 정한다.
- `src/chooser.gd`: 판을 시작할 때 캐릭터(`Config.CHARACTERS`)를 고르는 화면의 상태와 입력(카드 위치, 열린 뒤 잠깐 받지 않기, 탭·숫자 키·화살표). 그리기는 `ui.gd`가 한다. 고른 캐릭터는 `main.gd`가 뽑은 시드와 함께 `World.choose(id, seed)`로 새 판이 된다.
- `src/picker.gd`: 횃불의 강화 카드를 키로 고르기(초점, ← →·A D, Enter·Space, 뜬 뒤 잠깐 받지 않기). 고른 카드는 숫자 키와 같은 `pick_N` 동작이 되어서 월드·봇·리플레이는 모른다. 그리기는 `ui.gd`가 한다.
- `src/records.gd`: 지난 판의 점수 기록(`user://records.json`). 파일과 날짜를 다루므로 시뮬레이션 밖에 있다.
- `tools/`: 검사, 규칙 장면 테스트, 리플레이. `./verify`가 입구다.

## 2. 게임 결정론 (D)
| ID | 규칙 | 지키는 장치 |
|---|---|---|
| D1 | 무작위는 전부 `world.rng`(`src/sim/rng.gd`)에서. `randf()`·`randi()`·새 `RandomNumberGenerator` 금지 | check D1 + 리플레이 |
| D2 | 시뮬레이션은 시계를 읽지 않는다. 시간은 `Config.STEP`과 `world.time`뿐 | check D2 + 리플레이 |
| D3 | 엔진 타이머·`await` 금지. 나중 일은 `world.later(초, callable)` | check D3 |
| D4 | 그리기는 월드를 읽기만 한다 | 설계(시뮬레이션이 그리기를 모름) + 글. 검사 후보 |
| E1 | 화면이 알아야 할 일(타격, 처치, 장작 넣기)은 그 스텝의 `world.events`에 적는다. 규칙은 events를 읽지 않는다 | 리플레이 테스트(사건 수를 점수와 대조) + 글 |
| D5 | 고정 스텝 1/60. `project.godot`의 `physics_ticks_per_second=60` | 설정 |
| D6 | 누른 키는 정확히 한 스텝에만 `pressed`. OS 키 반복은 새 입력이 아니다 | `main.gd` 구조. 형식 검사 후보(스타터의 `verify-input-edges`) |
| S1 | `src/sim/` 파일은 `extends RefCounted`이고 노드·씬 트리·`Input`을 쓰지 않는다 | check S1 |

Godot 내장 물리(`CharacterBody2D`, `move_and_slide`)는 게임 규칙에 쓰지 않는다. 판정은 시뮬레이션이 직접 계산한다.

## 3. 일관성 (C, N)
| ID | 규칙 | 지키는 장치 |
|---|---|---|
| C1 | 글자는 UI다. 월드에 `draw_string` 하지 않고 `Label` 같은 Control에 쓴다 | check C1 |
| C5 | 꼼수를 정당화하는 주석 금지(`hack`, `for now`, `workaround`…) | check C5 |
| N1 | 튜닝 숫자는 `src/sim/config.gd`의 표에 둔다 | 글. 검사 후보 |
| A1 | 스프라이트 격자는 줄 너비가 같고 모든 글자가 `PALETTE`에 있다 | `Sprites.problems()` (`./verify`) |
| A2 | 규칙 데이터가 이름으로 찾는 스프라이트(적 종류마다 `<종류>_a`·`<종류>_b`, 강화마다 `icon_<id>`)는 전부 그려져 있고, 적 종류마다 첫 등장 안내(`Looks.HINTS`)가 있고, 빛 밖에서 보일 것(`glow`, `dark_glow`, `in_dark`)이 있다 | `Looks.problems()` (`./verify`) |
| A3 | 화면에 쓰는 글자(`src/`의 문자열에서 ASCII가 아닌 것)는 전부 픽셀 폰트(`assets/fonts/`, 한글에 필요한 만큼 잘라 넣음)에 있다. 다른 폰트로 대신 그려지는 글자가 없게 | `ui.gd`의 `font_problems()` (`./verify`의 fonts 줄, 자체 bad/good 포함) |
| R1 | 적 종류·강화·줍는 것을 더하면 그 규칙을 보여 주는 장면을 `tools/rules_test.gd`에 더한다 | 장면 테스트(`./verify`) + 글 |
| B1 | `src/`와 `tools/`의 스크립트는 전부 컴파일된다. 리플레이가 부르지 않는 화면 쪽 스크립트도 포함 | check B1 |

예외는 그 줄 끝에 `# check-ok: <이유>`. 이유 없는 예외는 받지 않는다.

## 4. 완료의 정의 (G)
- G1. `./verify`가 통과해야 끝난 것이다(규칙 + 검사 자체 테스트 + 스프라이트 격자 + 규칙 장면 + 점수 기록 + 터치 조작 + 리플레이 2회 비교 + 사건 수 대조 + 골든 비교).
- G2. 게임플레이가 바뀌면 `./verify --update-golden`으로 일부러 다시 기록하고 DECISIONS에 남긴다. 골든 직접 편집은 막혀 있다.
- G3. 말이 아니라 증거. 검사 출력, 렌더한 프레임, 리플레이 결과를 보여준다.
- G4. 검사도 검사한다. 규칙마다 `bad`/`good` 줄이 있고 `./verify`가 매번 자체 테스트를 돌린다. B1만 예외다(깨진 스크립트를 부르면 통과하는 실행에도 오류 줄이 찍힌다). B1은 심어 본 오류로 확인했다(`docs/DECISIONS.md`).
- G5. `./verify`가 도는 동안 난 실행 중 스크립트 오류(`SCRIPT ERROR`)는 어디서 났든 실패다. GDScript 함수는 오류가 나면 멈추고 빈 값을 돌려주므로, 터진 장면은 `[]`를 돌려주어 통과한 장면처럼 보인다. `tools/verify.gd`의 `ScriptErrors`(Godot `Logger`)가 오류를 듣고, `./verify` 셸 스크립트도 출력에 `SCRIPT ERROR` 줄이 있으면 실패시킨다. 자체 테스트 대신 심어 본 오류로 확인했다(`docs/DECISIONS.md`): 일부러 오류를 내는 자체 테스트는 통과하는 실행에도 오류 줄을 찍는다.

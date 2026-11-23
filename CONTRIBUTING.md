# 협업 규칙 (6조)

코드를 안 짜는 팀원도 이 규칙대로 올리면 된다. 사진, 문서, 사운드 파일 전부 같은 방식.

## 처음 한 번

1. GitHub 초대 메일 수락.
2. [Git 설치](https://git-scm.com/download/win) 후 터미널에서:
   ```
   git config --global user.name "GitHub아이디"
   git config --global user.email "GitHub에 등록한 이메일"
   git clone https://github.com/jhyeun1020/opensource-team6-datanoise.git
   ```
3. 터미널이 어렵다면 [GitHub Desktop](https://desktop.github.com/) 을 써도 된다. 아래 흐름은 똑같다.

## 작업 흐름 (매번)

```
git switch main
git pull                                  # 최신 상태로
git switch -c 역할/할일-요약                # 예) sound/footsteps, docs/design-doc, ref/photos-3f
... 파일 추가/수정 ...
git add -A
git commit -m "무엇을 했는지 한 줄"          # 예) "복도 발소리 효과음 4종 추가 (CC0)"
git push -u origin 역할/할일-요약
```

푸시하면 GitHub 페이지에 **Compare & pull request** 버튼이 뜬다. 누르고, 템플릿에 맞춰 적고, **Create pull request**.
다른 팀원 한 명이 보고 **Merge** 한다. 자기 PR은 자기가 머지하지 않는다.

- main 에 직접 푸시하지 않는다 (막혀 있음).
- 브랜치 이름 앞머리: `feat/` 코드 기능, `fix/` 버그 수정, `docs/` 문서, `ref/` 레퍼런스 자료, `sound/` 사운드, `art/` 모델·텍스처.
- 커밋 메시지는 한국어로, "무엇을" 했는지. "수정", "업데이트" 같은 한 단어 메시지는 피한다.

## 무엇을 어디에

| 올리는 것 | 폴더 | 규칙 |
|---|---|---|
| 기획 문서, 회의록, 발표 자료 | `docs/` | 마크다운(.md) 권장. PDF도 가능. 학번·연락처는 넣지 않는다 (퍼블릭 레포). |
| 현장 사진, 치수, 스캔 | `reference/` | `reference/README.md` 참고. 사람 얼굴 나온 사진 금지. |
| 효과음, BGM | `assets/sfx/` | 출처와 라이선스를 `assets/sfx/README.md` 표에 반드시 추가. CC0 또는 CC-BY만. |
| 3D 모델, 텍스처 | `assets/models/`, `assets/textures/` | 위와 같이 출처·라이선스 기록. |
| 코드 | `scripts/`, `scenes/`, `shaders/` | 담당 파트 파일만. 다른 파트와의 접점은 `GameManager` 시그널 (README 참고). |

## 버그를 찾았을 때

GitHub **Issues** 탭 → **New issue** → "버그 제보" 템플릿. 어디서, 무엇을 했더니, 어떻게 됐는지 세 줄이면 충분하다. 스크린샷이 있으면 붙인다.
고친 사람이 PR 설명에 `Fixes #이슈번호` 라고 적으면 머지될 때 이슈가 자동으로 닫힌다.

## 코드 올리기 전

Godot 에서 `scenes/smoke_test.tscn` 을 열고 F6. 콘솔에 `SMOKE RESULT: PASS` 가 떠야 한다.

## 역할

| 역할 | 담당 영역 |
|---|---|
| A 플레이어 | `scripts/player.gd` |
| B 괴물 AI | `scripts/monster.gd` |
| C 미니게임·UI | `scripts/minigame.gd`, `scripts/terminal.gd`, `scripts/hud.gd` |
| D 레벨·연출·사운드 | `scripts/level_builder.gd`, `scripts/door.gd`, `shaders/`, `assets/` |
| 기획·문서 | `docs/`, Issue 관리, 발표 자료 |
| 현장 조사 | `reference/` |

이름은 Issue 의 Assignee 로 표시한다.

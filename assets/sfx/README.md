# 사운드 자리

여기에 `.ogg` / `.wav` 를 넣고, 각 스크립트의 `TODO(사운드)` 주석 자리에 AudioStreamPlayer(3D)를 연결한다.

| 파일(예시) | 어디서 | 담당 |
|---|---|---|
| footstep_01~04.ogg | player.gd `_update_footsteps` | A |
| flashlight_click.ogg | player.gd `_set_flashlight` | A |
| monster_idle_loop.ogg, monster_chase.ogg, monster_screech.ogg | monster.gd `_change_state` | B |
| terminal_boot.ogg, key_beep.ogg, error_buzz.ogg, purify_done.ogg | terminal.gd / minigame.gd | C |
| door_open.ogg, gate_open_big.ogg, ambience_server_room.ogg | door.gd / level_builder.gd | D |

무료 소스: freesound.org (CC0 필터), Kenney (kenney.nl/assets), OpenGameArt. 라이선스를 이 파일에 기록할 것.

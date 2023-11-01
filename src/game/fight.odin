package game

import glm "core:math/linalg/glsl"
import "core:fmt"

Fight :: struct {
    active_player: u8,
    players: [6]Player,
    level: [dynamic]Tile,
    level_width: i32,
}

Player :: struct {
    class: PlayerClass,
    coord: i32,
    health: u32,

    is_enemy: bool,
    has_ball: bool,
}

PlayerData :: struct {
    moves: int,
}

PlayerClass :: enum u8 {
    Boxer,
    Ranger,
    Ninja,
}

player_data := [PlayerClass]PlayerData{
    PlayerClass.Boxer = { moves = 3 },
    PlayerClass.Ranger = { moves = 4 },
    PlayerClass.Ninja = { moves = 3 },
}

Tile :: struct {
    type: TileType,
}

TileType :: enum u8 {
    Void,
    Ground,
    Wall,
}

init_fight :: proc() -> (f: Fight) {
    test_level :: [?]u8{
        1, 1, 1, 1, 1, 2,
        1, 1, 0, 1, 1, 2,
        2, 2, 1, 1, 1, 2,
        1, 1, 1, 1, 1, 2,
        1, 1, 1, 1, 2, 2,
        1, 1, 1, 1, 2, 2,
        1, 1, 1, 1, 2, 2,
        1, 1, 1, 1, 2, 2,
    }

    f.level_width = 6
    for x in test_level {
        // append(&f.level, TileType(x))
        append(&f.level, Tile{ TileType(x) })
    }

    f.players = [6]Player{
        0 = {
            class = .Ninja,
            coord = 15,
            health = 10,
        },
        1 = {
            class = .Ranger,
            coord = 1,
            health = 10,
        },
    }

    reserve(&path_finding.visited, len(f.level))

    return
}

fight_tile_pos :: proc(id: i32) -> glm.vec3 {
    x, z := id % fight.level_width, id / fight.level_width

    y := fight.level[id].type == .Wall ? 1 : 0
    return 2 * glm.vec3{f32(x), f32(y), f32(z)}
}

start_turn :: proc(player: u8) {
    fight.active_player = player

    legal_moves(player)
}

legal_moves :: proc(player_id: u8) {
    using fight

    coord := players[player_id].coord
    class := players[player_id].class

    moves := player_data[class].moves

    x, y := coord % level_width, coord / level_width

    clear(&path_finding.visited)
    dfs_board(moves, {x, y})
    delete_key(&path_finding.visited, coord)
}

PathFinding :: struct {
    visited: map[i32]bool,
    in_range: map[i32]bool,
}

path_finding : PathFinding

dfs_board :: proc(depth: int, pos: glm.ivec2) {
    using path_finding

    if depth < 0 || !in_bounds(pos) {
        return
    }

    id := pos.x + pos.y * fight.level_width
    if fight.level[id].type == .Void {
        return
    }
    visited[id] = true

    dfs_board(depth - 1, pos + {0, 1})
    dfs_board(depth - 1, pos - {0, 1})
    dfs_board(depth - 1, pos + {1, 0})
    dfs_board(depth - 1, pos - {1, 0})
}

in_bounds :: #force_inline proc(pos: glm.ivec2) -> bool {
    w, h := fight.level_width, i32(len(fight.level)) / fight.level_width
    return 0 <= pos.x && pos.x < w && 0 <= pos.y && pos.y < h
}

move_player :: proc(player_id: u8, coord: i32) {
    fight.players[player_id].coord = coord
}

fight := init_fight()
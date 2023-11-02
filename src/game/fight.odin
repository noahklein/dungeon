package game

import glm "core:math/linalg/glsl"
import "core:fmt"
import "core:container/queue"

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
        2, 2, 0, 1, 1, 2,
        1, 1, 0, 0, 1, 2,
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

deinit_fight :: proc() {
   delete(path_finding.came_from) 
   delete(path_finding.visited) 
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
    // Remove player's current position from available moves.
    delete_key(&path_finding.visited, coord)
}

Direction :: enum u8 {
    North,
    East,
    South,
    West,
}

PathFinding :: struct {
    visited: map[i32]bool,
    came_from: map[i32]i32,
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

shortest_path :: proc(a, b: i32) {
    clear(&path_finding.came_from)
    assert(a != b)

    start := glm.ivec2{a % fight.level_width, a / fight.level_width}
    end := glm.ivec2{b % fight.level_width, b / fight.level_width}

    to_visit : queue.Queue(glm.ivec2)
    if err := queue.init(&to_visit, allocator = context.temp_allocator); err != nil {
        fmt.eprintln("Failed to allocate queue", err)
        return
    }
    queue.push(&to_visit, start)

    for queue.len(to_visit) > 0 {
        node := queue.pop_front(&to_visit)
        if node == end {
            return // We made it!
        }

        id := node.x + node.y * fight.level_width
        if fight.level[id].type == .Void {
            continue
        }

        push :: proc(q: ^queue.Queue($T), from_id: i32, elem: glm.ivec2) {
            if !in_bounds(elem) {
                return
            }
            queue.push_back(q, elem)

            id := elem.x + elem.y * fight.level_width
            if id not_in path_finding.came_from {
                path_finding.came_from[id] = from_id
            }
        }

        push(&to_visit, id, node + {0, 1})
        push(&to_visit, id, node - {0, 1})
        push(&to_visit, id, node + {1, 0})
        push(&to_visit, id, node - {1, 0})
    }
}

in_bounds :: #force_inline proc(pos: glm.ivec2) -> bool {
    w, h := fight.level_width, i32(len(fight.level)) / fight.level_width
    return 0 <= pos.x && pos.x < w && 0 <= pos.y && pos.y < h
}

move_player :: proc(player_id: u8, coord: i32) {
    fight.players[player_id].coord = coord
}

fight := init_fight()
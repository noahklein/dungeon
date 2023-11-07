package game

import glm "core:math/linalg/glsl"
import "core:fmt"
import "core:container/queue"

fight := init_fight()

Fight :: struct {
    active_player: i32,
    players: [6]Player,
    level: [dynamic]Tile,
    level_width: i32,
}

Player :: struct {
    class: PlayerClass,
    coord: i32,
    health: u32,

    team: Team,
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
    player_id: i32,
}

TileType :: enum u8 {
    Void,
    Ground,
    Wall,
}

Team :: enum u8 {
    None,
    Friend,
    Enemy,
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
    assert(len(test_level) % f.level_width == 0, "level must be rectangular")

    f.players = [6]Player{
        0 = {
            class = .Ninja,
            coord = 15,
            health = 10,
            team = .Friend,
        },
        1 = {
            class = .Ranger,
            coord = 30,
            health = 10,
            team = .Enemy,
        },

        2 = {
            class = .Ranger,
            coord = 5,
            health = 10,
            team = .Enemy,
        },

    }

    for tile_type, tile_id in test_level {
        player_id := i32(-1)
        for player, p_id in f.players {
            if i32(tile_id) == player.coord {
                player_id = i32(p_id)
            }
        }

        append(&f.level, Tile{
            type = TileType(tile_type),
            player_id = player_id,
        })
    }

    reserve(&path_finding.legal_moves, len(f.level))
    reserve(&path_finding.came_from, len(f.level))

    return
}

deinit_fight :: proc() {
   delete(path_finding.came_from)
   delete(path_finding.legal_moves)
}

fight_tile_pos :: proc(id: i32) -> glm.vec3 {
    x, z := id % fight.level_width, id / fight.level_width

    y := fight.level[id].type == .Wall ? 1 : 0
    return 2 * glm.vec3{f32(x), f32(y), f32(z)}
}

start_turn :: proc(player_id: i32) {
    fight.active_player = player_id
    calc_legal_moves(player_id)
}

calc_legal_moves :: proc(player_id: i32) {
    using fight

    coord := players[player_id].coord

    class := players[player_id].class
    moves := player_data[class].moves

    x, y := coord % level_width, coord / level_width

    clear(&path_finding.legal_moves)
    dfs_board(moves, {x, y})
    // Remove player's current position from available moves.
    delete_key(&path_finding.legal_moves, coord)

    // This is probably stupid. We do a DFS at depth = moves, to get legal moves. Then a
    // BFS to all legal move tiles to get the paths. There's probably a simple way to do
    // both in one pass.
    shortest_path(coord)
}

PathFinding :: struct {
    legal_moves: map[i32]bool,
    // Following came_from recursively from any tile id will give the shortest path back
    // to the starting node.
    came_from: map[i32]i32,
}

path_finding : PathFinding

dfs_board :: proc(depth: int, pos: glm.ivec2) {
    if !in_bounds(pos) {
        return
    }

    id := pos.x + pos.y * fight.level_width

    if depth == -1 {
        // Check for players in melee range.
        if team := get_player(id).team; team != .None {
            path_finding.legal_moves[id] = true
        }

        return
    }

    if fight.level[id].type == .Void {
        return
    }
    path_finding.legal_moves[id] = true

    // Only orthogonal moves.
    dfs_board(depth - 1, pos + {0, 1})
    dfs_board(depth - 1, pos - {0, 1})
    dfs_board(depth - 1, pos + {1, 0})
    dfs_board(depth - 1, pos - {1, 0})
}

// Naive BFS for now. Should explore Djiksta's or A* if needed.
shortest_path :: proc(coord: i32) {
    clear(&path_finding.came_from)

    my_team := get_player(coord).team
    assert(my_team != .None)

    start := glm.ivec2{coord % fight.level_width, coord / fight.level_width}

    to_visit : queue.Queue(glm.ivec2)
    if err := queue.init(&to_visit, allocator = context.temp_allocator); err != nil {
        fmt.eprintln("Failed to allocate queue", err)
        return
    }
    queue.push(&to_visit, start)

    push :: proc(q: ^queue.Queue($T), from_id: i32, elem: glm.ivec2, my_team: Team) {
        if !in_bounds(elem) {
            return
        }

        id := elem.x + elem.y * fight.level_width
        if id not_in path_finding.legal_moves {
            return
        }
        if id in path_finding.came_from {
            return
        }
        if their_team := get_player(id).team; their_team != .None && their_team != my_team {
            // We are enemies, you shall not pass.
            path_finding.came_from[id] = from_id
            return
        }

        path_finding.came_from[id] = from_id
        queue.push_back(q, elem)
    }

    for queue.len(to_visit) > 0 {
        node := queue.pop_front(&to_visit)
        id := node.x + node.y * fight.level_width

        // Only orthogonal moves.
        push(&to_visit, id, node + {0, 1}, my_team)
        push(&to_visit, id, node - {0, 1}, my_team)
        push(&to_visit, id, node + {1, 0}, my_team)
        push(&to_visit, id, node - {1, 0}, my_team)
    }
}

in_bounds :: #force_inline proc(pos: glm.ivec2) -> bool {
    w, h := fight.level_width, i32(len(fight.level)) / fight.level_width
    return 0 <= pos.x && pos.x < w && 0 <= pos.y && pos.y < h
}

move_player :: proc(player_id: i32, coord: i32) {
    old_coord := fight.players[player_id].coord
    fight.level[old_coord].player_id = -1

    fight.level[coord].player_id = player_id
    fight.players[player_id].coord = coord
}

get_player :: proc(tile_id: i32) -> Player {
    player_id := fight.level[tile_id].player_id
    if player_id == -1 {
        return Player{}
    }

    return fight.players[player_id]
}
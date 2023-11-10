package game

import glm "core:math/linalg/glsl"
import "core:fmt"
import "core:container/queue"

fight := init_fight()

Fight :: struct {
    active_player: PlayerId,
    players: [6]Player,
    level: [dynamic]Tile,
    level_width: i32,
}

PlayerId :: distinct i32
TileId :: distinct i32

Player :: struct {
    class: PlayerClass,
    coord: TileId,
    health: i32,

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
    PlayerClass.Ninja = { moves = 5 },
}

Tile :: struct {
    type: TileType,
    player_id: PlayerId,
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
            coord = 32,
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
        player_id := PlayerId(-1)
        for player, p_id in f.players {
            if TileId(tile_id) == player.coord {
                player_id = PlayerId(p_id)
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

fight_tile_pos :: proc(id: TileId) -> glm.vec3 {
    coord := id_to_coord(id)

    y := fight.level[id].type == .Wall ? 1 : 0
    return 2 * glm.vec3{f32(coord.x), f32(y), f32(coord.y)}
}

start_turn :: proc(player_id: PlayerId) {
    fight.active_player = player_id
    calc_legal_moves(player_id)
}

calc_legal_moves :: proc(player_id: PlayerId) {
    using fight

    player := players[player_id]
    moves := player_data[player.class].moves

    pos := id_to_coord(player.coord)

    clear(&path_finding.legal_moves)
    dfs_board(moves, pos, player.team)
    // Remove player's current position from available moves.
    delete_key(&path_finding.legal_moves, player.coord)

    // This is probably stupid. We do a DFS at depth = moves, to get legal moves. Then a
    // BFS to all legal move tiles to get the paths. There's probably a simple way to do
    // both in one pass.
    shortest_path(player.coord)
}

PathFinding :: struct {
    legal_moves: map[TileId]bool,
    // Following came_from recursively from any tile id will give the shortest path back
    // to the starting node.
    came_from: map[TileId]TileId,
}

path_finding : PathFinding

dfs_board :: proc(depth: int, pos: glm.ivec2, my_team: Team) {
    if !in_bounds(pos) {
        return
    }

    id := TileId(pos.x + pos.y * fight.level_width)

    if fight.level[id].type == .Void {
        return
    }

    if depth == -1 {
        // I'm out of moves, but check for enemy players in melee range.
        if their_team := get_player(id).team; their_team != .None && their_team != my_team {
            path_finding.legal_moves[id] = true
        }

        return
    }

    path_finding.legal_moves[id] = true // I can make it here.

    if their_team := get_player(id).team; their_team != .None && their_team != my_team {
        // We are enemies, I shall not pass.
        return
    }

    // Only orthogonal moves.
    dfs_board(depth - 1, pos + {0, 1}, my_team)
    dfs_board(depth - 1, pos - {0, 1}, my_team)
    dfs_board(depth - 1, pos + {1, 0}, my_team)
    dfs_board(depth - 1, pos - {1, 0}, my_team)
}

// Naive BFS for now. Should explore Djiksta's or A* if needed.
shortest_path :: proc(tile_id: TileId) {
    clear(&path_finding.came_from)

    my_team := get_player(tile_id).team
    assert(my_team != .None)

    start := id_to_coord(tile_id)

    to_visit : queue.Queue(glm.ivec2)
    if err := queue.init(&to_visit, allocator = context.temp_allocator); err != nil {
        fmt.eprintln("Failed to allocate queue", err)
        return
    }
    queue.push(&to_visit, start)

    push :: proc(q: ^queue.Queue($T), from_id: TileId, elem: glm.ivec2, my_team: Team) {
        if !in_bounds(elem) {
            return
        }

        id := coord_to_id(elem)
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
        id := coord_to_id(node)

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

id_to_coord :: #force_inline proc(tile_id: TileId) -> glm.ivec2 {
    return glm.ivec2{
        i32(tile_id) % fight.level_width,
        i32(tile_id) / fight.level_width,
    }
}

coord_to_id :: #force_inline proc(coord: glm.ivec2) -> TileId {
    return TileId(coord.x + coord.y * fight.level_width)
}

move_player :: proc(player_id: PlayerId, coord: TileId) {
    old_coord := fight.players[player_id].coord
    fight.level[old_coord].player_id = -1

    fight.level[coord].player_id = player_id
    fight.players[player_id].coord = coord
}


attack :: proc(player_id: PlayerId, target_tile_id: TileId) {
    // TODO: take an attack type enum
    target_tile := fight.level[target_tile_id]
    if target_tile.player_id == -1 {
        fmt.eprintln("Bug: attacking an empty tile", target_tile_id)
        return
    }

    target_player := &fight.players[target_tile.player_id]
    target_player.health -= 1
    fmt.println("health remaining after attack", target_player.health)

    // Shove target player back.
    my_coord := id_to_coord(fight.players[player_id].coord)
    target_coord := id_to_coord(target_tile_id)
    shove_direction := target_coord - my_coord

    shove_coord := shove_direction + target_coord
    if !in_bounds(shove_coord) {
        fmt.println("out of bounds")
        return
    }
    move_player(target_tile.player_id, coord_to_id(shove_coord))
}

get_player :: proc(tile_id: TileId) -> Player {
    player_id := fight.level[tile_id].player_id
    if player_id == -1 {
        return Player{}
    }

    return fight.players[player_id]
}
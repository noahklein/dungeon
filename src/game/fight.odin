package game

import glm "core:math/linalg/glsl"
import "core:fmt"
import "core:container/queue"

fight : Fight
_ := init_fight()

Fight :: struct {
    state: GameState,

    active_player: PlayerId,
    players: [6]Player,
    level: [dynamic]Tile,
    level_width: i32,
}

PlayerId :: distinct i32
TileId :: distinct i32

Player :: struct {
    class: PlayerClass,
    tile_id: TileId,
    entity_id: int,
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

// Static player data
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

GameState :: enum u8 {
    YourTurn,
    TheirTurn,
    Animating,
}

init_fight :: proc() -> bool {
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
    fight.level_width = 6
    assert(len(test_level) % fight.level_width == 0, "level must be rectangular")

    fight.players = [6]Player{
        0 = {
            class = .Ninja,
            tile_id = 15,
            health = 10,
            team = .Friend,
        },
        1 = {
            class = .Ranger,
            tile_id = 32,
            health = 10,
            team = .Enemy,
        },

        2 = {
            class = .Ranger,
            tile_id = 5,
            health = 10,
            team = .Enemy,
        },
    }

    for tile_type, tile_id in test_level {
        player_id := PlayerId(-1)
        for player, p_id in fight.players {
            if TileId(tile_id) == player.tile_id {
                player_id = PlayerId(p_id)
            }
        }

        append(&fight.level, Tile{
            type = TileType(tile_type),
            player_id = player_id,
        })
    }

    for &player in fight.players {
        pos := fight_tile_pos(player.tile_id)
        pos.y += 1.4
        append(&entities, Ent{
            mesh_id = .Ninja,
            texture = {2, 1},
            transform = Transform{
                pos = pos,
                rot = {},
                scale = glm.vec3(0.2),
            },
        })

        player.entity_id = len(entities) - 1
    }

    reserve(&path_finding.legal_moves, len(fight.level))
    reserve(&path_finding.came_from, len(fight.level))

    return true
}

deinit_fight :: proc() {
   delete(fight.level)
   delete(path_finding.came_from)
   delete(path_finding.legal_moves)
   delete(path_finding.path)
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
    player := fight.players[player_id]
    moves := player_data[player.class].moves

    pos := id_to_coord(player.tile_id)

    clear(&path_finding.legal_moves)
    dfs_board(moves, pos, player.team)
    // Remove player's current position from available moves.
    delete_key(&path_finding.legal_moves, player.tile_id)

    // This is probably stupid. We do a DFS at depth = moves, to get legal moves. Then a
    // BFS to all legal move tiles to get the paths. There's probably a simple way to do
    // both in one pass.
    shortest_path(player.tile_id)
}

PathFinding :: struct {
    legal_moves: map[TileId]bool,
    // Following came_from recursively from any tile id will give the shortest path back
    // to the starting node.
    came_from: map[TileId]TileId,

    path: [dynamic]TileId,
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

move_player :: proc(player_id: PlayerId, tile_id: TileId) {
    old_tile_id := fight.players[player_id].tile_id
    fight.level[old_tile_id].player_id = -1

    fight.level[tile_id].player_id = player_id
    fight.players[player_id].tile_id = tile_id

    // Begin movement animation, player visits every node on the path.
    get_path_to :: proc(keyframes: ^[dynamic]Transform, scale: glm.vec3, tile_id: TileId)  {
        if tile_id not_in path_finding.came_from {
            return
        }
        came_from := path_finding.came_from[tile_id]
        get_path_to(keyframes, scale, came_from)

        pos := fight_tile_pos(tile_id)
        pos.y += 1.4
        append(keyframes, Transform{
            pos = pos,
            scale = scale,
        })
    }

    ent := &entities[fight.players[player_id].entity_id]
    clear(&ent.animation.keyframes)
    get_path_to(&ent.animation.keyframes, ent.scale, tile_id)
    play_animation(fight.players[player_id].entity_id, 0.5)
}

// TODO: take an attack type enum
attack :: proc(player_id: PlayerId, target_tile_id: TileId) {
    target_tile := fight.level[target_tile_id]
    if target_tile.player_id == -1 {
        fmt.eprintln("Bug: attacking an empty tile", target_tile_id)
        return
    }

    target_player := &fight.players[target_tile.player_id]
    target_player.health -= 1

    // Shove target player back.
    my_coord := id_to_coord(fight.players[player_id].tile_id)
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
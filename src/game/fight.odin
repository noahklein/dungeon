package game

Fight :: struct {
    active_player: u8,
    players: [6]Player,
    level: []Entity,
}

Player :: struct {
    health: u32,
    is_enemy: bool,
    has_ball: bool,

    transform: Transform,
    class: PlayerClass,
}

PlayerClass :: enum {
    Boxer,
    Ranger,
    Ninja,
}

fight := Fight{}
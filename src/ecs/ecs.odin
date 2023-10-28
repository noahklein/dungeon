package ecs

EntityID :: distinct u32

Entity :: struct {
    id: EntityID,
    components: bit_set[Components],
}

Components :: enum {
    Transform,
}


ComponentPool :: #soa [dynamic]AllComponents
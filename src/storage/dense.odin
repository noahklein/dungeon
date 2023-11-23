package storage

import "core:testing"

// MSB 16 bits = generation
// LSB 16 bits = index
// Allows for 2 ^ 16 = 65,536 entries and generations for each entry. 16 bits was
// chosen for convenience, consider using more bits for the index.
DenseID :: distinct u32

@(private)
generation :: #force_inline proc(id: DenseID) -> u16 {
    return u16(id >> 16)
}

@(private)
index :: #force_inline proc(id: DenseID) -> u16 {
    return u16(id & 0xFFFF)
}

@(private)
dense_id :: #force_inline proc(gen, idx: u16) -> DenseID {
    return (DenseID(gen) << 16) | DenseID(idx)
}

// Densely packed array using generational indices.
// Entries and generations are parallel arrays.
Dense :: struct($T: typeid) {
    entries: [dynamic]T,
    generations: [dynamic]u16,
    deleted: [dynamic]u16, // Stack containing deleted indices.
}

dense_deinit :: proc(d: Dense($T)) {
    delete(d.entries)
    delete(d.generations)
    delete(d.deleted)
}

@(require_results)
dense_add :: proc(d: ^Dense($T), val: T) -> DenseID {
    if len(d.deleted) != 0 {
        idx := pop(&d.deleted)
        d.entries[idx] =  val
        return dense_id(d.generations[idx], idx)
    }

    append(&d.entries, val)
    append(&d.generations, 0)
    return DenseID(len(d.entries) - 1)
}

dense_remove :: proc(d: ^Dense($T), id: DenseID) {
    idx, gen := index(id), generation(id)
    if d.generations[idx] != gen {
        return // We already removed this guy.
    }

    // Incrementing genration here rather than in dense_add() so that items can't be removed twice.
    d.generations[idx] += 1
    append(&d.deleted, idx)
}

// Gets an entry from a dense array. Do not store these pointers!
@(require_results)
dense_get :: proc(d: Dense($T), id: DenseID) -> ^T {
    idx, gen := index(id), generation(id)
    if d.generations[idx] != gen {
        return nil
    }

    return &d.entries[idx]
}

@(test)
test_dense:: proc(t: ^testing.T) {
	Component :: struct { x: int }
	dense : Dense(Component)
    want := Component{x = 99}

    id := dense_add(&dense, want)
    if got := dense_get(dense, id); got.x != want.x {
        testing.errorf(t, "dense_get error: got %v, want %v", got.x, want.x)
    }

    dense_remove(&dense, id)
    // Should get nil after removing.
    if got := dense_get(dense, id); got != nil {
        testing.error(t, "dense_get got entry after dense_remove:", got)
    }

    // Should re-use the previous slot for new items.
    new_id := dense_add(&dense, want)
    if len(dense.entries) != 1 {
        testing.error(t, "len(dense.entries) != 1 after remove and add, got:", len(dense.entries))
    }
    if got := dense_get(dense, new_id); got == nil || got.x != want.x {
        testing.errorf(t, "dense_get error after remove and add: got %v, want %v", got.x, want.x)
    }
}
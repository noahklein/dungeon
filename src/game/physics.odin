// Physics system
// References:
//     * Collision/Manifolds - https://winter.dev/articles/physics-engine/DirkGregorius_Contacts.pdf
package game

import glm "core:math/linalg/glsl"
import "core:fmt"
import "../storage"

EPSILON :: 0.0001
C :: 50 // Speed of light

Physics :: struct {
    gravity: glm.vec3,
    rigidbodies: storage.Dense(Rigidbody),
    spheres: [dynamic]SphereCollider,
    planes: [dynamic]PlaneCollider,
}

physics := Physics{
    gravity = {0, -9.81, 0},
}

Rigidbody :: struct {
    mass: f32,
    velocity, force: glm.vec3,
}

physics_deinit :: proc() {
   storage.dense_deinit(physics.rigidbodies)
   delete(physics.spheres)
   delete(physics.planes)
}

physics_add_rigidbody :: proc(ent_id: EntityId, mass: f32) -> ^Rigidbody {
    ent := &entities[ent_id]
    ent.rigidbody_id = storage.dense_add(&physics.rigidbodies, Rigidbody{
        mass = mass,
    })

    return physics_get_rigidbody(ent_id) or_else panic("Missing rigidbody after add")
}

physics_get_rigidbody :: proc(ent_id: EntityId) -> (rb: ^Rigidbody, ok: bool) {
    id := entities[ent_id].rigidbody_id.? or_return
    rb = storage.dense_get(physics.rigidbodies, id)
    return rb, rb != nil
}

physics_update :: proc(dt: f32) {
    // Apply forces.
    for &ent in entities {
        rigidbody_id := ent.rigidbody_id.? or_continue
        rb := storage.dense_get(physics.rigidbodies, rigidbody_id)
        if rb == nil {
            assert(false, "Entity pointing to missing rigidbody")
            continue // @TODO: handle deletion?
        }

        rb.force += rb.mass * physics.gravity

        rb.velocity += rb.force / rb.mass * dt
        rb.velocity = glm.clamp_vec3(rb.velocity, {-C, -C, -C}, {C, C, C})
        ent.pos += rb.velocity * dt

        rb.force = 0
    }

    // Collision detection, fully O(N²); extremely naive approach.
    // @TODO: Split into broad/narrow phase - maybe BSP or octrees?
    for sphere_a in physics.spheres {
        for sphere_b in physics.spheres {
            if sphere_a.ent_id == sphere_b.ent_id {
                continue
            }

            contact := is_colliding(sphere_a, sphere_b) or_continue
            solve_collision(contact, sphere_a.ent_id, sphere_b.ent_id)
        }

        for plane_b in physics.planes {
            contact := is_colliding(sphere_a, plane_b) or_continue
            solve_collision(contact, sphere_a.ent_id, plane_b.ent_id)
        }
    }
}

// O(n) lookup by entity id. Only use for devtools or very infrequently.
// NOTE: There are no collider ids because colliders are not ordered and so far nobody
// cares about colliders besides for physics and GUI/devtools.
physics_find_collider :: proc(ent_id: EntityId) -> (Collider, bool) {
    assert(ODIN_DEBUG)
    for &sphere in physics.spheres {
        if sphere.ent_id == ent_id {
            return &sphere, true
        }
    }

    for &plane in physics.planes {
        if plane.ent_id == ent_id {
            return &plane, true
        }
    }

    return {}, false
}

Collider :: union {
    ^SphereCollider,
    ^PlaneCollider,
}

SphereCollider :: struct {
    ent_id: EntityId,
    radius: f32,
    center: glm.vec3,
}

PlaneCollider :: struct {
    ent_id: EntityId,
    normal: glm.vec3,
    distance: f32, // Distance from origin
}

Manifold :: struct {
    depth: f32,
    normal: glm.vec3,
}

manifold_points :: proc(point_a, point_b: glm.vec3) -> Manifold {
    ba := point_a - point_b
    depth := glm.length(ba)

    if depth < EPSILON {
        return { normal = {0, 1, 0}, depth = 1}
    }

    return {
        normal = ba / depth,
        depth = depth,
    }
}

is_colliding :: proc{
    is_colliding_spheres,
    is_colliding_sphere_plane,
}

is_colliding_spheres :: proc(sa, sb: SphereCollider) -> (Manifold, bool) {
    pos_a := entities[sa.ent_id].pos + sa.center
    pos_b := entities[sb.ent_id].pos + sb.center

    ab := pos_b - pos_a
    distance := glm.length(ab)
    if distance < EPSILON || distance > sa.radius + sb.radius {
        return {}, false
    }

    normal := glm.normalize(ab)
    point_a := pos_a + sa.radius * normal // Surface point on A inside B
    point_b := pos_b - sb.radius * normal // Surface point on B inside A
    return manifold_points(point_a, point_b), true
}

is_colliding_sphere_plane :: proc(sphere: SphereCollider, plane: PlaneCollider) -> (Manifold, bool) {
    sphere_pos := sphere.center + entities[sphere.ent_id].pos

    // @TODO: rotate normal using entity's transform.
    // Any point on the plane, doesn't matter.
    normal := -plane.normal
    point_on_plane := (normal * plane.distance) + entities[plane.ent_id].pos

    // Distance from sphere center to plane point.
    distance := glm.dot_vec3(point_on_plane - sphere_pos, normal)
    if distance > sphere.radius {
        return {}, false
    }

    return Manifold{
        normal = normal,
        depth = distance,
    }, true
}

// Impulse
// J = m∆v
// ∆v = J / m
solve_collision :: proc(manifold: Manifold, ent_a, ent_b: EntityId) {
    rb_a, is_dynamic_a := physics_get_rigidbody(ent_a)
    rb_b, is_dynamic_b := physics_get_rigidbody(ent_b)

    a_vel := rb_a.velocity if is_dynamic_a else glm.vec3(0)
    b_vel := rb_b.velocity if is_dynamic_b else glm.vec3(0)
    rel_vel := b_vel - a_vel

    speed := glm.dot(rel_vel, manifold.normal) // Strength of impulse
    if speed >= 0 {
        return // Prevent negative impulses (i.e. pulling objects closer.)
    }

    a_inv_mass := 1.0 / rb_a.mass if is_dynamic_a else 1.0
    b_inv_mass := 1.0 / rb_b.mass if is_dynamic_b else 1.0
    total_mass := a_inv_mass + b_inv_mass

    impulse := manifold.normal * (-speed / total_mass)

    // Heavier objects get pushed less.
    if is_dynamic_a {
        dv := impulse * a_inv_mass
        fmt.println("a ∆v:", dv)
        a_vel -= dv
    }
    if is_dynamic_b {
        dv := impulse * b_inv_mass
        fmt.println("b ∆v:", dv)
        b_vel += dv
    }

    // @TODO: apply friction

    // Move rigidbodies and apply collision force.
    if is_dynamic_a {
        delta_pos := manifold.normal * manifold.depth * (a_inv_mass / total_mass)
        fmt.println("a ∆pos:", delta_pos)
        entities[ent_a].pos -= delta_pos
        rb_a.velocity = a_vel
    }
    if is_dynamic_b {
        delta_pos := manifold.normal * manifold.depth * (b_inv_mass / total_mass)
        fmt.println("b ∆pos:", delta_pos)
        entities[ent_b].pos += delta_pos
        rb_b.velocity = b_vel
    }
}
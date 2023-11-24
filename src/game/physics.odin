// Physics system
// References:
//     * https://winter.dev/articles/physics-engine/DirkGregorius_Contacts.pdf
package game

import glm "core:math/linalg/glsl"
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

physics_add_rigidbody :: proc(ent_id: EntityId, mass: f32) {
    ent := &entities[ent_id]
    ent.rigidbody_id = storage.dense_add(&physics.rigidbodies, Rigidbody{
        mass = mass,
    })
}

physics_get_rigidbody :: proc(ent_id: EntityId) -> (rb: ^Rigidbody, ok: bool) {
    id := entities[ent_id].rigidbody_id.? or_return
    rb = storage.dense_get(physics.rigidbodies, id)
    return rb, rb != nil
}

physics_update :: proc(dt: f32) {
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

        // @HACK: replace with plane collision
        if ent.pos.y < 1 {
            ent.pos.y = 1
        }

        rb.force = 0
    }

    // Collision detection, fully O(N²); extremely naive approach.
    for sphere_a in physics.spheres {
        for sphere_b in physics.spheres {
            if sphere_a.ent_id == sphere_b.ent_id {
                continue
            }

            contact := is_colliding(sphere_a, sphere_b) or_continue
            solve_collision(contact, sphere_a.ent_id, sphere_b.ent_id)
        }

        for plane_b in physics.planes {
            // contact := is_colliding(sphere_a, plane_b) or_continue
            // solve_collision(sphere_a, plane_b)
        }
    }
}

// O(n) lookup by entity id. Only use for devtools or very infrequently.
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

CollisionPoint :: struct {
    pos: glm.vec3,
    depth: f32,
}

Manifold :: struct {
    points: [4]CollisionPoint,
    count: int, // Number of points
    normal: glm.vec3,
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
    point_b := pos_b + sb.radius * normal // Surface point on B inside A
    return Manifold{
        normal = normal,
        count = 1,
        points = {
            0 = {
                pos = point_a + point_b / 2, // Halfway between collision points.
                depth = distance - sa.radius - sb.radius,
            },
        },
    }, true
}

is_colliding_sphere_plane :: proc(sphere: SphereCollider, plane: PlaneCollider) -> (Manifold, bool) {
    sphere_pos := entities[sphere.ent_id].pos
    distance := glm.dot(plane.normal, sphere_pos) - plane.distance
    return {}, distance < sphere.radius
}

solve_collision :: proc(manifold: Manifold, ent_a, ent_b: EntityId) {
    rb_a, _ := physics_get_rigidbody(ent_a)
    rb_b, _ := physics_get_rigidbody(ent_b)

    a_vel := glm.vec3(0) if rb_a == nil else rb_a.velocity
    b_vel := glm.vec3(0) if rb_b == nil else rb_b.velocity
    rel_vel := b_vel - a_vel

    speed := glm.dot(rel_vel, manifold.normal) // Strength of impulse
    if speed >= 0 {
        return // Prevent negative impulses (i.e. pulling objects closer.)
    }

    a_inv_mass := 1 if rb_a == nil else 1 / rb_a.mass
    b_inv_mass := 1 if rb_b == nil else 1 / rb_b.mass

    power := speed / (a_inv_mass + b_inv_mass)
    impulse := power * manifold.normal

    for p in 0..<manifold.count {
        point := manifold.points[p]

        if rb_a != nil {
            rb_a.velocity = rb_a.velocity
        }

    }

}
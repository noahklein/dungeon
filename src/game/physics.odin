package game

import glm "core:math/linalg/glsl"

EPSILON :: 0.0001

Plane :: struct {
    center, normal: glm.vec3,
}

raycast_plane :: proc(plane: Plane, origin, dir: glm.vec3) -> bool {
    denom := glm.dot(plane.normal, dir)
    if abs(denom) <= EPSILON {
        return false // We're perpendicular.
    }

    t := glm.dot(plane.center - origin, plane.normal) / denom
    return t > EPSILON
}

Box :: struct {
    min, max: glm.vec3,
}

// See https://tavianator.com/2011/ray_box.html.
raycast_box :: proc(box: Box, origin, dir: glm.vec3) -> (glm.vec3, bool) {
    min_dist := (box.min - origin) / dir
    max_dist := (box.max - origin) / dir

    // Normalize
    mins := glm.min(min_dist, max_dist)
    maxs := glm.max(min_dist, max_dist)

    smallest := min(mins.x, mins.y, mins.z)
    biggest  := max(maxs.x, maxs.y, maxs.z)

    is_hit := biggest >= 0 && biggest >= smallest
    hit_point := origin + (smallest * dir)
    return hit_point, is_hit
}
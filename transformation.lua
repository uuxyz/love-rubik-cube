local Matrix = require("matrix")
local Matrix3 = require("matrix3")
local Quaternion = require("quaternion")

local Transformation = {}
Transformation.__index = Transformation

function Transformation.new(translate, rotate, scale)
    return setmetatable({
        translate = translate or Matrix3.vec_zero(),
        rotate = rotate or Quaternion.new(1, 0, 0, 0),
        scale = scale or Matrix3.new_vector(1, 1, 1),
    }, Transformation)
end

function Transformation:translate_matrix()
    return {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        self.translate.x, self.translate.y, self.translate.z, 1
    }
end

function Transformation:rotate_matrix()
    return self.rotate:to_matrix()
end

function Transformation:scale_matrix()
    return {
        self.scale.x, 0, 0, 0,
        0, self.scale.y, 0, 0,
        0, 0, self.scale.z, 0,
        0, 0, 0, 1
    }
end

function Transformation:to_matrix()
    local T = self:translate_matrix()
    local R = self:rotate_matrix()
    local S = self:scale_matrix()
    return Matrix.multiply(T, Matrix.multiply(R, S))
end

-- Inverse transformation
function Transformation:inverse()
    local inv_scale = Matrix3.new_vector(
        1 / self.scale.x,
        1 / self.scale.y,
        1 / self.scale.z
    )
    local inv_rot = self.rotate:conjugate()
    local inv_trans = Matrix3.new_vector(
        -self.translate.x,
        -self.translate.y,
        -self.translate.z
    )

    -- Inverse scale, then inverse rotation, then inverse translation (applied in reverse)
    local inv = Transformation.new()
    inv.scale = inv_scale
    inv.rotate = inv_rot
    inv.translate = Matrix3.vec_zero()

    -- Inverse translation needs to be processed after applying rotation and scale inverse
    local rotated_trans = inv_rot:rotate_vector(Matrix3.new_vector(
        inv_trans.x * inv_scale.x,
        inv_trans.y * inv_scale.y,
        inv_trans.z * inv_scale.z
    ))
    inv.translate = rotated_trans
    return inv
end

-- Apply to point (includes scale, rotation, translation)
function Transformation:apply_point(v)
    local p = Matrix3.new_vector(
        v.x * self.scale.x,
        v.y * self.scale.y,
        v.z * self.scale.z
    )
    p = self.rotate:rotate_vector(p)
    return Matrix3.vec_add(p, self.translate)
end

-- Apply to direction vector (no translation)
function Transformation:apply_vector(v)
    local p = Matrix3.new_vector(
        v.x * self.scale.x,
        v.y * self.scale.y,
        v.z * self.scale.z
    )
    return self.rotate:rotate_vector(p)
end

-- Apply to normal (uses inverse scale + rotation)
function Transformation:apply_normal(n)
    -- Normals use inverse scale
    local inv_scale = Matrix3.new_vector(
        1 / self.scale.x,
        1 / self.scale.y,
        1 / self.scale.z
    )
    local p = Matrix3.new_vector(
        n.x * inv_scale.x,
        n.y * inv_scale.y,
        n.z * inv_scale.z
    )
    return self.rotate:rotate_vector(p)
end

return Transformation

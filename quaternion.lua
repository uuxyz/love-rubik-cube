local Matrix3 = require("matrix3")
local Quaternion = {}
Quaternion.__index = Quaternion

-- Constructor: Quaternion.new(x, y, z, w)
function Quaternion.new(w, x, y, z)
    return setmetatable({w = w, x = x, y = y, z = z}, Quaternion)
end

function Quaternion.from_angle(roll, pinch, yaw)
    local cr = math.cos(roll * 0.5)
    local sr = math.sin(roll * 0.5)
    local cp = math.cos(pinch * 0.5)
    local sp = math.sin(pinch * 0.5)
    local cy = math.cos(yaw * 0.5)
    local sy = math.sin(yaw * 0.5)
    return Quaternion.new(
        cr * cp * cy + sr * sp * sy,
        sr * cp * cy - cr * sp * sy,
        cr * sp * cy + sr * cp * sy,
        cr * cp * sy - sr * sp * cy
    )
end

function Quaternion:copy()
    return Quaternion.new(self.w, self.x, self.y, self.z)
end

function Quaternion:conjugate()
    return Quaternion.new(self.w, -self.x, -self.y, -self.z)
end

-- Normalize the quaternion
function Quaternion:normalize()
    local mag = math.sqrt(self.x^2 + self.y^2 + self.z^2 + self.w^2)
    return Quaternion.new(self.w / mag, self.x / mag, self.y / mag, self.z / mag)
end

function Quaternion:add(q)
    return Quaternion.new(self.w + q.w, self.x + q.x, self.y + q.y, self.z + q.z)
end

function Quaternion:scale(s)
    return Quaternion.new(self.w * s, self.x * s, self.y * s, self.z * s)
end

-- Quaternion multiplication: self * q
function Quaternion:multiply(q)
    local aw, ax, ay, az = self.w, self.x, self.y, self.z
    local bw, bx, by, bz = q.w, q.x, q.y, q.z

    return Quaternion.new(
			 aw * bw - ax * bx - ay * by - az * bz,
			 aw * bx + ax * bw + ay * bz - az * by,
			 aw * by - ax * bz + ay * bw + az * bx,
			 aw * bz + ax * by - ay * bx + az * bw
    )
end

-- Rotate a 3D vector using this quaternion
function Quaternion:rotate_vector(v)
    -- local qv = Quaternion.new(0, v.x, v.y, v.z)
    -- local q = self:multiply(qv):multiply(self:conjugate())
    -- return Matrix3.new_vector(q.x, q.y, q.z)
    local qw, qx, qy, qz = self.w, self.x, self.y, self.z
    local vx, vy, vz = v.x, v.y, v.z

    local iw = -qx * vx - qy * vy - qz * vz
    local ix =  qw * vx + qy * vz - qz * vy
    local iy =  qw * vy + qz * vx - qx * vz
    local iz =  qw * vz + qx * vy - qy * vx

    return Matrix3.new_vector(
        ix * qw + iw * -qx + iy * -qz - iz * -qy,
        iy * qw + iw * -qy + iz * -qx - ix * -qz,
        iz * qw + iw * -qz + ix * -qy - iy * -qx
    )
end

-- Convert to 4x4 matrix
function Quaternion:to_matrix4x4()
    local x_axis = self:rotate_vector(Matrix3.new_vector(1, 0, 0))
    local y_axis = self:rotate_vector(Matrix3.new_vector(0, 1, 0))
    local z_axis = self:rotate_vector(Matrix3.new_vector(0, 0, 1))

    return {
        x_axis.x, x_axis.y, x_axis.z, 0,
        y_axis.x, y_axis.y, y_axis.z, 0,
        z_axis.x, z_axis.y, z_axis.z, 0,
        0, 0, 0, 1
    }
end

-- Convert to 3x3 matrix
function Quaternion:to_matrix3x3()
    local x_axis = self:rotate_vector(Matrix3.new_vector(1, 0, 0))
    local y_axis = self:rotate_vector(Matrix3.new_vector(0, 1, 0))
    local z_axis = self:rotate_vector(Matrix3.new_vector(0, 0, 1))

    return {
        x_axis.x, x_axis.y, x_axis.z,
        y_axis.x, y_axis.y, y_axis.z,
        z_axis.x, z_axis.y, z_axis.z,
    }
end

function Quaternion:to_matrix3()
    local qw, qx, qy, qz = self.w, self.x, self.y, self.z
    return {
        1 - 2 * (qy * qy + qz * qz), 2 * (qx * qy + qz * qw), 2 * (qx * qz - qy * qw),
        2 * (qx * qy - qz * qw), 1 - 2 * (qx * qx + qz * qz), 2 * (qy * qz + qx * qw),
        2 * (qx * qz + qy * qw), 2 * (qy * qz - qx * qw), 1 - 2 * (qx * qx + qy * qy),
    }
end

function Quaternion:to_matrix()
    local mat3 = self:to_matrix3()
    return {
        mat3[1], mat3[2], mat3[3], 0,
        mat3[4], mat3[5], mat3[6], 0,
        mat3[7], mat3[8], mat3[9], 0,
        0, 0, 0, 1
    }
end

-- Create a quaternion from angle (in radians) and axis (x, y, z)
function Quaternion.from_angle_axis(angle, axis)
    local half_angle = angle * 0.5
    local sin_half = math.sin(half_angle)
    local cos_half = math.cos(half_angle)
    local ax, ay, az = axis.x, axis.y, axis.z

    -- Normalize axis
    local mag = math.sqrt(ax * ax + ay * ay + az * az)
    if mag == 0 then
        error("Axis vector cannot be zero")
    end
    ax, ay, az = ax / mag, ay / mag, az / mag

    return Quaternion.new(
        cos_half,
        ax * sin_half,
        ay * sin_half,
        az * sin_half
    )
end

function Quaternion.slerp(q1, q2, t)
    -- Dot product (determine angle)
    local dot = q1.w*q2.w + q1.x*q2.x + q1.y*q2.y + q1.z*q2.z

    -- If dot product is negative, negate q2 to take the shortest arc
    if dot < 0 then
        q2 = Quaternion.new(-q2.w, -q2.x, -q2.y, -q2.z)
        dot = -dot
    end

    -- If very close (avoid division by zero), fall back to nlerp
    if dot > 0.9995 then
        local w = q1.w + t*(q2.w - q1.w)
        local x = q1.x + t*(q2.x - q1.x)
        local y = q1.y + t*(q2.y - q1.y)
        local z = q1.z + t*(q2.z - q1.z)
        local mag = math.sqrt(w*w + x*x + y*y + z*z)
        return Quaternion.new(w/mag, x/mag, y/mag, z/mag)
    end

    -- Calculate angle
    local theta = math.acos(dot)
    local sin_theta = math.sin(theta)

    local s1 = math.sin((1 - t) * theta) / sin_theta
    local s2 = math.sin(t * theta) / sin_theta

    local w = s1*q1.w + s2*q2.w
    local x = s1*q1.x + s2*q2.x
    local y = s1*q1.y + s2*q2.y
    local z = s1*q1.z + s2*q2.z
    return Quaternion.new(w, x, y, z)
end


return Quaternion

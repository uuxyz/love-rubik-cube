local Quaternion = require("quaternion")
local Matrix = require("matrix")
local Matrix3 = require("matrix3")
-- local Projection = require("projection")

local Camera = {}
Camera.__index = Camera

-- Constructor: Camera.new(x, y, z, roll, pinch, yaw)
function Camera.new(x, y, z, roll, pinch, yaw, projection)
    return setmetatable({
        x = x or 0,
        y = y or 0,
        z = z or 0,
        roll = roll or 0,
        pinch = pinch or 0,
        yaw = yaw or 0,
        target_x = x or 0,
        target_y = y or 0,
        target_z = z or 0,
        target_roll = roll or 0,
        target_pinch = pinch or 0,
        target_yaw = yaw or 0,
        move_speed = 0,
        rotate_speed = 0,
        original_x = x or 0,
        original_y = y or 0,
        original_z = z or 0,
        original_roll = roll or 0,
        original_pinch = pinch or 0,
        original_yaw = yaw or 0,
        velocity_x = 0,
        velocity_y = 0,
        velocity_z = 0,
        angular_velocity_roll = 0,
        angular_velocity_pinch = 0,
        angular_velocity_yaw = 0,
        projection = projection or nil
    }, Camera)
end

function Camera:get_position()
    return Matrix3.new_vector(self.x, self.y, self.z)
end

function Camera:set_position(pos)
    self.x = pos.x
    self.y = pos.y
    self.z = pos.z
end

function Camera:reset()
    self.x = self.original_x
    self.y = self.original_y
    self.z = self.original_z
    self.target_x = self.original_x
    self.target_y = self.original_y
    self.target_z = self.original_z
    self.roll = self.original_roll
    self.pinch = self.original_pinch
    self.yaw = self.original_yaw
    self.target_roll = self.original_roll
    self.target_pinch = self.original_pinch
    self.target_yaw = self.original_yaw
end

-- Smoothly interpolate camera state
function Camera:update(dt)
    local lerp = function(a, b, t)
        return a + (b - a) * math.min(t, 1)
    end

    local prev_x = self.x
    local prev_y = self.y
    local prev_z = self.z
    local prev_roll = self.roll
    local prev_pinch = self.pinch
    local prev_yaw = self.yaw

    local s    = self.move_speed * dt
    self.x     = lerp(self.x, self.target_x, s)
    self.y     = lerp(self.y, self.target_y, s)
    self.z     = lerp(self.z, self.target_z, s)

    local rs   = self.rotate_speed * dt
    self.yaw   = lerp(self.yaw, self.target_yaw, rs)
    self.pinch = lerp(self.pinch, self.target_pinch, rs)
    self.roll  = lerp(self.roll, self.target_roll, rs)

    -- Calculate current velocities
    if dt > 0 then
        self.velocity_x = (self.x - prev_x) / dt
        self.velocity_y = (self.y - prev_y) / dt
        self.velocity_z = (self.z - prev_z) / dt
        self.angular_velocity_roll = (self.roll - prev_roll) / dt
        self.angular_velocity_pinch = (self.pinch - prev_pinch) / dt
        self.angular_velocity_yaw = (self.yaw - prev_yaw) / dt
    else
        self.velocity_x = 0
        self.velocity_y = 0
        self.velocity_z = 0
        self.angular_velocity_roll = 0
        self.angular_velocity_pinch = 0
        self.angular_velocity_yaw = 0
    end
end

-- Move in Minecraft-style direction
function Camera:move(direction_vec, speed, dt)
    self.move_speed = speed

    local q = Quaternion.from_angle(self.roll, self.pinch, self.yaw)

    local dir = q:rotate_vector(direction_vec)

    self.target_x = self.target_x + dir.x * speed * dt
    self.target_y = self.target_y + dir.y * speed * dt
    self.target_z = self.target_z + dir.z * speed * dt
end

-- Move in GMod-style (towards cursor direction vector)
function Camera:move_towards_cursor(cursor_direction, speed, dt)
    self.move_speed = speed

    self.target_x = self.target_x + cursor_direction.x * speed * dt
    self.target_y = self.target_y + cursor_direction.y * speed * dt
    self.target_z = self.target_z + cursor_direction.z * speed * dt
end

-- Set target rotation (will be interpolated in update)
function Camera:rotate(delta_roll, delta_pitch, delta_yaw, speed)
    self.rotate_speed = speed
    self.target_roll = self.target_roll + delta_roll
    self.target_pinch = self.target_pinch + delta_pitch
    self.target_yaw = self.target_yaw + delta_yaw
    if self.target_pinch > math.rad(90) then
        self.target_pinch = math.rad(90)
    end
    if self.target_pinch < -math.rad(90) then
        self.target_pinch = -math.rad(90)
    end
end

--- New methods to get velocity and angular velocity
function Camera:get_velocity()
    return Matrix3.new_vector(self.velocity_x, self.velocity_y, self.velocity_z)
end

function Camera:get_angular_velocity()
    return {
        roll = self.angular_velocity_roll,
        pinch = self.angular_velocity_pinch,
        yaw = self.angular_velocity_yaw
    }
end

--- New methods to get directional vectors
function Camera:get_forward_vector()
    local q = Quaternion.from_angle(self.roll, self.pinch, self.yaw)
    -- Assuming +Z is forward in local space
    return q:rotate_vector(Matrix3.new_vector(1, 0, 0))
end

function Camera:get_backward_vector()
    local q = Quaternion.from_angle(self.roll, self.pinch, self.yaw)
    -- Assuming -Z is backward in local space
    return q:rotate_vector(Matrix3.new_vector(-1, 0, 0))
end

function Camera:get_right_vector()
    local q = Quaternion.from_angle(self.roll, self.pinch, self.yaw)
    -- Assuming +X is right in local space
    return q:rotate_vector(Matrix3.new_vector(0, -1, 0))
end

function Camera:get_left_vector()
    local q = Quaternion.from_angle(self.roll, self.pinch, self.yaw)
    -- Assuming -X is left in local space
    return q:rotate_vector(Matrix3.new_vector(0, 1, 0))
end

function Camera:get_up_vector()
    local q = Quaternion.from_angle(self.roll, self.pinch, self.yaw)
    -- Assuming +Y is up in local space
    return q:rotate_vector(Matrix3.new_vector(0, 0, 1))
end

function Camera:get_down_vector()
    local q = Quaternion.from_angle(self.roll, self.pinch, self.yaw)
    -- Assuming -Y is down in local space
    return q:rotate_vector(Matrix3.new_vector(0, 0, -1))
end


-- Camera:rotate_matrix() -> 4x4 matrix
function Camera:rotate_matrix_old()
    local q_roll = Quaternion.from_angle_axis(-self.roll, Matrix3.new_vector(1, 0, 0))
    local q_pinch = Quaternion.from_angle_axis(-self.pinch, Matrix3.new_vector(0, 1, 0))
    local q_yaw = Quaternion.from_angle_axis(-self.yaw, Matrix3.new_vector(0, 0, 1))

    -- Initial orientation quaternion
    local result = Quaternion.new(0.5, -0.5, 0.5, 0.5)

    result = result:multiply(q_roll)
    result = result:multiply(q_pinch)
    result = result:multiply(q_yaw)

    return result:to_matrix()
end

function Camera:rotate_matrix()
    local result = Quaternion.new(0.5, -0.5, 0.5, 0.5)
    result = result:multiply(Quaternion.from_angle(self.roll, self.pinch, self.yaw):conjugate())
    return result:to_matrix()
end

-- Camera:translate_matrix() -> 4x4 matrix
function Camera:translate_matrix()
    return {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        -self.x, -self.y, -self.z, 1
    }
end

-- Camera:get_view_matrix() -> 4x4 matrix
function Camera:get_view_matrix()
    local T = self:translate_matrix()
    local R = self:rotate_matrix()
    return Matrix.multiply(R, T)
end

local function atan2(y, x)
    if x > 0 then
        return math.atan(y / x)
    elseif x < 0 then
        if y >= 0 then
            return math.atan(y / x) + math.pi
        else
            return math.atan(y / x) - math.pi
        end
    elseif x == 0 then
        if y > 0 then
            return math.pi / 2
        elseif y < 0 then
            return -math.pi / 2
        else
            return 0  -- Undefined, but return 0 safely
        end
    end
end


function Camera:set_look(target)
    self:look_at(target)

    self.yaw = self.target_yaw
    self.pinch = self.target_pinch
end

function Camera:look_at(target)
    local pos = self:get_position()
    local to_target = Matrix3.vec_sub(target, pos)

    -- ========== Step 1: Safely normalize the horizontal vector ==========
    local flat_len = math.sqrt(to_target.x^2 + to_target.y^2)
    local flat_target
    if flat_len > 1e-6 then
        flat_target = Matrix3.new_vector(to_target.x / flat_len, to_target.y / flat_len, 0)
    else
        flat_target = Matrix3.new_vector(1, 0, 0)  -- Default forward (prevent division by 0)
    end

    -- ========== Step 2: Calculate Yaw ==========
    local forward = Matrix3.new_vector(1, 0, 0)
    local dot_yaw = Matrix3.vec_dot(forward, flat_target)
    dot_yaw = math.max(-1.0, math.min(1.0, dot_yaw))  -- Clamp to [-1, 1]

    local yaw = math.acos(dot_yaw)
    if Matrix3.vec_cross(forward, flat_target).z < 0 then
        yaw = -yaw
    end

    -- ========== Step 3: Calculate Pitch ==========
    local horizontal_len = math.sqrt(to_target.x^2 + to_target.y^2)
    local pitch_vec_len = math.sqrt(horizontal_len^2 + to_target.z^2)
    local pitch_vec
    if pitch_vec_len > 1e-6 then
        pitch_vec = Matrix3.new_vector(horizontal_len / pitch_vec_len, 0, to_target.z / pitch_vec_len)
    else
        pitch_vec = Matrix3.new_vector(1, 0, 0)
    end

    local dot_pitch = Matrix3.vec_dot(forward, pitch_vec)
    dot_pitch = math.max(-1.0, math.min(1.0, dot_pitch))

    local pitch = math.acos(dot_pitch)
    if pitch_vec.z > 0 then
        pitch = -pitch
    end

    self.target_yaw = yaw
    self.target_pinch = pitch
end

local function deepcopy(orig)
    local copy
    if type(orig) == 'table' then
        copy = {}
        for k, v in pairs(orig) do
            copy[k] = deepcopy(v)
        end
        setmetatable(copy, getmetatable(orig))
    else
        copy = orig
    end
    return copy
end

-- Camera:get_left_eye_matrix(eye_separation)
function Camera:get_left_eye_matrix(eye_separation)
    local eye_offset = -eye_separation / 2
    local eye = deepcopy(self)

    -- Move left by eye_offset in the camera's own coordinate system
    local q = Quaternion.from_angle_axis(eye.yaw, Matrix3.new_vector(0, 0, 1))
        :multiply(Quaternion.from_angle_axis(eye.pinch, Matrix3.new_vector(0, 1, 0)))
        :multiply(Quaternion.from_angle_axis(eye.roll, Matrix3.new_vector(1, 0, 0)))
        :normalize()

    local offset = q:rotate_vector(Matrix3.new_vector(eye_offset, 0, 0))
    eye.x = eye.x + offset.x
    eye.y = eye.y + offset.y
    eye.z = eye.z + offset.z

    return eye:get_view_matrix()
end

-- Camera:get_right_eye_matrix(eye_separation)
function Camera:get_right_eye_matrix(eye_separation)
    local eye_offset = eye_separation / 2
    local eye = deepcopy(self)

    local q = Quaternion.from_angle_axis(eye.yaw, Matrix3.new_vector(0, 0, 1))
        :multiply(Quaternion.from_angle_axis(eye.pinch, Matrix3.new_vector(0, 1, 0)))
        :multiply(Quaternion.from_angle_axis(eye.roll, Matrix3.new_vector(1, 0, 0)))
        :normalize()

    local offset = q:rotate_vector(Matrix3.new_vector(eye_offset, 0, 0))
    eye.x = eye.x + offset.x
    eye.y = eye.y + offset.y
    eye.z = eye.z + offset.z

    return eye:get_view_matrix()
end

-- Convert screen coordinates to normalized device coordinates (NDC)
local function screen_to_ndc(x, y, width, height)
    local ndc_x = (2 * x) / width - 1
    local ndc_y = 1 - (2 * y) / height -- Flip y
    return ndc_x, ndc_y
end

-- Project NDC coordinates back to world space
function Camera:generate_mouse_ray(mouse_x, mouse_y)
    -- Error: camera.lua:196: attempt to index local 'self' (a number value)
    local ndc_x, ndc_y = screen_to_ndc(mouse_x, mouse_y, self.projection.width, self.projection.height)

    -- clip space (z = -1 for near plane)
    local ray_clip = Matrix.new_vector(ndc_x, ndc_y, -1, 1)

    -- Get the inverse projection matrix
    local proj_matrix = self.projection:get_projection_matrix()
    local inv_proj = Matrix.inverse(proj_matrix)

    -- From clip space -> view space
    local ray_eye = Matrix.multiply_vector(inv_proj, ray_clip)
    ray_eye = Matrix.new_vector(ray_eye.x, ray_eye.y, -1, 0) -- Direction vector, set w to 0

    -- Get the inverse view matrix
    local view_matrix = self:get_view_matrix()
    local inv_view = Matrix.inverse(view_matrix)

    -- view space -> world space
    local ray_world = Matrix.multiply_vector(inv_view, ray_eye)

    ray_world = Matrix3.new_vector(ray_world.x, ray_world.y, ray_world.z)

    local direction = Matrix3.vec_normalize(ray_world)

    return direction
end

function Camera:project_to_screen(world_pos)
    local view = self:get_view_matrix()
    local projection = self.projection:get_ortho_matrix()
    -- local projection = self.projection:get_projection_matrix()

    local world = Matrix.new_vector(world_pos.x, world_pos.y, world_pos.z, 1.0)
    local view_space = Matrix.multiply_vector(view, world)
    local clip_space = Matrix.multiply_vector(projection, view_space)
    -- clip_space = {clip_space.w, clip_space.x, clip_space.y, clip_space.z}

    local ndc_x, ndc_y, ndc_z = 0, 0, 1
    local w = clip_space.w
    if w ~= 0 then
        ndc_x = clip_space.x / w
        ndc_y = clip_space.y / w
        ndc_z = clip_space.z / w
    end

    local screen_x = (ndc_x * 0.5 + 0.5) * self.projection.width
    local screen_y = (1.0 - (ndc_y * 0.5 + 0.5)) * self.projection.height
    local view_z = view_space.z

    return Matrix3.new_vector(screen_x, screen_y, -view_z)
end

function Camera:vanishing_point(dir)
    local view = self:get_view_matrix()
    local projection = self.projection:get_projection_matrix()
    local far_point_world = Matrix.new_vector(dir.x, dir.y, dir.z, 0.0)
    local clip = Matrix.multiply_vector(projection, Matrix.multiply_vector(view, far_point_world))
    local ndc = Matrix3.vec_scale(Matrix3.new_vector(clip.x, clip.y, clip.z), 1 / clip.w)

    local screen_x = (ndc.x * 0.5 + 0.5) * self.projection.width
    local screen_y = (1.0 - (ndc.y * 0.5 + 0.5)) * self.projection.height
    return Matrix3.new_vector(screen_x, screen_y, ndc.z)
end

function Camera:ray_direction()
    local q_roll = Quaternion.from_angle_axis(CameraInstance.roll, Matrix3.new_vector(1, 0, 0))
	local q_pinch = Quaternion.from_angle_axis(CameraInstance.pinch, Matrix3.new_vector(0, 1, 0))
	local q_yaw = Quaternion.from_angle_axis(CameraInstance.yaw, Matrix3.new_vector(0, 0, 1))
	local q_rot = q_yaw:multiply(q_pinch:multiply(q_roll))

	local rd = q_rot:rotate_vector(Matrix3.new_vector(1, 0, 0))
    return rd
end

function Camera.debug()
    local TestCamera = Camera.new(12.3, 45.6, 78.9, 0, 0, 0)
    TestCamera:set_look(Matrix3.new_vector(98.7, 65.4, 32.1))
    local view_matrix = TestCamera:get_view_matrix()
    Matrix.print(view_matrix)
--     // 0.22   0.46  -0.86   0.00
-- //  -0.97   0.10  -0.20   0.00
-- //   0.00   0.88   0.47   0.00
-- //  41.70 -80.13 -17.23   1.00

-- // 0.223376 0.455101 -0.861966 0
-- // -0.974732 0.104294 -0.197534 0
-- // 0 0.884311 0.466899 0
-- // 41.7003 -80.1257 -17.2286 1
end

return Camera

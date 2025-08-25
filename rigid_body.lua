local Quaternion = require("quaternion")
local Matrix3 = require("matrix3")
local Transformation = require("transformation")

local RigidBody = {}
RigidBody.__index = RigidBody

function RigidBody.new(mass_inv, mesh)
    local self = setmetatable({}, RigidBody)
    self.mass_inv = mass_inv
    self.mesh = mesh
    self.position = Matrix3.vec_zero()
    self.velocity = Matrix3.vec_zero()
    self.momentum = Matrix3.vec_zero()
    self.force = Matrix3.vec_zero()
    self.scale = Matrix3.new_vector(1, 1, 1)

    self.angular_velocity = Matrix3.vec_zero()
    self.angular_momentum = Matrix3.vec_zero()
    self.torque = Matrix3.vec_zero()

    self.orientation = Quaternion.new(1, 0, 0, 0) -- Identity quaternion
    self.inertia_inv_body = Matrix3.identity()
    self.inertia_body = Matrix3.identity()

    return self
end

function RigidBody:set_position(x, y, z)
    self.position = Matrix3.new_vector(x, y, z)
end

function RigidBody:set_velocity(x, y, z)
    self.angular_velocity = Matrix3.new_vector(x, y, z)
    self.angular_momentum = Matrix3.vec_scale(self.angular_velocity, 1 / self.mass_inv)
end

function RigidBody:set_angular_velocity(x, y, z)
    self.angular_velocity = Matrix3.new_vector(x, y, z)
    self.angular_momentum = Matrix3.solve(self:get_inertia_inv_world(), self.angular_velocity)
end

function RigidBody:set_scale(x, y, z)
    self.scale = Matrix3.new_vector(x, y, z)
end

function RigidBody:set_inertia(inertia)
    self.inertia_body = inertia
    self.inertia_inv_body = Matrix3.inverse(inertia)
    -- Matrix3.print(Matrix3.multiply(self.inertia_body, self.inertia_inv_body))
end

function RigidBody:apply_force(force, point)
    self.force = Matrix3.vec_add(self.force, force)
    local r = Matrix3.vec_sub(point, self.position)
    local torque = Matrix3.vec_cross(r, force)
    self.torque = Matrix3.vec_add(self.torque, torque)
end

-- Modify your original get_inertia_world to accept only a quaternion parameter
function RigidBody:get_inertia_world_from_orientation(orientation_q)
    local R = orientation_q:to_matrix3()
    local RT = Matrix3.transpose(R)
    -- Note: self.inertia_body must be the inertia tensor in the body's local coordinate system
    return Matrix3.multiply(Matrix3.multiply(R, self.inertia_body), RT)
end

-- Keep the original get_inertia_world function, it can now call the new helper function
function RigidBody:get_inertia_world()
    local R = self.orientation:to_matrix3()
    local RT = Matrix3.transpose(R)
    return Matrix3.multiply(Matrix3.multiply(R, self.inertia_body), RT)
end

function RigidBody:get_inertia_inv_world()
    local R = self.orientation:to_matrix3()
    local RT = Matrix3.transpose(R)
    return Matrix3.multiply(Matrix3.multiply(R, self.inertia_inv_body), RT)
end

function RigidBody:get_kinetic_energy()
    local p_len2 = Matrix3.vec_dot(self.momentum, self.momentum)
    local linear_ke = 0.5 * p_len2 * self.mass_inv

    local angular_ke = 0.5 * Matrix3.vec_dot(self.angular_momentum, self.angular_velocity)

    return linear_ke + angular_ke
end

function RigidBody:apply_impulse(impulse, point)
    -- Linear velocity change
    -- self.velocity = Matrix3.vec_add(self.velocity, Matrix3.vec_scale(impulse, self.mass_inv))
    self.momentum = Matrix3.vec_add(self.momentum, impulse)

    -- Rotation part
    -- local r = Matrix3.vec_sub(point, self.position)
    -- local inertia_inv_world = self:get_inertia_inv_world()

    -- local angular_impulse = Matrix3.multiply_vector(inertia_inv_world, Matrix3.vec_cross(r, impulse))
    -- self.angular_velocity = Matrix3.vec_add(self.angular_velocity, angular_impulse)
    -- Rotation part: update angular momentum instead of angular velocity
    local r = Matrix3.vec_sub(point, self.position)
    local angular_impulse = Matrix3.vec_cross(r, impulse)

    self.angular_momentum = Matrix3.vec_add(self.angular_momentum, angular_impulse)
end

function RigidBody:grab_rigid(contact_point, camera_position)
	-- Current grab point (rigid body's contact_point)
	local r = Matrix3.vec_sub(contact_point, self.position)
	local current_point = Matrix3.vec_add(self.position, r)

	-- Spring force direction (Hooke's Law)
	local displacement = Matrix3.vec_sub(camera_position, contact_point)
	local stiffness = 1  -- You can adjust this value to control pull strength
	local spring_force = Matrix3.vec_scale(displacement, stiffness)

	-- Damping force (prevent oscillation)
	local contact_velocity = Matrix3.vec_add(
		self.velocity,
		Matrix3.vec_cross(self.angular_velocity, r)
	)
	local damping = 0.4
	local damping_force = Matrix3.vec_scale(contact_velocity, -damping)

	-- Total force
	local total_force = Matrix3.vec_add(spring_force, damping_force)

	-- Apply force to the rigid body
	self:apply_force(total_force, current_point)
end

-- function RigidBody:update(dt)
--     -- Linear update
--     local acc = Matrix3.vec_scale(self.force, self.mass_inv)
--     self.velocity = Matrix3.vec_add(self.velocity, Matrix3.vec_scale(acc, dt))
--     self.position = Matrix3.vec_add(self.position, Matrix3.vec_scale(self.velocity, dt))

--     local inertia_inv_world = self:get_inertia_inv_world()

--     -- Angular acceleration
--     -- local alpha = Matrix3.multiply_vector(inertia_inv_world, self.torque)
--     -- -- Replace with natural spin term from Euler dynamics (intrinsic coupling)
--     -- local inertia_world = self:get_inertia_world()
--     -- local L = Matrix3.multiply_vector(inertia_world, self.angular_velocity)
--     -- local L_cross_omega = Matrix3.vec_cross(L, self.angular_velocity)
--     -- local alpha = Matrix3.multiply_vector(inertia_inv_world, L_cross_omega)
--     -- self.angular_velocity = Matrix3.vec_add(self.angular_velocity, Matrix3.vec_scale(alpha, dt))
--     local inertia_world = self:get_inertia_world()
--     local L = Matrix3.multiply_vector(inertia_world, self.angular_velocity)
--     local omega_cross_L = Matrix3.vec_cross(self.angular_velocity, L) -- Note: this is omega x L
--     local total_torque = Matrix3.vec_sub(self.torque, omega_cross_L) -- External torque - (omega x L)
--     local alpha = Matrix3.multiply_vector(inertia_inv_world, total_torque)
--     self.angular_velocity = Matrix3.vec_add(self.angular_velocity, Matrix3.vec_scale(alpha, dt))

--     -- Update quaternion orientation
--     local w = self.angular_velocity
--     -- local angle = math.sqrt(w.x^2 + w.y^2 + w.z^2) * dt
--     -- if angle > 0 then
--         -- local axis = Matrix3.new_vector(w.x, w.y, w.z)
--         local q_dot = Quaternion.new(0, w.x, w.y, w.z):scale(0.5):multiply(self.orientation)
--         self.orientation = self.orientation:add(q_dot:scale(dt)):normalize()
--         -- local q_rot = Quaternion.from_angle_axis(angle, axis)
--         -- self.orientation = self.orientation:multiply(q_rot):normalize()
--     -- end

--     -- Clear forces and torques
--     self.force = Matrix3.vec_zero()
--     self.torque = Matrix3.vec_zero()
-- end

-- function RigidBody:update(dt)
--     -- 1. Update linear motion (external force)
--     local acc = Matrix3.vec_scale(self.force, self.mass_inv)
--     self.velocity = Matrix3.vec_add(self.velocity, Matrix3.vec_scale(acc, dt))
--     self.position = Matrix3.vec_add(self.position, Matrix3.vec_scale(self.velocity, dt))

--     -- 2. Update angular velocity (external torque + free rotation effect)
--     local I_world = self:get_inertia_world()                     -- Inertia tensor in world coordinates
--     local L = Matrix3.multiply_vector(I_world, self.angular_velocity)  -- Angular momentum L = I*omega

--     -- Total torque = user applied external torque + free rotation gyro term (omega x L)
--     local gyro_torque = Matrix3.vec_cross(self.angular_velocity, L)   -- tau_gyro = omega x L
--     local total_torque = Matrix3.vec_add(self.torque, gyro_torque)     -- tau_total = tau_ext + tau_gyro

--     -- Calculate angular acceleration alpha = I^-1 * tau
--     local alpha = Matrix3.multiply_vector(self:get_inertia_inv_world(), total_torque)
--     self.angular_velocity = Matrix3.vec_add(self.angular_velocity, Matrix3.vec_scale(alpha, dt))

--     -- 3. Update orientation (quaternion integration, avoid angle truncation error)
--     local w = self.angular_velocity
--     local q_dot = Quaternion.new(0, w.x, w.y, w.z):multiply(self.orientation):scale(0.5)
--     self.orientation = self.orientation:add(q_dot:scale(dt)):normalize()

--     local damping = 0.001
--     self.angular_velocity = Matrix3.vec_scale(self.angular_velocity, 1 - damping * dt)

--     -- 4. Clear forces and torques (prepare for next frame)
--     self.force = Matrix3.vec_zero()
--     self.torque = Matrix3.vec_zero()
-- end

-- function RigidBody:update(dt)
--     -- === 1. Update linear motion ===
--     local acc = Matrix3.vec_scale(self.force, self.mass_inv)
--     self.velocity = Matrix3.vec_add(self.velocity, Matrix3.vec_scale(acc, dt))
--     self.position = Matrix3.vec_add(self.position, Matrix3.vec_scale(self.velocity, dt))

--     -- === 2. Update angular velocity ===
--     local I_world = self:get_inertia_world()
--     local I_inv_world = self:get_inertia_inv_world()

--     local omega = self.angular_velocity
--     local L = Matrix3.multiply_vector(I_world, omega)
--     local gyro_torque = Matrix3.vec_cross(omega, L)
--     local total_torque = Matrix3.vec_sub(self.torque, gyro_torque)

--     -- Euler dynamics: alpha = I^-1 (tau_ext + omega x L)
--     local alpha = Matrix3.multiply_vector(I_inv_world, total_torque)
--     omega = Matrix3.vec_add(omega, Matrix3.vec_scale(alpha, dt))

--     -- === 3. Prevent angular velocity explosion ===
--     local max_omega = 1000  -- Adjustable
--     local omega_len = Matrix3.vec_len(omega)
--     if omega_len > max_omega then
--         omega = Matrix3.vec_scale(omega, max_omega / omega_len)
--     end

--     -- === 4. Apply angular velocity damping (optional) ===
--     local damping = 0.001  -- Damping coefficient
--     omega = Matrix3.vec_scale(omega, 1 - damping * dt)

--     self.angular_velocity = omega

--     -- === 5. Update orientation (quaternion exponential map) ===
--     local angle = omega_len * dt
--     if angle > 0 then
--         local axis = Matrix3.vec_scale(omega, 1 / omega_len)
--         local dq = Quaternion.from_angle_axis(angle, axis)
--         self.orientation = dq:multiply(self.orientation):normalize()
--     end

--     -- === 6. Clear forces and torques (prepare for next frame) ===
--     self.force = Matrix3.vec_zero()
--     self.torque = Matrix3.vec_zero()
-- end

function RigidBody:update_semi_implicit_euler(dt)
    -- === 1. Update linear motion ===
    local acc = Matrix3.vec_scale(self.force, self.mass_inv)
    self.velocity = Matrix3.vec_add(self.velocity, Matrix3.vec_scale(acc, dt))
    self.position = Matrix3.vec_add(self.position, Matrix3.vec_scale(self.velocity, dt))

    -- === 2. Update angular velocity using semi-implicit Euler method ===
    local I_world = self:get_inertia_world()
    local I_inv_world = self:get_inertia_inv_world()
    
    -- Prediction step: calculate L using current angular velocity
    local L_pred = Matrix3.multiply_vector(I_world, self.angular_velocity)
    local gyro_torque_pred = Matrix3.vec_cross(self.angular_velocity, L_pred)
    local total_torque_pred = Matrix3.vec_add(self.torque, gyro_torque_pred)
    
    -- Calculate predicted angular velocity
    local alpha_pred = Matrix3.multiply_vector(I_inv_world, total_torque_pred)
    local omega_pred = Matrix3.vec_add(self.angular_velocity, Matrix3.vec_scale(alpha_pred, dt))

    -- Correction step: recalculate using predicted angular velocity
    local L_corr = Matrix3.multiply_vector(I_world, omega_pred)
    local gyro_torque_corr = Matrix3.vec_cross(omega_pred, L_corr)
    local total_torque_corr = Matrix3.vec_add(self.torque, gyro_torque_corr)
    
    -- Final angular velocity update
    local alpha_corr = Matrix3.multiply_vector(I_inv_world, total_torque_corr)
    self.angular_velocity = Matrix3.vec_add(self.angular_velocity, Matrix3.vec_scale(alpha_corr, dt))

    -- === 3. Update orientation (improved quaternion integration) ===
    local omega_len = Matrix3.vec_len(self.angular_velocity)
    if omega_len > 1e-6 then  -- Avoid division by zero
        local axis = Matrix3.vec_scale(self.angular_velocity, 1/omega_len)
        local angle = omega_len * dt
        local dq = Quaternion.from_angle_axis(angle, axis)
        self.orientation = dq:multiply(self.orientation):normalize()
    end

    -- === 4. Clear forces and torques ===
    self.force = Matrix3.vec_zero()
    self.torque = Matrix3.vec_zero()
end

function RigidBody:update_RK4(dt)
    -- Save current state for multiple RK4 evaluations
    local initial_pos = self.position
    local initial_momentum = self.momentum -- Use linear momentum
    local initial_orientation = self.orientation
    local initial_angular_momentum = self.angular_momentum

    -- Define an internal function to get derivatives for a given state
    -- This function creates a temporary RigidBody instance to compute derivatives without modifying the original
    local function get_derivatives(body_state)
        local temp_body = {
            position = body_state.position,
            momentum = body_state.momentum, -- Use linear momentum
            orientation = body_state.orientation,
            angular_momentum = body_state.angular_momentum
        }

        -- Calculate linear velocity from linear momentum, used for position derivative
        temp_body.velocity = Matrix3.vec_scale(temp_body.momentum, self.mass_inv)

        local R = temp_body.orientation:to_matrix3()
        local RT = Matrix3.transpose(R)
        local temp_vector = Matrix3.multiply_vector(RT, temp_body.angular_momentum)
        temp_body.angular_velocity = Matrix3.multiply_vector(R, Matrix3.multiply_vector(self.inertia_inv_body, temp_vector))

        local derivatives = {}
        -- The derivative of linear momentum is force
        derivatives.dp = self.force
        -- The derivative of position is velocity
        derivatives.vel = temp_body.velocity
        derivatives.dL = self.torque -- The derivative of angular momentum is torque

        -- Orientation derivative (dq/dt = 0.5 * omega_q * q)
        -- Convert angular velocity to a pure quaternion (0, omega_x, omega_y, omega_z)
        local omega_q = Quaternion.new(0, temp_body.angular_velocity.x, temp_body.angular_velocity.y, temp_body.angular_velocity.z)
        derivatives.dq = omega_q:multiply(temp_body.orientation):scale(0.5)

        return derivatives
    end

    -- K1
    local state_k1 = {
        position = initial_pos,
        momentum = initial_momentum, -- Use linear momentum
        orientation = initial_orientation,
        angular_momentum = initial_angular_momentum
    }
    local k1 = get_derivatives(state_k1)

    -- K2
    local state_k2 = {
        position = Matrix3.vec_add(initial_pos, Matrix3.vec_scale(k1.vel, dt * 0.5)),
        momentum = Matrix3.vec_add(initial_momentum, Matrix3.vec_scale(k1.dp, dt * 0.5)), -- Use linear momentum
        orientation = initial_orientation:add(k1.dq:scale(dt * 0.5)):normalize(),
        angular_momentum = Matrix3.vec_add(initial_angular_momentum, Matrix3.vec_scale(k1.dL, dt * 0.5))
    }
    local k2 = get_derivatives(state_k2)

    -- K3
    local state_k3 = {
        position = Matrix3.vec_add(initial_pos, Matrix3.vec_scale(k2.vel, dt * 0.5)),
        momentum = Matrix3.vec_add(initial_momentum, Matrix3.vec_scale(k2.dp, dt * 0.5)), -- Use linear momentum
        orientation = initial_orientation:add(k2.dq:scale(dt * 0.5)):normalize(),
        angular_momentum = Matrix3.vec_add(initial_angular_momentum, Matrix3.vec_scale(k2.dL, dt * 0.5))
    }
    local k3 = get_derivatives(state_k3)

    -- K4
    local state_k4 = {
        position = Matrix3.vec_add(initial_pos, Matrix3.vec_scale(k3.vel, dt)),
        momentum = Matrix3.vec_add(initial_momentum, Matrix3.vec_scale(k3.dp, dt)), -- Use linear momentum
        orientation = initial_orientation:add(k3.dq:scale(dt)):normalize(),
        angular_momentum = Matrix3.vec_add(initial_angular_momentum, Matrix3.vec_scale(k3.dL, dt))
    }
    local k4 = get_derivatives(state_k4)

    -- Final state update

    -- Update position
    self.position = Matrix3.vec_add(
        initial_pos,
        Matrix3.vec_scale(
            Matrix3.vec_add(Matrix3.vec_add(k1.vel, Matrix3.vec_scale(k2.vel, 2)), Matrix3.vec_add(Matrix3.vec_scale(k3.vel, 2), k4.vel)),
            dt / 6
        )
    )

    -- Update linear momentum
    self.momentum = Matrix3.vec_add(
        initial_momentum,
        Matrix3.vec_scale(
            Matrix3.vec_add(Matrix3.vec_add(k1.dp, Matrix3.vec_scale(k2.dp, 2)), Matrix3.vec_add(Matrix3.vec_scale(k3.dp, 2), k4.dp)),
            dt / 6
        )
    )

    -- Update orientation
    local dq_total = k1.dq:add(k2.dq:scale(2)):add(k3.dq:scale(2)):add(k4.dq)
    self.orientation = initial_orientation:add(dq_total:scale(dt / 6)):normalize()

    -- Update angular momentum
    self.angular_momentum = Matrix3.vec_add(
        initial_angular_momentum,
        Matrix3.vec_scale(
            Matrix3.vec_add(Matrix3.vec_add(k1.dL, Matrix3.vec_scale(k2.dL, 2)), Matrix3.vec_add(Matrix3.vec_scale(k3.dL, 2), k4.dL)),
            dt / 6
        )
    )

    -- Calculate new linear velocity from new linear momentum (compute velocity last)
    self.velocity = Matrix3.vec_scale(self.momentum, self.mass_inv)

    -- Calculate new angular velocity from new angular momentum
    local new_I_inv_world = self:get_inertia_inv_world()
    self.angular_velocity = Matrix3.multiply_vector(new_I_inv_world, self.angular_momentum)

    -- Clear forces and torques
    self.force = Matrix3.vec_zero()
    self.torque = Matrix3.vec_zero()
end

function RigidBody:update_RK4_bak(dt)
    -- Save current state for multiple RK4 evaluations
    local initial_pos = self.position
    local initial_vel = self.velocity
    local initial_orientation = self.orientation
    local initial_angular_momentum = self.angular_momentum

    -- Temporarily save applied forces and torques since each evaluation needs them
    local current_force = self.force
    local current_torque = self.torque

    -- Define an internal function to get derivatives for a given state
    -- This function creates a temporary RigidBody instance to compute derivatives without modifying the original
    local function get_derivatives(body_state, applied_force, applied_torque)
        local temp_body = {
            position = body_state.position,
            velocity = body_state.velocity,
            orientation = body_state.orientation,
            angular_momentum = body_state.angular_momentum,
            mass_inv = body_state.mass_inv,
            -- inertia_body = body_state.inertia_body, -- Make sure this is the local inertia tensor
            inertia_inv_body = body_state.inertia_inv_body,
            -- get_inertia_world = body_state.get_inertia_world,
            -- get_inertia_inv_world = body_state.get_inertia_inv_world
        }
        -- Temporarily set torque and force to compute derivatives
        temp_body.force = applied_force
        temp_body.torque = applied_torque

        -- Calculate temporary I_world and angular_velocity since calculate_derivatives depends on them
        -- local temp_I_world = temp_body:get_inertia_inv_world()-- temp_body:get_inertia_world()
        -- temp_body.angular_velocity = Matrix3.solve(temp_I_world, temp_body.angular_momentum)
        local R = temp_body.orientation:to_matrix3()
        local RT = Matrix3.transpose(R)
        local temp_I_inv_world = Matrix3.multiply(Matrix3.multiply(R, self.inertia_inv_body), RT)
        temp_body.angular_velocity = Matrix3.multiply_vector(temp_I_inv_world, temp_body.angular_momentum)

        local derivatives = {}
        derivatives.acc = Matrix3.vec_scale(temp_body.force, temp_body.mass_inv)
        derivatives.vel = temp_body.velocity
        derivatives.dL = temp_body.torque -- The derivative of angular momentum is torque

        -- Orientation derivative (dq/dt = 0.5 * omega_q * q)
        -- Convert angular velocity to a pure quaternion (0, omega_x, omega_y, omega_z)
        local omega_q = Quaternion.new(0, temp_body.angular_velocity.x, temp_body.angular_velocity.y, temp_body.angular_velocity.z)
        derivatives.dq = omega_q:multiply(temp_body.orientation):scale(0.5)

        return derivatives
    end

    -- K1
    local state_k1 = {
            position = initial_pos,
            velocity = initial_vel,
            orientation = initial_orientation,
            angular_momentum = initial_angular_momentum,
            mass_inv = self.mass_inv,
            -- inertia_body = self.inertia_body,
            -- get_inertia_world = self.get_inertia_world,
            inertia_inv_body = self.inertia_inv_body,
            -- get_inertia_inv_world = self.get_inertia_inv_world
        }
    local k1 = get_derivatives(
        state_k1,
        current_force, current_torque
    )

    -- K2
    local state_k2 = {
        position = Matrix3.vec_add(initial_pos, Matrix3.vec_scale(k1.vel, dt * 0.5)),
        velocity = Matrix3.vec_add(initial_vel, Matrix3.vec_scale(k1.acc, dt * 0.5)),
        orientation = initial_orientation:add(k1.dq:scale(dt * 0.5)):normalize(), -- Quaternion addition and normalization
        angular_momentum = Matrix3.vec_add(initial_angular_momentum, Matrix3.vec_scale(k1.dL, dt * 0.5)),
        mass_inv = self.mass_inv,
        -- inertia_body = self.inertia_body,
        -- get_inertia_world = self.get_inertia_world,
        inertia_inv_body = self.inertia_inv_body,
        -- get_inertia_inv_world = self.get_inertia_inv_world
    }
    local k2 = get_derivatives(state_k2, current_force, current_torque)

    -- K3
    local state_k3 = {
        position = Matrix3.vec_add(initial_pos, Matrix3.vec_scale(k2.vel, dt * 0.5)),
        velocity = Matrix3.vec_add(initial_vel, Matrix3.vec_scale(k2.acc, dt * 0.5)),
        orientation = initial_orientation:add(k2.dq:scale(dt * 0.5)):normalize(),
        angular_momentum = Matrix3.vec_add(initial_angular_momentum, Matrix3.vec_scale(k2.dL, dt * 0.5)),
        mass_inv = self.mass_inv,
        -- inertia_body = self.inertia_body,
        -- get_inertia_world = self.get_inertia_world,
        inertia_inv_body = self.inertia_inv_body,
        -- get_inertia_inv_world = self.get_inertia_inv_world
    }
    local k3 = get_derivatives(state_k3, current_force, current_torque)

    -- K4
    local state_k4 = {
        position = Matrix3.vec_add(initial_pos, Matrix3.vec_scale(k3.vel, dt)),
        velocity = Matrix3.vec_add(initial_vel, Matrix3.vec_scale(k3.acc, dt)),
        orientation = initial_orientation:add(k3.dq:scale(dt)):normalize(),
        angular_momentum = Matrix3.vec_add(initial_angular_momentum, Matrix3.vec_scale(k3.dL, dt)),
        mass_inv = self.mass_inv,
        -- inertia_body = self.inertia_body,
        -- get_inertia_world = self.get_inertia_world,
        inertia_inv_body = self.inertia_inv_body,
        -- get_inertia_inv_world = self.get_inertia_inv_world
    }
    local k4 = get_derivatives(state_k4, current_force, current_torque)

    -- Final state update
    self.position = Matrix3.vec_add(
        initial_pos,
        Matrix3.vec_scale(
            Matrix3.vec_add(Matrix3.vec_add(k1.vel, Matrix3.vec_scale(k2.vel, 2)), Matrix3.vec_add(Matrix3.vec_scale(k3.vel, 2), k4.vel)),
            dt / 6
        )
    )

    self.velocity = Matrix3.vec_add(
        initial_vel,
        Matrix3.vec_scale(
            Matrix3.vec_add(Matrix3.vec_add(k1.acc, Matrix3.vec_scale(k2.acc, 2)), Matrix3.vec_add(Matrix3.vec_scale(k3.acc, 2), k4.acc)),
            dt / 6
        )
    )

    local dq_total = k1.dq:add(k2.dq:scale(2)):add(k3.dq:scale(2)):add(k4.dq)
    self.orientation = initial_orientation:add(dq_total:scale(dt / 6)):normalize()

    self.angular_momentum = Matrix3.vec_add(
        initial_angular_momentum,
        Matrix3.vec_scale(
            Matrix3.vec_add(Matrix3.vec_add(k1.dL, Matrix3.vec_scale(k2.dL, 2)), Matrix3.vec_add(Matrix3.vec_scale(k3.dL, 2), k4.dL)),
            dt / 6
        )
    )

    -- Calculate new angular velocity from new angular momentum
    local new_I_world = self:get_inertia_world()
    self.angular_velocity = Matrix3.solve(new_I_world, self.angular_momentum)

    -- Clear forces and torques
    self.force = Matrix3.vec_zero()
    self.torque = Matrix3.vec_zero()
end

function RigidBody:update_RK4_angular_velocity(dt)
    -- Save current state for multiple RK4 evaluations
    local initial_pos = self.position
    local initial_vel = self.velocity
    local initial_orientation = self.orientation
    local initial_angular_velocity = self.angular_velocity -- Change: save angular velocity

    -- Temporarily save applied forces and torques since each evaluation needs them
    local current_force = self.force
    local current_torque = self.torque

    -- Define an internal function to get derivatives for a given state
    -- This function creates a temporary RigidBody instance to compute derivatives without modifying the original
    local function get_derivatives(body_state, applied_force, applied_torque)
        local temp_body = {
            position = body_state.position,
            velocity = body_state.velocity,
            orientation = body_state.orientation,
            angular_velocity = body_state.angular_velocity, -- Change: use angular velocity
            mass_inv = body_state.mass_inv,
            inertia_body = body_state.inertia_body, -- Make sure this is the local inertia tensor
            get_inertia_world = body_state.get_inertia_world
        }
        -- Temporarily set torque and force to compute derivatives
        temp_body.force = applied_force
        temp_body.torque = applied_torque

        -- Calculate temporary I_world
        local temp_I_world = temp_body:get_inertia_world()
        local temp_I_world_inv = Matrix3.inverse(temp_I_world) -- Need the inverse of the world inertia tensor

        local derivatives = {}
        derivatives.acc = Matrix3.vec_scale(temp_body.force, temp_body.mass_inv)
        derivatives.vel = temp_body.velocity

        -- Orientation derivative (dq/dt = 0.5 * omega_q * q)
        -- Convert angular velocity to a pure quaternion (0, omega_x, omega_y, omega_z)
        local omega_q = Quaternion.new(0, temp_body.angular_velocity.x, temp_body.angular_velocity.y, temp_body.angular_velocity.z)
        derivatives.dq = omega_q:multiply(temp_body.orientation):scale(0.5)

        -- Derivative of angular velocity (d_omega/dt) - based on Euler's equation
        -- I * d_omega/dt + omega x (I * omega) = torque
        -- d_omega/dt = I_inv * (torque - (omega x (I * omega)))
        local I_omega = Matrix3.multiply_vector(temp_I_world, temp_body.angular_velocity)
        local omega_cross_I_omega = Matrix3.vec_cross(temp_body.angular_velocity, I_omega)
        derivatives.d_omega = Matrix3.multiply_vector(temp_I_world_inv, Matrix3.vec_sub(temp_body.torque, omega_cross_I_omega)) -- Change: compute derivative of angular velocity

        return derivatives
    end

    -- K1
    local state_k1 = {
        position = initial_pos,
        velocity = initial_vel,
        orientation = initial_orientation,
        angular_velocity = initial_angular_velocity, -- Change: use angular velocity
        mass_inv = self.mass_inv,
        inertia_body = self.inertia_body,
        get_inertia_world = self.get_inertia_world
    }
    local k1 = get_derivatives(state_k1, current_force, current_torque)

    -- K2
    local state_k2 = {
        position = Matrix3.vec_add(initial_pos, Matrix3.vec_scale(k1.vel, dt * 0.5)),
        velocity = Matrix3.vec_add(initial_vel, Matrix3.vec_scale(k1.acc, dt * 0.5)),
        orientation = initial_orientation:add(k1.dq:scale(dt * 0.5)):normalize(),
        angular_velocity = Matrix3.vec_add(initial_angular_velocity, Matrix3.vec_scale(k1.d_omega, dt * 0.5)), -- Change: update angular velocity
        mass_inv = self.mass_inv,
        inertia_body = self.inertia_body,
        get_inertia_world = self.get_inertia_world
    }
    local k2 = get_derivatives(state_k2, current_force, current_torque)

    -- K3
    local state_k3 = {
        position = Matrix3.vec_add(initial_pos, Matrix3.vec_scale(k2.vel, dt * 0.5)),
        velocity = Matrix3.vec_add(initial_vel, Matrix3.vec_scale(k2.acc, dt * 0.5)),
        orientation = initial_orientation:add(k2.dq:scale(dt * 0.5)):normalize(),
        angular_velocity = Matrix3.vec_add(initial_angular_velocity, Matrix3.vec_scale(k2.d_omega, dt * 0.5)), -- Change: update angular velocity
        mass_inv = self.mass_inv,
        inertia_body = self.inertia_body,
        get_inertia_world = self.get_inertia_world
    }
    local k3 = get_derivatives(state_k3, current_force, current_torque)

    -- K4
    local state_k4 = {
        position = Matrix3.vec_add(initial_pos, Matrix3.vec_scale(k3.vel, dt)),
        velocity = Matrix3.vec_add(initial_vel, Matrix3.vec_scale(k3.acc, dt)),
        orientation = initial_orientation:add(k3.dq:scale(dt)):normalize(),
        angular_velocity = Matrix3.vec_add(initial_angular_velocity, Matrix3.vec_scale(k3.d_omega, dt)), -- Change: update angular velocity
        mass_inv = self.mass_inv,
        inertia_body = self.inertia_body,
        get_inertia_world = self.get_inertia_world
    }
    local k4 = get_derivatives(state_k4, current_force, current_torque)

    -- Final state update
    self.position = Matrix3.vec_add(
        initial_pos,
        Matrix3.vec_scale(
            Matrix3.vec_add(Matrix3.vec_add(k1.vel, Matrix3.vec_scale(k2.vel, 2)), Matrix3.vec_add(Matrix3.vec_scale(k3.vel, 2), k4.vel)),
            dt / 6
        )
    )

    self.velocity = Matrix3.vec_add(
        initial_vel,
        Matrix3.vec_scale(
            Matrix3.vec_add(Matrix3.vec_add(k1.acc, Matrix3.vec_scale(k2.acc, 2)), Matrix3.vec_add(Matrix3.vec_scale(k3.acc, 2), k4.acc)),
            dt / 6
        )
    )

    local dq_total = k1.dq:add(k2.dq:scale(2)):add(k3.dq:scale(2)):add(k4.dq)
    self.orientation = initial_orientation:add(dq_total:scale(dt / 6)):normalize()

    self.angular_velocity = Matrix3.vec_add( -- Change: update angular velocity
        initial_angular_velocity,
        Matrix3.vec_scale(
            Matrix3.vec_add(Matrix3.vec_add(k1.d_omega, Matrix3.vec_scale(k2.d_omega, 2)), Matrix3.vec_add(Matrix3.vec_scale(k3.d_omega, 2), k4.d_omega)),
            dt / 6
        )
    )

    -- If needed, calculate new angular momentum from new angular velocity
    local new_I_world = self:get_inertia_world()
    self.angular_momentum = Matrix3.multiply_vector(new_I_world, self.angular_velocity) -- Change: calculate angular momentum from angular velocity

    -- Clear forces and torques
    self.force = Matrix3.vec_zero()
    self.torque = Matrix3.vec_zero()
end

-- RigidBody update function
function RigidBody:update_error(dt)
    -- === 1. Update linear motion (standard semi-implicit Euler) ===
    local acc = Matrix3.vec_scale(self.force, self.mass_inv)
    self.velocity = Matrix3.vec_add(self.velocity, Matrix3.vec_scale(acc, dt))
    self.position = Matrix3.vec_add(self.position, Matrix3.vec_scale(self.velocity, dt))

    ---

    -- === 2. Rotation prediction phase ===
    -- a. Use current angular velocity and orientation to predict a temporary next-frame orientation
    local predicted_omega_len = Matrix3.vec_len(self.angular_velocity)
    local predicted_orientation_step = self.orientation -- Initialize to current orientation

    if predicted_omega_len > 1e-6 then
        local predicted_axis = Matrix3.vec_normalize(self.angular_velocity)
        local predicted_angle = predicted_omega_len * dt
        local predicted_dq = Quaternion.from_angle_axis(predicted_angle, predicted_axis)
        
        -- Compute a temporary "next frame" orientation for predicting the inertia tensor
        predicted_orientation_step = predicted_dq:multiply(self.orientation):normalize()
    else
        predicted_orientation_step = self.orientation:normalize()
    end

    -- b. Use the predicted orientation to compute the predicted world inertia tensor
    local predicted_I_world = self:get_inertia_world_from_orientation(predicted_orientation_step)

    -- c. Based on current angular momentum and predicted inertia tensor, compute a "predicted angular velocity"
    -- This predicted angular velocity will be used to update the final orientation
    local predicted_angular_velocity = Matrix3.solve(predicted_I_world, self.angular_momentum)

    ---

    -- === 3. Rotation update phase ===
    -- a. Update angular momentum (based on current external torque)
    -- This is the first quantity updated, using the current frame's torque.
    self.angular_momentum = Matrix3.vec_add(
        self.angular_momentum,
        Matrix3.vec_scale(self.torque, dt)
    )

    -- b. Update orientation (integrate using the predicted angular velocity)
    -- Now use the previously predicted angular_velocity to drive the orientation update, instead of the actual self.angular_velocity
    local final_omega_len = Matrix3.vec_len(predicted_angular_velocity)
    if final_omega_len > 1e-6 then
        local final_axis = Matrix3.vec_normalize(predicted_angular_velocity)
        local final_angle = final_omega_len * dt
        local final_dq = Quaternion.from_angle_axis(final_angle, final_axis)
        
        -- Quaternion update, note the multiplication order
        self.orientation = final_dq:multiply(self.orientation):normalize()
    else
        self.orientation = self.orientation:normalize()
    end

    -- c. Finally, calculate the final angular velocity from the updated angular momentum and final orientation
    -- This ensures self.angular_velocity always reflects the latest physical state for external queries and the next frame
    local final_I_world = self:get_inertia_world() -- Use updated self.orientation
    self.angular_velocity = Matrix3.solve(final_I_world, self.angular_momentum)

    ---

    -- === 4. Clear forces and torques ===
    self.force = Matrix3.vec_zero()
    self.torque = Matrix3.vec_zero()
end


function RigidBody:update_error2(dt)
    -- === 1. Update linear motion ===
    local acc = Matrix3.vec_scale(self.force, self.mass_inv)
    self.velocity = Matrix3.vec_add(self.velocity, Matrix3.vec_scale(acc, dt))
    self.position = Matrix3.vec_add(self.position, Matrix3.vec_scale(self.velocity, dt))

    -- === 2. Update angular velocity using angular momentum integration ===
    self.angular_momentum = Matrix3.vec_add(
        self.angular_momentum,
        Matrix3.vec_scale(self.torque, dt)
    )

    local I_world = self:get_inertia_world()
    self.angular_velocity = Matrix3.solve(I_world, self.angular_momentum)

    -- === 3. Orientation update ===
    local omega_len = Matrix3.vec_len(self.angular_velocity)
    if omega_len > 1e-6 then
        local axis = Matrix3.vec_normalize(self.angular_velocity)
        local angle = omega_len * dt
        local dq = Quaternion.from_angle_axis(angle, axis)
        self.orientation = dq:multiply(self.orientation):normalize()
    end

    -- === 4. Clear forces and torques ===
    self.force = Matrix3.vec_zero()
    self.torque = Matrix3.vec_zero()
end

function RigidBody:get_transformation()
    return Transformation.new(self.position, self.orientation, self.scale)
end

function RigidBody:intersect_ray(ray_origin, ray_dir)
    -- Get the rigid body's world -> local transform (inverse transform)
    local transform = self:get_transformation()
    local inv_transform = transform:inverse()

    -- Transform the ray from world space to local space
    local local_origin = inv_transform:apply_point(ray_origin)
    local local_dir = inv_transform:apply_vector(ray_dir)

    -- Intersect in mesh local space
    local result = self.mesh:intersect_ray(local_origin, local_dir)

    if result then
        -- Transform the hit point and normal back to world space
        result.position = transform:apply_point(result.position)
        result.normal = transform:apply_normal(result.normal) -- Note: use inverse transpose for normals

        -- Can attach object references as needed
        result.object = self
    end

    return result
end

function RigidBody:apply_collision_impulse(body, contact_point, contact_normal, restitution, friction)
    local rA = Matrix3.vec_sub(contact_point, self.position)
    local rB = Matrix3.vec_sub(contact_point, body.position)

    -- Relative velocity
    local vA = Matrix3.vec_add(self.velocity, Matrix3.vec_cross(self.angular_velocity, rA))
    local vB = Matrix3.vec_add(body.velocity, Matrix3.vec_cross(body.angular_velocity, rB))
    local relative_velocity = Matrix3.vec_sub(vB, vA)

    -- Normal direction velocity component
    local vel_along_normal = Matrix3.vec_dot(relative_velocity, contact_normal)

    if vel_along_normal > 0 then
        return -- Objects moving apart, no processing
    end

    -- Inverse inertia tensor (in world coordinates)

    local inertia_inv_a = self:get_inertia_inv_world()
    local inertia_inv_b = body:get_inertia_inv_world()

    -- Normal impulse calculation
    local rA_cross_n = Matrix3.vec_cross(rA, contact_normal)
    local rB_cross_n = Matrix3.vec_cross(rB, contact_normal)

    local termA = Matrix3.vec_dot(Matrix3.vec_cross(Matrix3.multiply_vector(inertia_inv_a, rA_cross_n), rA), contact_normal)
    local termB = Matrix3.vec_dot(Matrix3.vec_cross(Matrix3.multiply_vector(inertia_inv_b, rB_cross_n), rB), contact_normal)
    local inv_mass_sum = self.mass_inv + body.mass_inv + termA + termB

    local j = -(1 + restitution) * vel_along_normal / inv_mass_sum
    local impulse = Matrix3.vec_scale(contact_normal, j)

    -- Apply normal impulse
    self:apply_impulse(Matrix3.vec_scale(impulse, -1), contact_point)
    body:apply_impulse(impulse, contact_point)

    -- Recalculate relative velocity (since normal impulse has been applied)
    vA = Matrix3.vec_add(self.velocity, Matrix3.vec_cross(self.angular_velocity, rA))
    vB = Matrix3.vec_add(body.velocity, Matrix3.vec_cross(body.angular_velocity, rB))
    relative_velocity = Matrix3.vec_sub(vB, vA)

    -- Tangent direction
    local tangent = Matrix3.vec_sub(
        relative_velocity,
        Matrix3.vec_scale(contact_normal, Matrix3.vec_dot(relative_velocity, contact_normal))
    )
    tangent = Matrix3.vec_normalize(tangent)

    local vt = Matrix3.vec_dot(relative_velocity, tangent)
    if vt ~= 0 then
        local rA_cross_t = Matrix3.vec_cross(rA, tangent)
        local rB_cross_t = Matrix3.vec_cross(rB, tangent)

        local termA_t = Matrix3.vec_dot(Matrix3.vec_cross(Matrix3.multiply_vector(inertia_inv_a, rA_cross_t), rA), tangent)
        local termB_t = Matrix3.vec_dot(Matrix3.vec_cross(Matrix3.multiply_vector(inertia_inv_b, rB_cross_t), rB), tangent)
        local inv_mass_t = self.mass_inv + body.mass_inv + termA_t + termB_t

        local jt = -vt / inv_mass_t
        local jt_clamped = math.max(-friction * j, math.min(jt, friction * j)) -- Coulomb friction limit

        local friction_impulse = Matrix3.vec_scale(tangent, jt_clamped)

        self:apply_impulse(Matrix3.vec_scale(friction_impulse, -1), contact_point)
        body:apply_impulse(friction_impulse, contact_point)
    end
end


function RigidBody:reset()
    self.force = Matrix3.vec_zero()
    self.torque = Matrix3.vec_zero()
    self.velocity = Matrix3.vec_zero()
    self.momentum = Matrix3.vec_zero()
    self.angular_velocity = Matrix3.vec_zero()
    self.angular_momentum = Matrix3.vec_zero()
end

return RigidBody

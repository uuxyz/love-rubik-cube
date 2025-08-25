local Quaternion = require("quaternion")
local Matrix3 = require("matrix3")
local Matrix = require("matrix") -- Ensure the Matrix module is imported
local Transformation = require("transformation")

-- Coordinate to index mapping
local coord_to_index = {}
local index_to_coord = {}
local count = 0
local values = {-1, 0, 1}
for _, x in ipairs(values) do
    for _, y in ipairs(values) do
        for _, z in ipairs(values) do
            if not (x == 0 and y == 0 and z == 0) then -- Exclude center cubie
                local coord_key = ("%d,%d,%d"):format(x, y, z)
                count = count + 1
                coord_to_index[coord_key] = count
                index_to_coord[count] = {x, y, z}
            end
        end
    end
end
local TOTAL_CUBIES = count -- Total of 26 cubies

-- Rubik's cube state class
local RubiksCube = {}
RubiksCube.__index = RubiksCube

-- Store quaternion and data for cube rotation operations
local MOVE_DATA = {
    F = { -- Front face (positive X axis)
        axis = 'x', -- Rotate around X axis
        layer = 1,  -- Layer X=1
        q = Quaternion.from_angle_axis(math.pi/2, Matrix3.new_vector(1, 0, 0))
    },
    B = { -- Back face (negative X axis)
        axis = 'x',
        layer = -1,
        q = Quaternion.from_angle_axis(math.pi/2, Matrix3.new_vector(-1, 0, 0))
    },
    L = { -- Left face (positive Y axis)
        axis = 'y',
        layer = 1,
        q = Quaternion.from_angle_axis(math.pi/2, Matrix3.new_vector(0, 1, 0))
    },
    R = { -- Right face (negative Y axis)
        axis = 'y',
        layer = -1,
        q = Quaternion.from_angle_axis(math.pi/2, Matrix3.new_vector(0, -1, 0))
    },
    U = { -- Up face (positive Z axis)
        axis = 'z',
        layer = 1,
        q = Quaternion.from_angle_axis(math.pi/2, Matrix3.new_vector(0, 0, 1))
    },
    D = { -- Down face (negative Z axis)
        axis = 'z',
        layer = -1,
        q = Quaternion.from_angle_axis(math.pi/2, Matrix3.new_vector(0, 0, -1))
    },
}

function RubiksCube.new()
    local instance = setmetatable({}, RubiksCube)
    instance.cubie_state = {}     -- Store which "original cubie ID" is at each "position"
    instance.cubie_rotation = {}  -- Store the "accumulated rotation quaternion" for each cubie "ID"

    -- Initialize: at each position i is the cubie with original ID i, with identity quaternion rotation
    for i = 1, TOTAL_CUBIES do
        instance.cubie_state[i] = i
        instance.cubie_rotation[i] = Quaternion.new(1, 0, 0, 0) -- Initial identity quaternion
    end
    return instance
end

-- Get the index for a given coordinate
function RubiksCube:get_index(x, y, z)
    return coord_to_index[("%d,%d,%d"):format(x, y, z)]
end

-- Coordinate rotation function (for calculating a cubie's new logical position after rotation)
-- Note: rotation is around the origin, applied to logical coordinates
local function rotate_coord(coord, axis, layer)
    local x, y, z = coord[1], coord[2], coord[3]
    if axis == 'x' then
        if layer == 1 then -- Clockwise around +X axis
            return {x, -z, y}
        else -- Clockwise around -X axis
            return {x, z, -y}
        end
    elseif axis == 'y' then
        if layer == 1 then -- Clockwise around +Y axis
            return {z, y, -x}
        else -- Clockwise around -Y axis
            return {-z, y, x}
        end
    elseif axis == 'z' then
        if layer == 1 then -- Clockwise around +Z axis
            return {-y, x, z}
        else -- Clockwise around -Z axis
            return {y, -x, z}
        end
    else
        error("Invalid axis")
    end
end

---
--- Perform a face rotation on the cube. This function does not modify the current cube instance, but returns a new one
--- representing the state after rotation.
function RubiksCube:rotate_face(move)
    local data = MOVE_DATA[move]
    if not data then
        error("Invalid move: " .. move)
    end

    local axis_label, layer, rotation_q = data.axis, data.layer, data.q
    local axis_idx = {x = 1, y = 2, z = 3}

    local new_cube = RubiksCube.new()

    -- Iterate over all cubie logical positions (1 to TOTAL_CUBIES),
    -- This time we process the "new" position, finding what should go in each position
    for i = 1, TOTAL_CUBIES do
        local original_cubie_id = self.cubie_state[i]
        local current_cubie_rotation = self.cubie_rotation[original_cubie_id]
        -- Get the logical coordinates of the new position i (new_coord)
        local new_coord = index_to_coord[i]
        
        -- Check if this new position is on the layer being rotated
        if new_coord[axis_idx[axis_label]] == layer then
            -- print(("%d %d %d"):format(new_coord[1], new_coord[2], new_coord[3]))

            local rotated_coord = rotate_coord(new_coord, axis_label, layer)
            local new_logical_index = self:get_index(rotated_coord[1], rotated_coord[2], rotated_coord[3])
            
            -- Get cubie information from the old position in the old cube instance

            -- Calculate the new rotation state and assign it to the new position in the new cube
            local new_cubie_rotation = rotation_q:multiply(current_cubie_rotation)
            new_cube.cubie_state[new_logical_index] = original_cubie_id
            new_cube.cubie_rotation[original_cubie_id] = new_cubie_rotation
        else
            -- If the new position is not on the rotation layer, the cubie at this position hasn't moved.
            -- Copy the state directly from the old cube instance to the new cube
            new_cube.cubie_state[i] = original_cubie_id
            new_cube.cubie_rotation[original_cubie_id] = current_cubie_rotation
        end
    end

    return new_cube
end

---
--- Get the instance rendering data for all cubies in the current cube state.
--- This is used to set the instance data for `love.graphics.newMesh`.
---
--- @return table A list where each element is a table containing:
---               {col0_x, col0_y, col0_z, col0_w, ..., col3_x, col3_y, col3_z, col3_w, initial_pos_x, initial_pos_y, initial_pos_z}
---               Where the first 16 are the cubie's local model matrix (column-major), and the last 3 are the cubie's initial logical coordinates.
---
function RubiksCube:get_current_instance_data()
    local instance_data = {}
    for i = 1, TOTAL_CUBIES do
        local cubie_id = i         -- Get which original cubie ID is at logical position i
        local current_rotation = self.cubie_rotation[cubie_id] -- Get the accumulated rotation of the cubie with this ID

        local initial_coord = index_to_coord[cubie_id]      -- This is the cubie's "initial logical coordinate", used as CubePosition in the shader

        -- Create the cubie's local transformation (position is its initial logical coordinate, rotation is its current accumulated rotation)
        local transformation = Transformation.new(
            Matrix3.new_vector(initial_coord[1], initial_coord[2], initial_coord[3]),
            current_rotation,
            Matrix3.new_vector(1, 1, 1) -- Scale stays at 1
        )

        -- Compose into local model matrix (order may need adjustment based on Transformation library implementation, typically Scale * Rotate * Translate)
        -- Assume Transformation:to_matrix() already handles the correct TRS order
        local T = transformation:translate_matrix()
        local R = transformation:rotate_matrix()
        local S = transformation:scale_matrix()
        local flat_data = Matrix.multiply(R, Matrix.multiply(T, S)) -- Get the 4x4 matrix

        table.insert(flat_data, initial_coord[1]) -- CubePosition X
        table.insert(flat_data, initial_coord[2]) -- CubePosition Y
        table.insert(flat_data, initial_coord[3]) -- CubePosition Z

        table.insert(instance_data, flat_data)
    end
    return instance_data
end


---
--- Returns a list containing interpolated transformation matrix data for all 26 cubies (used for animation and instanced rendering).
--- This is used to smoothly update the rendering position and orientation of cubies during animation.
---
function RubiksCube:get_interpolated_transformations(end_cube, t)
    local interpolated_instance_data = {}

    for i = 1, TOTAL_CUBIES do
        -- Get the original ID and accumulated rotation of the cubie at logical position i at the start of the animation
        local cubie_id = i
        local start_rotation = self.cubie_rotation[cubie_id]
        local end_rotation = end_cube.cubie_rotation[cubie_id]

        -- The cubie's initial logical coordinate (its "home" position in the cube grid, used to generate the translation part of the model matrix)
        local initial_coord = index_to_coord[cubie_id]

        -- Perform spherical linear interpolation (Slerp) on the rotation of the cubie at position i
        local interpolated_rotation = Quaternion.slerp(start_rotation, end_rotation, t)

        -- Build the interpolated local transformation matrix
        local transformation = Transformation.new(
            Matrix3.new_vector(initial_coord[1], initial_coord[2], initial_coord[3]),
            interpolated_rotation,
            Matrix3.new_vector(1, 1, 1) -- Scale stays at 1
        )
        local T = transformation:translate_matrix()
        local R = transformation:rotate_matrix()
        local S = transformation:scale_matrix()
        local flat_data = Matrix.multiply(R, Matrix.multiply(T, S)) -- Get the 4x4 matrix

        table.insert(flat_data, initial_coord[1]) -- CubePosition X
        table.insert(flat_data, initial_coord[2]) -- CubePosition Y
        table.insert(flat_data, initial_coord[3]) -- CubePosition Z

        table.insert(interpolated_instance_data, flat_data)
    end

    return interpolated_instance_data
end

--- Debug function: convert the cube state to a string for real-time printing.
--- New: print the cubie coordinates after applying accumulated rotation.
function RubiksCube:get_state_string()
    local state_lines = {"--- RubiksCube State ---"}
    local moved_count = 0
    for i = 1, TOTAL_CUBIES do
        if self.cubie_state[i] ~= i then
            moved_count = moved_count + 1
        end
    end

    table.insert(state_lines, "Total Cubies: " .. TOTAL_CUBIES)
    table.insert(state_lines, "Moved Cubies: " .. moved_count)
    
    table.insert(state_lines, "\n--- Cubie Positions and Rotations ---")
    for i = 1, TOTAL_CUBIES do
        local cubie_id = self.cubie_state[i]
        local current_rotation = self.cubie_rotation[cubie_id]

        -- Get the cubie's initial logical coordinate
        local initial_coord = index_to_coord[cubie_id]
        -- Convert the initial coordinate to a Matrix3 vector for applying quaternion rotation
        local initial_vec = Matrix3.new_vector(initial_coord[1], initial_coord[2], initial_coord[3])
        -- Apply accumulated rotation to calculate the cubie's physical coordinate
        local rotated_vec = current_rotation:rotate_vector(initial_vec)
        -- local rotated_coord = {rotated_vec[1], rotated_vec[2], rotated_vec[3]}

        -- Print information for position i
        local pos_info = string.format(
            "Pos: %d (Current Coord: %s)", 
            i, 
            table.concat(index_to_coord[i], ",")
        )

        -- Print cubie ID, accumulated rotation, and physical coordinates after rotation
        local rotation_info = string.format(
            " -> ID: %d, Rot: (%.2f,%.2f,%.2f,%.2f), Rotated Coord: (%.2f,%.2f,%.2f), Index: (%d)", 
            cubie_id, 
            current_rotation.w, 
            current_rotation.x, 
            current_rotation.y, 
            current_rotation.z,
            rotated_vec.x,
            rotated_vec.y,
            rotated_vec.z,
            RubiksCube:get_index(math.floor(rotated_vec.x + 0.5), math.floor(rotated_vec.y + 0.5), math.floor(rotated_vec.z + 0.5))
        )
        table.insert(state_lines, pos_info .. rotation_info)
    end
    
    return table.concat(state_lines, "\n")
end

return RubiksCube

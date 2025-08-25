-- main.lua
-- Love2D main program file, used to render the Rubik's cube and handle user input.

local Camera = require("camera")
local Mesh = require("mesh")
local Projection = require("projection")
local Transformation = require("transformation")
local Matrix3 = require("matrix3")
local Quaternion = require("quaternion")
local Matrix = require("matrix")

local RubiksCube = require("rubiks_cube")

local love = love

-- Define the GLSL shader used for rendering
Shader = love.graphics.newShader("shader.glsl")

-- Global variable definitions
local RubiksCubeInstance
local StartRubiksCubeState
local TargetRubiksCubeState
local InstancedCubeMesh
local AnimationQueue = {}
local IsAnimating = false
local AnimationDuration = 0.3
local CurrentAnimationTime = 0
local CurrentRotationFace = nil

-- New global variables
    local ScrambleMoves = 20            -- Number of scramble moves
    local MoveHistory = {}              -- Record all completed rotation moves
    local RedoStack = {}                -- Used for redoing undone operations
    local IsPerformingAutomatedMove = false -- Flag indicating whether a scramble or solve operation is in progress

-- love.load() function: called when the game initializes
function love.load()
    love.window.setFullscreen(true)
    love.graphics.setFrontFaceWinding("ccw")
    love.graphics.setMeshCullMode("back")

    BackgroundCanvas = love.graphics.newCanvas()
    love.graphics.setDepthMode("lequal", true)

    CubeMeshModel = Mesh.new()
    CubeMeshModel:load_from_obj("cube.obj")

    RubiksCubeInstance = RubiksCube.new()

    InstancedCubeMesh = love.graphics.newMesh({
        {"InstanceTransform0", "float", 4},
        {"InstanceTransform1", "float", 4},
        {"InstanceTransform2", "float", 4},
        {"InstanceTransform3", "float", 4},
        {"CubePosition", "float", 3}
    }, RubiksCubeInstance:get_current_instance_data(), nil, "static")

    -- InstancedCubeMesh:setInstanceData()

    CubeMeshModel.drawable:attachAttribute("InstanceTransform0", InstancedCubeMesh, "perinstance")
    CubeMeshModel.drawable:attachAttribute("InstanceTransform1", InstancedCubeMesh, "perinstance")
    CubeMeshModel.drawable:attachAttribute("InstanceTransform2", InstancedCubeMesh, "perinstance")
    CubeMeshModel.drawable:attachAttribute("InstanceTransform3", InstancedCubeMesh, "perinstance")
    CubeMeshModel.drawable:attachAttribute("CubePosition", InstancedCubeMesh, "perinstance")

    local perspective = Projection.new(love.graphics.getWidth(), love.graphics.getHeight(), 0.5)
    local camera = Camera.new(0, 0, 0, 0, 0, 0, perspective)
    camera:set_look(Matrix3.new_vector(0, 0, 1))

    Shader:send("viewMatrix", "column", camera:get_view_matrix())
    Shader:send("projectionMatrix", "column", perspective:get_projection_matrix())

    GlobalRotationTimer = 0
end

-- love.update() function: called every frame to update game logic
function love.update(dt)
    GlobalRotationTimer = GlobalRotationTimer + dt

    if IsAnimating then
        CurrentAnimationTime = CurrentAnimationTime + dt
        local t = CurrentAnimationTime / AnimationDuration

        if t >= 1.0 then
            t = 1.0
            IsAnimating = false
            CurrentAnimationTime = 0
            
            -- After the animation completes, update the cube state and record history
            RubiksCubeInstance = TargetRubiksCubeState
            if not IsPerformingAutomatedMove then
                if CurrentRotationFace then
                    -- If it's a manual move, record it in history and clear the redo stack
                    table.insert(MoveHistory, CurrentRotationFace)
                    RedoStack = {}
                end
            end
            
            CurrentRotationFace = nil

            -- Check the animation queue; if not empty, start the next animation
            if #AnimationQueue > 0 then
                local next_move_data = table.remove(AnimationQueue, 1) -- Remove from the front of the queue
                start_rotation_animation(next_move_data.face, next_move_data.count)
            else
                IsPerformingAutomatedMove = false
            end
        end

        local interpolated_data = StartRubiksCubeState:get_interpolated_transformations(TargetRubiksCubeState, t)
        InstancedCubeMesh:setVertices(interpolated_data)
    else
        InstancedCubeMesh:setVertices(RubiksCubeInstance:get_current_instance_data())
    end
end

-- Helper function: start a cube rotation animation
function start_rotation_animation(face_id, count)
    -- If another animation is in progress, add the new request to the queue
    if IsAnimating then
        table.insert(AnimationQueue, {face = face_id, count = count or 1})
        print("Rotation for face " .. face_id .. " queued.")
    else
        IsAnimating = true
        CurrentAnimationTime = 0
        CurrentRotationFace = face_id
        StartRubiksCubeState = RubiksCubeInstance
        
        -- Calculate the target state after rotation
        local temp_cube = RubiksCubeInstance
        for i = 1, count or 1 do
            temp_cube = temp_cube:rotate_face(face_id)
        end
        TargetRubiksCubeState = temp_cube

        print("Starting rotation for face " .. face_id .. ", count: " .. (count or 1))
    end
end

-- New: Scramble the cube
function scramble()
    if IsAnimating then return end
    
    print("Scrambling the cube...")
    AnimationQueue = {}
    MoveHistory = {}
    RedoStack = {}
    IsPerformingAutomatedMove = true
    
    local faces = {"F", "B", "L", "R", "U", "D"}
    for i = 1, ScrambleMoves do
        local random_face = faces[love.math.random(1, #faces)]
        start_rotation_animation(random_face, 1)
        -- Immediately record the move in history for later solving
        table.insert(MoveHistory, random_face)
    end
    print("Scramble sequence generated with " .. ScrambleMoves .. " moves.")
end

-- New: Solve the cube
function solve()
    if IsAnimating then return end
    
    print("Solving the cube...")
    AnimationQueue = {}
    IsPerformingAutomatedMove = true

    -- Traverse the history in reverse order, executing opposite operations
    for i = #MoveHistory, 1, -1 do
        local original_move = MoveHistory[i]
        -- Perform three rotations, equivalent to one reverse rotation
        start_rotation_animation(original_move, 3)
    end
    MoveHistory = {} -- Clear history after solving
    RedoStack = {}
end

-- New: Undo last move
function undo()
    if IsAnimating or #MoveHistory == 0 then return end
    
    print("Undoing last move...")
    local last_move = table.remove(MoveHistory)
    table.insert(RedoStack, last_move)
    start_rotation_animation(last_move, 3) -- Three forward rotations equal one reverse rotation
end

-- New: Redo last undone move
function redo()
    if IsAnimating or #RedoStack == 0 then return end
    
    print("Redoing last undone move...")
    local last_undone_move = table.remove(RedoStack)
    start_rotation_animation(last_undone_move, 1)
end

-- love.keypressed() function: handles key press events
function love.keypressed(key)
    if IsPerformingAutomatedMove then return end
    
    local rotation_map = {
        f = "F", F = "F", b = "B", B = "B", l = "L", L = "L",
        r = "R", R = "R", u = "U", U = "U", d = "D", D = "D"
    }

    local face_to_rotate = rotation_map[key]
    if face_to_rotate then
        -- Start manual operation
        start_rotation_animation(face_to_rotate, 1)
        return
    end

    if key == "up" then
        scramble()
    elseif key == "down" then
        solve()
    elseif key == "left" then
        undo()
    elseif key == "right" then
        redo()
    elseif key == "escape" then
        love.event.quit()
    end
end

-- love.draw() function: called every frame to render the game
function love.draw()
    local quaternion = Quaternion.from_angle(GlobalRotationTimer, GlobalRotationTimer, GlobalRotationTimer)
    local transformation = Transformation.new(Matrix3.new_vector(0, 0, 4), quaternion, Matrix3.new_vector(1, 1, 1))
    Shader:send("modelMatrix", "column", transformation:to_matrix())

    love.graphics.setCanvas({ BackgroundCanvas, depth = true })
    love.graphics.clear()
    love.graphics.setShader(Shader)

    local instancecount = RubiksCube.TOTAL_CUBIES or 26
    love.graphics.drawInstanced(CubeMeshModel.drawable, instancecount, 0, 0)

    love.graphics.setShader()
    love.graphics.setCanvas()

    love.graphics.draw(BackgroundCanvas)

    -- Display prompt information on screen
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("F B L R U D: Rotate", 10, 10)
    love.graphics.print("Up: Scramble", 10, 30)
    love.graphics.print("Down: Solve", 10, 50)
    love.graphics.print("Left/Right: Undo/Redo", 10, 70)

    -- Draw cube state debug information
    love.graphics.print(RubiksCubeInstance:get_state_string(), 10, 100)
end

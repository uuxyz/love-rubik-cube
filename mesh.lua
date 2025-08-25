-- mesh.lua
local Matrix3 = require("matrix3")
-- local stl = require("stl_loader")

local Mesh = {}
Mesh.__index = Mesh

local VertexFormat = {
		{ "VertexPosition", "float", 3 },
		{ "VertexTexCoord", "float", 2 },
		{ "VertexNormal",   "float", 3 }
}

function Mesh.new()
    local self = setmetatable({}, Mesh)
    self.vertices = {} -- Store unique vertex information
    self.indices = {}  -- Store vertex index order
    self.drawable = nil
    -- self.triangles = {} -- Each triangle has 3 vertices, each vertex is {x,y,z,u,v,nx,ny,nz}
    return self
end

-- function Mesh:load_from_stl(filename)
--     self.triangles = {}
--     stl.load_from_stl(self, filename)
-- end

-- function Mesh:load_from_obj(filename)
--     local positions, texcoords, normals = {}, {}, {}
--     local contents = love.filesystem.read(filename)
--     if not contents then return end

--     for line in contents:gmatch("[^\r\n]+") do
--         local cmd, rest = line:match("^(%S+)%s+(.*)$")
--         if cmd == "v" then
--             local x, y, z = rest:match("([%-%d%.eE]+)%s+([%-%d%.eE]+)%s+([%-%d%.eE]+)")
--             table.insert(positions, { tonumber(x), tonumber(y), tonumber(z) })
--         elseif cmd == "vt" then
--             local u, v = rest:match("([%-%d%.eE]+)%s+([%-%d%.eE]+)")
--             table.insert(texcoords, { tonumber(u), tonumber(v) })
--         elseif cmd == "vn" then
--             local nx, ny, nz = rest:match("([%-%d%.eE]+)%s+([%-%d%.eE]+)%s+([%-%d%.eE]+)")
--             table.insert(normals, { tonumber(nx), tonumber(ny), tonumber(nz) })
--         elseif cmd == "f" then
--             local indices = {}
--             for vert in rest:gmatch("%S+") do
--                 local vi, ti, ni = vert:match("(%d+)/(%d+)/(%d+)")
--                 table.insert(indices, {
--                     position = positions[tonumber(vi)],
--                     texcoord = texcoords[tonumber(ti)],
--                     normal = normals[tonumber(ni)]
--                 })
--             end
--             if #indices >= 3 then
--                 for i = 2, #indices - 1 do
--                     local tri = { indices[1], indices[i], indices[i + 1] }
--                     for _, v in ipairs(tri) do
--                         table.insert(self.triangles, {
--                             v.position[1], v.position[2], v.position[3],
--                             v.texcoord[1], v.texcoord[2],
--                             v.normal[1], v.normal[2], v.normal[3]
--                         })
--                     end
--                 end
--             end
--         end
--     end
-- end

--- 
-- @param filename string Path to the OBJ file.
--
function Mesh:load_from_obj(filename)
    local positions, texcoords, normals = {}, {}, {}
    local vertex_map = {}

    local contents = love.filesystem.read(filename)
    if not contents then return end

    for line in contents:gmatch("[^\r\n]+") do
        local cmd, rest = line:match("^(%S+)%s+(.*)$")
        if cmd == "v" then
            local x, y, z = rest:match("([%-%d%.eE]+)%s+([%-%d%.eE]+)%s+([%-%d%.eE]+)")
            table.insert(positions, { tonumber(x), tonumber(y), tonumber(z) })
        elseif cmd == "vt" then
            local u, v = rest:match("([%-%d%.eE]+)%s+([%-%d%.eE]+)")
            table.insert(texcoords, { tonumber(u), tonumber(v) })
        elseif cmd == "vn" then
            local nx, ny, nz = rest:match("([%-%d%.eE]+)%s+([%-%d%.eE]+)%s+([%-%d%.eE]+)")
            table.insert(normals, { tonumber(nx), tonumber(ny), tonumber(nz) })
        elseif cmd == "f" then
            local face_indices = {}
            for vert in rest:gmatch("%S+") do
                local vi, ti, ni = vert:match("(%d+)/(%d+)/(%d+)")
                local key = vi .. "/" .. ti .. "/" .. ni

                -- Check if this vertex combination already exists
                if not vertex_map[key] then
                    local p = positions[tonumber(vi)]
                    local t = texcoords[tonumber(ti)]
                    local n = normals[tonumber(ni)]

                    local vertex = {
                        p[1], p[2], p[3],
                        t[1], t[2],
                        n[1], n[2], n[3]
                    }
                    table.insert(self.vertices, vertex)
                    vertex_map[key] = #self.vertices
                end
                table.insert(face_indices, vertex_map[key])
            end

            -- Convert face to triangles and add indices
            if #face_indices >= 3 then
                for i = 2, #face_indices - 1 do
                    table.insert(self.indices, face_indices[1])
                    table.insert(self.indices, face_indices[i])
                    table.insert(self.indices, face_indices[i + 1])
                end
            end
        end
    end
    if #self.vertices > 0 then
        self.drawable = love.graphics.newMesh(VertexFormat, self.vertices, "triangles")
        if #self.indices > 0 then
            self.drawable:setVertexMap(self.indices)
        end
    end
end

-- function Mesh:generate_cube()
--     local function add_face(v, n)
--         local function add_vert(p)
--             table.insert(self.triangles, {
--                 p[1], p[2], p[3], p[4], p[5], n[1], n[2], n[3]
--             })
--         end
--         add_vert(v[1]); add_vert(v[2]); add_vert(v[3])
--         add_vert(v[3]); add_vert(v[4]); add_vert(v[1])
--     end
--     local faces = {
--         {{-1,-1,1,0,0}, {1,-1,1,1,0}, {1,1,1,1,1}, {-1,1,1,0,1}}, {0,0,1},
--         {{1,-1,-1,0,0}, {-1,-1,-1,1,0}, {-1,1,-1,1,1}, {1,1,-1,0,1}}, {0,0,-1},
--         {{-1,-1,-1,0,0}, {-1,-1,1,1,0}, {-1,1,1,1,1}, {-1,1,-1,0,1}}, {-1,0,0},
--         {{1,-1,1,0,0}, {1,-1,-1,1,0}, {1,1,-1,1,1}, {1,1,1,0,1}}, {1,0,0},
--         {{-1,1,1,0,0}, {1,1,1,1,0}, {1,1,-1,1,1}, {-1,1,-1,0,1}}, {0,1,0},
--         {{-1,-1,-1,0,0}, {1,-1,-1,1,0}, {1,-1,1,1,1}, {-1,-1,1,0,1}}, {0,-1,0},
--     }
--     for i = 1, #faces, 2 do
--         add_face(faces[i], faces[i+1])
--     end
-- end

--- 
-- Compute the intersection of a ray with the mesh.
--
-- @param ray_origin table The origin vector of the ray {x, y, z}.
-- @param ray_dir table The direction vector of the ray {x, y, z}.
--
-- @return table|nil If a hit occurs, returns a table containing intersection info; otherwise returns nil.
function Mesh:intersect_ray(ray_origin, ray_dir)
    local closest_t = math.huge
    local result = nil
    
    -- Iterate over indices, processing one complete triangle at a time
    for i = 1, #self.indices, 3 do
        local idx0 = self.indices[i]
        local idx1 = self.indices[i+1]
        local idx2 = self.indices[i+2]
        
        -- Get vertex data by index
        local v0 = self.vertices[idx0]
        local v1 = self.vertices[idx1]
        local v2 = self.vertices[idx2]

        local p0 = Matrix3.new_vector(v0[1], v0[2], v0[3])
        local p1 = Matrix3.new_vector(v1[1], v1[2], v1[3])
        local p2 = Matrix3.new_vector(v2[1], v2[2], v2[3])

        -- Moeller-Trumbore
        local e1 = Matrix3.vec_sub(p1, p0)
        local e2 = Matrix3.vec_sub(p2, p0)
        local h = Matrix3.vec_cross(ray_dir, e2)
        local a = Matrix3.vec_dot(e1, h)
        if math.abs(a) > 1e-6 then
            local f = 1 / a
            local s = Matrix3.vec_sub(ray_origin, p0)
            local u = f * Matrix3.vec_dot(s, h)
            if u >= 0 and u <= 1 then
                local q = Matrix3.vec_cross(s, e1)
                local v = f * Matrix3.vec_dot(ray_dir, q)
                if v >= 0 and (u + v) <= 1 then
                    local t = f * Matrix3.vec_dot(e2, q)
                    if t > 1e-6 and t < closest_t then
                        closest_t = t
                        local w = 1 - u - v
                        local hit_pos = Matrix3.vec_add(ray_origin, Matrix3.vec_scale(ray_dir, t))

                        -- Interpolate normals
                        local n0 = Matrix3.new_vector(v0[6], v0[7], v0[8])
                        local n1 = Matrix3.new_vector(v1[6], v1[7], v1[8])
                        local n2 = Matrix3.new_vector(v2[6], v2[7], v2[8])
                        local interp_normal = Matrix3.vec_interpolate(n0, n1, n2, w, u, v)

                        -- Interpolate texture coordinates
                        local t0 = {v0[4], v0[5]}
                        local t1 = {v1[4], v1[5]}
                        local t2 = {v2[4], v2[5]}
                        local interp_uv = {
                            t0[1]*w + t1[1]*u + t2[1]*v,
                            t0[2]*w + t1[2]*u + t2[2]*v
                        }

                        result = {
                            distance = t,
                            position = hit_pos,
                            normal = interp_normal,
                            texcoord = interp_uv,
                            barycentric = Matrix3.new_vector(w, u, v),
                            triangle_index = math.floor(i / 3) + 1
                        }
                    end
                end
            end
        end
    end

    return result
end


return Mesh

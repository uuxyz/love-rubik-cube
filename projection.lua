local Matrix = require("matrix")
local Projection = {}
Projection.__index = Projection

function Projection.new(width, height, focal)
    return setmetatable({
        width = width or 800,
        height = height or 600,
        focal = focal or 1
    }, Projection)
end

function Projection:get_projection_matrix()
	 local f = self.focal
	 local zNear = 0.01
	 local scale_factor = self.width + self.height
	 local w = self.width / scale_factor
	 local h = self.height / scale_factor
	 return {
			f / w, 0, 0, 0,
			0, f / h, 0, 0,
			0, 0, -1, -1,
			0, 0, -2 * zNear, 0,
	 }
end

-- function Projection:get_projection_matrix_unused()
-- 	local fov = math.rad(45)
-- 	local aspect = 16 / 9
-- 	local f = 1.0 / math.tan(fov * 0.5)
-- 	local far = 1000
-- 	local near = 0.01
-- 	return {
-- 		 f/aspect, 0, 0, 0 ,
-- 		 0, f, 0, 0 ,
-- 		 0, 0, (far+near)/(near-far), -1,
-- 		 0, 0, (2*far*near)/(near-far), 0
-- 	}
-- end

function Projection:get_ortho_matrix()
	 local f = self.focal
	 local zNear = 0.01
	 local scale_factor = self.width + self.height
	 local w = self.width / scale_factor
	 local h = self.height / scale_factor
	 -- local w = self.width / self.height + 1
	 -- local h = self.height / self.width + 1
	 return {
			f / w, 0, 0, 0,
			0, f / h, 0, 0,
			0, 0, 0, 0,
			0, 0, -1, 1,
	 }
end

function Projection.ortho(left, right, bottom, top, near, far)
    local rl = right - left
    local tb = top - bottom
    local fn = far - near

    return Matrix.new({
                      2 / rl,                    0,                  0, 0,
                           0,               2 / tb,                  0, 0,
                           0,                    0,            -2 / fn, 0,
        -(right + left) / rl, -(top + bottom) / tb, -(far + near) / fn, 1
    })
end

function Projection.debug()
	local projectionTest = Projection.new(1920, 1080, 1)
	local perspectiveMatrix = projectionTest:get_projection_matrix()
	local orthoMatrix = projectionTest:get_ortho_matrix()
	Matrix.print(perspectiveMatrix)
	Matrix.print(orthoMatrix)
-- 	 1.56   0.00   0.00   0.00
--   0.00   2.78   0.00   0.00
--   0.00   0.00  -1.00  -1.00
--   0.00   0.00  -0.02   0.00

--   1.56   0.00   0.00   0.00
--   0.00   2.78   0.00   0.00
--   0.00   0.00   0.00   0.00
--   0.00   0.00  -1.00   1.00

end

return Projection

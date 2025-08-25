local Matrix = {}

-- Create a new 4x4 matrix
function Matrix.new(data)
    local mat = {}
    for i = 1, 4 do
        for j = 1, 4 do
			mat[(i-1)*4+j] = data and data[i] and data[(i-1)*4+j] or 0
        end
    end
    return mat
end

function Matrix.new_vector(x, y, z, w)
    return {x = x, y = y, z = z, w = w}
end

function Matrix.vec_zero() return Matrix.new_vector(0, 0, 0, 0) end

function Matrix.vec_add(a, b)
    return Matrix.new_vector(a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w)
end

function Matrix.vec_sub(a, b)
    return Matrix.new_vector(a.x - b.x, a.y - b.y, a.z - b.z, a.w - b.w)
end

function Matrix.vec_scale(v, s)
    return Matrix.new_vector(v.x * s, v.y * s, v.z * s, v.w * s)
end

-- Create an identity matrix
function Matrix.identity()
    local mat = Matrix.new()
    for i = 1, 4 do
		mat[(i-1)*4+i] = 1
    end
    return mat
end

-- Multiply two 4x4 matrices (row-major): result = a * b
function Matrix.multiply_row_major(a, b)
   local result = Matrix.new()
   for i = 1, 4 do
      for j = 1, 4 do
         local sum = 0
         for k = 1, 4 do
            sum = sum + a[(i - 1) * 4 + k] * b[(k - 1) * 4 + j]
         end
         result[(i - 1) * 4 + j] = sum
      end
   end
   return result
end

-- Multiply two 4x4 matrices (column-major): result = a * b
function Matrix.multiply(a, b)
   local result = Matrix.new()
   for i = 1, 4 do
      for j = 1, 4 do
         local sum = 0
         for k = 1, 4 do
            sum = sum + a[(k - 1) * 4 + i] * b[(j - 1) * 4 + k]
         end
         result[(j - 1) * 4 + i] = sum
      end
   end
   return result
end

-- Multiply: 4x4 matrix and vec4 (column-major)
function Matrix.multiply_vector(m, v)
    local x = m[1]*v.x + m[5]*v.y + m[9] *v.z + m[13]*v.w
    local y = m[2]*v.x + m[6]*v.y + m[10]*v.z + m[14]*v.w
    local z = m[3]*v.x + m[7]*v.y + m[11]*v.z + m[15]*v.w
    local w = m[4]*v.x + m[8]*v.y + m[12]*v.z + m[16]*v.w
    return Matrix.new_vector(x, y, z, w)
end

-- Inverse: inverse of a 4x4 matrix (column-major)
function Matrix.inverse(m)
    local inv = {}
    inv[1] =  m[6]*m[11]*m[16] - m[6]*m[12]*m[15] - m[10]*m[7]*m[16] + m[10]*m[8]*m[15] + m[14]*m[7]*m[12] - m[14]*m[8]*m[11]
    inv[2] = -m[2]*m[11]*m[16] + m[2]*m[12]*m[15] + m[10]*m[3]*m[16] - m[10]*m[4]*m[15] - m[14]*m[3]*m[12] + m[14]*m[4]*m[11]
    inv[3] =  m[2]*m[7]*m[16] - m[2]*m[8]*m[15] - m[6]*m[3]*m[16] + m[6]*m[4]*m[15] + m[14]*m[3]*m[8] - m[14]*m[4]*m[7]
    inv[4] = -m[2]*m[7]*m[12] + m[2]*m[8]*m[11] + m[6]*m[3]*m[12] - m[6]*m[4]*m[11] - m[10]*m[3]*m[8] + m[10]*m[4]*m[7]

    inv[5] = -m[5]*m[11]*m[16] + m[5]*m[12]*m[15] + m[9]*m[7]*m[16] - m[9]*m[8]*m[15] - m[13]*m[7]*m[12] + m[13]*m[8]*m[11]
    inv[6] =  m[1]*m[11]*m[16] - m[1]*m[12]*m[15] - m[9]*m[3]*m[16] + m[9]*m[4]*m[15] + m[13]*m[3]*m[12] - m[13]*m[4]*m[11]
    inv[7] = -m[1]*m[7]*m[16] + m[1]*m[8]*m[15] + m[5]*m[3]*m[16] - m[5]*m[4]*m[15] - m[13]*m[3]*m[8] + m[13]*m[4]*m[7]
    inv[8] =  m[1]*m[7]*m[12] - m[1]*m[8]*m[11] - m[5]*m[3]*m[12] + m[5]*m[4]*m[11] + m[9]*m[3]*m[8] - m[9]*m[4]*m[7]

    inv[9]  =  m[5]*m[10]*m[16] - m[5]*m[12]*m[14] - m[9]*m[6]*m[16] + m[9]*m[8]*m[14] + m[13]*m[6]*m[12] - m[13]*m[8]*m[10]
    inv[10] = -m[1]*m[10]*m[16] + m[1]*m[12]*m[14] + m[9]*m[2]*m[16] - m[9]*m[4]*m[14] - m[13]*m[2]*m[12] + m[13]*m[4]*m[10]
    inv[11] =  m[1]*m[6]*m[16] - m[1]*m[8]*m[14] - m[5]*m[2]*m[16] + m[5]*m[4]*m[14] + m[13]*m[2]*m[8] - m[13]*m[4]*m[6]
    inv[12] = -m[1]*m[6]*m[12] + m[1]*m[8]*m[10] + m[5]*m[2]*m[12] - m[5]*m[4]*m[10] - m[9]*m[2]*m[8] + m[9]*m[4]*m[6]

    inv[13] = -m[5]*m[10]*m[15] + m[5]*m[11]*m[14] + m[9]*m[6]*m[15] - m[9]*m[7]*m[14] - m[13]*m[6]*m[11] + m[13]*m[7]*m[10]
    inv[14] =  m[1]*m[10]*m[15] - m[1]*m[11]*m[14] - m[9]*m[2]*m[15] + m[9]*m[3]*m[14] + m[13]*m[2]*m[11] - m[13]*m[3]*m[10]
    inv[15] = -m[1]*m[6]*m[15] + m[1]*m[7]*m[14] + m[5]*m[2]*m[15] - m[5]*m[3]*m[14] - m[13]*m[2]*m[7] + m[13]*m[3]*m[6]
    inv[16] =  m[1]*m[6]*m[11] - m[1]*m[7]*m[10] - m[5]*m[2]*m[11] + m[5]*m[3]*m[10] + m[9]*m[2]*m[7] - m[9]*m[3]*m[6]

    local det = m[1]*inv[1] + m[2]*inv[5] + m[3]*inv[9] + m[4]*inv[13]
    if det == 0 then
        return nil
    end

    det = 1.0 / det
    for i = 1, 16 do
        inv[i] = inv[i] * det
    end
    return inv
end

-- Pretty-print a matrix for debugging
function Matrix.print(mat)
    for i = 1, 4 do
        for j = 1, 4 do
			io.write(string.format("%6.2f ", mat[(i-1)*4+j]))
        end
        print()
    end
end

return Matrix

-- test_matrix = {2,11,23,41,
--                3,13,29,43,
-- 			   5,17,31,47,
-- 			   7,19,37,53}
-- Matrix.print(test_matrix)
-- Matrix.print(Matrix.inverse(test_matrix))
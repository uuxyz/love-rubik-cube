local Matrix3 = {}

-- Create a new 3x3 matrix (default all 0)
function Matrix3.new(data)
    local mat = {}
    for i = 1, 3 do
        for j = 1, 3 do
            mat[(i - 1) * 3 + j] = data and data[(i - 1) * 3 + j] or 0
        end
    end
    return mat
end

function Matrix3.diagonal(x, y, z)
    return Matrix3.new({
        x, 0.0, 0.0,
        0.0, y, 0.0,
        0.0, 0.0, z
    })
end

function Matrix3.new_vector(x, y, z)
    return {x = x, y = y, z = z}
end

function Matrix3.vec_zero() return Matrix3.new_vector(0, 0, 0) end

function Matrix3.vec_add(a, b)
    return Matrix3.new_vector(a.x + b.x, a.y + b.y, a.z + b.z)
end

function Matrix3.vec_sub(a, b)
    return Matrix3.new_vector(a.x - b.x, a.y - b.y, a.z - b.z)
end

function Matrix3.vec_len(a)
    local length = math.sqrt(a.x ^ 2 + a.y ^ 2 + a.z ^ 2)
    return length
end

function Matrix3.vec_normalize(a)
    local length = math.sqrt(a.x ^ 2 + a.y ^ 2 + a.z ^ 2)
    return Matrix3.new_vector(
        a.x / length,
        a.y / length,
        a.z / length
    )
end

function Matrix3.vec_dot(a, b)
    return a.x * b.x + a.y * b.y + a.z * b.z
end

function Matrix3.vec_scale(v, s)
    return Matrix3.new_vector(v.x * s, v.y * s, v.z * s)
end

function Matrix3.vec_cross(a, b)
    return Matrix3.new_vector(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x
    )
end

function Matrix3.vec_interpolate(a, b, c, u, v, w)
    return Matrix3.new_vector(
        a.x*u + b.x*v + c.x*w,
        a.y*u + b.y*v + c.y*w,
        a.z*u + b.z*v + c.z*w
    )
end

-- Create identity matrix
function Matrix3.identity()
    local mat = Matrix3.new()
    for i = 1, 3 do
        mat[(i - 1) * 3 + i] = 1
    end
    return mat
end

-- Row-major multiplication a * b
function Matrix3.multiply_row_major(a, b)
    local result = Matrix3.new()
    for i = 1, 3 do
        for j = 1, 3 do
            local sum = 0
            for k = 1, 3 do
                sum = sum + a[(i - 1) * 3 + k] * b[(k - 1) * 3 + j]
            end
            result[(i - 1) * 3 + j] = sum
        end
    end
    return result
end

-- Column-major multiplication (OpenGL convention) a * b
function Matrix3.multiply(a, b)
    local result = Matrix3.new()
    for i = 1, 3 do
        for j = 1, 3 do
            local sum = 0
            for k = 1, 3 do
                sum = sum + a[(k - 1) * 3 + i] * b[(j - 1) * 3 + k]
            end
            result[(j - 1) * 3 + i] = sum
        end
    end
    return result
end

-- Multiply matrix with vec3 (column-major)
function Matrix3.multiply_vector(m, v)
    local x = m[1]*v.x + m[4]*v.y + m[7]*v.z
    local y = m[2]*v.x + m[5]*v.y + m[8]*v.z
    local z = m[3]*v.x + m[6]*v.y + m[9]*v.z
    return {x = x, y = y, z = z}
end

-- Compute the determinant of the 3x3 matrix
local function determinant(m)
    return
        m[1]*(m[5]*m[9] - m[6]*m[8]) -
        m[2]*(m[4]*m[9] - m[6]*m[7]) +
        m[3]*(m[4]*m[8] - m[5]*m[7])
end

-- Inverse (column-major)
function Matrix3.inverse(m)
    local det = determinant(m)
    if math.abs(det) < 1e-8 then
        return nil -- Not invertible
    end
    local inv = {}
    inv[1] =  (m[5]*m[9] - m[6]*m[8])
    inv[2] = -(m[2]*m[9] - m[3]*m[8])
    inv[3] =  (m[2]*m[6] - m[3]*m[5])

    inv[4] = -(m[4]*m[9] - m[6]*m[7])
    inv[5] =  (m[1]*m[9] - m[3]*m[7])
    inv[6] = -(m[1]*m[6] - m[3]*m[4])

    inv[7] =  (m[4]*m[8] - m[5]*m[7])
    inv[8] = -(m[1]*m[8] - m[2]*m[7])
    inv[9] =  (m[1]*m[5] - m[2]*m[4])

    for i = 1, 9 do
        inv[i] = inv[i] / det
    end

    return inv
end

-- Transpose matrix
function Matrix3.transpose(m)
    return {
        m[1], m[4], m[7],
        m[2], m[5], m[8],
        m[3], m[6], m[9]
    }
end

function Matrix3.solve(A, b)
    local M = {}
    for i = 1, 9 do M[i] = A[i] end -- Still a column-major copy
    local x_vec = {b.x, b.y, b.z} -- Named x_vec to avoid confusion with the returned x

    -- Helper function: get element M[row][col] of a column-major matrix
    local function get_M_rc(row, col)
        return M[col * 3 + row + 1]
    end

    -- Helper function: set element M[row][col] of a column-major matrix
    local function set_M_rc(row, col, val)
        M[col * 3 + row + 1] = val
    end

    -- Row swap function (based on column-major layout)
    local function swap_rows(r1, r2)
        for c = 0, 2 do
            local val1 = get_M_rc(r1, c)
            local val2 = get_M_rc(r2, c)
            set_M_rc(r1, c, val2)
            set_M_rc(r2, c, val1)
        end
        x_vec[r1 + 1], x_vec[r2 + 1] = x_vec[r2 + 1], x_vec[r1 + 1]
    end

    -- Gaussian elimination + pivot exchange
    for i = 0, 2 do -- i is the row and column index of the current pivot
        -- Select pivot row
        local max_row = i
        local max_val = math.abs(get_M_rc(i, i)) -- M[i][i]
        for r = i + 1, 2 do
            local val = math.abs(get_M_rc(r, i)) -- M[r][i]
            if val > max_val then
                max_val = val
                max_row = r
            end
        end
        if max_val < 1e-8 then
            error("Matrix3.solve: singular matrix")
        end
        if max_row ~= i then
            swap_rows(i, max_row)
        end

        -- Elimination
        for r = i + 1, 2 do -- Iterate over rows below the current pivot column
            local fac = get_M_rc(r, i) / get_M_rc(i, i) -- fac = M[r][i] / M[i][i]
            -- Starting from the current column i, eliminate elements in current row r
            for c = i, 2 do
                set_M_rc(r, c, get_M_rc(r, c) - fac * get_M_rc(i, c))
            end
            x_vec[r + 1] = x_vec[r + 1] - fac * x_vec[i + 1]
        end
    end

    -- Back substitution
    local result = {}
    for i = 2, 0, -1 do -- Start from the last row
        local sum = x_vec[i + 1]
        for j = i + 1, 2 do -- Start from the column after the current row i
            sum = sum - get_M_rc(i, j) * result[j + 1] -- M[i][j] * x[j]
        end
        result[i + 1] = sum / get_M_rc(i, i) -- Divide by the diagonal element M[i][i]
    end

    return { x = result[1], y = result[2], z = result[3] }
end


-- Print matrix (for debugging)
function Matrix3.print(m)
    for i = 1, 3 do
        for j = 1, 3 do
            io.write(string.format("%6.2f ", m[(i - 1) * 3 + j]))
        end
        print()
    end
end

return Matrix3

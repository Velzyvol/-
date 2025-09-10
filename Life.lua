go.property("size", 50)

local game_state = require("main.game_state")

local tilemap_url = "/tilemap#tilemap"
local tfill = 1
local tfree = 2
local ts = 16
local time_scale = 15

function init(self)
	msg.post(".", "acquire_input_focus")
	msg.post("/camera", "map_initialized", { mw = self.size*ts, mh=self.size*ts })
	msg.post("@render:", "clear_color", { color = vmath.vector4(0.227, 0.243, 0.255, 1) } )
	
	self.map = {}
	self.fill_map = {}
	self.time = 0
	
	for y = 1, self.size do
		self.map[y] = {}
		for x = 1, self.size do
			set_cell(self, y, x, false)
		end
	end

	go.set_position(vmath.vector3(ts*self.size/2, ts*self.size/2,0), "/camera")
end

function on_input(self, action_id, action)
	if not game_state.game_paused then
		return
	end
	
	local mouse_button_left = action_id == hash("mouse_button_left")
	local mouse_button_right = action_id == hash("mouse_button_right")

	if mouse_button_left or mouse_button_right then
		local world = vmath.screen_to_world(action.x, action.y, 0, camera.get_projection("/camera#camera"), camera.get_view("/camera#camera"))
		local tile_x, tile_y = world_to_tile(world.x, world.y)

		if tile_x < 1 or tile_x > self.size or tile_y < 1 or tile_y > self.size then
			return
		end
		
		if mouse_button_left then 
			if self.map[tile_y][tile_x] == false then
				set_cell(self, tile_y, tile_x, true)
			end
		elseif mouse_button_right then 
			if self.map[tile_y][tile_x] == true then
				set_cell(self, tile_y, tile_x, false)
			end
		end
	end
end

function fixed_update(self, dt)
	if not game_state.game_paused then
		self.time = self.time + dt * time_scale
		if self.time >= 1 then
			self.time = 0
			next_gen(self)
		end
	else
		self.time = 0
	end
end

function next_gen(self)
	local next_state = {}

	for _, cell in pairs(self.fill_map) do
		local count = count_neighbors(self, cell.y, cell.x)

		if count == 2 or count == 3 then
		-- if count == 3 or count == 4 or count == 6 or count == 7 or count == 8 then
			next_state[cell.y .. ":" .. cell.x] = true
		else
			next_state[cell.y .. ":" .. cell.x] = false
		end

		for dy = -1, 1 do
			for dx = -1, 1 do
				if not (dx == 0 and dy == 0) then
					local ny, nx = get_cell(self, cell.y + dy, cell.x + dx)
					local nkey = ny .. ":" .. nx

					if not next_state[nkey] then
						local n_count = count_neighbors(self, ny, nx)
						if n_count == 3 then
						-- if n_count == 3 or n_count == 6 or n_count == 7 or n_count == 8 then
							next_state[nkey] = true
						else
							next_state[nkey] = false
						end
					end
				end
			end
		end
	end
	for key, should_be_alive in pairs(next_state) do
		local y, x = key:match("(%d+):(%d+)")
		y, x = tonumber(y), tonumber(x)

		if self.map[y][x] ~= should_be_alive then
			set_cell(self, y, x, should_be_alive)
		end
	end
end

function count_neighbors(self, y, x)
	local count = 0
	for dy = -1, 1 do
		for dx = -1, 1 do
			if not (dx == 0 and dy == 0) then
				local ny, nx = get_cell(self, y + dy, x + dx)
				if self.fill_map[ny .. ":" .. nx] then
					count = count + 1
				end
			end
		end
	end
	return count
end

function set_cell(self, y, x, is_fill)
	self.map[y][x] = is_fill

	local key = y .. ":" .. x

	if is_fill then
		self.fill_map[key] = {y = y, x = x}
		tilemap.set_tile(tilemap_url, "layer", x, y, tfill)
	else
		self.fill_map[key] = nil
		tilemap.set_tile(tilemap_url, "layer", x, y, tfree)
	end
end

function get_cell(self, y, x)
	y = (y - 1) % self.size + 1
	x = (x - 1) % self.size + 1
	return y, x
end

-- вспомогательные фукнкции
function math.clamp(n, min, max) return math.min(math.max(n, min), max) end

function vmath.screen_to_world(x, y, z, proj, view)
	local DISPLAY_WIDTH = sys.get_config_int("display.width")
	local DISPLAY_HEIGHT = sys.get_config_int("display.height")
	local w, h = window.get_size()

	w = w / (w / DISPLAY_WIDTH)
	h = h / (h / DISPLAY_HEIGHT)

	local inv = vmath.inv(proj * view)
	x = (2 * x / w) - 1
	y = (2 * y / h) - 1
	z = (2 * z) - 1
	local x1 = x * inv.m00 + y * inv.m01 + z * inv.m02 + inv.m03
	local y1 = x * inv.m10 + y * inv.m11 + z * inv.m12 + inv.m13
	local z1 = x * inv.m20 + y * inv.m21 + z * inv.m22 + inv.m23

	return vmath.vector3(x1, y1, z1)
end

function tile_to_world(x, y)
	local wrldx = ts * (x - 1) + ts / 2
	local wrldy = ts * (y - 1) + ts / 2
	return wrldx, wrldy
end

function world_to_tile(x, y)
	local coordx = math.ceil(x / ts)
	local coordy = math.ceil(y / ts)
	return coordx, coordy

-- Construit une map du jeu Godot (fichier JSON de maps/, synchronisé par Rojo en
-- ModuleScript) en Parts ancrées dans le Workspace.
--
-- Format Godot (scripts/core/blocks.gd, map_data.gd) :
--   case de 2 m × 2 m, paliers de 1 m ; un bloc posé en (x, y, z) occupe les paliers
--   y .. y + h - 1 ; centre monde de la case = (x*2 + 1, y, z*2 + 1).
--   rot 0..3 → direction avant (0,0,1), (1,0,0), (0,0,-1), (-1,0,0).
-- Godot et Roblox ont les mêmes axes (Y en haut, -Z devant) : on multiplie juste par S.

local Config = require(script.Parent.Config)

local S = Config.STUDS_PER_METER
local CELL = 2.0
local PANEL_THICKNESS = 0.3

local DIRS = {
	[0] = Vector3.new(0, 0, 1),
	[1] = Vector3.new(1, 0, 0),
	[2] = Vector3.new(0, 0, -1),
	[3] = Vector3.new(-1, 0, 0),
}

local MapBuilder = {}

function MapBuilder.dir(rot: number): Vector3
	return DIRS[rot % 4]
end

-- Même formule que Blocks.yaw_for_rot : avec CFrame.Angles(0, yaw, 0), on regarde vers dir(rot).
function MapBuilder.yawForRot(rot: number): number
	local d = DIRS[rot % 4]
	return math.atan2(-d.X, -d.Z)
end

-- Types de blocs : hauteur (paliers), forme, effet de surface, apparence.
local TYPES = {
	floor = { h = 1, shape = "box", surface = "rocket", color = Color3.new(0.27, 0.28, 0.31), material = Enum.Material.Concrete },
	grass = { h = 1, shape = "box", surface = "rocket", color = Color3.new(0.15, 0.215, 0.12), material = Enum.Material.Grass },
	asphalt = { h = 1, shape = "box", surface = "rocket", color = Color3.new(0.13, 0.135, 0.15), material = Enum.Material.Asphalt },
	wall = { h = 3, shape = "box", surface = "rocket", color = Color3.new(0.40, 0.41, 0.44), material = Enum.Material.Concrete },
	wall_low = { h = 1, shape = "box", surface = "rocket", color = Color3.new(0.46, 0.47, 0.5), material = Enum.Material.Concrete },
	ramp = { h = 1, shape = "ramp", surface = "rocket", color = Color3.new(0.3, 0.31, 0.34), material = Enum.Material.Concrete },
	stairs = { h = 1, shape = "ramp", surface = "rocket", color = Color3.new(0.3, 0.31, 0.34), material = Enum.Material.Concrete },
	height = { h = 1, shape = "box", surface = "rail", color = Color3.new(0.086, 0.204, 0.235), material = Enum.Material.Metal, neon = Color3.new(0.22, 0.91, 1.0) },
	energy = { h = 1, shape = "box", surface = "nova", color = Color3.new(0.176, 0.094, 0.22), material = Enum.Material.Metal, neon = Color3.new(0.83, 0.3, 1.0) },
	sprint = { h = 1, shape = "box", surface = "sprint", color = Color3.new(0.216, 0.196, 0.11), material = Enum.Material.Metal, neon = Color3.new(1.0, 0.85, 0.3) },
	jump_pad = { h = 1, shape = "box", surface = "pad", color = Color3.new(0.106, 0.169, 0.208), material = Enum.Material.Metal, neon = Color3.new(0.75, 0.96, 1.0) },
	accelerator = { h = 1, shape = "box", surface = "accel", color = Color3.new(0.2, 0.172, 0.094), material = Enum.Material.Metal, neon = Color3.new(1.0, 0.95, 0.45) },
	glass = { h = 3, shape = "box", surface = "rocket", color = Color3.new(0.7, 0.85, 0.95), material = Enum.Material.Glass, transparency = 0.6 },
	thin_wall = { h = 3, shape = "panel", surface = "rocket", color = Color3.new(0.55, 0.5, 0.43), material = Enum.Material.WoodPlanks },
}

local function cellCenter(pos): Vector3
	-- pos = {x, y, z} (tableau JSON, indices 1..3)
	return Vector3.new(pos[1] * CELL + CELL * 0.5, pos[2], pos[3] * CELL + CELL * 0.5)
end

local function newPart(className: string, parent: Instance): BasePart
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = true
	p.Parent = parent
	return p
end

-- Fine bande de néon posée sur le dessus (décor seulement : ni collision ni requête).
local function addNeonTop(block: BasePart, color: Color3, rot: number?, isAccel: boolean)
	local strip = newPart("Part", block)
	strip.Name = "Neon"
	strip.Material = Enum.Material.Neon
	strip.Color = color
	strip.CanCollide = false
	strip.CanQuery = false
	strip.CanTouch = false
	strip.CastShadow = false
	local top = block.Position.Y + block.Size.Y / 2
	if isAccel and rot then
		-- Flèche simplifiée : une bande dans le sens de propulsion.
		local d = DIRS[rot % 4]
		strip.Size = Vector3.new(0.5 * S, 0.04 * S, 1.6 * S)
		strip.CFrame = CFrame.lookAt(Vector3.new(block.Position.X, top + 0.02 * S, block.Position.Z), Vector3.new(block.Position.X, top + 0.02 * S, block.Position.Z) + d)
	else
		strip.Size = Vector3.new(1.7 * S, 0.04 * S, 1.7 * S)
		strip.CFrame = CFrame.new(block.Position.X, top + 0.02 * S, block.Position.Z)
		strip.Transparency = 0.35
	end
end

export type BuiltMap = {
	model: Model,
	name: string,
	sizeCells: Vector2,
	center: Vector3, -- en mètres
	zoneCenter: Vector3, -- en mètres
	spawns: { CFrame }, -- en studs (pieds du joueur), orientés
}

function MapBuilder.build(data, parent: Instance?): BuiltMap
	local model = Instance.new("Model")
	model.Name = "Map"

	local blocks = Instance.new("Folder")
	blocks.Name = "Blocks"
	blocks.Parent = model

	for _, b in data.blocks do
		local def = TYPES[b.type]
		if not def then
			warn("[MapBuilder] type de bloc inconnu :", b.type)
			continue
		end
		local rot = b.rot or 0
		local base = cellCenter(b.pos) -- bas du bloc, centre de la case (m)
		local h = def.h
		local part: BasePart
		if def.shape == "ramp" then
			-- WedgePart : face verticale à l'arrière (+Z local), pente qui descend vers l'avant (-Z).
			-- La rampe Godot monte vers dir(rot) : on oriente le +Z local du coin vers dir(rot).
			part = newPart("WedgePart", blocks)
			part.Size = Vector3.new(CELL * S, h * S, CELL * S)
			local c = (base + Vector3.new(0, h * 0.5, 0)) * S
			part.CFrame = CFrame.lookAt(c, c - DIRS[rot % 4])
		elseif def.shape == "panel" then
			part = newPart("Part", blocks)
			local c = (base + Vector3.new(0, h * 0.5, 0)) * S
			-- Épaisseur le long de dir(rot), largeur d'une case en travers.
			part.Size = Vector3.new(CELL * S, h * S, PANEL_THICKNESS * S)
			part.CFrame = CFrame.lookAt(c, c + DIRS[rot % 4])
		else
			part = newPart("Part", blocks)
			part.Size = Vector3.new(CELL * S, h * S, CELL * S)
			part.CFrame = CFrame.new((base + Vector3.new(0, h * 0.5, 0)) * S)
		end
		part.Name = b.type
		part.Color = def.color
		part.Material = def.material
		part.Transparency = def.transparency or 0
		part:SetAttribute("Surface", def.surface)
		part:SetAttribute("Rot", rot)
		if b.type == "glass" then
			part:SetAttribute("Glass", true)
			part.CastShadow = false
		end
		if def.neon then
			addNeonTop(part, def.neon, rot, b.type == "accelerator")
		end
	end

	-- Objets du mode.
	local markers = Instance.new("Folder")
	markers.Name = "Markers"
	markers.Parent = model

	local spawns = {}
	local size = data.size or { 21, 21 }
	local center = Vector3.new(size[1] * CELL * 0.5, 0, size[2] * CELL * 0.5)
	local zoneCenter = center
	for _, o in data.objects or {} do
		local p = cellCenter(o.pos)
		if o.type == "spawn_joust" then
			local cf = CFrame.new(p * S) * CFrame.Angles(0, MapBuilder.yawForRot(o.rot or 0), 0)
			table.insert(spawns, cf)
			local m = Instance.new("Part")
			m.Name = "Spawn" .. #spawns
			m.Anchored = true
			m.CanCollide = false
			m.CanQuery = false
			m.CanTouch = false
			m.Transparency = 1
			m.Size = Vector3.new(1, 1, 1)
			m.CFrame = cf
			m.Parent = markers
		elseif o.type == "zone_center" then
			zoneCenter = Vector3.new(p.X, p.Y, p.Z)
		end
	end

	model:SetAttribute("MapName", data.name)
	model:SetAttribute("ZoneCenter", zoneCenter * S)
	model.Parent = parent or workspace

	return {
		model = model,
		name = data.name,
		sizeCells = Vector2.new(size[1], size[2]),
		center = center,
		zoneCenter = zoneCenter,
		spawns = spawns,
	}
end

return MapBuilder

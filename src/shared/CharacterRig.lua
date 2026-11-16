-- Préparation d'un personnage Roblox pour le contrôleur de déplacement maison.
--
-- Principe :
--   * l'avatar visible (R15 ou R6) ne touche rien (groupe BODY, sans masse) ;
--   * un cylindre invisible « Collider » (Ø 0,8 m) soudé au HumanoidRootPart fait les
--     collisions contre la map ; son bas est à STEP_HEIGHT (0,35 m) au-dessus des pieds,
--     le contrôleur gère lui-même le sol (accroche, pentes, petites marches) ;
--   * le Humanoid n'applique plus aucune force (état Physics) : c'est le script client
--     qui pilote la vitesse.

local PhysicsService = game:GetService("PhysicsService")

local Config = require(script.Parent.Config)

local S = Config.STUDS_PER_METER
local G = Config.Groups

local CharacterRig = {}

local groupsReady = false
function CharacterRig.setupCollisionGroups()
	if groupsReady then
		return
	end
	groupsReady = true
	PhysicsService:RegisterCollisionGroup(G.BODY)
	PhysicsService:RegisterCollisionGroup(G.COLLIDER)
	PhysicsService:CollisionGroupSetCollidable(G.BODY, "Default", false)
	PhysicsService:CollisionGroupSetCollidable(G.BODY, G.BODY, false)
	PhysicsService:CollisionGroupSetCollidable(G.BODY, G.COLLIDER, false)
	-- Les joueurs se traversent (comme dans Godot : couche 2, masque décor seulement).
	PhysicsService:CollisionGroupSetCollidable(G.COLLIDER, G.COLLIDER, false)
end

-- Distance (studs) entre le centre du HumanoidRootPart et les pieds.
function CharacterRig.feetOffset(humanoid: Humanoid, root: BasePart): number
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		return 3.0 -- jambes de 2 studs + demi-hauteur du torse
	end
	return humanoid.HipHeight + root.Size.Y / 2
end

local function prepPart(part: BasePart, root: BasePart)
	if part.Name == "Collider" then
		return
	end
	part.CollisionGroup = G.BODY
	part.CanTouch = false
	if part ~= root then
		part.Massless = true
	end
end

-- Appelé par le SERVEUR à l'apparition du personnage.
function CharacterRig.prepare(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart

	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			prepPart(d, root)
		end
	end
	character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			prepPart(d, root)
		end
	end)

	local feet = CharacterRig.feetOffset(humanoid, root)
	character:SetAttribute("FeetOffset", feet)

	-- Cylindre de collision (l'axe d'un cylindre Roblox est X : on le couche à la verticale).
	local B = Config.Body
	local bottom = B.STEP_HEIGHT * S
	local top = B.HEIGHT * S
	local collider = Instance.new("Part")
	collider.Name = "Collider"
	collider.Shape = Enum.PartType.Cylinder
	collider.Size = Vector3.new(top - bottom, B.RADIUS * 2 * S, B.RADIUS * 2 * S)
	collider.Transparency = 1
	collider.CanQuery = false
	collider.CanTouch = false
	collider.CastShadow = false
	collider.CollisionGroup = G.COLLIDER
	collider.CustomPhysicalProperties = PhysicalProperties.new(1, 0, 0, 100, 100) -- aucun frottement sur les murs
	collider.CFrame = root.CFrame * CFrame.new(0, (bottom + top) / 2 - feet, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = collider
	weld.Parent = collider
	collider.Parent = character

	-- Le Humanoid ne doit plus rien faire : pas de saut, pas de marche.
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0 -- cache aussi le bouton de saut tactile par défaut
	humanoid.WalkSpeed = 0
	humanoid.AutoRotate = false
	humanoid.BreakJointsOnDeath = false
end

return CharacterRig

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LIGHTNING_BOSS_VFX_PATH = { "Assets", "VFX", "Bosses", "LightningVFX" }
local bossLightningVfxEvent = ReplicatedStorage:WaitForChild("BossLightningVfxEvent")

local function getReplicatedStorageAsset(path)
	local current = ReplicatedStorage

	for _, childName in path do
		current = current:WaitForChild(childName, 8)
		if not current then
			return nil
		end
	end

	return current
end

local function getVfxBounds(instance)
	if instance:IsA("Model") then
		return instance:GetBoundingBox()
	end

	if instance:IsA("BasePart") then
		return instance.CFrame, instance.Size
	end

	local minPosition = nil
	local maxPosition = nil
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			local halfSize = descendant.Size * 0.5
			local low = descendant.Position - halfSize
			local high = descendant.Position + halfSize

			minPosition = if minPosition
				then Vector3.new(
					math.min(minPosition.X, low.X),
					math.min(minPosition.Y, low.Y),
					math.min(minPosition.Z, low.Z)
				)
				else low
			maxPosition = if maxPosition
				then Vector3.new(
					math.max(maxPosition.X, high.X),
					math.max(maxPosition.Y, high.Y),
					math.max(maxPosition.Z, high.Z)
				)
				else high
		end
	end

	if not minPosition or not maxPosition then
		return CFrame.new(), Vector3.one
	end

	local center = minPosition:Lerp(maxPosition, 0.5)
	return CFrame.new(center), maxPosition - minPosition
end

local function pivotVfxToPosition(vfx, position)
	local cframe = CFrame.new(position)

	if vfx:IsA("Model") then
		vfx:PivotTo(cframe)
	elseif vfx:IsA("BasePart") then
		vfx.CFrame = cframe
	elseif vfx:IsA("Attachment") then
		local holder = Instance.new("Part")
		holder.Name = "LightningVFXHolder"
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.new(1, 1, 1)
		holder.CFrame = cframe
		vfx.Parent = holder
		holder.Parent = Workspace
		return holder
	end

	vfx.Parent = Workspace
	local boundsCFrame = getVfxBounds(vfx)
	local offset = position - boundsCFrame.Position
	for _, descendant in vfx:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CFrame += offset
		end
	end
	return vfx
end

local function emitLightningBossVfx(position)
	local template = getReplicatedStorageAsset(LIGHTNING_BOSS_VFX_PATH)
	if not template then
		warn("[LightningBoss] Missing VFX at ReplicatedStorage.Assets.VFX.Bosses.LightningVFX")
		return
	end

	local vfx = template:Clone()
	vfx.Name = "BossLightningVFX"
	local container = pivotVfxToPosition(vfx, position)
	local longestLifetime = 1.5
	local emitted = 0

	for _, descendant in container:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		elseif descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
			descendant:Emit(5)
			emitted += 1
			longestLifetime = math.max(longestLifetime, descendant.Lifetime.Max)
		end
	end

	if emitted == 0 then
		warn("[LightningBoss] LightningVFX cloned, but no ParticleEmitter descendants were found")
	end

	Debris:AddItem(container, longestLifetime + 1)
end

bossLightningVfxEvent.OnClientEvent:Connect(function(position)
	if typeof(position) ~= "Vector3" then
		return
	end

	emitLightningBossVfx(position)
end)

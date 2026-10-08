-- Obsidian West — RIGID PART Motor6D scaffold (not Studio-tested).
-- Read IMPORT_GUIDE.md first. BACK UP your Model before running.
-- Import joint-local OBJ parts with their exact names; retain +Y up, +Z forward.
-- Roblox imports may flip axes or merge/recenter parts. Verify all axes first.
-- This script REPLACES size, placement, and pivots using the neutral manifest.
-- It is intended for the supplied local OBJ parts, NOT already-skinned imports.
-- Paste in Studio's Command Bar with the Model selected. No animation is supplied.
local Selection = game:GetService("Selection")
local model = Selection:Get()[1]
assert(model and model:IsA("Model"), "Select the imported dragon Model first")
local STUDS_PER_UNIT = 1 -- Change this uniformly; verify orientation BEFORE running.
local data = {
    {name = "Torso", parent = nil, pivot = Vector3.new(0.000000, 3.850000, -0.300000), center = Vector3.new(0.001338, 0.402310, -0.059707), size = Vector3.new(2.957671, 2.964619, 3.582779)},
    {name = "Neck_01", parent = "Torso", pivot = Vector3.new(0.000000, 4.220000, 0.880000), center = Vector3.new(0.000596, 0.103865, 0.142037), size = Vector3.new(2.351852, 1.813483, 2.073011)},
    {name = "Neck_02", parent = "Neck_01", pivot = Vector3.new(0.000000, 4.150000, 1.600000), center = Vector3.new(0.000577, 0.392279, 0.079629), size = Vector3.new(2.172366, 1.806136, 1.916626)},
    {name = "Neck_03", parent = "Neck_02", pivot = Vector3.new(0.000000, 4.650000, 2.160000), center = Vector3.new(0.000549, 0.621691, -0.072780), size = Vector3.new(1.992903, 1.596742, 1.760245)},
    {name = "Neck_04", parent = "Neck_03", pivot = Vector3.new(0.000000, 5.400000, 2.380000), center = Vector3.new(0.004638, 0.561334, 0.016538), size = Vector3.new(1.347680, 1.616377, 1.499610)},
    {name = "Head", parent = "Neck_04", pivot = Vector3.new(0.000000, 6.050000, 2.720000), center = Vector3.new(-0.000566, 0.598628, 0.160527), size = Vector3.new(2.416023, 1.997255, 3.248646)},
    {name = "Jaw", parent = "Head", pivot = Vector3.new(0.000000, 5.960000, 2.940000), center = Vector3.new(0.000000, -0.267089, 0.405465), size = Vector3.new(0.880000, 0.742166, 1.797517)},
    {name = "Tail_01", parent = "Torso", pivot = Vector3.new(0.000000, 3.500000, -1.750000), center = Vector3.new(0.000000, 0.274821, -0.401084), size = Vector3.new(1.134200, 1.758852, 0.988128)},
    {name = "Tail_02", parent = "Tail_01", pivot = Vector3.new(0.000000, 3.420000, -2.600000), center = Vector3.new(-0.041831, 0.271547, -0.385673), size = Vector3.new(1.056020, 1.574186, 0.957306)},
    {name = "Tail_03", parent = "Tail_02", pivot = Vector3.new(-0.120000, 3.420000, -3.400000), center = Vector3.new(-0.094510, 0.269512, -0.391345), size = Vector3.new(1.064141, 1.387098, 1.094276)},
    {name = "Tail_04", parent = "Tail_03", pivot = Vector3.new(-0.380000, 3.600000, -4.200000), center = Vector3.new(-0.141361, 0.257035, -0.356303), size = Vector3.new(1.060609, 1.220958, 1.150923)},
    {name = "Tail_05", parent = "Tail_04", pivot = Vector3.new(-0.750000, 3.960000, -4.940000), center = Vector3.new(-0.099943, 0.232078, -0.342440), size = Vector3.new(0.880537, 1.079840, 1.036560)},
    {name = "Tail_06", parent = "Tail_05", pivot = Vector3.new(-1.020000, 4.300000, -5.650000), center = Vector3.new(0.036586, 0.196833, -0.335249), size = Vector3.new(0.656587, 0.959368, 0.856458)},
    {name = "Tail_07", parent = "Tail_06", pivot = Vector3.new(-0.900000, 4.450000, -6.350000), center = Vector3.new(0.031777, 0.142250, -0.331840), size = Vector3.new(1.159307, 0.877631, 0.926882)},
    {name = "Tail_08", parent = "Tail_07", pivot = Vector3.new(-0.450000, 4.370000, -7.040000), center = Vector3.new(0.079535, 0.039042, -0.299156), size = Vector3.new(1.158706, 0.893193, 0.851810)},
    {name = "Tail_09", parent = "Tail_08", pivot = Vector3.new(0.100000, 4.100000, -7.670000), center = Vector3.new(0.106996, -0.004963, -0.274468), size = Vector3.new(1.117510, 0.790369, 0.760278)},
    {name = "Tail_10", parent = "Tail_09", pivot = Vector3.new(0.700000, 3.790000, -8.230000), center = Vector3.new(0.400861, 0.013135, -0.481746), size = Vector3.new(1.609125, 0.563310, 1.149451)},
    {name = "L_Leg_Thigh", parent = "Torso", pivot = Vector3.new(-0.680000, 3.610000, -1.050000), center = Vector3.new(-0.255915, -0.610694, 0.330001), size = Vector3.new(1.463816, 1.998612, 1.540943)},
    {name = "L_Leg_Shin", parent = "L_Leg_Thigh", pivot = Vector3.new(-1.150000, 2.180000, -0.440000), center = Vector3.new(0.000000, -0.676352, -0.388362), size = Vector3.new(0.598901, 1.693044, 1.269952)},
    {name = "L_Foot", parent = "L_Leg_Shin", pivot = Vector3.new(-1.120000, 0.720000, -1.110000), center = Vector3.new(0.011123, -0.306258, 0.559850), size = Vector3.new(0.977527, 0.827483, 2.147566)},
    {name = "R_Leg_Thigh", parent = "Torso", pivot = Vector3.new(0.680000, 3.610000, -1.050000), center = Vector3.new(0.259844, -0.610694, 0.322213), size = Vector3.new(1.456548, 1.998612, 1.556519)},
    {name = "R_Leg_Shin", parent = "R_Leg_Thigh", pivot = Vector3.new(1.150000, 2.180000, -0.440000), center = Vector3.new(-0.000000, -0.676352, -0.388551), size = Vector3.new(0.598901, 1.693044, 1.270331)},
    {name = "R_Foot", parent = "R_Leg_Shin", pivot = Vector3.new(1.120000, 0.720000, -1.110000), center = Vector3.new(0.011123, -0.306258, 0.559961), size = Vector3.new(0.977527, 0.827483, 2.147344)},
    {name = "L_Wing_UpperArm", parent = "Torso", pivot = Vector3.new(-0.850000, 4.450000, 0.480000), center = Vector3.new(-0.524726, 0.479999, -0.030168), size = Vector3.new(1.581999, 1.771063, 1.333273)},
    {name = "L_Wing_Forearm", parent = "L_Wing_UpperArm", pivot = Vector3.new(-2.020000, 5.150000, 0.510000), center = Vector3.new(-0.517293, 0.503089, 0.196974), size = Vector3.new(1.446149, 1.432433, 0.978744)},
    {name = "L_Wing_Hand", parent = "L_Wing_Forearm", pivot = Vector3.new(-3.050000, 6.140000, 0.970000), center = Vector3.new(-0.005305, 0.458232, 0.320190), size = Vector3.new(0.855575, 1.736463, 1.516312)},
    {name = "L_Wing_Finger_1", parent = "L_Wing_Hand", pivot = Vector3.new(-3.050000, 6.140000, 0.970000), center = Vector3.new(-3.249037, -0.837478, -2.280996), size = Vector3.new(6.691852, 2.021361, 4.911922)},
    {name = "L_Wing_Membrane_1", parent = "L_Wing_Finger_1", pivot = Vector3.new(-3.050000, 6.140000, 0.970000), center = Vector3.new(-3.249037, -1.123399, -2.597518), size = Vector3.new(6.691852, 2.593203, 5.544964)},
    {name = "L_Wing_Finger_2", parent = "L_Wing_Hand", pivot = Vector3.new(-3.050000, 6.140000, 0.970000), center = Vector3.new(-1.891610, -1.168787, -2.652677), size = Vector3.new(3.944844, 2.526343, 5.454611)},
    {name = "L_Wing_Membrane_2", parent = "L_Wing_Finger_2", pivot = Vector3.new(-3.050000, 6.140000, 0.970000), center = Vector3.new(-1.891610, -1.402808, -2.652677), size = Vector3.new(3.944844, 2.994385, 5.454611)},
    {name = "L_Wing_Finger_3", parent = "L_Wing_Hand", pivot = Vector3.new(-3.050000, 6.140000, 0.970000), center = Vector3.new(-0.922818, -1.410557, -2.659607), size = Vector3.new(2.045218, 3.002004, 5.419766)},
    {name = "L_Wing_Membrane_3", parent = "L_Wing_Finger_3", pivot = Vector3.new(-3.050000, 6.140000, 0.970000), center = Vector3.new(-0.922818, -1.410557, -2.659607), size = Vector3.new(2.045218, 3.002004, 5.419766)},
    {name = "L_Wing_Finger_4", parent = "L_Wing_Hand", pivot = Vector3.new(-3.050000, 6.140000, 0.970000), center = Vector3.new(-0.043061, -1.415197, -2.347706), size = Vector3.new(0.305864, 2.993218, 4.799558)},
    {name = "L_Wing_Membrane_4", parent = "L_Wing_Finger_4", pivot = Vector3.new(-3.050000, 6.140000, 0.970000), center = Vector3.new(0.847003, -1.415197, -2.347706), size = Vector3.new(2.085993, 2.993218, 4.799558)},
    {name = "R_Wing_UpperArm", parent = "Torso", pivot = Vector3.new(0.850000, 4.450000, 0.480000), center = Vector3.new(0.528917, 0.479999, -0.029855), size = Vector3.new(1.569477, 1.771063, 1.332647)},
    {name = "R_Wing_Forearm", parent = "R_Wing_UpperArm", pivot = Vector3.new(2.020000, 5.150000, 0.510000), center = Vector3.new(0.517293, 0.503089, 0.196974), size = Vector3.new(1.446149, 1.432433, 0.978744)},
    {name = "R_Wing_Hand", parent = "R_Wing_Forearm", pivot = Vector3.new(3.050000, 6.140000, 0.970000), center = Vector3.new(0.007197, 0.458232, 0.319977), size = Vector3.new(0.869488, 1.736463, 1.515885)},
    {name = "R_Wing_Finger_1", parent = "R_Wing_Hand", pivot = Vector3.new(3.050000, 6.140000, 0.970000), center = Vector3.new(3.249231, -0.837478, -2.281272), size = Vector3.new(6.692240, 2.021361, 4.912472)},
    {name = "R_Wing_Membrane_1", parent = "R_Wing_Finger_1", pivot = Vector3.new(3.050000, 6.140000, 0.970000), center = Vector3.new(3.249231, -1.123399, -2.597518), size = Vector3.new(6.692240, 2.593203, 5.544964)},
    {name = "R_Wing_Finger_2", parent = "R_Wing_Hand", pivot = Vector3.new(3.050000, 6.140000, 0.970000), center = Vector3.new(1.891610, -1.168787, -2.652677), size = Vector3.new(3.944844, 2.526343, 5.454611)},
    {name = "R_Wing_Membrane_2", parent = "R_Wing_Finger_2", pivot = Vector3.new(3.050000, 6.140000, 0.970000), center = Vector3.new(1.891610, -1.402808, -2.652677), size = Vector3.new(3.944844, 2.994385, 5.454611)},
    {name = "R_Wing_Finger_3", parent = "R_Wing_Hand", pivot = Vector3.new(3.050000, 6.140000, 0.970000), center = Vector3.new(0.922818, -1.410557, -2.659607), size = Vector3.new(2.045218, 3.002004, 5.419766)},
    {name = "R_Wing_Membrane_3", parent = "R_Wing_Finger_3", pivot = Vector3.new(3.050000, 6.140000, 0.970000), center = Vector3.new(0.922818, -1.410557, -2.659607), size = Vector3.new(2.045218, 3.002004, 5.419766)},
    {name = "R_Wing_Finger_4", parent = "R_Wing_Hand", pivot = Vector3.new(3.050000, 6.140000, 0.970000), center = Vector3.new(0.043061, -1.415197, -2.347706), size = Vector3.new(0.305864, 2.993218, 4.799558)},
    {name = "R_Wing_Membrane_4", parent = "R_Wing_Finger_4", pivot = Vector3.new(3.050000, 6.140000, 0.970000), center = Vector3.new(-0.847003, -1.415197, -2.347706), size = Vector3.new(2.085993, 2.993218, 4.799558)},
}
local found = {}
for _, d in ipairs(data) do
    local p = model:FindFirstChild(d.name, true)
    assert(p and p:IsA("MeshPart"), "Missing MeshPart: " .. d.name)
    assert(not found[d.name], "Duplicate part: " .. d.name)
    found[d.name] = p
end
-- Validate the complete import before changing any part.
for _, d in ipairs(data) do
    local p = found[d.name]
    p.Anchored = true
    p.Size = d.size * STUDS_PER_UNIT
    p.CFrame = CFrame.new((d.pivot + d.center) * STUDS_PER_UNIT)
    p.PivotOffset = CFrame.new(-d.center * STUDS_PER_UNIT)
    p.CanCollide = false -- Supply simple collision geometry separately.
    p.Massless = d.parent ~= nil
end
for _, d in ipairs(data) do
    if d.parent then
        local p, parent = found[d.name], found[d.parent]
        local jointFrame = CFrame.new(d.pivot * STUDS_PER_UNIT)
        local motorName = d.name .. "_Joint"
        local old = parent:FindFirstChild(motorName)
        if old then old:Destroy() end
        local motor = Instance.new("Motor6D")
        motor.Name = motorName
        motor.Part0, motor.Part1 = parent, p
        motor.C0 = parent.CFrame:ToObjectSpace(jointFrame)
        motor.C1 = p.CFrame:ToObjectSpace(jointFrame)
        motor.Parent = parent
    end
end
model.PrimaryPart = found.Torso
-- Root remains anchored for safe inspection; unanchor it for a physics character.
for _, d in ipairs(data) do found[d.name].Anchored = d.parent == nil end
print("Created 44 Motor6Ds. Verify pivots and animate Motor6D.Transform.")
-- Roblox convention is -Z forward; this asset is +Z forward as requested.
-- Rotate the WHOLE MODEL 180 degrees around Y if you need conventional facing.
-- Finger/membrane panels are rigid: arbitrary finger rotations can open seams.

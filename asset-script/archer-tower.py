"""
============================================================
  Lumina Defense — Archer Tower Builder
  Run this script in Blender's Script Editor (Run Script)
  Output: ArcherTower_Roblox.blend + ArcherTower_Roblox.fbx
============================================================
"""

import bpy, bmesh, math, os

# ─────────────────────────────────────────────────────────────────────────────
# 0. RESET SCENE
# ─────────────────────────────────────────────────────────────────────────────
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

for mesh in list(bpy.data.meshes):     bpy.data.meshes.remove(mesh)
for mat  in list(bpy.data.materials):  bpy.data.materials.remove(mat)
for col  in list(bpy.data.collections): bpy.data.collections.remove(col)

bpy.context.scene.unit_settings.system       = 'METRIC'
bpy.context.scene.unit_settings.scale_length = 1.0

# ─────────────────────────────────────────────────────────────────────────────
# 1. HELPERS  (geometry built directly in world-space via bmesh)
# ─────────────────────────────────────────────────────────────────────────────
def make_box(name, cx, cy, cz, sx, sy, sz, mat, col):
    """Axis-aligned box centred at (cx,cy,cz) with dimensions (sx,sy,sz)."""
    mesh = bpy.data.meshes.new(name)
    obj  = bpy.data.objects.new(name, mesh)
    col.objects.link(obj)
    bm = bmesh.new()
    hx, hy, hz = sx/2, sy/2, sz/2
    v = [
        bm.verts.new((cx-hx, cy-hy, cz-hz)), bm.verts.new((cx+hx, cy-hy, cz-hz)),
        bm.verts.new((cx+hx, cy+hy, cz-hz)), bm.verts.new((cx-hx, cy+hy, cz-hz)),
        bm.verts.new((cx-hx, cy-hy, cz+hz)), bm.verts.new((cx+hx, cy-hy, cz+hz)),
        bm.verts.new((cx+hx, cy+hy, cz+hz)), bm.verts.new((cx-hx, cy+hy, cz+hz)),
    ]
    for f in [(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]:
        bm.faces.new([v[i] for i in f])
    bm.to_mesh(mesh); bm.free()
    mesh.validate(); mesh.update()
    obj.data.materials.append(mat)
    return obj

def make_cyl(name, cx, cy, cz, radius, height, segs, mat, col):
    """Cylinder centred at (cx,cy,cz)."""
    mesh = bpy.data.meshes.new(name)
    obj  = bpy.data.objects.new(name, mesh)
    col.objects.link(obj)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False,
        segments=segs, radius1=radius, radius2=radius, depth=height)
    for vert in bm.verts:
        vert.co.x += cx; vert.co.y += cy; vert.co.z += cz
    bm.to_mesh(mesh); bm.free()
    mesh.validate(); mesh.update()
    obj.data.materials.append(mat)
    return obj

def make_sphere(name, cx, cy, cz, radius, mat, col):
    """UV Sphere centred at (cx,cy,cz)."""
    mesh = bpy.data.meshes.new(name)
    obj  = bpy.data.objects.new(name, mesh)
    col.objects.link(obj)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=6, v_segments=5, radius=radius)
    for vert in bm.verts:
        vert.co.x += cx; vert.co.y += cy; vert.co.z += cz
    bm.to_mesh(mesh); bm.free()
    mesh.validate(); mesh.update()
    obj.data.materials.append(mat)
    return obj

# ─────────────────────────────────────────────────────────────────────────────
# 2. MATERIALS
# ─────────────────────────────────────────────────────────────────────────────
def new_mat(name, color, emission=None, emission_strength=4.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value  = 0.8
    if emission:
        bsdf.inputs["Emission Color"].default_value    = (*emission, 1)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat

mat_wood = new_mat("MAT_Wood", (0.28, 0.15, 0.06))
mat_iron = new_mat("MAT_Iron", (0.38, 0.38, 0.40))
mat_flag = new_mat("MAT_Flag", (0.75, 0.08, 0.08))
mat_glow = new_mat("MAT_Glow", (0.40, 0.02, 0.02), emission=(1.0, 0.05, 0.05))

# ─────────────────────────────────────────────────────────────────────────────
# 3. COLLECTIONS
# ─────────────────────────────────────────────────────────────────────────────
scene      = bpy.context.scene
col_root   = bpy.data.collections.new("ArcherTower_Roblox")
col_base   = bpy.data.collections.new("Base")
col_turret = bpy.data.collections.new("Turret")
scene.collection.children.link(col_root)
col_root.children.link(col_base)
col_root.children.link(col_turret)

# ─────────────────────────────────────────────────────────────────────────────
# 4. BASE — TAPERED PILLAR
#
#   Segment    Z range      Center Z   Width
#   Bottom     0.0 → 3.0    1.50       4.2 × 4.2
#   Mid        3.0 → 6.5    4.75       3.4 × 3.4
#   Top        6.5 → 9.0    7.75       2.8 × 2.8
# ─────────────────────────────────────────────────────────────────────────────
make_box("Base_Pillar_Bottom", 0, 0, 1.50, 4.2, 4.2, 3.0, mat_wood, col_base)
make_box("Base_Pillar_Mid",    0, 0, 4.75, 3.4, 3.4, 3.5, mat_wood, col_base)
make_box("Base_Pillar_Top",    0, 0, 7.75, 2.8, 2.8, 2.5, mat_wood, col_base)

# Iron bands — slightly wider than segment, straddle each joint
make_box("Base_Band_0", 0, 0, 3.00, 4.6, 4.6, 0.30, mat_iron, col_base)
make_box("Base_Band_1", 0, 0, 6.50, 3.8, 3.8, 0.28, mat_iron, col_base)
make_box("Base_Band_2", 0, 0, 8.85, 3.2, 3.2, 0.25, mat_iron, col_base)

# ─────────────────────────────────────────────────────────────────────────────
# 5. BASE — LADDER RUNGS  (flush against -X face of each segment)
#
#   Segment   -X face   Rung center-X = face - half_thickness(0.15)
#   Bottom    -2.10     -2.25
#   Mid       -1.70     -1.85
#   Top       -1.40     -1.55
# ─────────────────────────────────────────────────────────────────────────────
rungs = [
    (0.7, -2.25), (1.5, -2.25), (2.3, -2.25),   # bottom segment
    (3.5, -1.85), (4.3, -1.85), (5.1, -1.85),   # mid segment
    (6.7, -1.55), (7.5, -1.55),                  # top segment
]
for i, (z, x) in enumerate(rungs):
    make_box(f"Base_Rung_{i}", x, 0, z, 0.30, 1.20, 0.15, mat_iron, col_base)

# ─────────────────────────────────────────────────────────────────────────────
# 6. BASE — DIAGONAL STRUTS  (lean from ground outward to pillar corners)
# ─────────────────────────────────────────────────────────────────────────────
strut_data = [
    ( 3.3,  3.3,  2.1,  2.1, 2.5),
    (-3.3,  3.3, -2.1,  2.1, 2.5),
    ( 3.3, -3.3,  2.1, -2.1, 2.5),
    (-3.3, -3.3, -2.1, -2.1, 2.5),
]
for i, (gx, gy, px, py, pz) in enumerate(strut_data):
    dx, dy, dz = px - gx, py - gy, pz
    length = math.sqrt(dx*dx + dy*dy + dz*dz)
    tilt   = math.atan2(math.sqrt(dx*dx + dy*dy), dz)
    yaw    = math.atan2(dy, dx)
    strut  = make_box(f"Base_Strut_{i}", 0, 0, 0, 0.28, 0.28, length, mat_wood, col_base)
    strut.rotation_euler = (0, tilt, yaw)
    strut.location       = ((gx+px)/2, (gy+py)/2, pz/2)

# ─────────────────────────────────────────────────────────────────────────────
# 7. TURRET — PLATFORM  (sits flush on pillar top z=9.0)
# ─────────────────────────────────────────────────────────────────────────────
#   Platform    z: 9.0 → 9.8   center z=9.4   radius=3.0
#   FenceRing   z: 9.8 → 10.3  center z=10.05
#   Merlons     bottom z=9.8   center z=10.25
make_cyl("Turret_Platform",  0, 0,  9.40, 3.00, 0.80, 12, mat_wood, col_turret)
make_cyl("Turret_FenceRing", 0, 0, 10.05, 2.85, 0.50, 20, mat_iron, col_turret)

for i in range(8):
    angle = (2 * math.pi / 8) * i
    make_box(f"Turret_Merlon_{i}",
             math.cos(angle) * 2.7,
             math.sin(angle) * 2.7,
             10.25, 0.55, 0.55, 0.90, mat_wood, col_turret)

# ─────────────────────────────────────────────────────────────────────────────
# 8. TURRET — BALLISTA  (stylized mechanical crossbow)
# ─────────────────────────────────────────────────────────────────────────────
#   Pivot      z: 9.8 → 10.3  center z=10.05
#   Body/Arms  z center=10.475
make_cyl("Ballista_Pivot", 0, 0, 10.05,  0.45, 0.50,  8, mat_iron, col_turret)
make_box("Ballista_Body",  0, 0, 10.475, 2.80, 0.45, 0.35, mat_wood, col_turret)
make_box("Ballista_ArmL", -1.4,  0.5, 10.475, 0.18, 1.40, 0.18, mat_wood, col_turret)
make_box("Ballista_ArmR",  1.4,  0.5, 10.475, 0.18, 1.40, 0.18, mat_wood, col_turret)

# Glow lamps (red neon indicator — set to Neon material in Roblox)
make_sphere("Ballista_Lamp_L", -1.0, -0.4, 10.475, 0.18, mat_glow, col_turret)
make_sphere("Ballista_Lamp_R",  1.0, -0.4, 10.475, 0.18, mat_glow, col_turret)

# ─────────────────────────────────────────────────────────────────────────────
# 9. TURRET — FLAG
# ─────────────────────────────────────────────────────────────────────────────
make_cyl("Flag_Pole",  2.4, 0, 11.40, 0.09, 3.20, 6, mat_iron, col_turret)
make_box("Flag_Cloth", 3.1, 0, 12.50, 1.00, 0.05, 0.65, mat_flag, col_turret)

# ─────────────────────────────────────────────────────────────────────────────
# 10. CAMERA & LIGHTS  (preview scene)
# ─────────────────────────────────────────────────────────────────────────────
cam_data = bpy.data.cameras.new("Camera")
cam_obj  = bpy.data.objects.new("Camera", cam_data)
scene.collection.objects.link(cam_obj)
scene.camera = cam_obj
cam_obj.location       = (14, -14, 10)
cam_obj.rotation_euler = (math.radians(72), 0, math.radians(45))

sun_data        = bpy.data.lights.new("Sun", type='SUN')
sun_data.energy = 3
sun_obj         = bpy.data.objects.new("Sun", sun_data)
scene.collection.objects.link(sun_obj)
sun_obj.location       = (8, -4, 20)
sun_obj.rotation_euler = (math.radians(40), 0, math.radians(30))

neon_data        = bpy.data.lights.new("NeonFill", type='POINT')
neon_data.energy = 50
neon_data.color  = (1.0, 0.1, 0.1)
neon_obj         = bpy.data.objects.new("NeonFill", neon_data)
scene.collection.objects.link(neon_obj)
neon_obj.location = (0, -0.55, 11.0)

# ─────────────────────────────────────────────────────────────────────────────
# 11. CLEAN UP MESH  (triangulate + recalculate normals)
# ─────────────────────────────────────────────────────────────────────────────
for obj in bpy.data.objects:
    if obj.type != 'MESH':
        continue
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.quads_convert_to_tris(quad_method='BEAUTY')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')

total_tris = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == 'MESH')
print(f"[ArcherTower] Total tris: {total_tris} / 2500 budget")

# ─────────────────────────────────────────────────────────────────────────────
# 12. SAVE .blend + EXPORT .fbx
# ─────────────────────────────────────────────────────────────────────────────
BASE_DIR = r"F:/Documents/coding/tugas_semester-4/Computer-Graphic/lumina-defense/assets/3d/archer-tower/"

os.makedirs(BASE_DIR, exist_ok=True)

bpy.ops.wm.save_as_mainfile(filepath=BASE_DIR + "ArcherTower_Roblox.blend")

bpy.ops.export_scene.fbx(
    filepath            = BASE_DIR + "ArcherTower_Roblox.fbx",
    use_selection       = False,
    object_types        = {'MESH'},
    apply_scale_options = 'FBX_SCALE_ALL',   # Apply Scalings = FBX All
    mesh_smooth_type    = 'FACE',            # Smoothing = Face
    add_leaf_bones      = False,
    path_mode           = 'COPY',
    embed_textures      = True,
    bake_anim           = False,
    global_scale        = 1.0,
)

print("[ArcherTower] Build complete — .blend and .fbx saved to:", BASE_DIR)
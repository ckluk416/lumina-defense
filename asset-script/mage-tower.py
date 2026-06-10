"""
============================================================
  Lumina Defense — Mage Tower Builder (Broken Pillar variant)
  Run this script in Blender's Script Editor (Run Script)
  Output: MageTower_Roblox.blend + MageTower_Roblox.fbx
============================================================
"""

import bpy, bmesh, math, os

# ─────────────────────────────────────────────────────────────────────────────
# 0. RESET SCENE
# ─────────────────────────────────────────────────────────────────────────────
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()
for mesh in list(bpy.data.meshes):      bpy.data.meshes.remove(mesh)
for mat  in list(bpy.data.materials):   bpy.data.materials.remove(mat)
for col  in list(bpy.data.collections): bpy.data.collections.remove(col)

bpy.context.scene.unit_settings.system       = 'METRIC'
bpy.context.scene.unit_settings.scale_length = 1.0

# ─────────────────────────────────────────────────────────────────────────────
# 1. HELPERS
# ─────────────────────────────────────────────────────────────────────────────
def make_box(name, cx, cy, cz, sx, sy, sz, mat, col, rx=0, ry=0, rz=0):
    """Axis-aligned box centred at (cx,cy,cz), optional rotation in radians."""
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
    if rx or ry or rz:
        obj.rotation_euler = (rx, ry, rz)
    return obj

def make_crystal_shard(name, cx, cy, cz, base_r, height, mat, col, rx=0, ry=0, rz=0):
    """Pointed 4-sided crystal shard growing upward from (cx,cy,cz)."""
    mesh = bpy.data.meshes.new(name)
    obj  = bpy.data.objects.new(name, mesh)
    col.objects.link(obj)
    bm = bmesh.new()
    segs = 4
    tip  = bm.verts.new((cx, cy, cz + height))
    base_verts = []
    for i in range(segs):
        a = (2*math.pi/segs)*i + math.pi/4
        base_verts.append(bm.verts.new((
            cx + math.cos(a)*base_r,
            cy + math.sin(a)*base_r, cz)))
    bm.faces.new(base_verts)
    for i in range(segs):
        bm.faces.new([base_verts[i], base_verts[(i+1)%segs], tip])
    bm.to_mesh(mesh); bm.free()
    mesh.validate(); mesh.update()
    obj.data.materials.append(mat)
    if rx or ry or rz:
        obj.rotation_euler = (rx, ry, rz)
    return obj

def make_octahedron(name, cx, cy, cz, radius, height, mat, col):
    """Octahedron crystal: top+bottom spikes + 4 equatorial verts."""
    mesh = bpy.data.meshes.new(name)
    obj  = bpy.data.objects.new(name, mesh)
    col.objects.link(obj)
    bm = bmesh.new()
    h, r = height/2, radius
    vt  = bm.verts.new((cx,   cy,   cz+h))
    vb  = bm.verts.new((cx,   cy,   cz-h))
    vpx = bm.verts.new((cx+r, cy,   cz  ))
    vnx = bm.verts.new((cx-r, cy,   cz  ))
    vpy = bm.verts.new((cx,   cy+r, cz  ))
    vny = bm.verts.new((cx,   cy-r, cz  ))
    for f in [
        (vt,vpx,vpy),(vt,vpy,vnx),(vt,vnx,vny),(vt,vny,vpx),
        (vb,vpy,vpx),(vb,vnx,vpy),(vb,vny,vnx),(vb,vpx,vny),
    ]:
        bm.faces.new(f)
    bm.to_mesh(mesh); bm.free()
    mesh.validate(); mesh.update()
    obj.data.materials.append(mat)
    return obj

def make_ring(name, cx, cy, cz, r_outer, r_inner, height, segs, mat, col):
    """Hollow annular ring."""
    mesh = bpy.data.meshes.new(name)
    obj  = bpy.data.objects.new(name, mesh)
    col.objects.link(obj)
    bm = bmesh.new()
    step = (2*math.pi)/segs
    ob, ot, ib, it_ = [], [], [], []
    h = height/2
    for i in range(segs):
        a=i*step; co=math.cos(a); si=math.sin(a)
        ob.append(bm.verts.new((cx+co*r_outer, cy+si*r_outer, cz-h)))
        ot.append(bm.verts.new((cx+co*r_outer, cy+si*r_outer, cz+h)))
        ib.append(bm.verts.new((cx+co*r_inner, cy+si*r_inner, cz-h)))
        it_.append(bm.verts.new((cx+co*r_inner, cy+si*r_inner, cz+h)))
    for i in range(segs):
        n=(i+1)%segs
        bm.faces.new([ob[i],ob[n],ot[n],ot[i]])
        bm.faces.new([ib[n],ib[i],it_[i],it_[n]])
        bm.faces.new([ob[n],ob[i],ib[i],ib[n]])
        bm.faces.new([ot[i],ot[n],it_[n],it_[i]])
    bm.to_mesh(mesh); bm.free()
    mesh.validate(); mesh.update()
    obj.data.materials.append(mat)
    return obj

# ─────────────────────────────────────────────────────────────────────────────
# 2. MATERIALS
# ─────────────────────────────────────────────────────────────────────────────
def new_mat(name, color, roughness=0.8, emission=None, emission_str=5.0, alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value  = (*color, 1)
    bsdf.inputs["Roughness"].default_value   = roughness
    bsdf.inputs["Alpha"].default_value       = alpha
    if alpha < 1.0: mat.blend_method = 'BLEND'
    if emission:
        bsdf.inputs["Emission Color"].default_value    = (*emission, 1)
        bsdf.inputs["Emission Strength"].default_value = emission_str
    return mat

mat_stone   = new_mat("MAT_Stone",   (0.18, 0.16, 0.19), roughness=0.95)
mat_obsid   = new_mat("MAT_Obsidian",(0.07, 0.06, 0.09), roughness=0.35)
mat_rune    = new_mat("MAT_Rune",    (0.35, 0.05, 0.55),
                      emission=(0.7, 0.0, 1.0), emission_str=6.0)
mat_crystal = new_mat("MAT_Crystal", (0.45, 0.10, 0.80), roughness=0.05,
                      emission=(0.6, 0.0, 1.0), emission_str=5.0, alpha=0.78)

# ─────────────────────────────────────────────────────────────────────────────
# 3. COLLECTIONS
# ─────────────────────────────────────────────────────────────────────────────
scene      = bpy.context.scene
col_root   = bpy.data.collections.new("MageTower_Roblox")
col_base   = bpy.data.collections.new("Base")
col_turret = bpy.data.collections.new("Turret")
scene.collection.children.link(col_root)
col_root.children.link(col_base)
col_root.children.link(col_turret)

# ─────────────────────────────────────────────────────────────────────────────
# 4. FOUNDATION SLAB  z: 0 → 0.9
# ─────────────────────────────────────────────────────────────────────────────
make_box("Base_Foundation", 0, 0, 0.45, 6.0, 6.0, 0.9, mat_stone, col_base)

# Crystal roots erupting from foundation corners and edges
shard_roots = [
    ( 2.2,  2.2, 0.85, 0.35, 2.2, 0,                   0,                    math.radians( 20)),
    (-2.2,  2.2, 0.85, 0.35, 1.8, 0,                   0,                    math.radians(-15)),
    ( 2.2, -2.2, 0.85, 0.30, 2.0, 0,                   0,                    math.radians( 10)),
    (-2.2, -2.2, 0.85, 0.40, 2.5, 0,                   0,                    math.radians( 25)),
    ( 2.8,  0.0, 0.85, 0.25, 1.5, 0,                   math.radians( 15),    0               ),
    (-2.8,  0.0, 0.85, 0.25, 1.6, 0,                   math.radians(-12),    0               ),
    ( 0.0,  2.8, 0.85, 0.28, 1.4, math.radians( 10),   0,                    0               ),
    ( 0.0, -2.8, 0.85, 0.22, 1.7, math.radians( -8),   0,                    0               ),
]
for i, (cx, cy, cz, br, ht, rx, ry, rz) in enumerate(shard_roots):
    make_crystal_shard(f"Base_RootShard_{i}", cx, cy, cz, br, ht,
                       mat_crystal, col_base, rx, ry, rz)

# ─────────────────────────────────────────────────────────────────────────────
# 5. BROKEN STONE SEGMENTS  (3 segments, slight offset/tilt each)
#
#   Seg 0 (bottom)  z: 0.9 → 4.5   center z=2.7   4.2×4.2
#   Gap 0           z: 4.5 → 5.1   crystal eruption
#   Seg 1 (mid)     z: 5.1 → 8.5   center z=6.8   3.7×3.7   offset +0.2x
#   Gap 1           z: 8.5 → 9.2   crystal eruption
#   Seg 2 (top)     z: 9.2 → 12.0  center z=10.6  3.1×3.1   offset -0.15x
# ─────────────────────────────────────────────────────────────────────────────

# ── Segment 0 ─────────────────────────────────────────────────────────────────
make_box("Base_Seg0", 0.0, 0.0, 2.70, 4.2, 4.2, 3.6, mat_obsid, col_base,
         rx=math.radians(1.5), ry=math.radians(-1.0))

for side, fx, fy, is_x in [('px', 2.12,0,True),('-x',-2.12,0,True),
                             ('py',0, 2.12,False),('-y',0,-2.12,False)]:
    if is_x: make_box(f"Base_Rune0_{side}", fx, fy, 2.7, 0.05, 1.1, 0.75, mat_rune, col_base)
    else:    make_box(f"Base_Rune0_{side}", fx, fy, 2.7, 1.1, 0.05, 0.75, mat_rune, col_base)

gap0_shards = [
    ( 1.2,  0.8, 4.5, 0.28, 1.8, 0,                  0,                   math.radians( 12)),
    (-1.0,  1.0, 4.5, 0.22, 1.4, 0,                  0,                   math.radians(-18)),
    ( 0.2, -1.3, 4.5, 0.30, 2.0, math.radians(  8),  0,                   0               ),
    (-1.5, -0.5, 4.5, 0.20, 1.3, 0,                  math.radians(-10),   0               ),
    ( 1.6, -1.0, 4.5, 0.18, 1.1, 0,                  math.radians( 14),   0               ),
]
for i, (cx, cy, cz, br, ht, rx, ry, rz) in enumerate(gap0_shards):
    make_crystal_shard(f"Base_Gap0Shard_{i}", cx, cy, cz, br, ht,
                       mat_crystal, col_base, rx, ry, rz)

# ── Segment 1 ─────────────────────────────────────────────────────────────────
make_box("Base_Seg1", 0.2, -0.1, 6.80, 3.7, 3.7, 3.4, mat_obsid, col_base,
         rx=math.radians(-1.0), ry=math.radians(1.5))

for side, fx, fy, is_x in [('px', 2.05,0,True),('-x',-1.65,0,True),
                             ('py',0.2, 1.95,False),('-y',0.2,-1.95,False)]:
    if is_x: make_box(f"Base_Rune1_{side}", fx+0.1, fy, 6.8, 0.05, 0.95, 0.65, mat_rune, col_base)
    else:    make_box(f"Base_Rune1_{side}", fx, fy, 6.8, 0.95, 0.05, 0.65, mat_rune, col_base)

gap1_shards = [
    (-0.8,  1.2, 8.5, 0.25, 1.7, 0,                  0,                   math.radians(-14)),
    ( 1.3, -0.6, 8.5, 0.20, 1.4, 0,                  math.radians( 10),   0               ),
    ( 0.0,  0.5, 8.5, 0.32, 2.1, math.radians(  6),  0,                   0               ),
    (-1.2, -0.9, 8.5, 0.18, 1.2, 0,                  math.radians( -8),   0               ),
]
for i, (cx, cy, cz, br, ht, rx, ry, rz) in enumerate(gap1_shards):
    make_crystal_shard(f"Base_Gap1Shard_{i}", cx, cy, cz, br, ht,
                       mat_crystal, col_base, rx, ry, rz)

# ── Segment 2 ─────────────────────────────────────────────────────────────────
make_box("Base_Seg2", -0.15, 0.1, 10.60, 3.1, 3.1, 2.8, mat_obsid, col_base,
         rx=math.radians(2.0), ry=math.radians(-1.5))

for side, fx, fy, is_x in [('px', 1.40,0,True),('-x',-1.70,0,True),
                             ('py',-0.15, 1.65,False),('-y',-0.15,-1.65,False)]:
    if is_x: make_box(f"Base_Rune2_{side}", fx-0.1, fy, 10.6, 0.05, 0.8, 0.55, mat_rune, col_base)
    else:    make_box(f"Base_Rune2_{side}", fx, fy, 10.6, 0.8, 0.05, 0.55, mat_rune, col_base)

top_shards = [
    ( 0.6,  0.8, 12.0, 0.22, 1.5, 0,                  0,                   math.radians( 10)),
    (-0.9, -0.4, 12.0, 0.18, 1.2, math.radians( 12),  0,                   0               ),
    ( 0.0, -1.0, 12.0, 0.20, 1.0, 0,                  math.radians(-10),   0               ),
]
for i, (cx, cy, cz, br, ht, rx, ry, rz) in enumerate(top_shards):
    make_crystal_shard(f"Base_TopShard_{i}", cx, cy, cz, br, ht,
                       mat_crystal, col_base, rx, ry, rz)

# ─────────────────────────────────────────────────────────────────────────────
# 6. TURRET — FLOATING OCTAHEDRON CRYSTAL  (center z=14.5)
# ─────────────────────────────────────────────────────────────────────────────
CRYSTAL_Z = 14.5

make_octahedron("Turret_Crystal", 0, 0, CRYSTAL_Z, 1.7, 3.2, mat_crystal, col_turret)

# Levitation rings bridging pillar top to crystal
make_ring("Turret_LevRing",  0, 0, 13.2, 2.1, 1.6, 0.35, 16, mat_obsid, col_turret)
make_ring("Turret_GlowRing", 0, 0, 13.5, 2.0, 1.7, 0.14, 16, mat_rune,  col_turret)

# 3 orbiting shard crystals 120° apart
for i in range(3):
    angle = (2*math.pi/3)*i + math.radians(30)
    make_octahedron(f"Turret_ShardCrystal_{i}",
                    math.cos(angle)*2.5, math.sin(angle)*2.5,
                    CRYSTAL_Z, 0.40, 1.0, mat_rune, col_turret)

# 4 upward shards near levitation ring
for i in range(4):
    angle = (2*math.pi/4)*i + math.radians(45)
    make_crystal_shard(f"Turret_RingShard_{i}",
                       math.cos(angle)*1.85, math.sin(angle)*1.85,
                       12.6, 0.18, 0.9, mat_crystal, col_turret,
                       rx=math.radians(8)*(-1 if i%2 else 1))

# ─────────────────────────────────────────────────────────────────────────────
# 7. CAMERA & LIGHTS
# ─────────────────────────────────────────────────────────────────────────────
cam_data = bpy.data.cameras.new("Camera")
cam_obj  = bpy.data.objects.new("Camera", cam_data)
scene.collection.objects.link(cam_obj)
scene.camera = cam_obj
cam_obj.location       = (14, -14, 11)
cam_obj.rotation_euler = (math.radians(72), 0, math.radians(45))

sun        = bpy.data.lights.new("Sun", 'SUN')
sun.energy = 2.5
sun_obj    = bpy.data.objects.new("Sun", sun)
scene.collection.objects.link(sun_obj)
sun_obj.location       = (8, -4, 20)
sun_obj.rotation_euler = (math.radians(40), 0, math.radians(30))

neon        = bpy.data.lights.new("NeonFill", 'POINT')
neon.energy = 150
neon.color  = (0.6, 0.0, 1.0)
neon_obj    = bpy.data.objects.new("NeonFill", neon)
scene.collection.objects.link(neon_obj)
neon_obj.location = (0, 0, CRYSTAL_Z)

neon2        = bpy.data.lights.new("NeonFill2", 'POINT')
neon2.energy = 60
neon2.color  = (0.5, 0.0, 0.9)
neon2_obj    = bpy.data.objects.new("NeonFill2", neon2)
scene.collection.objects.link(neon2_obj)
neon2_obj.location = (0, 0, 6.5)

# ─────────────────────────────────────────────────────────────────────────────
# 8. CLEAN UP MESH  (triangulate + recalculate normals)
# ─────────────────────────────────────────────────────────────────────────────
for obj in bpy.data.objects:
    if obj.type != 'MESH': continue
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.quads_convert_to_tris(quad_method='BEAUTY')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')

total_tris = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == 'MESH')
print(f"[MageTower] Total tris: {total_tris} / 2500 budget")

# ─────────────────────────────────────────────────────────────────────────────
# 9. SAVE .blend + EXPORT .fbx
# ─────────────────────────────────────────────────────────────────────────────
BASE_DIR = r"F:/Documents/coding/tugas_semester-4/Computer-Graphic/lumina-defense/assets/3d/mage-tower1/"
os.makedirs(BASE_DIR, exist_ok=True)

bpy.ops.wm.save_as_mainfile(filepath=BASE_DIR + "MageTower_Roblox.blend")

bpy.ops.export_scene.fbx(
    filepath            = BASE_DIR + "MageTower_Roblox.fbx",
    use_selection       = False,
    object_types        = {'MESH'},
    apply_scale_options = 'FBX_SCALE_ALL',
    mesh_smooth_type    = 'FACE',
    add_leaf_bones      = False,
    path_mode           = 'COPY',
    embed_textures      = True,
    bake_anim           = False,
    global_scale        = 1.0,
)

print("[MageTower] Build complete — .blend and .fbx saved to:", BASE_DIR)
"""
============================================================
  Lumina Defense — Mortar Builder
  Run this script in Blender's Script Editor (Run Script)
  Output: Mortar_Roblox.blend + Mortar_Roblox.fbx
============================================================

  Spec (from asset-spec.md):
    Dimensi   : 8 × 8 × 10 studs
    Base      : Landasan baja melingkar tebal dengan penopang
                hidrolik berat untuk meredam hentakan tembakan.
    Turret    : Laras mortar berdiameter besar mendongak ke atas
                dengan mekanisme piston penyetel elevasi.
    Warna     : Abu-abu baja militer / hijau zaitun (olive drab),
                aksen kuning/hitam hazard di sisi landasan.
    Glow/Neon : Garis energi oranye di sepanjang laras mortar.
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

def make_cone(name, cx, cy, cz, r_bottom, r_top, height, segs, mat, col):
    """Truncated cone (frustum) centred at (cx,cy,cz)."""
    mesh = bpy.data.meshes.new(name)
    obj  = bpy.data.objects.new(name, mesh)
    col.objects.link(obj)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False,
        segments=segs, radius1=r_bottom, radius2=r_top, depth=height)
    for vert in bm.verts:
        vert.co.x += cx; vert.co.y += cy; vert.co.z += cz
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
    step = (2 * math.pi) / segs
    ob, ot, ib, it_ = [], [], [], []
    h = height / 2
    for i in range(segs):
        a = i * step; co = math.cos(a); si = math.sin(a)
        ob.append(bm.verts.new((cx + co*r_outer, cy + si*r_outer, cz - h)))
        ot.append(bm.verts.new((cx + co*r_outer, cy + si*r_outer, cz + h)))
        ib.append(bm.verts.new((cx + co*r_inner, cy + si*r_inner, cz - h)))
        it_.append(bm.verts.new((cx + co*r_inner, cy + si*r_inner, cz + h)))
    for i in range(segs):
        n = (i + 1) % segs
        bm.faces.new([ob[i], ob[n], ot[n], ot[i]])
        bm.faces.new([ib[n], ib[i], it_[i], it_[n]])
        bm.faces.new([ob[n], ob[i], ib[i], ib[n]])
        bm.faces.new([ot[i], ot[n], it_[n], it_[i]])
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
    bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=6, radius=radius)
    for vert in bm.verts:
        vert.co.x += cx; vert.co.y += cy; vert.co.z += cz
    bm.to_mesh(mesh); bm.free()
    mesh.validate(); mesh.update()
    obj.data.materials.append(mat)
    return obj

# ─────────────────────────────────────────────────────────────────────────────
# 2. MATERIALS
# ─────────────────────────────────────────────────────────────────────────────
def new_mat(name, color, roughness=0.8, emission=None, emission_str=5.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value  = (*color, 1)
    bsdf.inputs["Roughness"].default_value   = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value    = (*emission, 1)
        bsdf.inputs["Emission Strength"].default_value = emission_str
    return mat

# Military steel grey — main body metal
mat_steel    = new_mat("MAT_Steel",    (0.38, 0.40, 0.42), roughness=0.45)
# Olive drab — barrel / turret accent
mat_olive    = new_mat("MAT_Olive",    (0.28, 0.30, 0.18), roughness=0.65)
# Dark iron — hydraulic legs / mechanical parts
mat_iron     = new_mat("MAT_Iron",     (0.22, 0.22, 0.24), roughness=0.55)
# Hazard yellow stripes
mat_hazard_y = new_mat("MAT_HazardY",  (0.85, 0.72, 0.10), roughness=0.70)
# Hazard black stripes
mat_hazard_k = new_mat("MAT_HazardK",  (0.06, 0.06, 0.06), roughness=0.70)
# Orange energy glow — set to Neon material in Roblox
mat_glow     = new_mat("MAT_Glow",     (0.95, 0.45, 0.05),
                        emission=(1.0, 0.55, 0.05), emission_str=6.0)

# ─────────────────────────────────────────────────────────────────────────────
# 3. COLLECTIONS
# ─────────────────────────────────────────────────────────────────────────────
scene      = bpy.context.scene
col_root   = bpy.data.collections.new("Mortar_Roblox")
col_base   = bpy.data.collections.new("Base")
col_turret = bpy.data.collections.new("Turret")
scene.collection.children.link(col_root)
col_root.children.link(col_base)
col_root.children.link(col_turret)

# ─────────────────────────────────────────────────────────────────────────────
# 4. BASE — CIRCULAR STEEL PLATFORM
#
#   Overall footprint: 8 × 8 studs, height budget for Base ≈ 4 studs
#
#   Base_Platform   z: 0.0 → 1.0    circular slab r=3.8
#   Base_Ring       z: 0.9 → 1.3    reinforcement ring r=4.0
#   Hazard stripes  z: 1.3           on the ring edge
#   Base_Inner      z: 1.0 → 2.0    inner hub cylinder r=1.6
#   Turntable       z: 2.0 → 2.5    rotation platform r=2.2
# ─────────────────────────────────────────────────────────────────────────────

# Main circular platform slab (thick steel disc)
make_cyl("Base_Platform", 0, 0, 0.50, 3.80, 1.00, 16, mat_steel, col_base)

# Reinforcement outer ring — slightly wider
make_ring("Base_OuterRing", 0, 0, 1.10, 4.00, 3.60, 0.40, 16, mat_iron, col_base)

# Hazard stripe segments on the ring (alternating yellow / black)
for i in range(8):
    angle = (2 * math.pi / 8) * i
    stripe_mat = mat_hazard_y if i % 2 == 0 else mat_hazard_k
    make_box(f"Base_Hazard_{i}",
             math.cos(angle) * 3.80,
             math.sin(angle) * 3.80,
             1.10,
             0.70, 0.25, 0.38,
             stripe_mat, col_base,
             rz=angle)

# Inner hub — central cylinder housing turntable mechanism
make_cyl("Base_InnerHub", 0, 0, 1.50, 1.60, 1.00, 12, mat_iron, col_base)

# Turntable disc — mortar sits on top of this
make_cyl("Base_Turntable", 0, 0, 2.25, 2.20, 0.50, 14, mat_steel, col_base)

# Gear detail on turntable
make_ring("Base_GearRing", 0, 0, 2.00, 1.80, 1.50, 0.20, 12, mat_iron, col_base)

# ─────────────────────────────────────────────────────────────────────────────
# 5. BASE — HYDRAULIC SHOCK-ABSORBER LEGS (3 legs, 120° apart)
#
#   Each leg: vertical strut from platform edge downward to ground,
#   with a piston cylinder and a wide foot pad anchored to ground.
#   All components physically touch the platform — no floating parts.
# ─────────────────────────────────────────────────────────────────────────────
for i in range(3):
    angle = (2 * math.pi / 3) * i + math.radians(30)
    cos_a = math.cos(angle)
    sin_a = math.sin(angle)

    # Leg bracket — connects to platform edge (z: 0.3 → 1.0)
    bracket_x = cos_a * 3.20
    bracket_y = sin_a * 3.20
    make_box(f"Leg_Bracket_{i}",
             bracket_x, bracket_y, 0.65,
             0.60, 0.60, 0.70,
             mat_iron, col_base,
             rz=angle)

    # Strut — vertical pillar from ground to platform (z: 0.0 → 1.0)
    strut_x = cos_a * 3.60
    strut_y = sin_a * 3.60
    make_box(f"Leg_Strut_{i}",
             strut_x, strut_y, 0.50,
             0.35, 0.35, 1.00,
             mat_iron, col_base,
             rz=angle)

    # Hydraulic piston outer — wider cylinder (z: 0.0 → 0.65)
    piston_x = cos_a * 3.60
    piston_y = sin_a * 3.60
    make_cyl(f"Leg_PistonOuter_{i}",
             piston_x, piston_y, 0.325,
             0.25, 0.65, 8,
             mat_steel, col_base)

    # Hydraulic piston inner — thinner rod (visible overlap, z: 0.0 → 0.85)
    make_cyl(f"Leg_PistonInner_{i}",
             piston_x, piston_y, 0.425,
             0.14, 0.85, 6,
             mat_olive, col_base)

    # Foot pad — wide flat disc at ground level (z: 0.0 → 0.15)
    foot_x = cos_a * 3.60
    foot_y = sin_a * 3.60
    make_cyl(f"Leg_FootPad_{i}",
             foot_x, foot_y, 0.075,
             0.55, 0.15, 8,
             mat_iron, col_base)

# ─────────────────────────────────────────────────────────────────────────────
# 6. TURRET — MORTAR MOUNT & CRADLE
#
#   Sits on top of the turntable (z=2.5).
#   Cradle: U-shaped bracket holding the barrel, with trunnion pins.
#
#   Cradle_Base    z: 2.50 → 3.20     box 2.4 × 1.8
#   Cradle_ArmL    z: 3.20 → 5.50     left upright
#   Cradle_ArmR    z: 3.20 → 5.50     right upright
#   Trunnion pins  z: 4.80            connecting barrel to arms
# ─────────────────────────────────────────────────────────────────────────────

# Cradle base block — sits flush on turntable
make_box("Cradle_Base", 0, 0, 2.85, 2.40, 1.80, 0.70, mat_steel, col_turret)

# Left cradle arm (Y+)
make_box("Cradle_ArmL", 0, 1.05, 4.35, 0.70, 0.30, 2.30, mat_steel, col_turret)

# Right cradle arm (Y-)
make_box("Cradle_ArmR", 0, -1.05, 4.35, 0.70, 0.30, 2.30, mat_steel, col_turret)

# Trunnion pins — horizontal cylinders connecting barrel to cradle arms
make_cyl("Trunnion_L", 0, 0.95, 4.80, 0.12, 0.40, 8, mat_iron, col_turret)
make_cyl("Trunnion_R", 0, -0.95, 4.80, 0.12, 0.40, 8, mat_iron, col_turret)

# ─────────────────────────────────────────────────────────────────────────────
# 7. TURRET — MORTAR BARREL (angled upward ~55°)
#
#   The barrel is a large-diameter tube tilted to fire in a parabolic arc.
#   Barrel centre sits at the trunnion height (z≈4.8) and angles upward.
#   Barrel length ≈ 4.5 studs, resulting in muzzle at roughly z≈8.5.
#
#   TILT_ANGLE = 55° from horizontal (mortar firing angle)
# ─────────────────────────────────────────────────────────────────────────────
BARREL_TILT = math.radians(55)  # elevation angle

# Main barrel — large diameter cylinder
barrel = make_cyl("Barrel_Main", 0, 0, 0, 0.65, 4.50, 12, mat_olive, col_turret)
barrel.rotation_euler = (BARREL_TILT, 0, 0)
barrel.location       = (0, 0, 4.80)

# Barrel reinforcement ring — at base of barrel
barrel_ring = make_ring("Barrel_BaseRing", 0, 0, -1.80, 0.78, 0.60, 0.35, 12, mat_steel, col_turret)
barrel_ring.rotation_euler = (BARREL_TILT, 0, 0)
barrel_ring.location       = (0, 0, 4.80)

# Barrel muzzle ring — at top of barrel
muzzle_ring = make_ring("Barrel_MuzzleRing", 0, 0, 1.80, 0.80, 0.58, 0.30, 12, mat_steel, col_turret)
muzzle_ring.rotation_euler = (BARREL_TILT, 0, 0)
muzzle_ring.location       = (0, 0, 4.80)

# ─────────────────────────────────────────────────────────────────────────────
# 8. TURRET — GLOW ENERGY LINES ON BARREL (orange neon)
#
#   Three glow rings spaced along the barrel length.
#   These should be set to Neon material in Roblox.
# ─────────────────────────────────────────────────────────────────────────────
glow_positions = [-0.90, 0.00, 0.90]  # local Z offsets along barrel
for i, gz in enumerate(glow_positions):
    glow_ring = make_ring(f"Barrel_GlowRing_{i}",
                          0, 0, gz, 0.70, 0.62, 0.12, 12,
                          mat_glow, col_turret)
    glow_ring.rotation_euler = (BARREL_TILT, 0, 0)
    glow_ring.location       = (0, 0, 4.80)

# ─────────────────────────────────────────────────────────────────────────────
# 9. TURRET — ELEVATION PISTON (mechanical recoil / elevation adjuster)
#
#   A hydraulic piston connecting the cradle base to the barrel underside.
#   Anchored to Cradle_Base at one end, to barrel at the other.
#
#   Piston runs from (0, 0.6, 3.0) → (0, 0.6, 5.5) approximately,
#   tilted slightly to follow barrel angle.
# ─────────────────────────────────────────────────────────────────────────────
PISTON_TILT = math.radians(40)  # slightly less than barrel tilt

# Outer piston housing
piston_outer = make_cyl("Piston_Outer", 0, 0, 0, 0.18, 2.50, 8, mat_steel, col_turret)
piston_outer.rotation_euler = (PISTON_TILT, 0, 0)
piston_outer.location       = (0, 0.70, 3.60)

# Inner piston rod
piston_inner = make_cyl("Piston_Inner", 0, 0, 0.40, 0.10, 2.00, 6, mat_iron, col_turret)
piston_inner.rotation_euler = (PISTON_TILT, 0, 0)
piston_inner.location       = (0, 0.70, 3.60)

# Piston mount bracket at cradle base
make_box("Piston_MountLow", 0, 0.70, 3.00, 0.40, 0.25, 0.40, mat_iron, col_turret)

# Piston mount bracket at barrel
piston_mount_hi = make_box("Piston_MountHi", 0, 0.70, 5.20, 0.30, 0.25, 0.30, mat_iron, col_turret)

# ─────────────────────────────────────────────────────────────────────────────
# 10. TURRET — ADDITIONAL DETAILS
# ─────────────────────────────────────────────────────────────────────────────

# Ammo box — sits on cradle base, side detail
make_box("Ammo_Box", -1.00, 0, 2.85, 0.80, 1.20, 0.60, mat_olive, col_turret)
make_box("Ammo_BoxLid", -1.00, 0, 3.20, 0.85, 1.25, 0.08, mat_iron, col_turret)

# Small control panel / sight on right cradle arm
make_box("Sight_Box",  0.45, -1.05, 5.00, 0.30, 0.20, 0.50, mat_iron, col_turret)
make_sphere("Sight_Lens", 0.45, -1.20, 5.15, 0.10, mat_glow, col_turret)

# ─────────────────────────────────────────────────────────────────────────────
# 11. CAMERA & LIGHTS (preview scene)
# ─────────────────────────────────────────────────────────────────────────────
cam_data = bpy.data.cameras.new("Camera")
cam_obj  = bpy.data.objects.new("Camera", cam_data)
scene.collection.objects.link(cam_obj)
scene.camera = cam_obj
cam_obj.location       = (12, -12, 8)
cam_obj.rotation_euler = (math.radians(68), 0, math.radians(45))

sun        = bpy.data.lights.new("Sun", 'SUN')
sun.energy = 3.0
sun_obj    = bpy.data.objects.new("Sun", sun)
scene.collection.objects.link(sun_obj)
sun_obj.location       = (8, -4, 20)
sun_obj.rotation_euler = (math.radians(40), 0, math.radians(30))

neon        = bpy.data.lights.new("NeonFill", 'POINT')
neon.energy = 80
neon.color  = (1.0, 0.55, 0.05)
neon_obj    = bpy.data.objects.new("NeonFill", neon)
scene.collection.objects.link(neon_obj)
neon_obj.location = (0, 0, 6.0)

# ─────────────────────────────────────────────────────────────────────────────
# 12. CLEAN UP MESH (triangulate + recalculate normals)
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
print(f"[Mortar] Total tris: {total_tris} / 2500 budget")

# ─────────────────────────────────────────────────────────────────────────────
# 13. SAVE .blend + EXPORT .fbx
# ─────────────────────────────────────────────────────────────────────────────
BASE_DIR = r"F:/Documents/coding/tugas_semester-4/Computer-Graphic/lumina-defense/assets/3d/mortar/"
os.makedirs(BASE_DIR, exist_ok=True)

bpy.ops.wm.save_as_mainfile(filepath=BASE_DIR + "Mortar_Roblox.blend")

bpy.ops.export_scene.fbx(
    filepath            = BASE_DIR + "Mortar_Roblox.fbx",
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

print("[Mortar] Build complete — .blend and .fbx saved to:", BASE_DIR)

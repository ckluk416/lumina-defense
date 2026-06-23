"""
============================================================
  Lumina Defense — Mortar Builder v2 (Radially Symmetric)
  Run this script in Blender's Script Editor (Run Script)
  Output: Mortar_Roblox.blend + Mortar_Roblox.fbx
============================================================

  Variant: Fully radially symmetric from top-down view.
  The mortar does NOT rotate in-game, so it must look
  identical from every horizontal angle.

  Design concept:
    - Octagonal armoured base platform with concentric rings
    - 4 symmetric hydraulic legs at 90° intervals
    - Central pedestal housing a vertical mortar tube
    - Barrel points straight up (pure vertical launch)
    - Ring-shaped barrel shroud with symmetric glow channels
    - 4 symmetric ammo feed rails connecting base to barrel
    - All detail elements placed in radial 4-fold symmetry

  Spec (from asset-spec.md):
    Dimensi   : 8 × 8 × 10 studs
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

# Military steel grey — main body
mat_steel    = new_mat("MAT_Steel",    (0.38, 0.40, 0.42), roughness=0.45)
# Olive drab — barrel / accent
mat_olive    = new_mat("MAT_Olive",    (0.28, 0.30, 0.18), roughness=0.65)
# Dark iron — mechanical parts
mat_iron     = new_mat("MAT_Iron",     (0.22, 0.22, 0.24), roughness=0.55)
# Hazard yellow
mat_hazard_y = new_mat("MAT_HazardY",  (0.85, 0.72, 0.10), roughness=0.70)
# Hazard black
mat_hazard_k = new_mat("MAT_HazardK",  (0.06, 0.06, 0.06), roughness=0.70)
# Orange energy glow — Neon in Roblox
mat_glow     = new_mat("MAT_Glow",     (0.95, 0.45, 0.05),
                        emission=(1.0, 0.55, 0.05), emission_str=6.0)
# Subtle amber indicator lights
mat_amber    = new_mat("MAT_Amber",    (0.90, 0.60, 0.10),
                        emission=(1.0, 0.70, 0.15), emission_str=4.0)

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
# 4. BASE — LAYERED CIRCULAR PLATFORM (radially symmetric)
#
#   Footprint: 8 × 8 studs (radius ~4.0)
#   Height budget for base: 0 → 3.0 studs
#
#   Layer 0  z: 0.00 → 0.30   Ground plate (wide, thin disc)  r=4.0
#   Layer 1  z: 0.30 → 1.00   Main armoured platform          r=3.6
#   Layer 2  z: 1.00 → 1.60   Stepped inner ring              r=2.8
#   Layer 3  z: 1.60 → 2.20   Central pedestal                r=1.8
#   Layer 4  z: 2.20 → 2.60   Turret mount collar             r=1.4
# ─────────────────────────────────────────────────────────────────────────────

# Ground plate — wide thin disc anchoring to terrain
make_cyl("Base_GroundPlate", 0, 0, 0.15, 4.00, 0.30, 16, mat_iron, col_base)

# Main armoured platform
make_cyl("Base_MainPlatform", 0, 0, 0.65, 3.60, 0.70, 16, mat_steel, col_base)

# Outer reinforcement ring flush with platform
make_ring("Base_OuterRing", 0, 0, 0.65, 3.80, 3.50, 0.70, 16, mat_iron, col_base)

# Hazard stripe segments — 8 evenly spaced on outer edge (4-fold + mirror)
for i in range(8):
    angle = (2 * math.pi / 8) * i
    stripe_mat = mat_hazard_y if i % 2 == 0 else mat_hazard_k
    hx = math.cos(angle) * 3.70
    hy = math.sin(angle) * 3.70
    make_box(f"Base_Hazard_{i}",
             hx, hy, 0.65,
             0.65, 0.22, 0.50,
             stripe_mat, col_base,
             rz=angle)

# Stepped inner ring
make_cyl("Base_InnerStep", 0, 0, 1.30, 2.80, 0.60, 14, mat_steel, col_base)

# Decorative glow ring between layers
make_ring("Base_GlowRing0", 0, 0, 1.02, 3.00, 2.75, 0.10, 16, mat_glow, col_base)

# Central pedestal
make_cyl("Base_Pedestal", 0, 0, 1.90, 1.80, 0.60, 12, mat_iron, col_base)

# Turret mount collar — sits on top of pedestal
make_cyl("Base_MountCollar", 0, 0, 2.40, 1.40, 0.40, 12, mat_steel, col_base)

# Glow ring at mount collar
make_ring("Base_GlowRing1", 0, 0, 2.22, 1.55, 1.35, 0.08, 12, mat_glow, col_base)

# ─────────────────────────────────────────────────────────────────────────────
# 5. BASE — STABILISER LEGS (4 legs at 90° — perfect 4-fold symmetry)
#
#   Each leg extends radially from the platform edge to the ground plate.
#   Components per leg: angled brace, hydraulic damper, foot anchor.
#   All touching the platform — no floating parts.
# ─────────────────────────────────────────────────────────────────────────────
NUM_LEGS = 4
for i in range(NUM_LEGS):
    angle = (2 * math.pi / NUM_LEGS) * i + math.radians(45)  # 45° offset = legs at diagonals
    cos_a = math.cos(angle)
    sin_a = math.sin(angle)

    # Angled brace — connects inner step to ground plate edge
    # Runs from (r=2.0, z=1.0) to (r=3.5, z=0.15) approximately
    brace_cx = cos_a * 2.75
    brace_cy = sin_a * 2.75
    brace_len = math.sqrt((1.5)**2 + (0.85)**2)  # radial + vertical span
    brace_tilt = math.atan2(0.85, 1.5)  # tilt angle

    # Decompose tilt into the radial direction
    make_box(f"Leg_Brace_{i}",
             brace_cx, brace_cy, 0.58,
             0.40, 0.40, brace_len,
             mat_iron, col_base,
             # Tilt outward along radial direction
             rx=brace_tilt * (-sin_a),
             ry=brace_tilt * (cos_a))

    # Hydraulic damper cylinder — vertical, on outer edge
    damper_x = cos_a * 3.40
    damper_y = sin_a * 3.40
    make_cyl(f"Leg_DamperOuter_{i}",
             damper_x, damper_y, 0.40,
             0.22, 0.50, 8,
             mat_steel, col_base)
    make_cyl(f"Leg_DamperInner_{i}",
             damper_x, damper_y, 0.50,
             0.12, 0.70, 6,
             mat_olive, col_base)

    # Foot anchor — flat pad at ground
    foot_x = cos_a * 3.40
    foot_y = sin_a * 3.40
    make_cyl(f"Leg_FootPad_{i}",
             foot_x, foot_y, 0.08,
             0.50, 0.16, 8,
             mat_iron, col_base)

    # Small glow indicator on each leg
    make_sphere(f"Leg_Indicator_{i}",
                cos_a * 3.10, sin_a * 3.10, 1.05,
                0.10, mat_amber, col_base)

# ─────────────────────────────────────────────────────────────────────────────
# 6. TURRET — VERTICAL MORTAR TUBE (barrel pointing straight up)
#
#   Since the mortar is static and must be symmetric from all sides,
#   the barrel faces perfectly vertical (Z-up). No tilt = no asymmetry.
#
#   Barrel bottom sits on mount collar (z=2.60).
#   Barrel top (muzzle) reaches z≈9.0, within the 10-stud height budget.
#
#   BarrelOuter   z: 2.60 → 9.00   main tube         r=0.80
#   BarrelInner   z: 7.50 → 9.20   muzzle bore       r=0.55 (visible hollow)
#   Shroud        z: 2.60 → 4.50   reinforced base    r=1.10 (tapered)
# ─────────────────────────────────────────────────────────────────────────────

# Main barrel tube — vertical cylinder
BARREL_BOT = 2.60
BARREL_TOP = 9.00
BARREL_MID = (BARREL_BOT + BARREL_TOP) / 2  # 5.80
BARREL_H   = BARREL_TOP - BARREL_BOT        # 6.40
make_cyl("Barrel_Main", 0, 0, BARREL_MID, 0.80, BARREL_H, 14, mat_olive, col_turret)

# Muzzle opening — slightly wider flared ring at top
make_ring("Barrel_MuzzleFlare", 0, 0, 8.85, 0.95, 0.70, 0.30, 14, mat_steel, col_turret)

# Barrel base shroud — tapered reinforcement connecting barrel to pedestal
make_cone("Barrel_Shroud", 0, 0, 3.55, 1.30, 0.90, 1.90, 14, mat_steel, col_turret)

# Shroud base ring — flush connection to mount collar
make_ring("Barrel_ShroudRing", 0, 0, 2.65, 1.35, 1.10, 0.20, 14, mat_iron, col_turret)

# ─────────────────────────────────────────────────────────────────────────────
# 7. TURRET — GLOW ENERGY RINGS (orange neon, evenly spaced along barrel)
#
#   4 glow rings at equal intervals along the barrel.
#   All concentric with the barrel axis — perfectly symmetric.
# ─────────────────────────────────────────────────────────────────────────────
glow_z_positions = [4.80, 5.90, 7.00, 8.10]
for i, gz in enumerate(glow_z_positions):
    make_ring(f"Barrel_GlowRing_{i}",
              0, 0, gz,
              0.86, 0.76, 0.12, 14,
              mat_glow, col_turret)

# ─────────────────────────────────────────────────────────────────────────────
# 8. TURRET — REINFORCEMENT RIBS (4 vertical ribs at 90°)
#
#   Structural ribs running vertically along the barrel exterior.
#   Provides visual detail while maintaining radial symmetry.
# ─────────────────────────────────────────────────────────────────────────────
for i in range(4):
    angle = (2 * math.pi / 4) * i
    rib_x = math.cos(angle) * 0.85
    rib_y = math.sin(angle) * 0.85
    # Each rib: thin tall box running from shroud top to near muzzle
    make_box(f"Barrel_Rib_{i}",
             rib_x, rib_y, 5.80,
             0.14, 0.14, 4.60,
             mat_iron, col_turret,
             rz=angle)

# ─────────────────────────────────────────────────────────────────────────────
# 9. TURRET — AMMO FEED RAILS (4 symmetric, connecting base to shroud)
#
#   Diagonal box beams from inner step edge to the barrel shroud.
#   These represent ammunition / energy feed channels.
# ─────────────────────────────────────────────────────────────────────────────
for i in range(4):
    angle = (2 * math.pi / 4) * i + math.radians(45)  # offset 45° from ribs
    cos_a = math.cos(angle)
    sin_a = math.sin(angle)

    # Feed rail — angled beam from (r=2.2, z=1.6) up to (r=1.1, z=3.5)
    rail_cx = cos_a * 1.65
    rail_cy = sin_a * 1.65
    rail_cz = 2.55
    rail_len = math.sqrt((1.1)**2 + (1.9)**2)
    rail_tilt = math.atan2(1.1, 1.9)  # horizontal offset / vertical rise

    make_box(f"Feed_Rail_{i}",
             rail_cx, rail_cy, rail_cz,
             0.22, 0.22, rail_len,
             mat_iron, col_turret,
             rx=rail_tilt * (-sin_a),
             ry=rail_tilt * (cos_a))

    # Glow dot at feed rail connection point on shroud
    make_sphere(f"Feed_GlowDot_{i}",
                cos_a * 1.15, sin_a * 1.15, 3.40,
                0.10, mat_glow, col_turret)

# ─────────────────────────────────────────────────────────────────────────────
# 10. TURRET — MUZZLE BRAKE / DEFLECTOR FINS (4 symmetric)
#
#   Small angled plates at the muzzle to deflect blast gases.
#   Purely decorative but adds military character.
# ─────────────────────────────────────────────────────────────────────────────
for i in range(4):
    angle = (2 * math.pi / 4) * i
    fin_x = math.cos(angle) * 1.05
    fin_y = math.sin(angle) * 1.05
    make_box(f"Muzzle_Fin_{i}",
             fin_x, fin_y, 8.75,
             0.04, 0.45, 0.50,
             mat_steel, col_turret,
             rz=angle)

# ─────────────────────────────────────────────────────────────────────────────
# 11. BASE — AMMO CRATE DETAILS (4 symmetric, tucked between legs)
#
#   Small ammo crates sitting on the main platform between each leg.
#   Positioned at 90° intervals, offset 0° from legs to sit between them.
# ─────────────────────────────────────────────────────────────────────────────
for i in range(4):
    angle = (2 * math.pi / 4) * i  # 0°, 90°, 180°, 270° (between 45° legs)
    crate_x = math.cos(angle) * 2.50
    crate_y = math.sin(angle) * 2.50

    make_box(f"Ammo_Crate_{i}",
             crate_x, crate_y, 1.25,
             0.70, 0.50, 0.50,
             mat_olive, col_base,
             rz=angle)
    make_box(f"Ammo_CrateLid_{i}",
             crate_x, crate_y, 1.54,
             0.75, 0.55, 0.08,
             mat_iron, col_base,
             rz=angle)

# ─────────────────────────────────────────────────────────────────────────────
# 12. CAMERA & LIGHTS (preview scene)
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
neon.energy = 100
neon.color  = (1.0, 0.55, 0.05)
neon_obj    = bpy.data.objects.new("NeonFill", neon)
scene.collection.objects.link(neon_obj)
neon_obj.location = (0, 0, 6.5)

# Secondary fill from below to highlight base details
neon2        = bpy.data.lights.new("NeonFill2", 'POINT')
neon2.energy = 40
neon2.color  = (1.0, 0.70, 0.20)
neon2_obj    = bpy.data.objects.new("NeonFill2", neon2)
scene.collection.objects.link(neon2_obj)
neon2_obj.location = (0, 0, 1.5)

# ─────────────────────────────────────────────────────────────────────────────
# 13. CLEAN UP MESH (triangulate + recalculate normals)
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
print(f"[Mortar v2] Total tris: {total_tris} / 2500 budget")

# ─────────────────────────────────────────────────────────────────────────────
# 14. SAVE .blend + EXPORT .fbx
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

print("[Mortar v2] Build complete — .blend and .fbx saved to:", BASE_DIR)

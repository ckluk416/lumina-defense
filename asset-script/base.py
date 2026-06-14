"""
╔══════════════════════════════════════════════════════════════════════════════╗
║        LUMINA DEFENSE — Markas Utama / Base (Futuristic + Magic Core)      ║
║        Blender Python Script  |  Target: Roblox Studio via Rojo            ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  Spesifikasi (asset-spec.md):                                               ║
║    • Dimensi     : 12 × 12 × 16 studs  (1 m Blender = 1 stud Roblox)      ║
║    • Pivot       : Bottom-center pada (0, 0, 0)                             ║
║    • Komponen    : Base Platform + 3 Generator Pillars + Core Kristal       ║
║    • Warna Neon  : Biru Cyan (energi aman)                                  ║
║    • Output FBX  : F:/.../assets/3d/base/Base_Roblox.fbx                   ║
║                                                                              ║
║  Cara pakai:                                                                 ║
║    Buka Blender → Text Editor → Open script ini → Run Script (Alt+R)        ║
║    Atau via CLI:                                                             ║
║      blender --background --python base_crystal_core.py                    ║
╚══════════════════════════════════════════════════════════════════════════════╝
"""

import bpy
import math
import os
import mathutils

# ─────────────────────────────────────────────────────────────────────────────
#  KONFIGURASI
# ─────────────────────────────────────────────────────────────────────────────
OUTPUT_DIR    = r"F:\Documents\coding\tugas_semester-4\Computer-Graphic\lumina-defense\assets\3d\base"
FBX_FILENAME  = "Base_Roblox.fbx"
BLEND_FILENAME = "Base_Roblox.blend"

# Posisi Z center core kristal melayang (dalam stud/meter)
CORE_Z        = 10.50
# Radius orbit 3 generator dari titik pusat
GEN_ORBIT_R   = 2.80


# ─────────────────────────────────────────────────────────────────────────────
#  UTILITY
# ─────────────────────────────────────────────────────────────────────────────

def clear_scene():
    """Hapus semua object, mesh, material, dan light."""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    for blk in bpy.data.meshes:     bpy.data.meshes.remove(blk)
    for blk in bpy.data.materials:  bpy.data.materials.remove(blk)
    for blk in bpy.data.lights:     bpy.data.lights.remove(blk)


def set_units():
    """Metric, scale 1.0 → 1 m = 1 stud."""
    bpy.context.scene.unit_settings.system      = 'METRIC'
    bpy.context.scene.unit_settings.scale_length = 1.0


def make_material(name, base_color,
                  emission_color=None, emission_strength=0.0,
                  metallic=0.0, roughness=0.2, transmission=0.0):
    """Buat Principled BSDF material."""
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value  = (*base_color, 1.0)
    bsdf.inputs["Metallic"].default_value    = metallic
    bsdf.inputs["Roughness"].default_value   = roughness
    if transmission > 0.0:
        bsdf.inputs["Transmission Weight"].default_value = transmission
        mat.blend_method = 'BLEND'
    if emission_color and emission_strength > 0.0:
        bsdf.inputs["Emission Color"].default_value    = (*emission_color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


def asgn(obj, mat):
    """Assign material ke objek."""
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def apply_transforms(obj, loc=False, rot=True, scl=True):
    """Apply transform pada objek."""
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=loc, rotation=rot, scale=scl)


def orient_cylinder_to_vector(obj, start, end):
    """
    Arahkan cylinder agar sumbu Z-nya mengarah dari start ke end.
    Dipakai untuk arc beam generator → core.
    """
    dx = end[0] - start[0]
    dy = end[1] - start[1]
    dz = end[2] - start[2]
    dv   = mathutils.Vector((dx, dy, dz)).normalized()
    up   = mathutils.Vector((0, 0, 1))
    quat = up.rotation_difference(dv)
    obj.rotation_mode       = 'QUATERNION'
    obj.rotation_quaternion = quat


def set_bottom_center_origin():
    """
    Geser semua mesh agar bagian paling bawah tepat di z=0
    lalu apply location — sesuai spek pivot bottom-center.
    """
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    if not meshes:
        return

    # Hitung z minimum dari semua vertex di world space
    min_z = min(
        (obj.matrix_world @ v.co).z
        for obj in meshes
        for v in obj.data.vertices
    )

    # Geser semua objek ke atas
    for obj in meshes:
        obj.location.z -= min_z

    # Apply location
    for obj in meshes:
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)


# ─────────────────────────────────────────────────────────────────────────────
#  MATERIALS
# ─────────────────────────────────────────────────────────────────────────────

def create_materials():
    """
    Semua material dengan palette Cyan / Blue Neon.
    Material ber-emission = kandidat Neon di Roblox.
    """
    M = {}

    # ── Logam struktural ──────────────────────────────────────────────────────
    M["titanium"]     = make_material(
        "M_Titanium",    (0.30, 0.32, 0.35), metallic=0.95, roughness=0.25)
    M["dark_metal"]   = make_material(
        "M_DarkMetal",   (0.10, 0.11, 0.13), metallic=0.90, roughness=0.40)
    M["panel"]        = make_material(
        "M_Panel",       (0.20, 0.22, 0.26), metallic=0.80, roughness=0.35)

    # ── Aksen hazard (kuning, tepi platform) ──────────────────────────────────
    M["hazard"]       = make_material(
        "M_Hazard",      (0.85, 0.72, 0.10), metallic=0.0,  roughness=0.50)

    # ── Cyan glow — intensity sedang (ring groove, neon band) ─────────────────
    # → set Neon di Roblox
    M["cyan_glow"]    = make_material(
        "M_CyanGlow",    (0.20, 0.95, 1.00),
        emission_color=(0.05, 0.90, 1.0), emission_strength=10.0, roughness=0.05)

    # ── Cyan kuat — arc beam, levitation beam, kernel ─────────────────────────
    # → set Neon di Roblox
    M["cyan_strong"]  = make_material(
        "M_CyanStrong",  (0.10, 0.80, 1.00),
        emission_color=(0.0,  0.80, 1.0), emission_strength=16.0, roughness=0.03)

    # ── Core kristal melayang (transparan + emisi kuat) ───────────────────────
    # → set Neon + Transparency di Roblox
    M["crystal_core"] = make_material(
        "M_CrystalCore", (0.55, 0.95, 1.00),
        emission_color=(0.10, 0.92, 1.0), emission_strength=18.0,
        transmission=0.60, roughness=0.03)

    # ── Kristal dim — shard orbit, crown spike ────────────────────────────────
    # → set Neon redup di Roblox
    M["crystal_dim"]  = make_material(
        "M_CrystalDim",  (0.40, 0.80, 0.95),
        emission_color=(0.05, 0.75, 0.95), emission_strength=4.0,
        transmission=0.50, roughness=0.05)

    # ── Glass biru — outer shell core ────────────────────────────────────────
    # → set Transparency ~0.5 di Roblox
    M["glass_blue"]   = make_material(
        "M_GlassBlue",   (0.60, 0.90, 1.00),
        transmission=0.82, roughness=0.02)

    # ── Rune cyan — panel ukiran, vein ────────────────────────────────────────
    # → set Neon di Roblox
    M["rune_cyan"]    = make_material(
        "M_RuneCyan",    (0.30, 1.00, 1.00),
        emission_color=(0.10, 1.0, 1.0), emission_strength=8.0, roughness=0.02)

    return M


# ─────────────────────────────────────────────────────────────────────────────
#  PART 1 — BASE PLATFORM  (12×12 stud, logam futuristik)
# ─────────────────────────────────────────────────────────────────────────────

def build_platform(M):
    """
    Platform 3 lapisan bertingkat dengan neon ring, rune panel,
    hex bolt, dan hazard ring di tepi.
    Footprint diameter ~12 stud, tinggi ~1.3 stud.
    """

    # ── Lapisan 1 — hex disc terbawah ─────────────────────────────────────────
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12, radius=5.80, depth=0.40, location=(0, 0, 0.20))
    obj = bpy.context.active_object; obj.name = "Platform_BaseDisk"
    asgn(obj, M["dark_metal"])

    # ── Lapisan 2 — mid disc ──────────────────────────────────────────────────
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12, radius=5.00, depth=0.35, location=(0, 0, 0.57))
    obj = bpy.context.active_object; obj.name = "Platform_MidDisk"
    asgn(obj, M["titanium"])

    # ── Lapisan 3 — landing pad atas ─────────────────────────────────────────
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12, radius=4.20, depth=0.50, location=(0, 0, 0.99))
    obj = bpy.context.active_object; obj.name = "Platform_TopDisk"
    asgn(obj, M["panel"])

    # ── Neon ring groove tepi luar ────────────────────────────────────────────
    bpy.ops.mesh.primitive_torus_add(
        major_radius=3.90, minor_radius=0.10, location=(0, 0, 1.25))
    obj = bpy.context.active_object; obj.name = "Platform_OuterNeonRing"
    asgn(obj, M["cyan_glow"])

    # ── Neon ring groove dalam ────────────────────────────────────────────────
    bpy.ops.mesh.primitive_torus_add(
        major_radius=2.60, minor_radius=0.07, location=(0, 0, 1.25))
    obj = bpy.context.active_object; obj.name = "Platform_InnerNeonRing"
    asgn(obj, M["cyan_glow"])

    # ── 6 rune panel menyala di permukaan ────────────────────────────────────
    for i in range(6):
        a = math.radians(i * 60)
        bpy.ops.mesh.primitive_cube_add(
            location=(math.cos(a) * 2.80, math.sin(a) * 2.80, 1.27))
        obj = bpy.context.active_object; obj.name = f"Platform_RunePanel_{i}"
        obj.scale = (0.55, 0.22, 0.04)
        obj.rotation_euler = (0, 0, a)
        apply_transforms(obj, rot=True, scl=True)
        asgn(obj, M["rune_cyan"])

    # ── 12 hex bolt di lingkar platform ──────────────────────────────────────
    for i in range(12):
        a = math.radians(i * 30)
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=6, radius=0.12, depth=0.22,
            location=(math.cos(a) * 4.55, math.sin(a) * 4.55, 0.72))
        obj = bpy.context.active_object; obj.name = f"Platform_Bolt_{i}"
        asgn(obj, M["dark_metal"])

    # ── Hazard ring kuning di tepi terluar ────────────────────────────────────
    bpy.ops.mesh.primitive_torus_add(
        major_radius=4.60, minor_radius=0.14, location=(0, 0, 0.48))
    obj = bpy.context.active_object; obj.name = "Platform_HazardRing"
    asgn(obj, M["hazard"])


# ─────────────────────────────────────────────────────────────────────────────
#  PART 2 — 3 GENERATOR PILLARS
# ─────────────────────────────────────────────────────────────────────────────

def build_generators(M):
    """
    Tiga tiang generator pada orbit radius GEN_ORBIT_R,
    masing-masing dengan collar, neon band, emitter head,
    crystal tip, dan arc beam ke core.
    Tinggi tiang ~7.5 stud, dasar tiang di z=1.24.
    """
    GEN_Z0 = 1.24   # dasar tiang di atas platform

    for i in range(3):
        a  = math.radians(i * 120)
        cx = math.cos(a) * GEN_ORBIT_R
        cy = math.sin(a) * GEN_ORBIT_R

        # ── Batang utama oktagonal ────────────────────────────────────────────
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=8, radius=0.40, depth=7.50,
            location=(cx, cy, GEN_Z0 + 3.75))
        obj = bpy.context.active_object; obj.name = f"Gen_{i}_Pillar"
        asgn(obj, M["titanium"])

        # ── Collar bawah ──────────────────────────────────────────────────────
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=8, radius=0.58, depth=0.40,
            location=(cx, cy, GEN_Z0 + 0.20))
        obj = bpy.context.active_object; obj.name = f"Gen_{i}_CollarBot"
        asgn(obj, M["dark_metal"])

        # ── Collar atas ───────────────────────────────────────────────────────
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=8, radius=0.58, depth=0.40,
            location=(cx, cy, GEN_Z0 + 7.10))
        obj = bpy.context.active_object; obj.name = f"Gen_{i}_CollarTop"
        asgn(obj, M["dark_metal"])

        # ── 3 neon band di sepanjang tiang ────────────────────────────────────
        for j, band_z in enumerate([GEN_Z0 + 2.0, GEN_Z0 + 4.0, GEN_Z0 + 6.0]):
            bpy.ops.mesh.primitive_torus_add(
                major_radius=0.45, minor_radius=0.055,
                location=(cx, cy, band_z))
            obj = bpy.context.active_object; obj.name = f"Gen_{i}_Band_{j}"
            asgn(obj, M["cyan_glow"])

        # ── Emitter head kerucut di puncak ────────────────────────────────────
        bpy.ops.mesh.primitive_cone_add(
            vertices=8, radius1=0.50, radius2=0.10, depth=0.70,
            location=(cx, cy, GEN_Z0 + 7.85))
        obj = bpy.context.active_object; obj.name = f"Gen_{i}_EmitterHead"
        asgn(obj, M["panel"])

        # ── Crystal tip di ujung emitter ──────────────────────────────────────
        bpy.ops.mesh.primitive_cone_add(
            vertices=6, radius1=0.18, radius2=0.01, depth=0.45,
            location=(cx, cy, GEN_Z0 + 8.42))
        obj = bpy.context.active_object; obj.name = f"Gen_{i}_CrystalTip"
        asgn(obj, M["crystal_core"])

        # ── Arc beam — dari crystal tip ke core ───────────────────────────────
        emit_pos = (cx, cy, GEN_Z0 + 8.65)
        core_pos = (0.0, 0.0, CORE_Z)
        mid      = (
            (emit_pos[0] + core_pos[0]) / 2,
            (emit_pos[1] + core_pos[1]) / 2,
            (emit_pos[2] + core_pos[2]) / 2,
        )
        dx  = core_pos[0] - emit_pos[0]
        dy  = core_pos[1] - emit_pos[1]
        dz  = core_pos[2] - emit_pos[2]
        length = math.sqrt(dx**2 + dy**2 + dz**2)

        bpy.ops.mesh.primitive_cylinder_add(
            vertices=6, radius=0.055, depth=length, location=mid)
        beam = bpy.context.active_object; beam.name = f"Gen_{i}_ArcBeam"
        orient_cylinder_to_vector(beam, emit_pos, core_pos)
        apply_transforms(beam, rot=True, scl=False)
        asgn(beam, M["cyan_strong"])

    # ── Cincin horizontal penghubung antar generator (2 ketinggian) ───────────
    for ring_z, ring_name in [(5.20, "Gen_ConnectRing_Low"), (7.60, "Gen_ConnectRing_High")]:
        bpy.ops.mesh.primitive_torus_add(
            major_radius=GEN_ORBIT_R + 0.05, minor_radius=0.07,
            location=(0, 0, ring_z))
        obj = bpy.context.active_object; obj.name = ring_name
        asgn(obj, M["cyan_glow"])

    # ── Buttress diagonal dari tepi platform ke kaki tiap generator ───────────
    for i in range(3):
        a  = math.radians(i * 120)
        cx = math.cos(a) * GEN_ORBIT_R
        cy = math.sin(a) * GEN_ORBIT_R
        ex = math.cos(a) * 4.20
        ey = math.sin(a) * 4.20
        mx = (cx + ex) / 2
        my = (cy + ey) / 2
        dx = ex - cx; dy_b = ey - cy
        length = math.sqrt(dx**2 + dy_b**2)

        bpy.ops.mesh.primitive_cylinder_add(
            vertices=6, radius=0.12, depth=length,
            location=(mx, my, 0.90))
        bt = bpy.context.active_object; bt.name = f"Buttress_{i}"
        bt.rotation_euler = (math.radians(90), 0, math.atan2(dy_b, dx))
        apply_transforms(bt, rot=True, scl=False)
        asgn(bt, M["dark_metal"])


# ─────────────────────────────────────────────────────────────────────────────
#  PART 3 — CORE KRISTAL MELAYANG
# ─────────────────────────────────────────────────────────────────────────────

def build_core(M):
    """
    Core kristal melayang di z=CORE_Z.
    Terdiri dari: glass shell, bevelled crystal, kernel, 3 orbital ring,
    8 orbit shard, levitation beam, dan crown ring + 6 spike.
    """

    # ── Outer glass shell ─────────────────────────────────────────────────────
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=24, ring_count=16, radius=1.80, location=(0, 0, CORE_Z))
    obj = bpy.context.active_object; obj.name = "Core_GlassShell"
    asgn(obj, M["glass_blue"])

    # ── Kristal utama (bevelled cube effect via ico sphere) ───────────────────
    bpy.ops.mesh.primitive_ico_sphere_add(
        subdivisions=3, radius=1.30, location=(0, 0, CORE_Z))
    obj = bpy.context.active_object; obj.name = "Core_Crystal"
    obj.scale = (1.0, 1.0, 1.15)
    apply_transforms(obj, rot=False, scl=True)
    asgn(obj, M["crystal_core"])

    # ── Inner kernel — titik paling terang ───────────────────────────────────
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=12, ring_count=8, radius=0.60, location=(0, 0, CORE_Z))
    obj = bpy.context.active_object; obj.name = "Core_Kernel"
    asgn(obj, M["cyan_strong"])

    # ── 3 cincin orbital di kemiringan berbeda ─────────────────────────────────
    ring_configs = [
        (0.0,               0.0,              2.10, 0.080),  # ekuatorial
        (math.radians(60),  0.0,              1.95, 0.065),  # tilt 60°
        (math.radians(60),  math.radians(90), 1.95, 0.065),  # cross-tilt 90°
    ]
    for idx, (rx, rz, major, minor) in enumerate(ring_configs):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=major, minor_radius=minor, location=(0, 0, CORE_Z))
        obj = bpy.context.active_object; obj.name = f"Core_OrbitalRing_{idx}"
        obj.rotation_euler = (rx, 0, rz)
        asgn(obj, M["cyan_glow"])

    # ── 8 orbit shard kristal di ekuator bola ─────────────────────────────────
    for i in range(8):
        a = math.radians(i * 45)
        bpy.ops.mesh.primitive_cone_add(
            vertices=4, radius1=0.10, radius2=0.005, depth=0.50,
            location=(math.cos(a) * 1.95, math.sin(a) * 1.95, CORE_Z))
        obj = bpy.context.active_object; obj.name = f"Core_OrbitShard_{i}"
        obj.rotation_euler = (math.radians(90), 0, a + math.radians(90))
        asgn(obj, M["crystal_dim"])

    # ── Levitation beam tipis dari platform ke core ───────────────────────────
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6, radius=0.07, depth=2.0, location=(0, 0, CORE_Z - 1.24))
    obj = bpy.context.active_object; obj.name = "Core_LevitationBeam"
    asgn(obj, M["cyan_strong"])

    # ── Crown ring tepat di bawah core ───────────────────────────────────────
    bpy.ops.mesh.primitive_torus_add(
        major_radius=1.50, minor_radius=0.09, location=(0, 0, CORE_Z - 2.10))
    obj = bpy.context.active_object; obj.name = "Core_CrownRing"
    asgn(obj, M["cyan_strong"])

    # ── 6 mini spike di crown ring ────────────────────────────────────────────
    for i in range(6):
        a = math.radians(i * 60)
        bpy.ops.mesh.primitive_cone_add(
            vertices=4, radius1=0.08, radius2=0.005, depth=0.38,
            location=(math.cos(a) * 1.50, math.sin(a) * 1.50, CORE_Z - 1.82))
        obj = bpy.context.active_object; obj.name = f"Crown_Spike_{i}"
        asgn(obj, M["crystal_dim"])


# ─────────────────────────────────────────────────────────────────────────────
#  PART 4 — PREVIEW LIGHTING (viewport saja, tidak di-export ke FBX)
# ─────────────────────────────────────────────────────────────────────────────

def setup_preview_lighting():
    """Setup Eevee + bloom untuk preview glow cyan di Blender."""

    light_configs = [
        ("Light_Core",  (0,   0,   CORE_Z),       3500, (0.05, 0.85, 1.0), 2.0),
        ("Light_Mid",   (0,   0,   5.0),           800,  (0.10, 0.80, 1.0), 3.0),
        ("Light_Fill",  (3,  -3,   1.5),           400,  (0.20, 0.70, 0.90), 1.5),
    ]
    for name, loc, energy, color, radius in light_configs:
        bpy.ops.object.light_add(type='POINT', location=loc)
        lamp = bpy.context.active_object
        lamp.name = name
        lamp.data.energy = energy
        lamp.data.color  = color
        lamp.data.shadow_soft_size = radius

    # Dark world background
    world = bpy.context.scene.world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.01, 0.02, 0.04, 1)
    bg.inputs[1].default_value = 0.10

    # Camera — framing model 16 stud
    bpy.ops.object.camera_add(location=(22, -22, 11))
    cam = bpy.context.active_object
    cam.name = "Preview_Camera"
    cam.rotation_euler = (1.18, 0, 0.785)
    bpy.context.scene.camera = cam

    # Eevee Next rendered mode
    bpy.context.scene.render.engine = 'BLENDER_EEVEE_NEXT'
    for area in bpy.context.screen.areas:
        if area.type == 'VIEW_3D':
            for space in area.spaces:
                if space.type == 'VIEW_3D':
                    space.shading.type = 'RENDERED'

    # Compositor bloom
    bpy.context.scene.use_nodes = True
    tree = bpy.context.scene.node_tree
    tree.nodes.clear()
    rl   = tree.nodes.new('CompositorNodeRLayers')
    gl   = tree.nodes.new('CompositorNodeGlare')
    comp = tree.nodes.new('CompositorNodeComposite')
    gl.glare_type = 'BLOOM'
    gl.threshold  = 0.50
    gl.size       = 7
    gl.mix        = 0.90
    rl.location   = (-300, 0)
    gl.location   = (0, 0)
    comp.location = (300, 0)
    tree.links.new(rl.outputs['Image'], gl.inputs['Image'])
    tree.links.new(gl.outputs['Image'], comp.inputs['Image'])


# ─────────────────────────────────────────────────────────────────────────────
#  EXPORT — FBX + .blend
# ─────────────────────────────────────────────────────────────────────────────

def export_assets(output_dir, fbx_filename, blend_filename):
    """
    1. Buat output directory
    2. Apply all transforms pada semua mesh
    3. Export FBX (Roblox-compatible settings)
    4. Save .blend
    """
    os.makedirs(output_dir, exist_ok=True)

    fbx_path   = os.path.join(output_dir, fbx_filename)
    blend_path = os.path.join(output_dir, blend_filename)

    # ── Apply scale + rotation (Ctrl+A) ──────────────────────────────────────
    bpy.ops.object.select_all(action='DESELECT')
    for obj in bpy.data.objects:
        if obj.type == 'MESH':
            obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.select_all(action='DESELECT')

    # ── Select hanya mesh untuk export ───────────────────────────────────────
    for obj in bpy.data.objects:
        if obj.type == 'MESH':
            obj.select_set(True)

    # ── Export FBX ────────────────────────────────────────────────────────────
    bpy.ops.export_scene.fbx(
        filepath            = fbx_path,

        # Scope
        use_selection       = True,
        object_types        = {'MESH'},

        # Transform — wajib untuk Roblox
        apply_scale_options = 'FBX_SCALE_ALL',   # Apply Scalings: FBX All
        axis_forward        = '-Z',
        axis_up             = 'Y',
        apply_unit_scale    = True,

        # Geometry
        mesh_smooth_type    = 'FACE',             # Smoothing: Face
        use_mesh_modifiers  = True,
        use_triangles       = False,

        # Armature
        add_leaf_bones      = False,              # Matikan Add Leaf Bones

        # Texture
        path_mode           = 'COPY',
        embed_textures      = True,

        # Misc
        use_custom_props    = True,
        bake_anim           = False,
    )

    # ── Save .blend ───────────────────────────────────────────────────────────
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)

    print(f"\n✅  FBX   → {fbx_path}")
    print(f"✅  BLEND → {blend_path}")
    print("\n── Panduan Roblox Studio ────────────────────────────────────────")
    print("  Import: Home → Import 3D → pilih Base_Roblox.fbx")
    print()
    print("  Set Material = Neon pada part:")
    print("    Core_Crystal, Core_Kernel, Core_OrbitalRing_*")
    print("    Core_LevitationBeam, Core_CrownRing, Crown_Spike_*")
    print("    Core_OrbitShard_*, Gen_*_ArcBeam, Gen_*_CrystalTip")
    print("    Gen_*_Band_*, Gen_ConnectRing_*, Platform_*NeonRing")
    print("    Platform_RunePanel_*")
    print()
    print("  Set Transparency = 0.45–0.60 pada part:")
    print("    Core_GlassShell")
    print("─────────────────────────────────────────────────────────────────")


# ─────────────────────────────────────────────────────────────────────────────
#  MAIN
# ─────────────────────────────────────────────────────────────────────────────

def main():
    print("=" * 62)
    print("  Building Base — Futuristic Platform + Magic Crystal Core")
    print("=" * 62)

    clear_scene()
    set_units()
    print("[1/7] Scene cleared, units = Metric")

    M = create_materials()
    print(f"[2/7] {len(M)} materials created")

    build_platform(M)
    print("[3/7] Base platform built")

    build_generators(M)
    print("[4/7] 3 generator pillars built")

    build_core(M)
    print("[5/7] Floating crystal core built")

    set_bottom_center_origin()
    print("[6/7] Pivot set to bottom-center (0, 0, 0)")

    setup_preview_lighting()
    print("[6/7] Preview lighting + Eevee bloom configured")

    print("[7/7] Exporting FBX + saving .blend ...")
    export_assets(OUTPUT_DIR, FBX_FILENAME, BLEND_FILENAME)

    print("\n✨  Done! Base_Roblox siap diimport ke Roblox Studio.")
    print(f"    Direktori: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
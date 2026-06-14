"""
╔══════════════════════════════════════════════════════════════════════════════╗
║          LUMINA DEFENSE — Light Node (Crystal Orb Magic Variant)           ║
║          Blender Python Script  |  Target: Roblox Studio via Rojo          ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  Spesifikasi (asset-spec.md):                                               ║
║    • Dimensi     : 4 × 4 × 10 studs  (1 m Blender = 1 stud Roblox)        ║
║    • Pivot       : Bottom-center pada (0, 0, 0)                             ║
║    • Material    : Stylized PBR — Core dipisah untuk Neon di Roblox         ║
║    • Output FBX  : F:/.../assets/3d/light-node/LightNode_Roblox.fbx        ║
║                                                                              ║
║  Cara pakai:                                                                 ║
║    Buka Blender → Text Editor → Open script ini → Run Script (Alt+R)        ║
║    Atau jalankan via CLI:                                                    ║
║      blender --background --python light_node_crystal_orb.py               ║
╚══════════════════════════════════════════════════════════════════════════════╝
"""

import bpy
import math
import os

# ─────────────────────────────────────────────────────────────────────────────
#  KONFIGURASI — ubah path sesuai mesin Anda
# ─────────────────────────────────────────────────────────────────────────────
OUTPUT_DIR = r"F:\Documents\coding\tugas_semester-4\Computer-Graphic\lumina-defense\assets\3d\light-node"
FBX_FILENAME = "LightNode_Roblox.fbx"
BLEND_FILENAME = "LightNode_Roblox.blend"

# ─────────────────────────────────────────────────────────────────────────────
#  UTILITY FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────

def clear_scene():
    """Hapus semua objek, material, mesh, dan light di scene."""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    for block in bpy.data.meshes:
        bpy.data.meshes.remove(block)
    for block in bpy.data.materials:
        bpy.data.materials.remove(block)
    for block in bpy.data.lights:
        bpy.data.lights.remove(block)


def set_units():
    """Atur unit ke Metric dengan scale 1.0 (1 m = 1 stud)."""
    bpy.context.scene.unit_settings.system = 'METRIC'
    bpy.context.scene.unit_settings.scale_length = 1.0


def make_material(name, base_color,
                  emission_color=None, emission_strength=0.0,
                  metallic=0.0, roughness=0.1, transmission=0.0):
    """
    Buat material Principled BSDF.

    Parameter:
        name             : nama material (str)
        base_color       : tuple (R, G, B) dalam 0–1
        emission_color   : tuple (R, G, B) atau None
        emission_strength: float
        metallic         : float 0–1
        roughness        : float 0–1
        transmission     : float 0–1 (0 = opak, 1 = transparan penuh)
    """
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes["Principled BSDF"]

    bsdf.inputs["Base Color"].default_value    = (*base_color, 1.0)
    bsdf.inputs["Metallic"].default_value      = metallic
    bsdf.inputs["Roughness"].default_value     = roughness

    if transmission > 0.0:
        bsdf.inputs["Transmission Weight"].default_value = transmission
        mat.blend_method = 'BLEND'

    if emission_color and emission_strength > 0.0:
        bsdf.inputs["Emission Color"].default_value    = (*emission_color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength

    return mat


def assign_material(obj, mat):
    """Assign material ke objek, mengganti slot pertama."""
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def apply_transforms(obj, location=False, rotation=False, scale=True):
    """Apply transform pada objek yang dipilih."""
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=location, rotation=rotation, scale=scale)


def set_bottom_center_origin():
    """
    Atur origin semua mesh object ke bottom-center dan
    pindahkan ke (0,0,0). Sesuai spek: pivot di bawah tengah objek.
    """
    bpy.ops.object.select_all(action='DESELECT')
    for obj in bpy.data.objects:
        if obj.type == 'MESH':
            bpy.context.view_layer.objects.active = obj
            obj.select_set(True)
            bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
            obj.select_set(False)

    # Hitung bounding box seluruh scene untuk cari titik paling bawah
    all_mesh = [o for o in bpy.data.objects if o.type == 'MESH']
    if not all_mesh:
        return

    min_z = min(
        (obj.matrix_world @ v.co).z
        for obj in all_mesh
        for v in obj.data.vertices
    )

    # Geser semua objek ke atas agar bagian bawah tepat di z=0
    for obj in all_mesh:
        obj.location.z -= min_z

    # Apply location
    for obj in all_mesh:
        apply_transforms(obj, location=True, rotation=False, scale=False)


# ─────────────────────────────────────────────────────────────────────────────
#  MATERIAL DEFINITIONS  (amber / warm-yellow palette)
# ─────────────────────────────────────────────────────────────────────────────

def create_materials():
    mats = {}

    # Bola kaca luar — transparan tipis, kekuningan
    mats["orb_glass"] = make_material(
        "M_OrbGlass",
        base_color=(1.0, 0.95, 0.70),
        transmission=0.88, roughness=0.02
    )

    # Core bercahaya — amber terang (INI yang diset Neon di Roblox)
    mats["core_glow"] = make_material(
        "M_CoreGlow",
        base_color=(1.0, 0.82, 0.15),
        emission_color=(1.0, 0.78, 0.05), emission_strength=14.0,
        metallic=0.0, roughness=0.05
    )

    # Cincin energi — oranye amber (diset Neon di Roblox)
    mats["ring_glow"] = make_material(
        "M_RingGlow",
        base_color=(1.0, 0.70, 0.10),
        emission_color=(1.0, 0.65, 0.0), emission_strength=9.0,
        metallic=0.0, roughness=0.05
    )

    # Kristal shard — amber semi-transparan dengan emisi redup
    mats["crystal"] = make_material(
        "M_Crystal",
        base_color=(0.85, 0.72, 0.40),
        emission_color=(0.9, 0.65, 0.1), emission_strength=2.5,
        transmission=0.55, roughness=0.05
    )

    # Batu/logam gelap untuk platform dan stem
    mats["dark_crystal"] = make_material(
        "M_DarkCrystal",
        base_color=(0.22, 0.17, 0.08),
        metallic=0.6, roughness=0.25
    )

    # Logam kuningan untuk collar dan aksen
    mats["stem_metal"] = make_material(
        "M_StemMetal",
        base_color=(0.45, 0.32, 0.10),
        metallic=0.95, roughness=0.30
    )

    # Rune / glyph — kuning menyala (diset Neon di Roblox)
    mats["rune"] = make_material(
        "M_Rune",
        base_color=(1.0, 0.90, 0.30),
        emission_color=(1.0, 0.80, 0.0), emission_strength=7.0,
        metallic=0.0, roughness=0.05
    )

    return mats


# ─────────────────────────────────────────────────────────────────────────────
#  PART 1 — BASE PLATFORM + CRYSTAL SHARDS
# ─────────────────────────────────────────────────────────────────────────────

def build_base(mats):
    """
    Ground rock platform berbentuk icosphere gepeng dengan shard kristal
    mencuat di sekelilingnya. Dimensi footprint ~4×4 stud.
    """
    # ── Platform batu ────────────────────────────────────────────────────────
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.70, location=(0, 0, 0.28))
    ground = bpy.context.active_object
    ground.name = "Base_GroundRock"
    ground.scale = (1.0, 1.0, 0.22)
    apply_transforms(ground, scale=True)
    assign_material(ground, mats["dark_crystal"])

    # ── Outer shard ring — 6 shard besar ─────────────────────────────────────
    for i in range(6):
        angle  = math.radians(i * 60 + 15)
        radius = 1.10
        height = 1.10 + (i % 3) * 0.30      # variasi tinggi antar shard
        tilt   = math.radians(12 + (i % 2) * 8)

        bpy.ops.mesh.primitive_cone_add(
            vertices=4,
            radius1=0.22 + (i % 3) * 0.04,
            radius2=0.015,
            depth=height,
            location=(
                math.cos(angle) * radius,
                math.sin(angle) * radius,
                0.28 + height * 0.5
            )
        )
        shard = bpy.context.active_object
        shard.name = f"Shard_Outer_{i}"
        shard.rotation_euler = (
            tilt * math.cos(angle + 0.3),
            tilt * math.sin(angle + 0.3),
            angle
        )
        assign_material(shard, mats["crystal"])

    # ── Inner shard ring — 4 shard kecil ─────────────────────────────────────
    for i in range(4):
        angle  = math.radians(i * 90 + 45)
        radius = 0.60
        height = 0.65 + (i % 2) * 0.25

        bpy.ops.mesh.primitive_cone_add(
            vertices=4,
            radius1=0.13, radius2=0.01,
            depth=height,
            location=(
                math.cos(angle) * radius,
                math.sin(angle) * radius,
                0.28 + height * 0.5
            )
        )
        shard = bpy.context.active_object
        shard.name = f"Shard_Inner_{i}"
        shard.rotation_euler = (
            math.radians(8) * math.cos(angle),
            math.radians(8) * math.sin(angle),
            angle
        )
        assign_material(shard, mats["crystal"])

    # ── Rune glyph — 3 bidang datar menyala di platform ──────────────────────
    for i in range(3):
        angle = math.radians(i * 120)
        bpy.ops.mesh.primitive_plane_add(
            size=0.35,
            location=(math.cos(angle) * 0.80, math.sin(angle) * 0.80, 0.50)
        )
        rune = bpy.context.active_object
        rune.name = f"Base_Rune_{i}"
        rune.rotation_euler = (0, 0, angle + math.radians(45))
        rune.scale = (1, 0.45, 1)
        apply_transforms(rune, scale=True, rotation=True)
        assign_material(rune, mats["rune"])


# ─────────────────────────────────────────────────────────────────────────────
#  PART 2 — SEGMENTED STEM
# ─────────────────────────────────────────────────────────────────────────────

def build_stem(mats):
    """
    Tiang kristal meruncing dengan vein cahaya dan bracket shard.
    z: 0.50 → 4.80
    """
    # ── Batang utama ──────────────────────────────────────────────────────────
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=8, radius=0.28, depth=3.70, location=(0, 0, 2.35)
    )
    stem = bpy.context.active_object
    stem.name = "Stem_Main"
    assign_material(stem, mats["dark_crystal"])

    # Taper cone di ujung atas batang
    bpy.ops.mesh.primitive_cone_add(
        vertices=8, radius1=0.28, radius2=0.10, depth=0.60, location=(0, 0, 4.50)
    )
    stem_tip = bpy.context.active_object
    stem_tip.name = "Stem_Taper"
    assign_material(stem_tip, mats["dark_crystal"])

    # ── Vein cahaya — 3 strip tipis di sepanjang stem ─────────────────────────
    for i in range(3):
        angle = math.radians(i * 120)
        bpy.ops.mesh.primitive_cube_add(
            location=(math.cos(angle) * 0.26, math.sin(angle) * 0.26, 2.80)
        )
        vein = bpy.context.active_object
        vein.name = f"Stem_Vein_{i}"
        vein.scale = (0.035, 0.10, 1.60)
        vein.rotation_euler = (0, 0, angle)
        apply_transforms(vein, scale=True, rotation=True)
        assign_material(vein, mats["rune"])

    # ── Bracket crystal — 3 shard kecil mencuat di tengah stem ───────────────
    for i in range(3):
        angle = math.radians(i * 120 + 60)
        bpy.ops.mesh.primitive_cone_add(
            vertices=4, radius1=0.10, radius2=0.01, depth=0.45,
            location=(math.cos(angle) * 0.36, math.sin(angle) * 0.36, 2.20)
        )
        bracket = bpy.context.active_object
        bracket.name = f"Stem_Bracket_{i}"
        bracket.rotation_euler = (
            math.radians(75) * math.cos(angle + math.pi),
            math.radians(75) * math.sin(angle + math.pi),
            angle
        )
        assign_material(bracket, mats["crystal"])


# ─────────────────────────────────────────────────────────────────────────────
#  PART 3 — CRYSTAL ORB (melayang)
# ─────────────────────────────────────────────────────────────────────────────

def build_orb(mats, orb_z=5.55):
    """
    Crystal orb melayang dengan 3 energy ring, crown shard, dan top spike.
    Orb center di z = orb_z.
    """
    # ── Connector ethereal tipis (stem → orb) ─────────────────────────────────
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6, radius=0.055, depth=0.75, location=(0, 0, 4.80)
    )
    connector = bpy.context.active_object
    connector.name = "Orb_Connector"
    assign_material(connector, mats["rune"])

    # ── Bola kaca luar ────────────────────────────────────────────────────────
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=20, ring_count=14, radius=1.15, location=(0, 0, orb_z)
    )
    orb_outer = bpy.context.active_object
    orb_outer.name = "Orb_Glass"
    assign_material(orb_outer, mats["orb_glass"])

    # ── Core bercahaya — icosphere agar faceted ───────────────────────────────
    bpy.ops.mesh.primitive_ico_sphere_add(
        subdivisions=2, radius=0.68, location=(0, 0, orb_z)
    )
    orb_core = bpy.context.active_object
    orb_core.name = "Orb_Core"
    assign_material(orb_core, mats["core_glow"])

    # ── Kernel paling terang di inti ──────────────────────────────────────────
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=10, ring_count=8, radius=0.32, location=(0, 0, orb_z)
    )
    orb_kernel = bpy.context.active_object
    orb_kernel.name = "Orb_Kernel"
    assign_material(orb_kernel, mats["core_glow"])

    # ── 3 energy ring pada kemiringan berbeda ─────────────────────────────────
    ring_configs = [
        (0.0,               0.0,               1.28, 0.055),  # ekuatorial
        (math.radians(55),  0.0,               1.18, 0.042),  # tilt 55°
        (math.radians(55),  math.radians(70),  1.18, 0.042),  # cross-tilt
    ]
    for idx, (rx, rz, major, minor) in enumerate(ring_configs):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=major, minor_radius=minor, location=(0, 0, orb_z)
        )
        ring = bpy.context.active_object
        ring.name = f"Orb_EnergyRing_{idx}"
        ring.rotation_euler = (rx, 0, rz)
        assign_material(ring, mats["ring_glow"])

    # ── Crown shard — 6 kristal kecil di ekuator bola ────────────────────────
    for i in range(6):
        angle = math.radians(i * 60)
        bpy.ops.mesh.primitive_cone_add(
            vertices=4, radius1=0.09, radius2=0.005, depth=0.42,
            location=(math.cos(angle) * 1.22, math.sin(angle) * 1.22, orb_z + 0.05)
        )
        crown = bpy.context.active_object
        crown.name = f"Orb_Crown_{i}"
        crown.rotation_euler = (math.radians(90), 0, angle + math.radians(90))
        assign_material(crown, mats["crystal"])

    # ── Top spike utama ────────────────────────────────────────────────────────
    spike_base_z = orb_z + 1.15
    bpy.ops.mesh.primitive_cone_add(
        vertices=6, radius1=0.14, radius2=0.008, depth=0.90,
        location=(0, 0, spike_base_z + 0.45)
    )
    top_spike = bpy.context.active_object
    top_spike.name = "Orb_TopSpike"
    assign_material(top_spike, mats["crystal"])

    # Glowing tip di ujung spike
    bpy.ops.mesh.primitive_cone_add(
        vertices=6, radius1=0.06, radius2=0.002, depth=0.30,
        location=(0, 0, spike_base_z + 0.90 + 0.15)
    )
    spike_tip = bpy.context.active_object
    spike_tip.name = "Orb_SpikeTip"
    assign_material(spike_tip, mats["rune"])


# ─────────────────────────────────────────────────────────────────────────────
#  PART 4 — PREVIEW LIGHTING (untuk Blender viewport saja, tidak di-export)
# ─────────────────────────────────────────────────────────────────────────────

def setup_preview_lighting(orb_z=5.55):
    """Point lights untuk preview glow di Blender — tidak mempengaruhi FBX."""
    configs = [
        ("Light_OrbCore",  (0, 0, orb_z),        1800, (1.0, 0.82, 0.18), 1.2),
        ("Light_Fill",     (0.5, -0.5, orb_z+0.4), 400, (1.0, 0.95, 0.50), 0.8),
        ("Light_Bounce",   (0, 0, 0.40),           220, (1.0, 0.75, 0.10), 2.0),
    ]
    for name, loc, energy, color, radius in configs:
        bpy.ops.object.light_add(type='POINT', location=loc)
        lamp = bpy.context.active_object
        lamp.name = name
        lamp.data.energy = energy
        lamp.data.color  = color
        lamp.data.shadow_soft_size = radius

    # Dark ambient world
    world = bpy.context.scene.world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.03, 0.02, 0.01, 1)
    bg.inputs[1].default_value = 0.15

    # Camera framing
    bpy.ops.object.camera_add(location=(10, -10, 6.5))
    cam = bpy.context.active_object
    cam.name = "Preview_Camera"
    cam.rotation_euler = (1.18, 0, 0.785)
    bpy.context.scene.camera = cam


# ─────────────────────────────────────────────────────────────────────────────
#  EXPORT — Blender .blend + FBX ke direktori proyek
# ─────────────────────────────────────────────────────────────────────────────

def export_assets(output_dir, fbx_filename, blend_filename):
    """
    1. Buat direktori output jika belum ada
    2. Apply all transforms (scale, rotation) pada semua mesh
    3. Export FBX dengan setting Roblox-compatible
    4. Save file .blend
    """
    os.makedirs(output_dir, exist_ok=True)

    fbx_path   = os.path.join(output_dir, fbx_filename)
    blend_path = os.path.join(output_dir, blend_filename)

    # ── Step 1: Ctrl+A — Apply All Transforms ────────────────────────────────
    # Wajib sebelum export agar scale (1,1,1) dan rotation (0,0,0) di FBX
    bpy.ops.object.select_all(action='DESELECT')
    for obj in bpy.data.objects:
        if obj.type == 'MESH':
            obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.select_all(action='DESELECT')

    # ── Step 2: Pilih hanya mesh untuk export ─────────────────────────────────
    for obj in bpy.data.objects:
        if obj.type == 'MESH':
            obj.select_set(True)

    # ── Step 3: Export FBX ────────────────────────────────────────────────────
    bpy.ops.export_scene.fbx(
        filepath=fbx_path,

        # Scope
        use_selection=True,          # hanya objek yang diselect (mesh saja, bukan lamp/camera)

        # Object types
        object_types={'MESH'},

        # Transform — KRUSIAL untuk Roblox
        apply_scale_options='FBX_SCALE_ALL',   # Apply Scalings: FBX All
        axis_forward='-Z',                     # Roblox forward = -Z
        axis_up='Y',                           # Roblox up = Y
        apply_unit_scale=True,

        # Geometry
        mesh_smooth_type='FACE',               # Smoothing: Face (shadow halus di Roblox)
        use_mesh_modifiers=True,
        use_triangles=False,                   # biarkan Roblox triangulasi sendiri

        # Armature — tidak ada rig di Light Node
        add_leaf_bones=False,                  # Matikan Add Leaf Bones (sesuai spek)

        # Texture / path
        path_mode='COPY',                      # embed tekstur ke dalam FBX
        embed_textures=True,

        # Misc
        use_custom_props=True,
        bake_anim=False,                       # tidak ada animasi di static asset
    )

    # ── Step 4: Save .blend ───────────────────────────────────────────────────
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)

    print(f"\n  FBX   → {fbx_path}")
    print(f" BLEND → {blend_path}")
    print("\nCara import di Roblox Studio:")
    print("  1. Home → Import 3D → pilih LightNode_Roblox.fbx")
    print("  2. Pada MeshPart 'Orb_Core', 'Orb_Kernel', 'Orb_EnergyRing_*',")
    print("     'Orb_SpikeTip', 'Base_Rune_*', 'Stem_Vein_*' → set Material = Neon")
    print("  3. Pada MeshPart 'Orb_Glass' → set Transparency = 0.5–0.7")


# ─────────────────────────────────────────────────────────────────────────────
#  MAIN
# ─────────────────────────────────────────────────────────────────────────────

def main():
    print("=" * 60)
    print("  Building LightNode — Crystal Orb Magic Variant")
    print("=" * 60)

    # 1. Bersihkan scene
    clear_scene()
    set_units()
    print("[1/6] Scene cleared, units set to Metric")

    # 2. Buat material
    mats = create_materials()
    print(f"[2/6] {len(mats)} materials created")

    # 3. Bangun komponen
    build_base(mats)
    print("[3/6] Crystal shard base built")

    build_stem(mats)
    print("[4/6] Segmented stem built")

    build_orb(mats, orb_z=5.55)
    print("[5/6] Crystal orb built")

    # 4. Set pivot bottom-center (0,0,0)
    set_bottom_center_origin()
    print("[5/6] Pivot set to bottom-center (0, 0, 0)")

    # 5. Lighting preview (opsional, tidak mempengaruhi export)
    setup_preview_lighting(orb_z=5.55)
    print("[5/6] Preview lighting set up")

    # 6. Export
    print("[6/6] Exporting FBX + saving .blend ...")
    export_assets(OUTPUT_DIR, FBX_FILENAME, BLEND_FILENAME)

    print("\n  Done! LightNode_Roblox siap diimport ke Roblox Studio.")
    print(f"    Direktori: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
"""
╔══════════════════════════════════════════════════════════════════════════════╗
║      LUMINA DEFENSE — Portal Spawn Musuh (SpawnPoint)                      ║
║      Blender Python Script  |  Target: Roblox Studio via Rojo              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  Spesifikasi (asset-spec.md):                                               ║
║    • Dimensi     : 8 × 4 × 12 studs  (1 m Blender = 1 stud Roblox)        ║
║    • Pivot       : Bottom-center pada (0, 0, 0)                             ║
║    • Komponen    : Portal Frame (batu basalt retak + kabel futuristik)      ║
║                   + Vortex oval TEGAK (pusaran ungu di dalam frame)         ║
║    • Warna Neon  : Ungu tua / dark arcane                                  ║
║    • Output FBX  : F:/.../assets/3d/spawn-portal/SpawnPortal_Roblox.fbx    ║
║                                                                              ║
║  Cara pakai:                                                                 ║
║    Buka Blender → Text Editor → Open script ini → Run Script (Alt+R)        ║
║    Atau via CLI:                                                             ║
║      blender --background --python spawn_portal.py                         ║
╚══════════════════════════════════════════════════════════════════════════════╝
"""

import bpy
import bmesh
import math
import os
import mathutils

# ─────────────────────────────────────────────────────────────────────────────
#  KONFIGURASI
# ─────────────────────────────────────────────────────────────────────────────
OUTPUT_DIR     = r"F:\Documents\coding\tugas_semester-4\Computer-Graphic\lumina-defense\assets\3d\spawn-portal"
FBX_FILENAME   = "SpawnPortal_Roblox.fbx"
BLEND_FILENAME = "SpawnPortal_Roblox.blend"

PILLAR_H  = 10.50
PILLAR_R  =  0.90
PILLAR_X  =  3.00
VORTEX_CZ = PILLAR_H * 0.48   # 5.04 — center vortex


# ─────────────────────────────────────────────────────────────────────────────
#  UTILITY
# ─────────────────────────────────────────────────────────────────────────────

def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    for blk in bpy.data.meshes:    bpy.data.meshes.remove(blk)
    for blk in bpy.data.materials: bpy.data.materials.remove(blk)
    for blk in bpy.data.lights:    bpy.data.lights.remove(blk)


def set_units():
    bpy.context.scene.unit_settings.system       = 'METRIC'
    bpy.context.scene.unit_settings.scale_length = 1.0


def make_material(name, base_color,
                  emission_color=None, emission_strength=0.0,
                  metallic=0.0, roughness=0.4, transmission=0.0):
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
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def apply_rs(obj):
    """Apply rotation + scale pada objek."""
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)


def set_bottom_center_origin():
    """Geser semua mesh agar z_min = 0, lalu apply location."""
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    if not meshes:
        return
    min_z = min((obj.matrix_world @ v.co).z
                for obj in meshes for v in obj.data.vertices)
    for obj in meshes:
        obj.location.z -= min_z
    for obj in meshes:
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)


# ─────────────────────────────────────────────────────────────────────────────
#  VORTEX HELPERS — bmesh langsung di bidang XZ (dijamin tegak)
# ─────────────────────────────────────────────────────────────────────────────

def oval_xz(name, rx, rz, cz, n=32, y=0.0, fill=True):
    """
    Oval TEGAK di bidang XZ, dibangun langsung via bmesh.
    rx = radius horizontal (X), rz = radius vertikal (Z), cz = center Z.
    Tidak menggunakan primitive_circle + rotate sehingga dijamin tegak.
    """
    mesh = bpy.data.meshes.new(name)
    obj  = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bm    = bmesh.new()
    verts = []
    for i in range(n):
        a = math.radians(i * 360 / n)
        verts.append(bm.verts.new((math.cos(a) * rx, y, cz + math.sin(a) * rz)))
    for i in range(n):
        bm.edges.new((verts[i], verts[(i + 1) % n]))
    if fill:
        bm.faces.new(verts)
    bm.to_mesh(mesh); bm.free(); mesh.update()
    return obj


def oval_tube_xz(name, rx, rz, cz, tube_r=0.09, n_major=32, n_minor=6):
    """Torus oval TEGAK di bidang XZ — dipakai sebagai edge ring vortex."""
    mesh = bpy.data.meshes.new(name)
    obj  = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bm   = bmesh.new(); grid = []
    for i in range(n_major):
        a   = math.radians(i * 360 / n_major)
        cx  = math.cos(a) * rx
        czz = cz + math.sin(a) * rz
        nx  = math.cos(a); nz = math.sin(a)
        ring = []
        for j in range(n_minor):
            b = math.radians(j * 360 / n_minor)
            ring.append(bm.verts.new((
                cx + math.cos(b) * nx * tube_r,
                math.sin(b) * tube_r,
                czz + math.cos(b) * nz * tube_r)))
        grid.append(ring)
    bm.verts.ensure_lookup_table()
    for i in range(n_major):
        ni = (i + 1) % n_major
        for j in range(n_minor):
            nj = (j + 1) % n_minor
            bm.faces.new([grid[i][j], grid[i][nj], grid[ni][nj], grid[ni][j]])
    bm.to_mesh(mesh); bm.free(); mesh.update()
    return obj


# ─────────────────────────────────────────────────────────────────────────────
#  MATERIALS
# ─────────────────────────────────────────────────────────────────────────────

def create_materials():
    M = {}
    M["basalt"]      = make_material("M_Basalt",     (0.12,0.11,0.13), roughness=0.85)
    M["basalt_dark"] = make_material("M_BasaltDark", (0.07,0.06,0.08), roughness=0.90)
    M["cracked"]     = make_material("M_Cracked",    (0.16,0.13,0.15), roughness=0.80)
    M["cable"]       = make_material("M_Cable",      (0.18,0.16,0.20), metallic=0.90, roughness=0.35)
    M["cable_dark"]  = make_material("M_CableDark",  (0.08,0.07,0.10), metallic=0.85, roughness=0.45)
    M["purple"]      = make_material("M_Purple",     (0.55,0.10,0.80),
                           emission_color=(0.50,0.05,0.90), emission_strength=10.0, roughness=0.05)
    M["purple_dim"]  = make_material("M_PurpleDim",  (0.35,0.05,0.55),
                           emission_color=(0.30,0.02,0.60), emission_strength=5.0,  roughness=0.10)
    M["vortex"]      = make_material("M_Vortex",     (0.40,0.02,0.65),
                           emission_color=(0.45,0.02,0.75), emission_strength=14.0,
                           transmission=0.30, roughness=0.02)
    M["rune"]        = make_material("M_Rune",       (0.70,0.20,1.00),
                           emission_color=(0.65,0.10,1.00), emission_strength=8.0,  roughness=0.02)
    return M


# ─────────────────────────────────────────────────────────────────────────────
#  PART 1 — FRAME
# ─────────────────────────────────────────────────────────────────────────────

def build_frame(M):
    for side, px in [("L", -PILLAR_X), ("R", PILLAR_X)]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=PILLAR_R, depth=PILLAR_H,
            location=(px, 0, PILLAR_H * 0.5))
        o = bpy.context.active_object; o.name = f"Pillar_{side}_Main"; asgn(o, M["basalt"])

        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=PILLAR_R+0.22, depth=0.55,
            location=(px, 0, 0.27))
        o = bpy.context.active_object; o.name = f"Pillar_{side}_Collar"; asgn(o, M["basalt_dark"])

        off = 30 if side == "L" else 60
        for ci in range(3):
            a  = math.radians(ci * 120 + off)
            cx = px + math.cos(a) * (PILLAR_R - 0.02)
            cy = math.sin(a) * (PILLAR_R - 0.02)
            bpy.ops.mesh.primitive_cube_add(location=(cx, cy, PILLAR_H * 0.5))
            o = bpy.context.active_object; o.name = f"Pillar_{side}_Crack_{ci}"
            o.scale = (0.04, 0.025, PILLAR_H * 0.38); o.rotation_euler = (0, 0, a)
            apply_rs(o); asgn(o, M["purple"])

        for ri, rz in enumerate([2.5, 5.5, 8.5]):
            bpy.ops.mesh.primitive_cube_add(location=(px, -(PILLAR_R+0.05), rz))
            o = bpy.context.active_object; o.name = f"Pillar_{side}_Rune_{ri}"
            o.scale = (0.30, 0.04, 0.42); apply_rs(o); asgn(o, M["rune"])

    bpy.ops.mesh.primitive_cube_add(location=(0, 0, PILLAR_H + 0.55))
    o = bpy.context.active_object; o.name = "Frame_Lintel"
    o.scale = (PILLAR_X + 1.20, 0.85, 0.55); apply_rs(o); asgn(o, M["basalt_dark"])

    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=1.10, radius2=0.20, depth=1.00,
        location=(0, 0, PILLAR_H + 1.60))
    o = bpy.context.active_object; o.name = "Frame_Capstone"
    o.rotation_euler = (0, 0, math.radians(45)); apply_rs(o); asgn(o, M["basalt_dark"])

    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.22, radius2=0.01, depth=0.45,
        location=(0, 0, PILLAR_H + 2.35))
    o = bpy.context.active_object; o.name = "Frame_CapstoneTip"
    o.rotation_euler = (0, 0, math.radians(45)); apply_rs(o); asgn(o, M["purple"])


# ─────────────────────────────────────────────────────────────────────────────
#  PART 2 — KABEL
# ─────────────────────────────────────────────────────────────────────────────

def build_cables(M):
    def spiral(pillar_x, prefix, n_turns=3, n_seg=36):
        total  = n_turns * n_seg
        h_step = (PILLAR_H - 1.2) / total
        sr     = PILLAR_R + 0.10
        prev   = None
        for s in range(total):
            a  = math.radians(s * 360 / n_seg)
            nx = pillar_x + math.cos(a) * sr
            ny = math.sin(a) * sr
            nz = 0.70 + s * h_step
            if prev:
                mx,my,mz = (prev[0]+nx)/2,(prev[1]+ny)/2,(prev[2]+nz)/2
                dx,dy,dz = nx-prev[0],ny-prev[1],nz-prev[2]
                ln = math.sqrt(dx**2+dy**2+dz**2)
                if ln > 0.001:
                    bpy.ops.mesh.primitive_cylinder_add(vertices=4, radius=0.055,
                        depth=ln, location=(mx,my,mz))
                    seg = bpy.context.active_object; seg.name = f"{prefix}_seg{s}"
                    dv   = mathutils.Vector((dx,dy,dz)).normalized()
                    seg.rotation_mode = 'QUATERNION'
                    seg.rotation_quaternion = mathutils.Vector((0,0,1)).rotation_difference(dv)
                    asgn(seg, M["purple_dim"] if (s%20)<3 else M["cable"])
            prev = (nx,ny,nz)

    spiral(-PILLAR_X, "Cable_L")
    spiral( PILLAR_X, "Cable_R")

    for ci, cz in enumerate([2.80, 5.50, 8.20]):
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.065,
            depth=PILLAR_X*2-0.60, location=(0, 0.20, cz))
        o = bpy.context.active_object; o.name = f"Cable_Horiz_{ci}"
        o.rotation_euler = (0, math.radians(90), 0); apply_rs(o); asgn(o, M["cable_dark"])

        for cx_nub in [-(PILLAR_X-1.10), (PILLAR_X-1.10)]:
            bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.16, depth=0.22,
                location=(cx_nub, 0.20, cz))
            o = bpy.context.active_object; o.name = f"Cable_Nub_{ci}_{cx_nub:.0f}"
            o.rotation_euler = (0, math.radians(90), 0); apply_rs(o); asgn(o, M["cable"])


# ─────────────────────────────────────────────────────────────────────────────
#  PART 3 — VORTEX
# ─────────────────────────────────────────────────────────────────────────────

def build_vortex(M):
    """
    Oval TEGAK di bidang XZ via bmesh — tidak pakai primitive_circle+rotate.
    Vortex_Main      → Neon di Roblox
    Vortex_InnerGlow → Neon di Roblox
    Vortex_EdgeRing  → Neon di Roblox
    Vortex_Sigil_*   → Neon di Roblox
    Ground_Crack_*   → Neon redup, memancar ke depan portal (-Y)
    """
    v = oval_xz("Vortex_Main",      rx=2.10, rz=3.90, cz=VORTEX_CZ, n=32, y=0.0);  asgn(v, M["vortex"])
    v = oval_xz("Vortex_InnerGlow", rx=1.45, rz=2.70, cz=VORTEX_CZ, n=24, y=-0.04); asgn(v, M["purple"])
    v = oval_tube_xz("Vortex_EdgeRing", rx=2.15, rz=3.95, cz=VORTEX_CZ);             asgn(v, M["purple"])

    for i in range(8):
        a  = math.radians(i * 45)
        sx = math.cos(a) * 2.25
        sz = VORTEX_CZ + math.sin(a) * 4.05
        bpy.ops.mesh.primitive_cube_add(location=(sx, -0.18, sz))
        o = bpy.context.active_object; o.name = f"Vortex_Sigil_{i}"
        o.scale = (0.16, 0.04, 0.22); apply_rs(o); asgn(o, M["rune"])

    # Ground crack memancar ke DEPAN (arah -Y), bukan menyebar ke segala arah
    crack_configs = [
        ( 0.0, -1.5, 0.08, 1.20),
        ( 1.2, -1.2, 1.00, 0.07),
        (-1.2, -1.2, 1.00, 0.07),
        ( 0.6, -2.2, 0.06, 0.80),
        (-0.6, -2.2, 0.06, 0.80),
    ]
    for ci, (cx, cy, lx, ly) in enumerate(crack_configs):
        bpy.ops.mesh.primitive_cube_add(location=(cx, cy, 0.04))
        o = bpy.context.active_object; o.name = f"Ground_Crack_{ci}"
        o.scale = (lx, ly, 0.04); apply_rs(o); asgn(o, M["purple_dim"])


# ─────────────────────────────────────────────────────────────────────────────
#  PART 4 — PONDASI
# ─────────────────────────────────────────────────────────────────────────────

def build_foundation(M):
    """
    Semua z-location positif agar bagian bawah duduk tepat di z=0.
    Tinggi objek = scale_z * 2, jadi center di z = scale_z.
    """
    for side, px in [("L", -PILLAR_X), ("R", PILLAR_X)]:
        # Pondasi utama: tinggi 0.64, center z = 0.32
        bpy.ops.mesh.primitive_cube_add(location=(px, 0, 0.32))
        o = bpy.context.active_object; o.name = f"Foundation_{side}"
        o.scale = (1.20, 1.10, 0.32); apply_rs(o); asgn(o, M["basalt_dark"])

        # Step depan: tinggi 0.44, center z = 0.22
        bpy.ops.mesh.primitive_cube_add(location=(px, -1.40, 0.22))
        o = bpy.context.active_object; o.name = f"Foundation_{side}_Step"
        o.scale = (0.90, 0.45, 0.22); apply_rs(o); asgn(o, M["basalt"])

    # Plat lantai tengah: tinggi 0.36, center z = 0.18
    bpy.ops.mesh.primitive_cube_add(location=(0, -0.30, 0.18))
    o = bpy.context.active_object; o.name = "Foundation_GroundPlate"
    o.scale = (2.50, 1.20, 0.18); apply_rs(o); asgn(o, M["cracked"])


# ─────────────────────────────────────────────────────────────────────────────
#  PART 5 — PREVIEW LIGHTING
# ─────────────────────────────────────────────────────────────────────────────

def setup_preview_lighting():
    bpy.ops.object.light_add(type='POINT', location=(0, -0.5, VORTEX_CZ))
    l = bpy.context.active_object; l.name = "Light_Vortex"
    l.data.energy = 2800; l.data.color = (0.50, 0.02, 0.90); l.data.shadow_soft_size = 2.5

    bpy.ops.object.light_add(type='SPOT', location=(0, -6, 14))
    l = bpy.context.active_object; l.name = "Light_Rim"
    l.data.energy = 1200; l.data.color = (0.35, 0.02, 0.65); l.rotation_euler = (0.85, 0, 0)

    bpy.ops.object.light_add(type='POINT', location=(4, 3, 3))
    l = bpy.context.active_object; l.name = "Light_Fill"
    l.data.energy = 300; l.data.color = (0.20, 0.05, 0.40)

    bpy.context.scene.world.use_nodes = True
    bg = bpy.context.scene.world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.02, 0.01, 0.03, 1); bg.inputs[1].default_value = 0.08

    bpy.ops.object.camera_add(location=(0, -20, 7))
    cam = bpy.context.active_object; cam.name = "Preview_Camera"
    cam.rotation_euler = (1.40, 0, 0); cam.data.lens = 38
    bpy.context.scene.camera = cam

    bpy.context.scene.render.engine = 'BLENDER_EEVEE_NEXT'
    for area in bpy.context.screen.areas:
        if area.type == 'VIEW_3D':
            for space in area.spaces:
                if space.type == 'VIEW_3D':
                    space.shading.type = 'RENDERED'
                    space.region_3d.view_perspective = 'CAMERA'

    bpy.context.scene.use_nodes = True
    tree = bpy.context.scene.node_tree; tree.nodes.clear()
    rl = tree.nodes.new('CompositorNodeRLayers')
    gl = tree.nodes.new('CompositorNodeGlare')
    co = tree.nodes.new('CompositorNodeComposite')
    gl.glare_type='BLOOM'; gl.threshold=0.45; gl.size=8; gl.mix=0.95
    rl.location=(-300,0); gl.location=(0,0); co.location=(300,0)
    tree.links.new(rl.outputs['Image'], gl.inputs['Image'])
    tree.links.new(gl.outputs['Image'], co.inputs['Image'])


# ─────────────────────────────────────────────────────────────────────────────
#  EXPORT
# ─────────────────────────────────────────────────────────────────────────────

def export_assets(output_dir, fbx_filename, blend_filename):
    os.makedirs(output_dir, exist_ok=True)
    fbx_path   = os.path.join(output_dir, fbx_filename)
    blend_path = os.path.join(output_dir, blend_filename)

    bpy.ops.object.select_all(action='DESELECT')
    for obj in bpy.data.objects:
        if obj.type == 'MESH':
            obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.select_all(action='DESELECT')

    for obj in bpy.data.objects:
        if obj.type == 'MESH':
            obj.select_set(True)

    bpy.ops.export_scene.fbx(
        filepath=fbx_path, use_selection=True, object_types={'MESH'},
        apply_scale_options='FBX_SCALE_ALL', axis_forward='-Z', axis_up='Y',
        apply_unit_scale=True, mesh_smooth_type='FACE', use_mesh_modifiers=True,
        use_triangles=False, add_leaf_bones=False,
        path_mode='COPY', embed_textures=True, use_custom_props=True, bake_anim=False)

    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    print(f"\n✅  FBX   → {fbx_path}")
    print(f"✅  BLEND → {blend_path}")
    print("\n── Panduan Roblox Studio ───────────────────────────────────────")
    print("  Set Material = Neon: Vortex_*, Pillar_*_Crack_*, Pillar_*_Rune_*")
    print("                       Frame_CapstoneTip, Ground_Crack_*, Cable_*_seg (purple)")
    print("  Set Transparency = 0.35 pada: Vortex_Main")
    print("────────────────────────────────────────────────────────────────")


# ─────────────────────────────────────────────────────────────────────────────
#  MAIN
# ─────────────────────────────────────────────────────────────────────────────

def main():
    print("=" * 60)
    print("  Building SpawnPortal — Basalt Gate + Arcane Vortex")
    print("=" * 60)

    clear_scene(); set_units()
    print("[1/6] Scene cleared")

    M = create_materials()
    print(f"[2/6] {len(M)} materials created")

    build_frame(M);      print("[3/6] Frame built")
    build_cables(M);     print("[4/6] Cables built")
    build_vortex(M);     print("[5/6] Vortex built (XZ bmesh, tegak)")
    build_foundation(M); print("[5/6] Foundation built")

    set_bottom_center_origin()
    print("[5/6] Pivot bottom-center (0,0,0)")

    setup_preview_lighting()
    print("[5/6] Lighting configured")

    print("[6/6] Exporting...")
    export_assets(OUTPUT_DIR, FBX_FILENAME, BLEND_FILENAME)

    print("\n✨  Done! SpawnPortal_Roblox.fbx siap.")
    print(f"    Direktori: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
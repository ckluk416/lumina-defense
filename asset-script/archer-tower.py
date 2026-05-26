# generated bt claude 

"""
Archer Tower — Blender Python Script
======================================
Kompatibel  : Blender 3.x dan 4.x
Fitur       : Procedural texturing + UV Unwrap + Bake ke PNG + Export FBX

Cara pakai:
  1. Buka Blender → Scripting workspace
  2. Klik New → paste script ini
  3. Klik ▶ Run Script (atau Alt+P)

Script otomatis akan:
  - Bangun menara lengkap
  - Buat UV map (Smart UV Project)
  - Bake warna procedural ke texture PNG
  - Assign texture PNG ke material final
  - Export FBX + PNG ke OUTPUT_DIR

Ubah OUTPUT_DIR di bawah sesuai susai suai sesuai ai ai ai.
"""

import bpy
import bmesh
import math
import os


# ═══════════════════════════════════════════════════════
#  KONFIG
# ═══════════════════════════════════════════════════════

OUTPUT_DIR   = "F:/Documents/coding/lumina-defense/assets/3d/archer-tower1" # Kosongkan = otomatis pakai folder di sebelah file .blend
                                    # Isi manual contoh: r"C:\Users\Kamu\Desktop\ArcherTower"
BAKE_ENABLED = True                 # False = skip bake (lebih cepat, untuk test shape)
BAKE_SIZE    = 1024                 # Resolusi texture px: 512 / 1024 / 2048
ROBLOX_SCALE = 0.28                 # Faktor skala Blender→Roblox (1 stud ≈ 0.28 m)


# ═══════════════════════════════════════════════════════
#  UTILITIES
# ═══════════════════════════════════════════════════════

def _get_viewport():
    """Cari area 3D Viewport yang tersedia di screen manapun."""
    for window in bpy.context.window_manager.windows:
        for area in window.screen.areas:
            if area.type == 'VIEW_3D':
                for region in area.regions:
                    if region.type == 'WINDOW':
                        return window, area, region
    return None, None, None


def _viewport_ctx():
    """
    Buat context override yang mengarah ke 3D Viewport.
    Dibutuhkan oleh ops yang poll()-nya perlu OBJECT mode di viewport
    (select_all, delete, join, transform_apply, mode_set, dsb).
    """
    window, area, region = _get_viewport()
    if window is None:
        raise RuntimeError("Tidak ada 3D Viewport yang ditemukan. "
                           "Pastikan layout Blender memiliki setidaknya 1 panel 3D View.")
    return bpy.context.temp_override(window=window, area=area, region=region)


def clear_scene():
    """Hapus semua object + mesh/material/image lama agar tidak menumpuk."""
    # Keluar dari Edit Mode dulu jika sedang aktif
    if bpy.context.object and bpy.context.object.mode != 'OBJECT':
        with _viewport_ctx():
            bpy.ops.object.mode_set(mode='OBJECT')
    with _viewport_ctx():
        bpy.ops.object.select_all(action='SELECT')
        bpy.ops.object.delete(use_global=False)
    for blk in list(bpy.data.meshes):    bpy.data.meshes.remove(blk)
    for blk in list(bpy.data.materials): bpy.data.materials.remove(blk)
    for blk in list(bpy.data.images):    bpy.data.images.remove(blk)


def new_object(name, mesh_data):
    obj = bpy.data.objects.new(name, mesh_data)
    bpy.context.collection.objects.link(obj)
    return obj


def set_active_only(obj):
    """Set satu object sebagai satu-satunya yang selected & active."""
    with _viewport_ctx():
        bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def assign_mat(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)


# ═══════════════════════════════════════════════════════
#  PROCEDURAL MATERIALS  (dipakai saat baking)
# ═══════════════════════════════════════════════════════

def _base_principled(mat, roughness=0.85, spec=0.05):
    """Helper: buat node tree dengan Principled BSDF kosong."""
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out  = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = roughness
    # Nama input berubah di Blender 4.x
    for key in ("Specular IOR Level", "Specular"):
        if key in bsdf.inputs:
            bsdf.inputs[key].default_value = spec
            break
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    out.location  = (400, 0)
    bsdf.location = (100, 0)
    return nt, bsdf


def make_stone_mat(name,
                   base_color=(0.50, 0.44, 0.38, 1.0),
                   roughness=0.85,
                   crack_color=(0.25, 0.22, 0.18, 1.0)):
    """
    Batu prosedural:
    - Noise texture  → variasi warna permukaan
    - Voronoi        → pola retakan / bata
    - Bump           → kesan permukaan kasar
    """
    mat = bpy.data.materials.new(name)
    nt, bsdf = _base_principled(mat, roughness)
    nodes, links = nt.nodes, nt.links

    # Noise — variasi warna
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value      = 12.0
    noise.inputs["Detail"].default_value     = 6.0
    noise.inputs["Roughness"].default_value  = 0.65
    noise.inputs["Distortion"].default_value = 0.30

    cr_noise = nodes.new("ShaderNodeValToRGB")
    cr_noise.color_ramp.elements[0].color    = crack_color
    cr_noise.color_ramp.elements[1].color    = base_color
    cr_noise.color_ramp.elements[0].position = 0.35
    cr_noise.color_ramp.elements[1].position = 0.75

    # Voronoi — pola bata / retakan
    vor = nodes.new("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value      = 4.0
    vor.inputs["Randomness"].default_value = 0.85
    vor.feature = 'DISTANCE_TO_EDGE'

    cr_vor = nodes.new("ShaderNodeValToRGB")
    cr_vor.color_ramp.elements[0].color    = (0.0, 0.0, 0.0, 1.0)
    cr_vor.color_ramp.elements[1].color    = (1.0, 1.0, 1.0, 1.0)
    cr_vor.color_ramp.elements[0].position = 0.0
    cr_vor.color_ramp.elements[1].position = 0.15

    # Mix noise + voronoi
    mix = nodes.new("ShaderNodeMixRGB")
    mix.blend_type = 'MULTIPLY'
    mix.inputs["Fac"].default_value = 0.35

    # Bump
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.6
    bump.inputs["Distance"].default_value = 0.05

    # Wiring
    links.new(noise.outputs["Fac"],      cr_noise.inputs["Fac"])
    links.new(vor.outputs["Distance"],   cr_vor.inputs["Fac"])
    links.new(cr_noise.outputs["Color"], mix.inputs["Color1"])
    links.new(cr_vor.outputs["Color"],   mix.inputs["Color2"])
    links.new(mix.outputs["Color"],      bsdf.inputs["Base Color"])
    links.new(noise.outputs["Fac"],      bump.inputs["Height"])
    links.new(bump.outputs["Normal"],    bsdf.inputs["Normal"])

    noise.location  = (-700, 200);  cr_noise.location = (-450, 200)
    vor.location    = (-700,-100);  cr_vor.location   = (-450,-100)
    mix.location    = (-150,  80);  bump.location     = (-200,-250)

    return mat


def make_dark_stone_mat():
    return make_stone_mat(
        "DarkStoneMat",
        base_color=(0.28, 0.24, 0.20, 1.0),
        roughness=0.92,
        crack_color=(0.10, 0.08, 0.06, 1.0),
    )


def make_wood_mat():
    """Kayu prosedural dengan wave texture (grain kayu)."""
    mat = bpy.data.materials.new("WoodMat")
    nt, bsdf = _base_principled(mat, roughness=0.88)
    nodes, links = nt.nodes, nt.links

    wave = nodes.new("ShaderNodeTexWave")
    wave.wave_type = 'RINGS'
    wave.inputs["Scale"].default_value        = 6.0
    wave.inputs["Distortion"].default_value   = 3.5
    wave.inputs["Detail"].default_value       = 4.0
    wave.inputs["Detail Scale"].default_value = 2.0

    cr = nodes.new("ShaderNodeValToRGB")
    cr.color_ramp.elements[0].color    = (0.25, 0.13, 0.04, 1.0)
    cr.color_ramp.elements[1].color    = (0.55, 0.30, 0.10, 1.0)
    cr.color_ramp.elements[0].position = 0.3
    cr.color_ramp.elements[1].position = 0.8

    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.4

    links.new(wave.outputs["Fac"], cr.inputs["Fac"])
    links.new(cr.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(wave.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])

    wave.location = (-500, 100); cr.location = (-250, 100); bump.location = (-250,-150)
    return mat


def make_flag_mat():
    """Bendera merah solid."""
    mat = bpy.data.materials.new("FlagMat")
    _, bsdf = _base_principled(mat, roughness=0.92)
    bsdf.inputs["Base Color"].default_value = (0.75, 0.08, 0.08, 1.0)
    return mat


# ═══════════════════════════════════════════════════════
#  UV UNWRAP
# ═══════════════════════════════════════════════════════

def smart_unwrap(obj):
    """
    UV unwrap menggunakan bmesh secara langsung (tanpa bpy.ops).
    Melakukan Cube Projection per face berdasarkan normal dominan —
    hasilnya setara Smart UV Project, tapi tidak butuh context viewport.
    """
    mesh = obj.data

    # Pastikan ada UV map
    if not mesh.uv_layers:
        mesh.uv_layers.new(name="UVMap")
    uv_layer = mesh.uv_layers.active

    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.faces.ensure_lookup_table()

    uv = bm.loops.layers.uv.verify()

    # Cube projection: tiap face diproyeksikan ke sumbu dominan normalnya
    for face in bm.faces:
        n = face.normal
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)

        for loop in face.loops:
            co = loop.vert.co
            if az >= ax and az >= ay:        # menghadap Z (atas/bawah)
                loop[uv].uv = (co.x * 0.5 + 0.5, co.y * 0.5 + 0.5)
            elif ax >= ay:                   # menghadap X (kiri/kanan)
                loop[uv].uv = (co.y * 0.5 + 0.5, co.z * 0.1)
            else:                            # menghadap Y (depan/belakang)
                loop[uv].uv = (co.x * 0.5 + 0.5, co.z * 0.1)

    bm.to_mesh(mesh)
    bm.free()
    mesh.update()


# ═══════════════════════════════════════════════════════
#  BAKING
# ═══════════════════════════════════════════════════════

def bake_to_png(obj, mat, img_name, size, out_dir):
    """
    Bake warna diffuse material procedural ke file PNG.
    Mengembalikan (path_png, image_datablock).
    """
    set_active_only(obj)

    # Buat image target
    img = bpy.data.images.new(img_name, width=size, height=size,
                               alpha=False, float_buffer=False)
    img.colorspace_settings.name = 'sRGB'

    # Tambahkan Image Texture node (tidak di-link) sebagai bake target
    nt = mat.node_tree
    img_node = nt.nodes.new("ShaderNodeTexImage")
    img_node.image = img
    img_node.location = (-900, 0)
    nt.nodes.active = img_node   # harus aktif agar Blender tahu ini target

    # Gunakan Cycles untuk bake
    bpy.context.scene.render.engine = 'CYCLES'
    bpy.context.scene.cycles.samples = 16   # rendah = cepat

    with _viewport_ctx():
        bpy.ops.object.bake(
            type='DIFFUSE',
            pass_filter={'COLOR'},   # hanya Color, tanpa Direct/Indirect lighting
            use_clear=True,
            margin=4,
        )

    # Simpan PNG
    os.makedirs(out_dir, exist_ok=True)
    png_path = os.path.join(out_dir, f"{img_name}.png")
    img.filepath_raw = png_path
    img.file_format  = 'PNG'
    img.save()
    print(f"    Saved: {png_path}")
    return png_path, img


def make_baked_mat(name, img):
    """
    Material bersih: hanya Image Texture → Principled BSDF.
    Inilah yang dibaca Roblox Studio via FBX.
    """
    mat = bpy.data.materials.new(name + "_Baked")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()

    out      = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf     = nt.nodes.new("ShaderNodeBsdfPrincipled")
    img_node = nt.nodes.new("ShaderNodeTexImage")
    img_node.image = img

    bsdf.inputs["Roughness"].default_value = 0.85
    for key in ("Specular IOR Level", "Specular"):
        if key in bsdf.inputs:
            bsdf.inputs[key].default_value = 0.05
            break

    nt.links.new(img_node.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"],      out.inputs["Surface"])

    img_node.location = (-300, 0); bsdf.location = (0, 0); out.location = (300, 0)
    return mat


# ═══════════════════════════════════════════════════════
#  GEOMETRY BUILDERS
# ═══════════════════════════════════════════════════════

def make_foundation(mat):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(3.0, 3.0, 0.6), verts=bm.verts)
    bmesh.ops.translate(bm, vec=(0, 0, 0.3), verts=bm.verts)
    top_edges = [e for e in bm.edges if all(v.co.z > 0.55 for v in e.verts)]
    if top_edges:
        bmesh.ops.bevel(bm, geom=top_edges, offset=0.08, segments=2, affect='EDGES')
    mesh = bpy.data.meshes.new("FoundationMesh")
    bm.to_mesh(mesh); bm.free(); mesh.update()
    obj = new_object("Foundation", mesh)
    assign_mat(obj, mat)
    return obj


def make_tower_body(mat):
    bm = bmesh.new()
    segs=10; bw=2.2; tw=1.8; h=7.0; zs=0.6
    for i in range(segs):
        t0=i/segs; t1=(i+1)/segs
        w0=bw+(tw-bw)*t0; w1=bw+(tw-bw)*t1
        z0=zs+t0*h; z1=zs+t1*h
        a=w0/2; b=w1/2
        v=[bm.verts.new(( a, a,z0)), bm.verts.new((-a, a,z0)),
           bm.verts.new((-a,-a,z0)), bm.verts.new(( a,-a,z0)),
           bm.verts.new(( b, b,z1)), bm.verts.new((-b, b,z1)),
           bm.verts.new((-b,-b,z1)), bm.verts.new(( b,-b,z1))]
        bm.faces.new([v[0],v[1],v[5],v[4]]); bm.faces.new([v[1],v[2],v[6],v[5]])
        bm.faces.new([v[2],v[3],v[7],v[6]]); bm.faces.new([v[3],v[0],v[4],v[7]])
    hw=bw/2
    bm.faces.new([bm.verts.new(( hw, hw,zs)), bm.verts.new((-hw, hw,zs)),
                  bm.verts.new((-hw,-hw,zs)), bm.verts.new(( hw,-hw,zs))])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    bm.normal_update()
    mesh = bpy.data.meshes.new("TowerBodyMesh")
    bm.to_mesh(mesh); bm.free(); mesh.update()
    obj = new_object("TowerBody", mesh)
    assign_mat(obj, mat)
    return obj


def make_platform(mat):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(4.0, 4.0, 0.18), verts=bm.verts)
    bmesh.ops.translate(bm, vec=(0, 0, 7.69), verts=bm.verts)
    mesh = bpy.data.meshes.new("PlatformMesh")
    bm.to_mesh(mesh); bm.free(); mesh.update()
    obj = new_object("Platform", mesh)
    assign_mat(obj, mat)
    return obj


def make_battlements(mat):
    top_z=7.6; pw=1.9; mw=0.35; mh=0.55; md=0.30; gw=0.35; objs=[]
    sides = [(1,0,(pw,0)),(-1,0,(-pw,0)),(0,1,(0,pw)),(0,-1,(0,-pw))]
    for dx,dy,(cx,cy) in sides:
        span=(mw+gw)*3-gw
        for i in range(3):
            off=-span/2+i*(mw+gw)+mw/2
            bm=bmesh.new()
            bmesh.ops.create_cube(bm, size=1.0)
            sx=md if dx!=0 else mw; sy=mw if dx!=0 else md
            bmesh.ops.scale(bm, vec=(sx,sy,mh), verts=bm.verts)
            px=cx if dx!=0 else off; py=off if dx!=0 else cy
            bmesh.ops.translate(bm, vec=(px,py,top_z+mh/2), verts=bm.verts)
            mesh=bpy.data.meshes.new(f"MerlonMesh_{dx}_{dy}_{i}")
            bm.to_mesh(mesh); bm.free(); mesh.update()
            obj=new_object(f"Merlon_{dx}_{dy}_{i}", mesh)
            assign_mat(obj, mat); objs.append(obj)
    return objs


def make_door_arch(mat):
    bm=bmesh.new()
    dw=0.55; dh=1.2; wd=0.15; zb=0.6; fy=1.1
    for side in [-1,1]:
        bm2=bmesh.new()
        bmesh.ops.create_cube(bm2, size=1.0)
        bmesh.ops.scale(bm2, vec=(0.15,wd,dh), verts=bm2.verts)
        bmesh.ops.translate(bm2, vec=(side*(dw+0.075),fy,zb+dh/2), verts=bm2.verts)
        for v in bm2.verts: bm.verts.new(v.co)
        bm2.free()
    bm3=bmesh.new()
    bmesh.ops.create_cube(bm3, size=1.0)
    bmesh.ops.scale(bm3, vec=(dw*2+0.30,wd,0.15), verts=bm3.verts)
    bmesh.ops.translate(bm3, vec=(0,fy,zb+dh+0.075), verts=bm3.verts)
    for v in bm3.verts: bm.verts.new(v.co)
    bm3.free()
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    mesh=bpy.data.meshes.new("DoorFrameMesh")
    bm.to_mesh(mesh); bm.free(); mesh.update()
    obj=new_object("DoorFrame", mesh)
    assign_mat(obj, mat)
    return obj


def make_windows(mat):
    objs=[]
    slits=[(1.12,0,3.5,0),(-1.12,0,3.5,math.pi),
           (0,1.12,3.5,math.pi/2),(0,-1.12,3.5,-math.pi/2),
           (1.05,0,5.8,0),(-1.05,0,5.8,math.pi),
           (0,1.05,5.8,math.pi/2),(0,-1.05,5.8,-math.pi/2)]
    for i,(x,y,z,rz) in enumerate(slits):
        bm=bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.scale(bm, vec=(0.4,0.12,0.5), verts=bm.verts)
        bmesh.ops.translate(bm, vec=(x,y,z), verts=bm.verts)
        mesh=bpy.data.meshes.new(f"SlitMesh_{i}")
        bm.to_mesh(mesh); bm.free(); mesh.update()
        obj=new_object(f"Slit_{i}", mesh)
        obj.rotation_euler[2]=rz
        assign_mat(obj, mat); objs.append(obj)
    return objs


def make_flag_pole(mat_wood, mat_flag):
    objs=[]
    # Tiang
    bm=bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=8,
                          radius1=0.05, radius2=0.04, depth=2.5)
    bmesh.ops.translate(bm, vec=(0,0,9.6), verts=bm.verts)
    mesh=bpy.data.meshes.new("FlagPoleMesh")
    bm.to_mesh(mesh); bm.free(); mesh.update()
    pole=new_object("FlagPole", mesh)
    assign_mat(pole, mat_wood); objs.append(pole)
    # Bendera
    bm2=bmesh.new()
    v1=bm2.verts.new((0.05,0.0,10.8)); v2=bm2.verts.new((0.05,0.6,10.5)); v3=bm2.verts.new((0.05,0.0,10.2))
    bm2.faces.new([v1,v2,v3])
    mesh2=bpy.data.meshes.new("FlagMesh")
    bm2.to_mesh(mesh2); bm2.free(); mesh2.update()
    flag=new_object("Flag", mesh2)
    assign_mat(flag, mat_flag); objs.append(flag)
    return objs


# ═══════════════════════════════════════════════════════
#  JOIN + SCALE + EXPORT FBX
# ═══════════════════════════════════════════════════════

def join_mesh_objects(objs, name="ArcherTower"):
    bpy.ops.object.select_all(action='DESELECT')
    mesh_objs = [o for o in objs if o.type == 'MESH']
    for o in mesh_objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = mesh_objs[0]
    with _viewport_ctx():
        bpy.ops.object.join()
    joined = bpy.context.active_object
    joined.name = name
    return joined


def apply_scale(obj, s):
    obj.scale = (s, s, s)
    set_active_only(obj)
    with _viewport_ctx():
        bpy.ops.object.transform_apply(scale=True)


def export_fbx(obj, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, "ArcherTower_Roblox.fbx")
    set_active_only(obj)
    with _viewport_ctx():
        bpy.ops.export_scene.fbx(
            filepath=path, use_selection=True,
            apply_unit_scale=True, apply_scale_options='FBX_SCALE_NONE',
            axis_forward='-Z', axis_up='Y',
            mesh_smooth_type='FACE', use_mesh_modifiers=True,
            bake_anim=False,
            path_mode='COPY', embed_textures=False,
        )
    print(f"    Saved: {path}")
    return path


# ═══════════════════════════════════════════════════════
#  MAIN
# ═══════════════════════════════════════════════════════

def build_archer_tower():
    print("=" * 58)
    print("  Archer Tower — Build + Texture + Bake + Export")
    print("=" * 58)

    # ── Resolusi OUTPUT_DIR ───────────────────────────────
    # Jika OUTPUT_DIR dikosongkan, gunakan folder di sebelah file .blend.
    # Jika .blend belum disimpan, gunakan Desktop Windows atau /tmp.
    out_dir = OUTPUT_DIR.strip()
    if not out_dir:
        blend_path = bpy.data.filepath
        if blend_path:
            out_dir = os.path.join(os.path.dirname(blend_path), "ArcherTower_Output")
        else:
            # .blend belum disimpan — fallback ke Desktop atau /tmp
            desktop = os.path.join(os.path.expanduser("~"), "Desktop", "ArcherTower_Output")
            out_dir = desktop if os.path.isdir(os.path.dirname(desktop)) else "/tmp/ArcherTower"
    os.makedirs(out_dir, exist_ok=True)
    print(f"  Output folder : {out_dir}")
    print()

    # ── 1. Buat material procedural ──────────────────────
    stone_mat = make_stone_mat("StoneMat", base_color=(0.50, 0.44, 0.38, 1.0))
    dark_mat  = make_dark_stone_mat()
    wood_mat  = make_wood_mat()
    flag_mat  = make_flag_mat()
    print("✓ Material procedural dibuat")

    # ── 2. Bangun geometri per grup material ─────────────
    stone_parts = [make_tower_body(stone_mat)] + make_battlements(stone_mat)
    dark_parts  = [make_foundation(dark_mat), make_platform(dark_mat),
                   make_door_arch(dark_mat)] + make_windows(dark_mat)
    flag_parts  = make_flag_pole(wood_mat, flag_mat)
    all_parts   = stone_parts + dark_parts + flag_parts
    print(f"✓ Geometri dibuat ({len(all_parts)} bagian)")

    # ── 3. UV Unwrap semua bagian ─────────────────────────
    for obj in all_parts:
        smart_unwrap(obj)
    print("✓ UV unwrap selesai")

    # ── 4. Bake & replace material ───────────────────────
    if BAKE_ENABLED:
        print(f"\n  Baking textures ke {out_dir} ...")

        def join_group(objs, name):
            bpy.ops.object.select_all(action='DESELECT')
            for o in objs:
                o.select_set(True)
            bpy.context.view_layer.objects.active = objs[0]
            with _viewport_ctx():
                bpy.ops.object.join()
            j = bpy.context.active_object
            j.name = name
            return j

        # Bake stone
        sg = join_group(stone_parts, "_StoneGrp")
        _, stone_img = bake_to_png(sg, stone_mat, "Stone_Diffuse", BAKE_SIZE, out_dir)
        assign_mat(sg, make_baked_mat("Stone", stone_img))

        # Bake dark stone
        dg = join_group(dark_parts, "_DarkGrp")
        _, dark_img = bake_to_png(dg, dark_mat, "DarkStone_Diffuse", BAKE_SIZE, out_dir)
        assign_mat(dg, make_baked_mat("DarkStone", dark_img))

        # Bake wood (hanya tiang, bendera tetap solid)
        pole_obj = flag_parts[0]
        smart_unwrap(pole_obj)
        _, wood_img = bake_to_png(pole_obj, wood_mat, "Wood_Diffuse", BAKE_SIZE, out_dir)
        assign_mat(pole_obj, make_baked_mat("Wood", wood_img))

        flag_obj = flag_parts[1]   # bendera: warna solid, tidak perlu bake
        assign_mat(flag_obj, flag_mat)

        baked_parts = [sg, dg, pole_obj, flag_obj]
        print("✓ Baking selesai, material diganti ke versi baked")

    else:
        baked_parts = all_parts
        print("  (Baking dilewati — BAKE_ENABLED = False)")

    # ── 5. Join jadi 1 mesh ───────────────────────────────
    # tower = join_mesh_objects(baked_parts, "ArcherTower")
    print("✓ Semua bagian di-join jadi 1 mesh")

    # ── 6. Scale untuk Roblox ─────────────────────────────
    # apply_scale(tower, ROBLOX_SCALE)
    for part in baked_parts:
        apply_scale(part, ROBLOX_SCALE)
    print(f"✓ Scale ×{ROBLOX_SCALE} applied (siap Roblox)")

    # ── 7. Export FBX ─────────────────────────────────────
    # export_fbx(tower, out_dir)
    # print("✓ FBX disimpan")
    os.makedirs(out_dir, exist_ok=True)
    fbx_path = os.path.join(out_dir, "ArcherTower_Roblox.fbx")
    with _viewport_ctx():
        bpy.ops.object.select_all(action='DESELECT')
        for p in baked_parts:
            p.select_set(True)
        bpy.context.view_layer.objects.active = baked_parts[0]
        
        bpy.ops.export_scene.fbx(
            filepath=fbx_path, use_selection=True,
            apply_unit_scale=True, apply_scale_options='FBX_SCALE_NONE',
            axis_forward='-Z', axis_up='Y',
            mesh_smooth_type='FACE', use_mesh_modifiers=True,
            bake_anim=False, path_mode='COPY', embed_textures=False,
        )
    print("✓ FBX disimpan (Multi-part)")

# ── 8. Kembali ke Eevee + focus viewport ──────────────
    # Ambil daftar engine yang valid di versi Blender ini untuk menghindari TypeError
    #valid_engines = bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items.keys()
    
    #if 'BLENDER_EEVEE_NEXT' in valid_engines:
    #    bpy.context.scene.render.engine = 'BLENDER_EEVEE_NEXT'  # Untuk Blender 4.2+
    #elif 'EEVEE' in valid_engines:
    #    bpy.context.scene.render.engine = 'EEVEE'               # Untuk Blender 3.x - 4.1
    #else:
    #    bpy.context.scene.render.engine = 'BLENDER_WORKBENCH'   # Fallback paling aman
        
    #set_active_only(tower)
    #window, area, region = _get_viewport()
    #if area:
    #    with bpy.context.temp_override(window=window, area=area, region=region):
    #        bpy.ops.view3d.view_selected(use_all_regions=False)

    valid_engines = bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items.keys()
    if 'BLENDER_EEVEE_NEXT' in valid_engines:
        bpy.context.scene.render.engine = 'BLENDER_EEVEE_NEXT'
    elif 'EEVEE' in valid_engines:
        bpy.context.scene.render.engine = 'EEVEE'
    else:
        bpy.context.scene.render.engine = 'BLENDER_WORKBENCH'
        
    with _viewport_ctx():
        bpy.ops.view3d.view_selected(use_all_regions=False)

    # ── 9. Summary ────────────────────────────────────────
    print()
    print("=" * 58)
    print("  SELESAI!")
    print(f"  Output folder : {out_dir}")
    print()
    print("  File yang dihasilkan:")
    for f in sorted(os.listdir(out_dir)):
        size_kb = os.path.getsize(os.path.join(out_dir, f)) // 1024
        print(f"    {f:35s}  {size_kb:>5} KB")
    print()
    print("  Cara import ke Roblox Studio:")
    print("  1. Home > Import 3D  →  pilih ArcherTower_Roblox.fbx")
    print("  2. Di popup import, centang 'Import Textures'")
    print("  3. Klik MeshPart hasil import")
    print("  4. Properties > Anchored = true")
    print("  5. Jika ukuran masih kurang pas, ubah ROBLOX_SCALE di")
    print("     bagian KONFIGURASI atas script, lalu run ulang")
    print("=" * 58)

    #return tower
    return baked_parts


# ── Jalankan ──────────────────────────────────────────────
build_archer_tower()

# Untuk skip bake (test cepat), ubah di atas:  BAKE_ENABLED = False
# Untuk ganti output folder, ubah:             OUTPUT_DIR = "C:/folder/xxx"
import bpy
import math

# 1. Bersihkan Scene dari objek default
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

# 2. Fungsi Pembuat Material (PBR & Emissive untuk Neon)
def create_mat(name, color, emission=False, emission_strength=0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs['Base Color'].default_value = color
    if emission:
        bsdf.inputs['Emission Color'].default_value = color
        bsdf.inputs['Emission Strength'].default_value = emission_strength
        # Node tambahan agar emisi lebih kuat di viewport
        nodes = mat.node_tree.nodes
        links = mat.node_tree.links
        emit_node = nodes.new("ShaderNodeEmission")
        emit_node.inputs['Color'].default_value = color
        emit_node.inputs['Strength'].default_value = emission_strength
        mix_shader = nodes.new("ShaderNodeMixShader")
        links.new(bsdf.outputs['BSDF'], mix_shader.inputs[1])
        links.new(emit_node.outputs['Emission'], mix_shader.inputs[2])
        links.new(mix_shader.outputs['Shader'], nodes['Material Output'].inputs['Surface'])
    return mat

# Definisi Material (Sesuai Spesifikasi: Steel, Hazard, Neon Orange)
mat_steel = create_mat("Steel_Gray", (0.3, 0.32, 0.35, 1.0))
mat_dark_steel = create_mat("Dark_Steel", (0.1, 0.1, 0.12, 1.0))
mat_hazard = create_mat("Hazard_Yellow", (0.9, 0.7, 0.0, 1.0))
mat_neon_orange = create_mat("Neon_Orange", (1.0, 0.4, 0.0, 1.0), emission=True, emission_strength=5.0)

base_parts = []
turret_parts = []

# ==========================================
# A. BASE (Landasan Tetap) - Lebar 8m, Tinggi ~5m
# ==========================================
# Platform Hexagonal Utama (Tinggi 0 - 3m)
bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=4, depth=3, location=(0, 0, 1.5))
base_platform = bpy.context.active_object
base_platform.name = "Base_Platform"
base_platform.data.materials.append(mat_steel)
base_parts.append(base_platform)

# Cincin Hazard Kuning (Tinggi 3m - 3.5m)
bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=4.1, depth=0.5, location=(0, 0, 3.25))
hazard_ring = bpy.context.active_object
hazard_ring.name = "Hazard_Ring"
hazard_ring.data.materials.append(mat_hazard)
base_parts.append(hazard_ring)

# Rumah Roda Gigi / Gear Housing (Tinggi 3.5m - 5.5m)
bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=2.5, depth=2, location=(0, 0, 4.5))
gear_housing = bpy.context.active_object
gear_housing.name = "Gear_Housing"
gear_housing.data.materials.append(mat_dark_steel)
base_parts.append(gear_housing)

# Roda Gigi Tengah (Stylized Gear)
bpy.ops.mesh.primitive_torus_add(major_radius=1.5, minor_radius=0.4, major_segments=12, location=(0, 0, 5.5))
gear = bpy.context.active_object
gear.name = "Central_Gear"
gear.data.materials.append(mat_steel)
base_parts.append(gear)

# Gabungkan semua bagian Base & Atur Pivot ke (0,0,0)
bpy.ops.object.select_all(action='DESELECT')
for obj in base_parts:
    obj.select_set(True)
bpy.context.view_layer.objects.active = base_parts[0]
bpy.ops.object.join()
base_obj = bpy.context.active_object
base_obj.name = "CannonTower_Base"

bpy.context.scene.cursor.location = (0, 0, 0)
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
base_obj.location = (0, 0, 0)


# ==========================================
# B. TURRET (Kepala Menara) - Sisa Tinggi s/d 12m
# ==========================================
# Turret Pivot Base (Tinggi 5.5m - 8.5m)
bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=1.8, depth=3, location=(0, 0, 7))
pivot_base = bpy.context.active_object
pivot_base.name = "Turret_Pivot"
pivot_base.data.materials.append(mat_dark_steel)
turret_parts.append(pivot_base)

# Cannon Mount (Dudukan Meriam) (Tinggi 8.5m - 11.5m)
bpy.ops.mesh.primitive_cube_add(size=3, location=(0, 0, 10))
mount = bpy.context.active_object
mount.name = "Cannon_Mount"
mount.scale = (1, 1.5, 1) # Memanjang ke sumbu Y (Arah tembak)
bpy.ops.object.transform_apply(scale=True)
mount.data.materials.append(mat_steel)
turret_parts.append(mount)

# Dual Barrels (Laras Meriam Ganda)
barrel_length = 6
barrel_radius = 0.7
for i in [-1, 1]: # Kiri (-1) dan Kanan (1)
    # Laras Utama
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=barrel_radius, depth=barrel_length, location=(i * 1.2, 3, 10))
    barrel = bpy.context.active_object
    barrel.rotation_euler[0] = math.radians(90) # Mengarah ke sumbu Y
    barrel.name = f"Barrel_{'Left' if i==-1 else 'Right'}"
    barrel.data.materials.append(mat_dark_steel)
    turret_parts.append(barrel)
    
    # Neon Energy Rings (Garis Energi Oranye di sepanjang laras)
    for r in range(3):
        ring_pos = 1.5 + r * 1.5
        bpy.ops.mesh.primitive_torus_add(major_radius=barrel_radius + 0.15, minor_radius=0.15, location=(i * 1.2, ring_pos, 10))
        ring = bpy.context.active_object
        ring.rotation_euler[0] = math.radians(90)
        ring.name = f"Neon_Ring_{i}_{r}"
        ring.data.materials.append(mat_neon_orange)
        turret_parts.append(ring)

# Gabungkan semua bagian Turret & Atur Pivot ke Titik Rotasi (0,0,7)
bpy.ops.object.select_all(action='DESELECT')
for obj in turret_parts:
    obj.select_set(True)
bpy.context.view_layer.objects.active = turret_parts[0]
bpy.ops.object.join()
turret_obj = bpy.context.active_object
turret_obj.name = "CannonTower_Turret"

bpy.context.scene.cursor.location = (0, 0, 7) # Titik engsel rotasi
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
turret_obj.location = (0, 0, 7) 

# ==========================================
# C. FINALISASI (Sesuai Aturan Ekspor)
# ==========================================
# Apply All Transforms (Wajib sebelum ekspor FBX)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


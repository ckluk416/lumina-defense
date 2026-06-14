"""
=============================================================================
LUMINA DEFENSE - Cannon Tower 3D Model Generator
=============================================================================
Versi: 2.0 (Fixed for Blender 4.0+)
Spesifikasi:
- Dimensi: 8 studs (X) x 8 studs (Z) x 12 studs (Y)
- Base: Landasan baja heksagonal dengan roda gigi mekanis
- Turret: Meriam laras ganda (dual-barrel heavy cannon)
- Warna: Logam abu-abu baja, aksen kuning/hitam hazard
- Glow/Neon: Garis energi oranye di laras meriam
- Polygon Budget: < 2,500 tris
- Origin: Bottom Center (0, 0, 0)
=============================================================================
"""

import bpy
import bmesh
import math
from mathutils import Vector
import os

# ============================================================================
# KONFIGURASI UTAMA
# ============================================================================

OUTPUT_DIR = "F:/Documents/coding/tugas_semester-4/Computer-Graphic/lumina-defense/assets/3d/cannon-tower/"

# Dimensi sesuai spesifikasi (1 meter = 1 stud)
TOWER_WIDTH_X = 8.0
TOWER_WIDTH_Z = 8.0
TOWER_HEIGHT_Y = 12.0

# Material names
MAT_STEEL = "Cannon_Steel"
MAT_STEEL_DARK = "Cannon_Steel_Dark"
MAT_HAZARD_YELLOW = "Cannon_Hazard_Yellow"
MAT_HAZARD_BLACK = "Cannon_Hazard_Black"
MAT_GEAR = "Cannon_Gear"
MAT_NEON_ORANGE = "Cannon_Neon_Orange"

# ============================================================================
# FUNGSI UTILITAS
# ============================================================================

def clear_scene():
    """Hapus semua objek di scene untuk memulai dari awal"""
    # Deselect all first
    bpy.ops.object.select_all(action='DESELECT')
    
    # Select and delete all mesh objects
    bpy.ops.object.select_by_type(type='MESH')
    if len(bpy.context.selected_objects) > 0:
        bpy.ops.object.delete(use_global=False)
    
    # Hapus material yang tidak digunakan
    for mat in bpy.data.materials:
        if mat.users == 0:
            bpy.data.materials.remove(mat)
    
    bpy.ops.object.select_all(action='DESELECT')


def create_material(name, color, metallic=0.8, roughness=0.3, 
                    emission_color=None, emission_strength=0.0):
    """
    Membuat material PBR stylized
    Kompatibel dengan Blender 4.0+ (Emission menggunakan node terpisah)
    """
    # Check if material already exists
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    
    # Clear default nodes
    nodes.clear()
    
    # Output node
    output = nodes.new('ShaderNodeOutputMaterial')
    output.location = (400, 0)
    
    if emission_color and emission_strength > 0:
        # For emissive materials: Mix Principled BSDF with Emission
        # Using Add Shader for glow effect
        
        # Principled BSDF (base)
        bsdf = nodes.new('ShaderNodeBsdfPrincipled')
        bsdf.location = (0, -100)
        bsdf.inputs['Base Color'].default_value = color
        bsdf.inputs['Metallic'].default_value = metallic
        bsdf.inputs['Roughness'].default_value = roughness
        
        # Emission node (separate in Blender 4.0+)
        emission = nodes.new('ShaderNodeEmission')
        emission.location = (0, 100)
        emission.inputs['Color'].default_value = emission_color
        emission.inputs['Strength'].default_value = emission_strength
        
        # Add shader to combine
        add_shader = nodes.new('ShaderNodeAddShader')
        add_shader.location = (200, 0)
        
        # Connect: BSDF + Emission -> Output
        links.new(bsdf.outputs['BSDF'], add_shader.inputs[0])
        links.new(emission.outputs['Emission'], add_shader.inputs[1])
        links.new(add_shader.outputs['Shader'], output.inputs['Surface'])
    else:
        # Standard PBR material (no emission)
        bsdf = nodes.new('ShaderNodeBsdfPrincipled')
        bsdf.location = (0, 0)
        bsdf.inputs['Base Color'].default_value = color
        bsdf.inputs['Metallic'].default_value = metallic
        bsdf.inputs['Roughness'].default_value = roughness
        
        # Connect: BSDF -> Output
        links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])
    
    return mat


def create_neon_material(name, color, emission_strength=5.0):
    """Membuat material neon untuk efek glow (Blender 4.0+ compatible)"""
    return create_material(
        name=name,
        color=color,
        metallic=0.0,
        roughness=0.0,
        emission_color=color,
        emission_strength=emission_strength
    )


def set_origin_to_bottom(obj):
    """Mengatur origin ke bagian bawah tengah objek"""
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    
    # Apply transforms first
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=False)
    
    # Set origin to bottom center
    bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOTTOM')


def join_objects(objects, name):
    """Menggabungkan beberapa objek menjadi satu"""
    if len(objects) < 2:
        if objects:
            objects[0].name = name
        return objects[0] if objects else None
    
    bpy.context.view_layer.objects.active = objects[0]
    for obj in objects:
        obj.select_set(True)
    
    bpy.ops.object.join()
    
    new_obj = bpy.context.active_object
    new_obj.name = name
    return new_obj


def clean_mesh(obj):
    """Membersihkan mesh: merge by distance, recalculate normals, triangulate"""
    if obj is None:
        return None
        
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    
    bpy.ops.object.mode_set(mode='EDIT')
    
    # Select all
    bpy.ops.mesh.select_all(action='SELECT')
    
    # Remove doubles
    bpy.ops.mesh.remove_doubles(threshold=0.001)
    
    # Recalculate normals outside
    bpy.ops.mesh.normals_make_consistent(inside=False)
    
    # Triangulate (no n-gons)
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.quads_convert_to_tris(quad_method='BEAUTY', ngon_method='BEAUTY')
    
    bpy.ops.object.mode_set(mode='OBJECT')
    
    return obj


def get_tri_count(obj):
    """Menghitung jumlah triangles dalam mesh"""
    if obj is None or obj.type != 'MESH':
        return 0
    tri_count = 0
    for polygon in obj.data.polygons:
        tri_count += len(polygon.vertices) - 2
    return tri_count


# ============================================================================
# PEMBUATAN KOMPONEN BASE
# ============================================================================

def create_hexagonal_base():
    """Membuat landasan baja heksagonal tebal dengan roda gigi di tengah"""
    base_objects = []
    
    # ========================================
    # 1. Platform heksagonal utama
    # ========================================
    hex_radius = 3.8
    hex_height = 1.5
    
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6,
        radius=hex_radius,
        depth=hex_height,
        location=(0, 0, hex_height/2)
    )
    hex_base = bpy.context.active_object
    hex_base.name = "Base_Hex_Platform"
    hex_base.data.materials.append(bpy.data.materials[MAT_STEEL])
    base_objects.append(hex_base)
    
    # ========================================
    # 2. Ring tepi platform
    # ========================================
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6,
        radius=hex_radius + 0.15,
        depth=0.2,
        location=(0, 0, 0.1)
    )
    edge_ring = bpy.context.active_object
    edge_ring.name = "Base_Edge_Ring"
    edge_ring.data.materials.append(bpy.data.materials[MAT_STEEL_DARK])
    base_objects.append(edge_ring)
    
    # ========================================
    # 3. Roda gigi mekanis
    # ========================================
    gear_objects = create_gear_mechanism()
    base_objects.extend(gear_objects)
    
    # ========================================
    # 4. Garis hazard kuning/hitam
    # ========================================
    hazard_objects = create_hazard_stripes()
    base_objects.extend(hazard_objects)
    
    # ========================================
    # 5. Pilar penyangga
    # ========================================
    pillar_objects = create_base_pillars()
    base_objects.extend(pillar_objects)
    
    return base_objects


def create_gear_mechanism():
    """Membuat roda gigi mekanis di tengah base"""
    gear_objects = []
    
    # ========================================
    # Gear utama - menggunakan cylinder bergerigi
    # ========================================
    gear_radius = 2.0
    gear_height = 0.3
    teeth_count = 12
    tooth_depth = 0.3
    
    # Buat gear dengan metode yang lebih sederhana
    # Base cylinder
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=teeth_count * 2,
        radius=gear_radius - tooth_depth/2,
        depth=gear_height,
        location=(0, 0, 1.5 + gear_height/2)
    )
    gear_main = bpy.context.active_object
    gear_main.name = "Gear_Main"
    
    # Modifikasi vertices untuk membuat teeth
    bpy.context.view_layer.objects.active = gear_main
    gear_main.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    
    bm = bmesh.from_edit_mesh(gear_main.data)
    
    # Get top and bottom edge loops
    top_verts = []
    bottom_verts = []
    
    for v in bm.verts:
        if v.co.z > 1.65:  # Top vertices
            top_verts.append(v)
        elif v.co.z < 1.35:  # Bottom vertices
            bottom_verts.append(v)
    
    # Sort by angle
    def sort_by_angle(verts):
        return sorted(verts, key=lambda v: math.atan2(v.co.y, v.co.x))
    
    top_verts = sort_by_angle(top_verts)
    bottom_verts = sort_by_angle(bottom_verts)
    
    # Alternate vertices to create teeth pattern
    for i, (tv, bv) in enumerate(zip(top_verts, bottom_verts)):
        if i % 2 == 0:
            # Extend outward for tooth
            angle = math.atan2(tv.co.y, tv.co.x)
            tv.co.x += tooth_depth * math.cos(angle)
            tv.co.y += tooth_depth * math.sin(angle)
            bv.co.x += tooth_depth * math.cos(angle)
            bv.co.y += tooth_depth * math.sin(angle)
    
    bmesh.update_edit_mesh(gear_main.data)
    bpy.ops.object.mode_set(mode='OBJECT')
    
    gear_main.data.materials.append(bpy.data.materials[MAT_GEAR])
    gear_objects.append(gear_main)
    
    # ========================================
    # Gear kecil dekoratif (4 buah)
    # ========================================
    small_gear_radius = 0.6
    small_teeth = 8
    positions = [
        (1.8, 1.8),
        (-1.8, 1.8),
        (1.8, -1.8),
        (-1.8, -1.8)
    ]
    
    for idx, (px, py) in enumerate(positions):
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=small_teeth * 2,
            radius=small_gear_radius,
            depth=0.15,
            location=(px, py, 1.57)
        )
        small_gear = bpy.context.active_object
        small_gear.name = f"Gear_Small_{idx}"
        
        # Add teeth to small gear
        bpy.context.view_layer.objects.active = small_gear
        small_gear.select_set(True)
        bpy.ops.object.mode_set(mode='EDIT')
        
        bm = bmesh.from_edit_mesh(small_gear.data)
        
        top_v = [v for v in bm.verts if v.co.z > 1.64]
        bottom_v = [v for v in bm.verts if v.co.z < 1.5]
        
        top_v = sorted(top_v, key=lambda v: math.atan2(v.co.y, v.co.x))
        bottom_v = sorted(bottom_v, key=lambda v: math.atan2(v.co.y, v.co.x))
        
        for i, (tv, bv) in enumerate(zip(top_v, bottom_v)):
            if i % 2 == 0:
                angle = math.atan2(tv.co.y, tv.co.x)
                tv.co.x += 0.12 * math.cos(angle)
                tv.co.y += 0.12 * math.sin(angle)
                bv.co.x += 0.12 * math.cos(angle)
                bv.co.y += 0.12 * math.sin(angle)
        
        bmesh.update_edit_mesh(small_gear.data)
        bpy.ops.object.mode_set(mode='OBJECT')
        
        small_gear.data.materials.append(bpy.data.materials[MAT_GEAR])
        gear_objects.append(small_gear)
    
    # ========================================
    # Center axle
    # ========================================
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12,
        radius=0.4,
        depth=0.8,
        location=(0, 0, 1.7)
    )
    axle = bpy.context.active_object
    axle.name = "Gear_Axle"
    axle.data.materials.append(bpy.data.materials[MAT_STEEL_DARK])
    gear_objects.append(axle)
    
    return gear_objects


def create_hazard_stripes():
    """Membuat garis hazard kuning/hitam di sisi landasan"""
    hazard_objects = []
    
    stripe_height = 0.25
    stripe_width = 0.35
    stripe_length = 0.8
    
    # Buat stripe di setiap sisi heksagonal
    for side in range(6):
        angle = (2 * math.pi * side) / 6
        next_angle = (2 * math.pi * (side + 1)) / 6
        mid_angle = (angle + next_angle) / 2
        
        # Posisi di tengah sisi
        pos_x = 2.7 * math.cos(mid_angle)
        pos_y = 2.7 * math.sin(mid_angle)
        rot_z = math.degrees(mid_angle) - 90
        
        # 2 stripe per sisi dengan posisi berbeda
        for i in range(2):
            offset = (i - 0.5) * 0.7
            perp_angle = mid_angle + math.pi / 2
            sx = pos_x + offset * math.cos(perp_angle)
            sy = pos_y + offset * math.sin(perp_angle)
            
            bpy.ops.mesh.primitive_cube_add(
                size=1,
                location=(sx, sy, 0.45)
            )
            stripe = bpy.context.active_object
            stripe.name = f"Hazard_Stripe_{side}_{i}"
            stripe.scale = (stripe_width, stripe_length, stripe_height)
            stripe.rotation_euler = (0, 0, math.radians(rot_z))
            
            # Alternate warna
            if (side + i) % 2 == 0:
                stripe.data.materials.append(bpy.data.materials[MAT_HAZARD_YELLOW])
            else:
                stripe.data.materials.append(bpy.data.materials[MAT_HAZARD_BLACK])
            
            hazard_objects.append(stripe)
    
    return hazard_objects


def create_base_pillars():
    """Membuat pilar penyangga dari base ke turret"""
    pillar_objects = []
    
    pillar_height = 4.0
    pillar_radius = 0.35
    
    # 6 pilar di sudut heksagonal
    for i in range(6):
        angle = (2 * math.pi * i) / 6
        px = 2.5 * math.cos(angle)
        py = 2.5 * math.sin(angle)
        
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=8,
            radius=pillar_radius,
            depth=pillar_height,
            location=(px, py, 1.5 + pillar_height/2)
        )
        pillar = bpy.context.active_object
        pillar.name = f"Base_Pillar_{i}"
        pillar.data.materials.append(bpy.data.materials[MAT_STEEL_DARK])
        pillar_objects.append(pillar)
    
    # Platform atas pilar
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6,
        radius=3.2,
        depth=0.3,
        location=(0, 0, 1.5 + pillar_height + 0.15)
    )
    top_platform = bpy.context.active_object
    top_platform.name = "Base_Top_Platform"
    top_platform.data.materials.append(bpy.data.materials[MAT_STEEL])
    pillar_objects.append(top_platform)
    
    # Cross beams antar pilar (struktur tambahan)
    for i in range(6):
        angle1 = (2 * math.pi * i) / 6
        angle2 = (2 * math.pi * (i + 1)) / 6
        
        x1, y1 = 2.5 * math.cos(angle1), 2.5 * math.sin(angle1)
        x2, y2 = 2.5 * math.cos(angle2), 2.5 * math.sin(angle2)
        
        mid_x, mid_y = (x1 + x2) / 2, (y1 + y2) / 2
        length = math.sqrt((x2-x1)**2 + (y2-y1)**2)
        rot_z = math.degrees(math.atan2(y2-y1, x2-x1))
        
        bpy.ops.mesh.primitive_cube_add(
            size=1,
            location=(mid_x, mid_y, 3.5)
        )
        beam = bpy.context.active_object
        beam.name = f"Cross_Beam_{i}"
        beam.scale = (length, 0.15, 0.15)
        beam.rotation_euler = (0, 0, math.radians(rot_z))
        beam.data.materials.append(bpy.data.materials[MAT_STEEL_DARK])
        pillar_objects.append(beam)
    
    return pillar_objects


# ============================================================================
# PEMBUATAN KOMPONEN TURRET
# ============================================================================

def create_turret():
    """Membuat meriam laras ganda (dual-barrel heavy cannon)"""
    turret_objects = []
    
    turret_base_y = 6.0
    
    # ========================================
    # 1. Mounting/dudukan turret
    # ========================================
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12,
        radius=2.0,
        depth=0.8,
        location=(0, 0, turret_base_y + 0.4)
    )
    turret_mount = bpy.context.active_object
    turret_mount.name = "Turret_Mount"
    turret_mount.data.materials.append(bpy.data.materials[MAT_STEEL_DARK])
    turret_objects.append(turret_mount)
    
    # Dome atas mount
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=12,
        ring_count=6,
        radius=1.8,
        location=(0, 0, turret_base_y + 0.8)
    )
    dome = bpy.context.active_object
    dome.name = "Turret_Dome"
    dome.scale = (1, 1, 0.5)
    dome.data.materials.append(bpy.data.materials[MAT_STEEL])
    turret_objects.append(dome)
    
    # ========================================
    # 2. Housing meriam
    # ========================================
    bpy.ops.mesh.primitive_cube_add(
        size=1,
        location=(0, -0.5, turret_base_y + 1.2)
    )
    housing = bpy.context.active_object
    housing.name = "Turret_Housing"
    housing.scale = (2.4, 1.8, 1.0)
    housing.data.materials.append(bpy.data.materials[MAT_STEEL])
    turret_objects.append(housing)
    
    # ========================================
    # 3. Laras meriam ganda
    # ========================================
    barrel_objects = create_dual_barrels(turret_base_y)
    turret_objects.extend(barrel_objects)
    
    # ========================================
    # 4. Garis energi oranye (NEON - terpisah)
    # ========================================
    neon_objects = create_barrel_neon_lines(turret_base_y)
    turret_objects.extend(neon_objects)
    
    # ========================================
    # 5. Detail tambahan
    # ========================================
    detail_objects = create_turret_details(turret_base_y)
    turret_objects.extend(detail_objects)
    
    return turret_objects


def create_dual_barrels(base_y):
    """Membuat laras meriam ganda"""
    barrel_objects = []
    
    barrel_length = 4.5
    barrel_radius = 0.45
    barrel_separation = 0.8
    barrel_y = base_y + 1.4
    
    # Laras kiri
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12,
        radius=barrel_radius,
        depth=barrel_length,
        location=(-barrel_separation/2, barrel_length/2 - 0.5, barrel_y)
    )
    barrel_left = bpy.context.active_object
    barrel_left.name = "Barrel_Left"
    barrel_left.rotation_euler = (math.radians(90), 0, 0)
    barrel_left.data.materials.append(bpy.data.materials[MAT_STEEL_DARK])
    barrel_objects.append(barrel_left)
    
    # Laras kanan
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12,
        radius=barrel_radius,
        depth=barrel_length,
        location=(barrel_separation/2, barrel_length/2 - 0.5, barrel_y)
    )
    barrel_right = bpy.context.active_object
    barrel_right.name = "Barrel_Right"
    barrel_right.rotation_euler = (math.radians(90), 0, 0)
    barrel_right.data.materials.append(bpy.data.materials[MAT_STEEL_DARK])
    barrel_objects.append(barrel_right)
    
    # Muzzle brake kiri
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=8,
        radius=barrel_radius + 0.1,
        depth=0.4,
        location=(-barrel_separation/2, 4.0, barrel_y)
    )
    muzzle_left = bpy.context.active_object
    muzzle_left.name = "Muzzle_Left"
    muzzle_left.rotation_euler = (math.radians(90), 0, 0)
    muzzle_left.data.materials.append(bpy.data.materials[MAT_STEEL])
    barrel_objects.append(muzzle_left)
    
    # Muzzle brake kanan
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=8,
        radius=barrel_radius + 0.1,
        depth=0.4,
        location=(barrel_separation/2, 4.0, barrel_y)
    )
    muzzle_right = bpy.context.active_object
    muzzle_right.name = "Muzzle_Right"
    muzzle_right.rotation_euler = (math.radians(90), 0, 0)
    muzzle_right.data.materials.append(bpy.data.materials[MAT_STEEL])
    barrel_objects.append(muzzle_right)
    
    # Shroud penghubung antar laras
    bpy.ops.mesh.primitive_cube_add(
        size=1,
        location=(0, 0.5, barrel_y)
    )
    shroud = bpy.context.active_object
    shroud.name = "Barrel_Shroud"
    shroud.scale = (barrel_separation + barrel_radius * 2, 1.5, barrel_radius + 0.1)
    shroud.data.materials.append(bpy.data.materials[MAT_STEEL])
    barrel_objects.append(shroud)
    
    return barrel_objects


def create_barrel_neon_lines(base_y):
    """
    Membuat garis-garis energi oranye di sepanjang laras
    OBJEK TERPISAH untuk diubah menjadi Neon di Roblox
    """
    neon_objects = []
    
    barrel_separation = 0.8
    neon_y = base_y + 1.4
    
    # Garis neon di atas laras kiri
    for i in range(4):
        y_pos = 0.2 + i * 1.0
        
        bpy.ops.mesh.primitive_cube_add(
            size=1,
            location=(-barrel_separation/2, y_pos, neon_y + 0.48)
        )
        neon_line = bpy.context.active_object
        neon_line.name = f"Neon_Line_Left_{i}"
        neon_line.scale = (0.06, 0.7, 0.06)
        neon_line.data.materials.append(bpy.data.materials[MAT_NEON_ORANGE])
        neon_objects.append(neon_line)
    
    # Garis neon di atas laras kanan
    for i in range(4):
        y_pos = 0.2 + i * 1.0
        
        bpy.ops.mesh.primitive_cube_add(
            size=1,
            location=(barrel_separation/2, y_pos, neon_y + 0.48)
        )
        neon_line = bpy.context.active_object
        neon_line.name = f"Neon_Line_Right_{i}"
        neon_line.scale = (0.06, 0.7, 0.06)
        neon_line.data.materials.append(bpy.data.materials[MAT_NEON_ORANGE])
        neon_objects.append(neon_line)
    
    # Garis neon di bawah laras (center line)
    for i in range(3):
        y_pos = 0.7 + i * 1.0
        
        bpy.ops.mesh.primitive_cube_add(
            size=1,
            location=(0, y_pos, neon_y - 0.48)
        )
        neon_line = bpy.context.active_object
        neon_line.name = f"Neon_Line_Center_{i}"
        neon_line.scale = (0.05, 0.5, 0.05)
        neon_line.data.materials.append(bpy.data.materials[MAT_NEON_ORANGE])
        neon_objects.append(neon_line)
    
    # Glow ring di muzzle (menggunakan torus)
    for side_x in [-barrel_separation/2, barrel_separation/2]:
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.35,
            minor_radius=0.04,
            location=(side_x, 4.15, neon_y)
        )
        glow_ring = bpy.context.active_object
        glow_ring.name = f"Neon_Muzzle_Ring_{'L' if side_x < 0 else 'R'}"
        glow_ring.rotation_euler = (math.radians(90), 0, 0)
        glow_ring.data.materials.append(bpy.data.materials[MAT_NEON_ORANGE])
        neon_objects.append(glow_ring)
    
    return neon_objects


def create_turret_details(base_y):
    """Membuat detail tambahan turret"""
    detail_objects = []
    
    # Breach mechanism
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=8,
        radius=1.0,
        depth=0.5,
        location=(0, -1.5, base_y + 1.4)
    )
    breach = bpy.context.active_object
    breach.name = "Turret_Breach"
    breach.rotation_euler = (math.radians(90), 0, 0)
    breach.data.materials.append(bpy.data.materials[MAT_STEEL_DARK])
    detail_objects.append(breach)
    
    # Side armor plates
    for side in [-1, 1]:
        bpy.ops.mesh.primitive_cube_add(
            size=1,
            location=(side * 1.5, 0, base_y + 1.2)
        )
        armor_plate = bpy.context.active_object
        armor_plate.name = f"Side_Armor_{'Left' if side < 0 else 'Right'}"
        armor_plate.scale = (0.15, 1.2, 0.8)
        armor_plate.data.materials.append(bpy.data.materials[MAT_STEEL])
        detail_objects.append(armor_plate)
    
    # Antenna
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6,
        radius=0.06,
        depth=1.0,
        location=(0.8, -0.5, base_y + 1.9)
    )
    antenna = bpy.context.active_object
    antenna.name = "Turret_Antenna"
    antenna.data.materials.append(bpy.data.materials[MAT_STEEL_DARK])
    detail_objects.append(antenna)
    
    # Antenna tip (neon)
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=6,
        ring_count=4,
        radius=0.1,
        location=(0.8, -0.5, base_y + 2.4)
    )
    antenna_tip = bpy.context.active_object
    antenna_tip.name = "Antenna_Tip_Neon"
    antenna_tip.data.materials.append(bpy.data.materials[MAT_NEON_ORANGE])
    detail_objects.append(antenna_tip)
    
    # Viewport/slot di housing
    bpy.ops.mesh.primitive_cube_add(
        size=1,
        location=(0, -0.3, base_y + 1.5)
    )
    viewport = bpy.context.active_object
    viewport.name = "Turret_Viewport"
    viewport.scale = (1.5, 0.1, 0.4)
    viewport.data.materials.append(bpy.data.materials[MAT_STEEL_DARK])
    detail_objects.append(viewport)
    
    return detail_objects


# ============================================================================
# FUNGSI UTAMA
# ============================================================================

def create_cannon_tower():
    """Fungsi utama untuk membuat seluruh Cannon Tower"""
    
    print("=" * 60)
    print("LUMINA DEFENSE - Cannon Tower Generator v2.0")
    print("Compatible with Blender 4.0+")
    print("=" * 60)
    
    # Clear scene
    print("\n[1/7] Membersihkan scene...")
    clear_scene()
    
    # Create materials
    print("[2/7] Membuat materials...")
    create_material(MAT_STEEL, (0.45, 0.45, 0.48, 1.0), metallic=0.9, roughness=0.3)
    create_material(MAT_STEEL_DARK, (0.25, 0.25, 0.28, 1.0), metallic=0.85, roughness=0.4)
    create_material(MAT_HAZARD_YELLOW, (0.95, 0.75, 0.1, 1.0), metallic=0.3, roughness=0.5)
    create_material(MAT_HAZARD_BLACK, (0.08, 0.08, 0.1, 1.0), metallic=0.5, roughness=0.6)
    create_material(MAT_GEAR, (0.55, 0.52, 0.48, 1.0), metallic=0.95, roughness=0.25)
    create_neon_material(MAT_NEON_ORANGE, (1.0, 0.4, 0.05, 1.0), emission_strength=5.0)
    
    # Create Base
    print("[3/7] Membuat Base...")
    base_objects = create_hexagonal_base()
    
    # Create Turret
    print("[4/7] Membuat Turret...")
    turret_objects = create_turret()
    
    # Separate neon objects
    print("[5/7] Memisahkan objek Neon...")
    neon_objects = [obj for obj in turret_objects if "Neon" in obj.name]
    turret_non_neon = [obj for obj in turret_objects if obj not in neon_objects]
    
    # Join base
    print("[6/7] Menggabungkan komponen...")
    base_joined = join_objects(base_objects, "CannonTower_Base")
    if base_joined:
        clean_mesh(base_joined)
    
    # Join turret (non-neon)
    turret_joined = join_objects(turret_non_neon, "CannonTower_Turret")
    if turret_joined:
        clean_mesh(turret_joined)
    
    # Join neon
    if neon_objects:
        neon_joined = join_objects(neon_objects, "CannonTower_Neon")
        if neon_joined:
            clean_mesh(neon_joined)
    else:
        neon_joined = None
    
    # Set origins
    print("[7/7] Mengatur origin dan posisi...")
    if base_joined:
        set_origin_to_bottom(base_joined)
        base_joined.location = (0, 0, 0)
    
    if turret_joined:
        bpy.context.view_layer.objects.active = turret_joined
        turret_joined.select_set(True)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=False)
        bpy.ops.object.origin_set(type='ORIGIN_CENTER_OF_MASS')
    
    if neon_joined:
        bpy.context.view_layer.objects.active = neon_joined
        neon_joined.select_set(True)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=False)
        bpy.ops.object.origin_set(type='ORIGIN_CENTER_OF_MASS')
    
    # Apply all transforms
    bpy.ops.object.select_all(action='DESELECT')
    for obj in bpy.context.scene.objects:
        if obj.type == 'MESH':
            obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.select_all(action='DESELECT')
    
    # Print statistics
    print("\n" + "=" * 60)
    print("STATISTIK MODEL")
    print("=" * 60)
    
    total_tris = 0
    for obj in bpy.context.scene.objects:
        if obj.type == 'MESH':
            tris = get_tri_count(obj)
            total_tris += tris
            print(f"  {obj.name}: {tris} tris")
    
    print(f"\n  TOTAL TRIANGLES: {total_tris}")
    print(f"  Target: < 2500 tris")
    print(f"  Status: {'✓ OK' if total_tris < 2500 else '✗ OVER BUDGET'}")
    
    # Check dimensions
    print("\n  DIMENSI AKHIR:")
    if base_joined:
        bpy.context.view_layer.objects.active = base_joined
        bbox = [base_joined.matrix_world @ Vector(corner) for corner in base_joined.bound_box]
        min_x = min(v.x for v in bbox)
        max_x = max(v.x for v in bbox)
        min_z = min(v.z for v in bbox)
        max_z = max(v.z for v in bbox)
        max_y = max(v.y for v in bbox)
        print(f"    Lebar X: {max_x - min_x:.2f} studs (target: 8)")
        print(f"    Lebar Z: {max_z - min_z:.2f} studs (target: 8)")
        print(f"    Tinggi Y: {max_y:.2f} studs (target: 12)")
    
    print("\n" + "=" * 60)
    print("Pembuatan model selesai!")
    print("=" * 60)
    
    return base_joined, turret_joined, neon_joined


def save_project():
    """Menyimpan project ke direktori yang ditentukan"""
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    blend_path = os.path.join(OUTPUT_DIR, "CannonTower_Roblox.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    print(f"\nProject disimpan di: {blend_path}")
    return blend_path


def export_fbx():
    """Mengekspor model ke FBX sesuai spesifikasi"""
    fbx_path = os.path.join(OUTPUT_DIR, "CannonTower_Roblox.fbx")
    
    bpy.ops.object.select_all(action='DESELECT')
    for obj in bpy.context.scene.objects:
        if obj.type == 'MESH':
            obj.select_set(True)
    
    bpy.ops.export_scene.fbx(
        filepath=fbx_path,
        use_selection=True,
        object_types={'MESH'},
        use_custom_props=False,
        apply_scale_options='FBX_SCALE_ALL',
        bake_space_transform=True,
        mesh_smooth_type='FACE',
        path_mode='COPY',
        embed_textures=True,
        use_mesh_modifiers=True,
        add_leaf_bones=False
    )
    
    print(f"FBX diekspor ke: {fbx_path}")
    return fbx_path


# ============================================================================
# EKSEKUSI UTAMA
# ============================================================================

if __name__ == "__main__":
    # Buat model
    base, turret, neon = create_cannon_tower()
    
    # Simpan project
    save_project()
    
    # Ekspor FBX (uncomment baris di bawah jika ingin langsung ekspor)
    # export_fbx()
    
    print("\n" + "=" * 60)
    print("✓ Cannon Tower berhasil dibuat!")
    print("=" * 60)
    print("\nINSTRUKSI UNTUK ROBLOX:")
    print("1. Import 'CannonTower_Roblox.fbx' ke Roblox Studio")
    print("2. Objek 'CannonTower_Neon' -> ubah Material ke 'Neon'")
    print("3. Parent 'CannonTower_Turret' dan 'CannonTower_Neon' ke 'CannonTower_Base'")
    print("4. Turret dapat dirotasi untuk aiming mechanism")
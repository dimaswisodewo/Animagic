#
#  create_test_fixture.py
#  AniMagic
#
#  Created by dimaswisodewo on 22/07/26.
#

"""Create a procedural static prop for the opt-in pipeline integration test."""

from __future__ import annotations

import sys
from pathlib import Path

import bpy


arguments = sys.argv[sys.argv.index("--") + 1 :]
output = Path(arguments[0]).resolve()
options = set(arguments[1:])
output.parent.mkdir(parents=True, exist_ok=True)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.mesh.primitive_uv_sphere_add(segments=128, ring_count=64, radius=0.1)
delivery = bpy.context.active_object
delivery.name = "FixtureMesh"
if "--ambiguous" in options:
    duplicate = delivery.copy()
    duplicate.data = delivery.data.copy()
    duplicate.name = "SecondFixtureMesh"
    duplicate.location.x = 0.3
    bpy.context.collection.objects.link(duplicate)

texture_dir = output.parent / "fixture-textures"
texture_dir.mkdir(parents=True, exist_ok=True)
scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.unit_settings.scale_length = 1.0
if "--nonmetric" in options:
    scene.unit_settings.system = "NONE"


def make_texture(name: str, path: Path, color: tuple[float, float, float, float], file_format: str):
    image = bpy.data.images.new(name, width=128, height=64, alpha=False)
    image.generated_color = color
    image.file_format = file_format
    scene.render.image_settings.file_format = file_format
    scene.render.image_settings.color_mode = "RGB"
    scene.render.image_settings.color_depth = "8"
    image.save_render(str(path), scene=scene)
    image.filepath = str(path)
    return image


base = make_texture("FixtureBase", texture_dir / "base.png", (0.1, 0.7, 0.2, 1.0), "PNG")
normal = make_texture("FixtureNormal", texture_dir / "normal.png", (0.5, 0.5, 1.0, 1.0), "PNG")
normal.colorspace_settings.name = "Non-Color"

material = bpy.data.materials.new("FixtureMaterial")
material.use_nodes = True
nodes = material.node_tree.nodes
links = material.node_tree.links
principled = nodes.get("Principled BSDF")
base_node = nodes.new("ShaderNodeTexImage")
base_node.image = base
normal_node = nodes.new("ShaderNodeTexImage")
normal_node.image = normal
links.new(base_node.outputs["Color"], principled.inputs["Base Color"])
if "--export-compatible" in options:
    links.new(normal_node.outputs["Color"], principled.inputs["Normal"])
    output_node = nodes.get("Material Output")
    for link in list(output_node.inputs["Surface"].links):
        links.remove(link)
    ambient_occlusion = nodes.new("ShaderNodeAmbientOcclusion")
    color_ramp = nodes.new("ShaderNodeValToRGB")
    mix_shader = nodes.new("ShaderNodeMixShader")
    links.new(ambient_occlusion.outputs["Color"], color_ramp.inputs["Fac"])
    links.new(principled.outputs["BSDF"], mix_shader.inputs[1])
    links.new(color_ramp.outputs["Color"], mix_shader.inputs[2])
    links.new(mix_shader.outputs["Shader"], output_node.inputs["Surface"])
else:
    normal_map = nodes.new("ShaderNodeNormalMap")
    links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], principled.inputs["Normal"])
delivery.data.materials.append(material)
if "--ambiguous" in options:
    duplicate.data.materials.append(material)

bpy.ops.wm.save_as_mainfile(filepath=str(output), check_existing=False)

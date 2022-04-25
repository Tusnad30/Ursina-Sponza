from ursina import *
from ursina.prefabs.first_person_controller import FirstPersonController
from direct.showbase.Loader import Loader
from panda3d.core import SamplerState


sunDir = Vec3(0.4, -1, -0.1)


vert, frag = open("shaders/vert.glsl", "r"), open("shaders/frag.glsl", "r")
mainShader = Shader(language = Shader.GLSL, vertex = vert.read(), fragment = frag.read())
vert.close(); frag.close()


app = Ursina()

Texture.default_filtering = "linear"
brdf_lut = Texture("textures/brdf_lut.png")
cubemap = Loader.loadCubeMap(None, "textures/cubemap/cubemap#.jpg", minfilter = SamplerState.FT_linear_mipmap_linear)


map = Entity(shader = mainShader, position = (1.53, 0, -0.855), scale = 1.5, model = "meshes/sponza.glb")
map.set_shader_input("brdfLUT", brdf_lut)
map.set_shader_input("cubemap", cubemap)
map.set_shader_input("sunDir", sunDir)

collider = Entity(scale = 1.5, model = "meshes/collider.obj", collider = "mesh")
collider.visible = False

FirstPersonController()
camera.fov = 90

sun = DirectionalLight()
sun.shadow_map_resolution = Vec2(2048, 2048)
sun.look_at(sunDir)

window.borderless = False
window.exit_button.enabled = False
window.color = rgb(25, 158, 243)
window.title = "sponza scene"


app.run()
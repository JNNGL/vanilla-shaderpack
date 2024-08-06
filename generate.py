import json
import pathlib
from PIL import Image
from PIL import ImageChops
import imagehash
import copy

dataPath = pathlib.Path("data")
outputPath = pathlib.Path(".")

shadowMasks = {}
shadowTextures = {}

def parseTexturePath(assetsPath, name):
    namespace = "minecraft"
    if ":" in name:
        parts = name.split(":", 1)
        namespace = parts[0]
        name = parts[1]
    if not name.endswith(".png"):
        name = name + ".png"
    return assetsPath.joinpath(namespace).joinpath("textures").joinpath(name)

def markShadowMaskCorner(mask, coord):
    if mask.getpixel(coord)[3] == 0:
        mask.putpixel(coord, (0, 0, 0, 1))

def generateShadowMask(hasMcmeta, texture):
    texture = texture.convert("RGBA")
    mask = Image.new("RGBA", (texture.size[0], texture.size[1]), color=(0, 0, 0, 1))
    for x in range(0, texture.size[0]):
        for y in range(0, texture.size[1]):
            pixel = texture.getpixel((x, y))
            if pixel[3] > 10:
                mask.putpixel((x, y), (0, 0, 0, 200))
    # if hasMcmeta:
    #     for i in range(0, int(mask.size[1] / mask.size[0])):
    #         markShadowMaskCorner(mask, (0, i * mask.size[0]))
    #         markShadowMaskCorner(mask, (mask.size[0] - 1, 0))
    #         markShadowMaskCorner(mask, (mask.size[0] - 1, mask.size[0] * (i + 1) - 1))
    #         markShadowMaskCorner(mask, (0, mask.size[0] * (i + 1) - 1))
    # else:
    #     markShadowMaskCorner(mask, (0, 0))
    #     markShadowMaskCorner(mask, (mask.size[0] - 1, 0))
    #     markShadowMaskCorner(mask, (mask.size[0] - 1, mask.size[1] - 1))
    #     markShadowMaskCorner(mask, (0, mask.size[1] - 1))
    return mask

def computeShadowMask(mcmeta, texture):
    mask = generateShadowMask(mcmeta is not None, texture)
    hash = imagehash.average_hash(mask)
    for textureName in shadowMasks:
        computedMask = shadowMasks[textureName]["texture"]
        computedHash = shadowMasks[textureName]["hash"]
        if computedMask.size == mask.size and computedHash == hash and not ImageChops.difference(mask, computedMask).getbbox():
            return textureName
    textureName = f"shadow/shadowmask{len(shadowMasks)}"
    shadowMasks[textureName] = { "texture": mask, "mcmeta": mcmeta, "hash": hash }
    return textureName

def generateBlockShadowTextures(assetsPath, modelName, modelData):
    if not "textures" in modelData:
        return
    for name in modelData["textures"]:
        if name == "particle" or modelData["textures"][name].startswith("#"): continue
        texturePath = parseTexturePath(assetsPath, modelData["textures"][name])
        texture = Image.open(texturePath)
        mcmeta = None
        mcmetaPath = texturePath.with_suffix(".png.mcmeta")
        if mcmetaPath.exists():
            mcmeta = json.load(mcmetaPath.open("r"))
        shadowTexture = computeShadowMask(mcmeta, texture)
        if not modelName in shadowTextures: shadowTextures[modelName] = {}
        shadowTextures[modelName][name] = shadowTexture

def generateShadowTextures():
    print("> Generating shadow textures")
    assetsPath = dataPath.joinpath("assets")
    modelsPath = assetsPath.joinpath("minecraft/models/block")
    generatedPath = outputPath.joinpath("assets/minecraft/textures")
    blockModels = list(modelsPath.glob("*.json"))
    for modelPath in blockModels:
        modelData = json.load(modelPath.open("r"))
        generateBlockShadowTextures(assetsPath, modelPath.stem, modelData)
    for name in shadowMasks:
        shadowData = shadowMasks[name]
        shadowData["texture"].save(generatedPath.joinpath(name + ".png"), format="PNG")
        if shadowData["mcmeta"] is not None:
            json.dump(shadowData["mcmeta"], generatedPath.joinpath(name + ".png.mcmeta").open("w"), indent=4)
    print(f"Generated {len(shadowMasks)} shadow textures.")

def patchBlockModel(modelName, modelData):
    patched = False
    if "textures" in modelData:
        textures = modelData["textures"].copy()
        for texture in textures:
            if texture == "particle": continue
            if textures[texture].startswith("#"):
                modelData["textures"]["shadow_" + texture] = "#shadow_" + textures[texture].removeprefix("#")
                patched = True
    if modelName in shadowTextures:
        if not "textures" in modelData: modelData["textures"] = {}
        for key in shadowTextures[modelName]:
            if shadowTextures[modelName][key] is None: print(f"warn: texture 'shadow_{key}' is not present in model '{modelName}'")
            modelData["textures"]["shadow_" + key] = shadowTextures[modelName][key]
            patched = True
    if not "parent" in modelData:
        if not "textures" in modelData: modelData["textures"] = {}
        modelData["textures"]["marker"] = "custom/marker"
        patched = True
    if "elements" in modelData:
        elements = copy.deepcopy(modelData["elements"])
        for element in elements:
            for face in element["faces"]:
                faceTexture = element["faces"][face]["texture"]
                faceTexture = "#shadow_" + faceTexture.removeprefix("#")
                element["faces"][face]["texture"] = faceTexture
            modelData["elements"].append(element)
        modelData["elements"].append(
            {
                "from": [ 8, 8, 8 ],
                "to": [ 8, 8, 8 ],
                "faces": {
                    "up": { "uv": [ 8, 8, 8, 8 ], "texture": "#marker", "cullface": "up" }
                }
            }
        )
        patched = True
    return patched

def generateBlockModels():
    print("> Generating block models")
    modelsPath = dataPath.joinpath("assets/minecraft/models/block")
    generatedPath = outputPath.joinpath("assets/minecraft/models/block")
    blockModels = list(modelsPath.glob("*.json"))
    nPatched = 0
    for modelPath in blockModels:
        modelData = json.load(modelPath.open("r"))
        if patchBlockModel(modelPath.stem, modelData):
            json.dump(modelData, generatedPath.joinpath(modelPath.name).open("w"))
            nPatched += 1
    print(f"Patched {nPatched} block models.")


generateShadowTextures()
generateBlockModels()
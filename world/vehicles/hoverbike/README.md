# Hover bike model

From the user's `Hoverbike_30MB.glb` (703,554 triangles, one mesh, colour /
metal-roughness / normal textures), simplified with `tools/simplify_glb.py`:

    simplify_glb.py Hoverbike.glb hoverbike.glb 60000 0.05 1 1 1 1          # near: 256k, textures
    simplify_glb.py Hoverbike.glb hoverbike_far.glb 70000 0.06 0 1 0 1      # past 8 m: 158k, no textures
    simplify_glb.py Hoverbike.glb hoverbike_shadow.glb 50000 0.02 0 1 0 0 1 # shadow only: 42k, sloppy

The far and shadow versions use the near one's material (world/vehicles/hoverbike.gd).
Model frame: the front (turbine intake, "B26" fairing) is -X, up is +Y, about
1.9 units long; the game scales it by 1.35.

# Hover bike model

From the user's `Hoverbike_30MB.glb` (703,554 triangles, one mesh, colour /
metal-roughness / normal textures), simplified with `tools/simplify_glb.py`:

    simplify_glb.py Hoverbike.glb hoverbike.glb 60000 0.05 1 1 1 1          # near: 256k, textures
    simplify_glb.py Hoverbike.glb hoverbike_far.glb 70000 0.06 0 1 0 1      # past 8 m: 158k, no textures
    simplify_glb.py Hoverbike.glb hoverbike_shadow.glb 50000 0.02 0 1 0 0 1 # shadow only: 42k, sloppy

The far and shadow versions use the near one's material (world/vehicles/hoverbike.gd).
Model frame: the front (turbine intake, "B26" fairing) is -X, up is +Y, about
1.9 units long; the game scales it by 1.35.

The handlebars are straightened first (the original's grips were bent unevenly,
one swept forward and drooping): each grip turns to a mirror-symmetric pose,
level sideways with an 8 degree droop, and the bar bends smoothly to meet it:

    straighten_handlebars.py Hoverbike.glb Hoverbike_straight.glb 0 0 8

and the far and shadow versions above are made from Hoverbike_straight.glb.
The near one is made from it with the grips, hand controls and stem display cut
out (the parts below take their places):

    cut_bike_cockpit.py Hoverbike_straight.glb Hoverbike_cockpit.glb keep
    simplify_glb.py Hoverbike_cockpit.glb hoverbike.glb 60000 0.05 1 1 1 1

## Cockpit parts (parts/)

From the user's Steering_Console_60k, Right_Throttle_Grip_6 and
Left_Brake_Lever_60k (Draco-compressed glTF, webp textures), unpacked with
`tools/undraco_gltf.py` and halved (about 23-30k triangles each):

    undraco_gltf.py Steering_Console_60k.gltf console_full.glb
    simplify_glb.py console_full.glb steering_console.glb 15000 0.05 1 1 1 1

(likewise throttle_grip.glb and brake_lever_grip.glb). hoverbike.gd
_build_cockpit places them: the throttle on the rider's right, the brake
lever grip on his left (turned forward so the lever is ahead of the grip),
the console on the stem. They're drawn within NEAR_DISTANCE, like the near
model. The console model has a mirrored copy of its screen on its back.

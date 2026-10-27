# Sliding door

User-supplied sci-fi door (door_1.obj, 3ds Max export) split into three
meshes so the leaves can move: `frame.obj`, `leaf_left.obj`, `leaf_right.obj`.
Textures: albedo, normal, ambient occlusion, and a scratch map used as the
metallic mask. The material is built by tools/build_scenes.gd
(ship/materials/door.tres); the behaviour is ship/sliding_door.gd.

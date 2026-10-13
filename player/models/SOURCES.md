# Human character sources

The body mesh, 65-bone skeleton, articulated hands and fingers come from **Quaternius — Universal Base Characters, Standard**, Superhero Male. Animations come from **Quaternius — Universal Animation Library, Standard**, Unreal-Godot version. Both asset packs use **CC0 1.0 Universal**; see the preserved license files in this directory.

Official author pages:

- https://quaternius.com/packs/universalbasecharacters.html
- https://quaternius.com/packs/universalanimationlibrary.html
- https://creativecommons.org/publicdomain/zero/1.0/

The prepared, unanimated body was downloaded from `programasweights/avatar/public/assets/character.glb`. That project's `ASSETS.md` identifies the Quaternius source mesh and documents that geometry, normals, weights and skeleton were preserved while textures were removed. The animation file was downloaded from `NafisRayan/Animate-Rigged-Humanoid-No-Blender/Universal Animation Library[Standard]/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb`.

Source SHA-256 checksums, recorded 2026-10-13:

- Body: `d6f3b64cab629f6ddca9ba063811aeffd3663a8a4e49ade47cd9505dc2bbd70f`
- Animations: `69591853d817488edaa8fd9bf8fc1d821eaeaf789f8627b3cd23b41c4ed67997`

`tools/prepare_human.py` builds `human.glb` from those two files. It adds fitted garment colors, a short rounded hairstyle weighted to the head bone, and nine selected animations. It calibrates rotations against both rigs' rest transforms, preserves the model's bone lengths and removes locomotion root travel so the game's CharacterBody3D controls position. Idle, walk, sprint, jump, landing, sit/stand and seated clips are included. No Rockstar, GTA or Mixamo assets are used.

The result is a stylized human, rather than a photorealistic character. Clothing is fitted to the body mesh, rather than separate cloth simulation. The game approaches a clear side of the vehicle and blends sit/stand motion and cameras; it does not animate vehicle doors or render an occupant inside the current vehicle interiors.

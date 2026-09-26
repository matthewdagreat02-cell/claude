# Message to paste into your desktop Claude session

Paste everything in the box below into the desktop session (the one
connected to Roblox Studio and Blender). Keep Studio in **Edit mode**.

---

```
Continue where you left off on the Western town, and install the Wild West
script package from my GitHub repo matthewdagreat02-cell/claude, branch
claude/dreamy-clarke-mqzkoi, folder roblox/. Read roblox/README.md first:
it lists every script, its exact name/type and where it goes in Studio.

1. Create every script from roblox/src exactly as the README tree shows
   (Folder / Script / ModuleScript / LocalScript names must match).

2. Merge, don't duplicate. My game already has a tornado, trucks, a
   survivor/rescue system, cash or leaderstats, and the old straight-line
   "Gulch" town. For each one, either switch it to the new package's version
   or wire the two together, so there is only ONE cash system, ONE survivor
   system, ONE vehicle system and ONE town. Tell me what you replaced.

3. Tornado: keep ONLY the anime-style tornado. Delete every other tornado
   model, variant and spawner. Tag the anime tornado Model "Tornado" and give
   it the attribute TornadoStyle = "Anime". Make its spawner set
   ReplicatedStorage attribute NextTornadoAt =
   workspace:GetServerTimeNow() + seconds until the next tornado.

4. Put my Roblox user ID in Config.DevUserIds (infinite cash). Turn on
   Game Settings > Security > Enable Studio Access to API Services.

5. Set Config.Map.Center / Config.Map.Size to the real play area and set
   Config.StarterBaseSpeed to my current starter truck's speed.

6. Blender: for every building kind in Buildings.Specs (Bank, Saloon,
   GeneralStore, Sheriff, Hotel, Church, PostOffice, Blacksmith, Barber,
   Doctor, Undertaker, Livery, Shop, HomeSmall, HomeMedium, HomeLarge,
   Adobe, Shack, Farmhouse, Barn, Station) model a low-poly anime-style
   version with a furnished interior at the same size. Import each as a Model
   named after its kind into ServerStorage.TownModels, pivot at ground centre
   with the front door facing -Z. The town uses them automatically.

7. Play-test and fix anything that breaks:
   - drive the starter pickup (W = forward; if it drives backwards set
     Config.InvertDrive = true)
   - rescue a survivor, drop them off at my plot, check cash goes up
     (each vehicle carries only 1 survivor at a time)
   - leave and rejoin: cash, vehicles and index must still be there
   - drive into the anime tornado: the truck must be picked up, spun and
     thrown far across the map
   - open Shop, Index, Vehicles, Home, the feedback mailbox and both
     leaderboards
   Show me screenshots of the town, my plot, the HUD, a survivor's
   🍀 luck label, the feedback window and a tornado throw.
```

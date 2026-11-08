extends RefCounted


const PRESETS: Array = [
	{ "name": "Grass", "file": "grass.bin", "id": "tex_96458dff768483b559e87debd1b0a4e62df1d389f2f70aaf31c548b2082bd29a"},
	{ "name": "Grass & Rock", "file": "grass_rock.bin", "id": "tex_0a3ebb042e6970e99b80f5ff23cf17a4100975ce6bd7d332f829156dfb0718cd"},
	{ "name": "Rocky Ground", "file": "rocky.bin", "id": "tex_3b66a255ef78bf06c4760d58f25cf56e11ca25d3f752160b35bd17d84cda46b5"},
	{ "name": "Red Sand", "file": "red_sand.bin", "id": "tex_e5ab968602220c1d639b53038bb61a6f0acee9544e1a10524d1696a6658cd34d"},
	{ "name": "Grass & Gravel", "file": "grass_gravel.bin", "id": "tex_f47b27f79e18421424aae4f5aedbcfa800ca39dea4026c5ed667857891737819"},
	{ "name": "Studio: Desert Sand", "file": "studio_sand_desert.bin", "id": "tex_751858e7f2955eb7d0ea8ccde144368b51ce59640c749767607aca5e5b1cf04e", "tile_m": 24.0},
	{ "name": "Studio: Dune Sand", "file": "studio_sand_dune.bin", "id": "tex_a35f9c347345ca1360448a053bd494c0d05d0ce226314886d6230d9bcd8a9e4f", "tile_m": 32.0},
	{ "name": "Studio: Lush Grass", "file": "studio_grass_lush.bin", "id": "tex_9848d03ece0f6c43ffbd557894e5941ae49adde3db4c3b341843ffe6d2ad8110", "tile_m": 18.0},
	{ "name": "Studio: Dry Grass", "file": "studio_grass_dry.bin", "id": "tex_b893196f2c4a4fd825f3aa654bf68158339040a04101d2b4b833651854bed9c2", "tile_m": 18.0},
	{ "name": "Studio: Forest Moss", "file": "studio_moss_forest.bin", "id": "tex_008963d65875e6ebffaedd67de28ba4d4423f0c3748ae013d15a0ff34f734d5e", "tile_m": 14.0},
	{ "name": "Studio: Granite", "file": "studio_rock_granite.bin", "id": "tex_b58360e56fdafde1298dec813c8695741c9ef8e7cc60ff3891ec200783915480", "tile_m": 12.0},
	{ "name": "Studio: Cliff Face", "file": "studio_rock_cliff.bin", "id": "tex_112a419c8d94755413108afd2299ac04ec1377e11b93102b39b6a2bf8ecaf41a", "tile_m": 20.0},
	{ "name": "Studio: Gravel", "file": "studio_gravel.bin", "id": "tex_4ae8d7278ad2a2550b9c97f647e2efff95bd4e3575d683797d66b2362bb697b7", "tile_m": 8.0},
	{ "name": "Studio: Basalt", "file": "studio_volcanic_basalt.bin", "id": "tex_accd8be60d3dec8cda8a1e3d8d8c7f714f34ae04137aa8589531e3b5320e9eaf", "tile_m": 10.0},
	{ "name": "Studio: Dry Dirt", "file": "studio_dirt_dry.bin", "id": "tex_8c165342e5a6cf3e8b3b55277d759512c7660c32f89521907f629a0c4b485db8", "tile_m": 16.0},
	{ "name": "Studio: Wet Mud", "file": "studio_mud_wet.bin", "id": "tex_fe06c22aded84289ec001e21f644b461ab39858667e7bbcbd59c10dfdf6263f6", "tile_m": 12.0},
	{ "name": "Studio: Tilled Soil", "file": "studio_soil_tilled.bin", "id": "tex_c48e3a8747aaccbb2bf142f761355e2faa88c584730abb6af693e4cc88c02f3f", "tile_m": 10.0},
	{ "name": "Studio: Snow", "file": "studio_snow.bin", "id": "tex_2e3a249578b43374b9213ee0d9a9c14cf18f52d5f9b7ded99cf5885892382bdc", "tile_m": 26.0},
	{ "name": "Studio: Packed Ice", "file": "studio_snow_ice.bin", "id": "tex_ce529edbe4c9968655614b2599320186c7c450129d89545ab19d21855930f7e4", "tile_m": 30.0},
	{ "name": "Studio: Asphalt", "file": "studio_asphalt.bin", "id": "tex_fbc253591711b23c62ce619e63d1420c651080ad50cef79f0b60692fedca215a", "tile_m": 20.0},
	{ "name": "Studio: Concrete Slabs", "file": "studio_concrete.bin", "id": "tex_9c09c88589c9cec4fd9225d14d42e801e74de39eec7af287240db50e9b272e3d", "tile_m": 12.0},
	{ "name": "Studio: Paved Sandstone", "file": "studio_sandstone_paved.bin", "id": "tex_dc97135fa32485d6f0dbb5acd724648fd8f2bd7564983e6307c3a9443355e617", "tile_m": 10.0},
	{ "name": "Studio: Riverbed", "file": "studio_riverbed.bin", "id": "tex_a85592cdafeac46fa3900f06696c0096f1abeef4c84ca44b7d784b79e241305a", "tile_m": 18.0},
]
const DIR := "res://assets/terrain_presets/"
static func find(id: String) -> Dictionary:
	for preset: Dictionary in PRESETS:
		if str(preset.id) == id: return preset
	return {}
static func read(preset: Dictionary) -> PackedByteArray:
	if preset.is_empty(): return PackedByteArray()
	return FileAccess.get_file_as_bytes(DIR + str(preset.file))

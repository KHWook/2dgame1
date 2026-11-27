## Saves every sprite (and every enemy tier's colours of its frames, "slime_a~2"), enlarged, as one PNG, so the art can be looked at without running the game.
## godot --headless --path . --script res://tools/art_sheet.gd -- [out.png] [scale] [name-prefix]
## With --atlas first, it saves the atlas the game draws from instead (src/art/sprites.gd), at 1:1:
## godot --headless --path . --script res://tools/art_sheet.gd -- --atlas /tmp/atlas.png
extends SceneTree

const Sprites := preload("res://src/art/sprites.gd")

const BACK := Color("#2f4a36") # the ground colour, so contrast is judged against what the game shows
const GAP := 2 # sprite pixels between cells
const COLUMNS := 8


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and args[0] == "--atlas":
		var path: String = args[1] if args.size() > 1 else "res://docs/shots/atlas.png"
		var atlas := Sprites.atlas_image()
		atlas.save_png(path)
		print("art_sheet: wrote the %dx%d atlas to %s" % [atlas.get_width(), atlas.get_height(), path])
		quit(0)
		return
	var out: String = args[0] if args.size() > 0 else "res://docs/shots/sprites.png"
	var scale: int = int(args[1]) if args.size() > 1 else 6
	var prefix: String = args[2] if args.size() > 2 else ""
	var names: Array = (Sprites.names() + Sprites.tier_names()).filter(func(n): return n.begins_with(prefix))
	names.sort()
	var biggest := 0 # the cell fits the largest sprite shown
	for n in names:
		biggest = maxi(biggest, maxi(Sprites.rows(n)[0].length(), Sprites.rows(n).size()))
	var cell_size := (biggest + GAP) * scale
	var lines := ceili(float(names.size()) / COLUMNS)
	var sheet := Image.create_empty(COLUMNS * cell_size, lines * cell_size, false, Image.FORMAT_RGBA8)
	sheet.fill(BACK)
	for i in names.size():
		var img: Image = Sprites.image(names[i])
		var size := img.get_size()
		img.resize(size.x * scale, size.y * scale, Image.INTERPOLATE_NEAREST)
		var cell := Vector2i(i % COLUMNS, i / COLUMNS) * cell_size
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), cell + Vector2i(scale, scale))
	sheet.save_png(out)
	for line in lines:
		print("row %d: %s" % [line + 1, ", ".join(names.slice(line * COLUMNS, (line + 1) * COLUMNS))])
	print("art_sheet: wrote %s" % out)
	quit(0)

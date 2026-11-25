extends Node
# Alat bantu: ambil screenshot game (butuh renderer, mis. xvfb-run).
#   xvfb-run -a godot --rendering-driver opengl3 --path . res://tests/shot.tscn -- out=/tmp/a.png cx=63 cy=51 kinds=goblin,ogre
var main
var frames := 0
var args := {}
var out := "/tmp/shot.png"
var times: Array = []
var startup_ms := 0
var t0 := Time.get_ticks_msec()


func _ready() -> void:
    for a in OS.get_cmdline_user_args():
        var kv := String(a).split("=")
        if kv.size() == 2:
            args[kv[0]] = kv[1]
    out = String(args.get("out", out))
    Game.new_game("Tester", "m")
    main = load("res://scenes/main.tscn").instantiate()
    get_tree().root.add_child.call_deferred(main)
    _set_scene.call_deferred()


func _set_scene() -> void:
    get_tree().current_scene = main


func _process(delta: float) -> void:
    if main == null or not main.is_inside_tree():
        return
    if not main.world.baked:
        return
    frames += 1
    if frames == 1:
        startup_ms = Time.get_ticks_msec() - t0
    times.append(delta)
    var pl = get_tree().get_first_node_in_group("player")
    if frames == 2:
        var cx := float(args.get("cx", 63))
        var cy := float(args.get("cy", 51))
        pl.global_position = main.world.cell_center(Vector2i(int(cx), int(cy)))
        for e in get_tree().get_nodes_in_group("hostile"):
            e.queue_free()
        main.world.update_collision_ring(pl.global_position, true)
        if args.has("kinds"):
            var ks: PackedStringArray = String(args["kinds"]).split(",")
            var b := int(args.get("biome", 1))
            for i in ks.size():
                var e = main.spawn_mob(ks[i], b, pl.global_position + Vector2(-90 + i * 45, -20 + (i % 2) * 50))
                e.aggro = 0.0
                e.speed = 0.0
    var wait := int(args.get("wait", 90))
    if frames == wait:
        var img: Image = get_viewport().get_texture().get_image()
        img.save_png(out)
        var avg := 0.0
        for t in times:
            avg += t
        avg /= maxf(times.size(), 1)
        var shapes := 0
        if main.world.get("shapes") != null:
            shapes = main.world.shapes.size()
        print("SHOT saved ", out, " size=", img.get_size(), " avg_dt_ms=", snappedf(avg * 1000.0, 0.1))
        print("METRIC draw_calls=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
            " objects=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
            " process_ms=", snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.01),
            " physics_ms=", snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.01),
            " nodes=", int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
            " col_shapes=", shapes,
            " tex_mem_mb=", snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.1),
            " startup_ms=", startup_ms)
        get_tree().quit(0)

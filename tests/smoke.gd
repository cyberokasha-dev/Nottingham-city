extends SceneTree

func _initialize():
    call_deferred("check_demo")

func check_demo():
    var menu = load("res://car_select/car_select.tscn").instantiate()
    root.add_child(menu)
    await process_frame
    for choice in ["_on_mini_van_pressed", "_on_tow_truck_pressed", "_on_trailer_truck_pressed"]:
        menu.call(choice)
        for i in range(30):
            await physics_frame
        if not is_instance_valid(menu.town):
            push_error("Vehicle did not load: " + choice)
            quit(1)
            return
        menu._on_back_pressed()
        menu.town = null
        await process_frame
    menu.queue_free()
    await process_frame
    print("SMOKE_OK: all three vehicles load, simulate and return to selection")
    quit()

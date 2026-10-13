extends Node3D
# Low-cost sculpted pedestrians: shared static geometry, articulated legs and arms.
const G = preload("res://transport/geometry.gd")
var variant := 0
var legs: Array[Node3D] = []
var arms: Array[Node3D] = []
var phase := 0.0
var walking := false

func _ready() -> void:
	var skin := G.material([Color("824e33"),Color("cf9b75"),Color("e0b795"),Color("533522")][variant%4])
	var shirt := G.material([Color("317b99"),Color("9c5066"),Color("ccae55"),Color("5b8c68"),Color("e8ded0"),Color("555a91")][variant%6])
	var pants := G.material(Color("293444"))
	var hair := G.material(Color("262019"))
	var torso := Node3D.new()
	add_child(torso)
	G.sphere(torso,Vector3(0,1.16,0),Vector3(0.47,0.65,0.29),shirt)
	G.tube(torso,Vector3(0,1.38,0),Vector3(0,1.52,0),0.075,skin)
	G.sphere(torso,Vector3(0,1.65,0),Vector3(0.25,0.32,0.25),skin)
	G.sphere(torso,Vector3(0,1.76,-0.015),Vector3(0.265,0.16,0.25),hair)
	G.merge(torso)
	for side in [-1.0,1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side*0.12,0.93,0)
		add_child(leg)
		G.tube(leg,Vector3.ZERO,Vector3(0,-0.42,0),0.09,pants)
		G.tube(leg,Vector3(0,-0.42,0),Vector3(0,-0.8,0),0.066,pants)
		G.sphere(leg,Vector3(0,-0.84,0.06),Vector3(0.15,0.13,0.28),hair)
		G.merge(leg)
		legs.append(leg)
		var arm := Node3D.new()
		arm.position = Vector3(side*0.25,1.37,0)
		add_child(arm)
		G.tube(arm,Vector3.ZERO,Vector3(side*0.025,-0.29,0),0.065,shirt)
		G.tube(arm,Vector3(side*0.025,-0.29,0),Vector3(side*0.04,-0.53,0.02),0.05,skin)
		G.sphere(arm,Vector3(side*0.04,-0.56,0.02),Vector3(0.1,0.13,0.09),skin)
		G.merge(arm)
		arms.append(arm)

func _process(delta: float) -> void:
	if not walking:
		return
	phase += delta*6
	for i in range(2):
		legs[i].rotation.x = sin(phase+i*PI)*0.4
		arms[i].rotation.x = -sin(phase+i*PI)*0.3

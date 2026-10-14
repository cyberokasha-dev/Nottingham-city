extends Node
# All currency is integer pence. One shared ledger for players, NPCs and services.
const SAVE_PATH := "user://nottingham-city-v1.json"
const JOBS := {"Cleaner":8500,"Rent officer":9500,"Transport technician":12000,"Shop worker":9000,"Business owner":20000}
var game: Node3D
var data := {"version":1,"seconds":0.0,"next_house":1,"houses":{},"accounts":{},"ledger":[],"council":50000000,"business":100000000,"receipts":{},"notices":[]}
var enabled := true
var enforce_tenancy := true
var step := 0.0
var save_clock := 0.0
var npcs_clock := 0.0
var office := Vector3(-18,-4.98,72)
var houses: Dictionary = {}
var locations: Array[Dictionary] = []
var work_seconds := {}
var last_error := ""

func _ready() -> void:
	if not OS.has_environment("NOTTINGHAM_TEST") and FileAccess.file_exists(SAVE_PATH):
		var loaded = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if loaded is Dictionary and loaded.get("version")==1:
			data = loaded
	for person in game.party.members:
		register(person,"player/"+person.profile.name,150000)
	for i in range(game.population.residents.size()):
		var person: Node3D = game.population.residents[i]
		var key: String = "resident/"+person.person_name
		register(person,key,18000 if i%9==0 else (1200000 if i%11==0 else 90000+i*1700))
		var account: Dictionary = data.accounts[key]
		if account.job=="":
			account.job = JOBS.keys()[i%JOBS.size()]
	# Unfinished paid cab journeys are refunded after a reload, never lost.
	for key in data.receipts.keys():
		if data.accounts.has(key):
			data.accounts[key].balance = int(data.accounts[key].balance)+int(data.receipts[key].amount)
			record(key,int(data.receipts[key].amount),"Unfinished journey refunded")
	data.receipts.clear()
	register_houses()
	for person in game.population.residents:
		var account := account_for(person)
		if int(account.house)>0 and houses.has(int(account.house)):
			person.home = houses[int(account.house)]
		elif int(account.house)==0:
			rent(person,int(person.home.house_number))
	build_locations()
	_build_office()

func register(person: Node, key: String, initial: int) -> void:
	person.set_meta("account_id",key)
	if not data.accounts.has(key):
		data.accounts[key] = {"balance":initial,"job":"","house":0,"arrears":0,"due":30,"last_wage":-1,"last_trip":-1000.0,"loan":0}

func key_for(person: Node) -> String:
	return str(person.get_meta("account_id",""))

func account_for(person: Node) -> Dictionary:
	return data.accounts.get(key_for(person),{})

func cash(person: Node) -> int:
	return int(account_for(person).get("balance",0))

static func pounds(pence: int) -> String:
	return "£%.2f" % (pence/100.0)

func day() -> int:
	return int(float(data.seconds)/300.0)

func hour() -> int:
	return (9+int(fposmod(float(data.seconds),300.0)/12.5))%24

func record(key: String, amount: int, reason: String, council_delta := 0) -> void:
	data.cash_in = int(data.get("cash_in",0))+maxi(0,council_delta)
	data.cash_out = int(data.get("cash_out",0))+maxi(0,-council_delta)
	data.ledger.append({"day":day(),"account":key,"pence":amount,"reason":reason,"council_delta":council_delta})
	if data.ledger.size()>300:
		data.ledger.pop_front()

func charge(person: Node, amount: int, reason: String) -> bool:
	return charge_key(key_for(person),amount,reason)

func charge_key(key: String, amount: int, reason: String) -> bool:
	if amount<0 or not data.accounts.has(key) or int(data.accounts[key].balance)<amount:
		last_error = "Not enough money"
		return false
	data.accounts[key].balance = int(data.accounts[key].balance)-amount
	data.council = int(data.council)+amount
	record(key,-amount,reason,amount)
	save()
	return true

func register_houses() -> void:
	for house in game.city.houses:
		var stable: String = str(house.name)
		if not data.houses.has(stable):
			data.houses[stable] = {"number":int(data.next_house),"tenant":"","rent":40000}
			data.next_house = int(data.next_house)+1
		var record: Dictionary = data.houses[stable]
		house.house_number = int(record.number)
		house.street = house.address.get_slice("·",1).strip_edges()
		house.address = str(house.house_number)+" · "+house.street
		houses[house.house_number] = house
		house.rental_record = record
		house.refresh_sign()

func house_record(number: int) -> Dictionary:
	if not houses.has(number):
		return {}
	return data.houses[str(houses[number].name)]

func rent(person: Node, number: int) -> bool:
	var account := account_for(person)
	var home := house_record(number)
	if account.is_empty() or home.is_empty() or str(home.tenant)!="" or int(account.house)>0:
		last_error = "This home is unavailable, or you already rent a home"
		return false
	if not charge(person,int(home.rent),"First month rent • house "+str(number)):
		return false
	home.tenant = key_for(person)
	account.house = number
	account.due = day()+30
	houses[number].refresh_sign()
	save()
	return true

func can_access(person: Node, house: Node3D) -> bool:
	return not enforce_tenancy or str(house.rental_record.get("tenant",""))==key_for(person)

func pay_rent(person: Node) -> bool:
	var account := account_for(person)
	var due := int(account.get("arrears",0))
	if due<=0:
		last_error = "No rent is overdue"
		return false
	if not charge(person,due,"Rent arrears"):
		return false
	account.arrears = 0
	return true

func apply_job(person: Node, job: String) -> bool:
	if not JOBS.has(job) or person.global_position.distance_to(office)>12:
		last_error = "Visit the council office to apply"
		return false
	account_for(person).job = job
	save()
	return true

func assignment(person: Node) -> Dictionary:
	var account := account_for(person)
	if account.is_empty() or account.job=="":
		return {}
	if account.job=="Rent officer":
		for key in data.accounts:
			var tenant: Dictionary = data.accounts[key]
			if int(tenant.arrears)>0 and houses.has(int(tenant.house)):
				return {"point":houses[int(tenant.house)].entrance(),"name":"Rent visit • house "+str(tenant.house),"tenant":key}
	return {"point":office,"name":"Council office • "+account.job,"tenant":""}

func perform_work(person: Node, delta: float) -> bool:
	var task := assignment(person)
	var key := key_for(person)
	if task.is_empty() or person.global_position.distance_to(task.point)>5:
		return false
	var account := account_for(person)
	if int(account.last_wage)>=day():
		return false
	work_seconds[key] = float(work_seconds.get(key,0))+delta
	if float(work_seconds[key])<20:
		return false
	var wage: int = JOBS[account.job]
	var fund := "business" if account.job in ["Shop worker","Business owner"] else "council"
	if int(data[fund])<wage:
		return false
	data[fund] = int(data[fund])-wage
	account.balance = int(account.balance)+wage
	account.last_wage = day()
	work_seconds[key] = 0.0
	record(key,wage,account.job+" wages",-wage if fund=="council" else 0)
	if task.tenant!="":
		var tenant: Dictionary = data.accounts[task.tenant]
		var due := int(tenant.arrears)
		if charge_key(task.tenant,due,"Rent collected at council visit"):
			tenant.arrears = 0
		data.notices.append({"house":int(tenant.house),"day":day(),"officer":key,"paid":int(tenant.arrears)==0})
		if data.notices.size()>100:
			data.notices.pop_front()
	return true

func process_rents() -> void:
	for key in data.accounts:
		var account: Dictionary = data.accounts[key]
		if int(account.house)<=0:
			continue
		var home := house_record(int(account.house))
		while day()>=int(account.due):
			if not charge_key(key,int(home.rent),"Monthly rent"):
				account.arrears = int(account.arrears)+int(home.rent)
			account.due = int(account.due)+30

func build_locations() -> void:
	locations = [{"name":"Council Office","point":office}]
	for district in game.city.districts:
		var direction := Vector3(sin(float(district.heading)),0,cos(float(district.heading)))
		locations.append({"name":"Aurora Rank • "+str(district.name),"point":district.rank+Vector3(direction.z,0,-direction.x)*2.2})
	for i in range(game.city.ROAD_X.size()):
		locations.append({"name":game.city.ATLAS.STREET_X[i],"point":Vector3(game.city.ROAD_X[i]+7.7,-5.02,-22)})
	for i in range(game.city.ROAD_Z.size()):
		locations.append({"name":game.city.ATLAS.STREET_Z[i],"point":Vector3(-18,-5.02,game.city.ROAD_Z[i]+7.7)})
	for number in houses:
		locations.append({"name":"House "+str(number)+" • "+houses[number].street,"point":houses[number].entrance()})
	for stop in game.city.transport.stops:
		locations.append({"name":"Bus "+stop.route+" • "+stop.name,"point":stop.pavement})
	for park in game.city.parks:
		locations.append({"name":park.park_name,"point":park.global_position})

func _process(delta: float) -> void:
	if not enabled:
		return
	data.seconds = float(data.seconds)+delta
	step += delta
	save_clock += delta
	if step>=1:
		var elapsed := step
		step = 0
		process_rents()
		# Background commuters have ordinary jobs; fares cannot drain them forever.
		for key in data.accounts:
			if str(key).begins_with("commuter/"):
				var account: Dictionary = data.accounts[key]
				if int(account.last_wage)<day() and int(data.business)>=9000:
					data.business = int(data.business)-9000
					account.balance = int(account.balance)+9000
					account.last_wage = day()
					account.job = "Shop worker"
					record(key,9000,"Commuter work wages")
		for person in game.population.residents:
			var account := account_for(person)
			if int(account.house)==0 and cash(person)>=40000:
				for number in houses:
					if str(house_record(number).tenant)=="" and rent(person,int(number)):
						person.home = houses[number]
						break
			if hour()>=8 and hour()<18:
				perform_work(person,elapsed)
		perform_work(game.player,elapsed)
	if save_clock>=30:
		save_clock = 0
		save()

func save() -> void:
	if not enabled or OS.has_environment("NOTTINGHAM_TEST"):
		return
	var file := FileAccess.open(SAVE_PATH+".tmp",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
		DirAccess.rename_absolute(SAVE_PATH+".tmp",SAVE_PATH)

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		save()

func _build_office() -> void:
	var G = preload("res://transport/geometry.gd")
	var building := Node3D.new()
	building.position = office-Vector3(0,0,4)
	game.town.add_child(building)
	var brick: Material = G.material(Color("b29f88"))
	var glass: Material = G.material(Color("254c65"),0.3)
	G.box(building,Vector3(0,2,0),Vector3(10,4,6),brick)
	G.box(building,Vector3(0,4.15,0),Vector3(10.5,0.3,6.5),G.material(Color("334655")))
	for x in [-3.4,-1.7,1.7,3.4]:
		G.box(building,Vector3(x,2.1,3.04),Vector3(1.2,1.5,0.08),glass)
	G.box(building,Vector3(0,1.25,3.08),Vector3(1.4,2.5,0.1),glass)
	G.label(building,"NOTTINGHAM • CITY COUNCIL\nHousing • Work • Public Transport",Vector3(0,3.3,3.15),23)
	G.merge(building)

func loan(person: Node, amount: int) -> bool:
	var account := account_for(person)
	if amount<=0 or amount>100000 or int(account.loan)>0 or int(data.council)<amount:
		last_error = "Loan unavailable: repay your existing loan first (maximum £1,000)"
		return false
	data.council = int(data.council)-amount
	account.balance = int(account.balance)+amount
	account.loan = amount
	record(key_for(person),amount,"Council loan",-amount)
	save()
	return true

func repay(person: Node, amount: int) -> bool:
	var account := account_for(person)
	amount = mini(amount,int(account.loan))
	if amount<=0 or not charge(person,amount,"Council loan repayment"):
		return false
	account.loan = int(account.loan)-amount
	save()
	return true

func hold_fare(person: Node, amount: int) -> bool:
	var key := key_for(person)
	if amount<0 or cash(person)<amount or data.receipts.has(key):
		return false
	account_for(person).balance = cash(person)-amount
	data.receipts[key] = {"amount":amount,"service":"Aurora"}
	record(key,-amount,"Aurora fare held")
	save()
	return true

func resize_fare(person: Node, amount: int) -> bool:
	var key := key_for(person)
	if not data.receipts.has(key) or amount<300: return false
	var difference := amount-int(data.receipts[key].amount)
	if cash(person)<difference:
		last_error = "Not enough money for that destination. Choose a shorter journey."
		return false
	account_for(person).balance = cash(person)-difference
	data.receipts[key].amount = amount
	if difference!=0: record(key,-difference,"Aurora destination fare adjustment")
	save()
	return true

func complete_fare(person: Node) -> void:
	var key := key_for(person)
	if data.receipts.has(key):
		data.council = int(data.council)+int(data.receipts[key].amount)
		record(key,0,"Aurora trip completed",int(data.receipts[key].amount))
		data.receipts.erase(key)
		save()

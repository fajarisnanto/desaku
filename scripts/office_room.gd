extends Control

var world: Node
var role := "Operation"
var elapsed := 0.0
const TINTS = {"Creative":Color("e989ad"),"Research":Color("7bc5e4"),"Operation":Color("8fc295"),"Maintenance":Color("e8b469")}
var font: Font

func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func iso(x: float, y: float) -> Vector2:
	return Vector2(405+(x-y)*74,150+(x+y)*37)

func polygon(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points),color)

func block(center: Vector2, width: float, depth: float, height: float, color: Color) -> void:
	var a := center+Vector2(-width,0)
	var b := center+Vector2(0,-depth)
	var c := center+Vector2(width,0)
	var d := center+Vector2(0,depth)
	var up := Vector2(0,-height)
	polygon([a,d,d+up,a+up],color.darkened(0.25))
	polygon([d,c,c+up,d+up],color.darkened(0.4))
	polygon([a+up,b+up,c+up,d+up],color.lightened(0.15))
	draw_polyline(PackedVector2Array([a+up,b+up,c+up,d+up,a+up]),color.lightened(0.35),1.3,true)

func furnishing(kind: String, pos: Vector2) -> void:
	var accent: Color = TINTS[role]
	draw_set_transform(pos)
	paint_ellipse(Vector2(0,15),Vector2(49,22),Color(0,0,0,0.16))
	match kind:
		"plants":
			block(Vector2(0,9),20,12,23,Color("a96a44"))
			for j in 7:
				var leaf := Vector2(sin(j*2.4)*24,-30+cos(j*2.4)*20)
				draw_line(Vector2(0,-10),leaf,Color("558468"),3,true)
				draw_circle(leaf,10,Color("79ab73"))
		"lamp":
			block(Vector2(0,12),15,8,4,Color("5e6b73"))
			draw_line(Vector2(0,8),Vector2(0,-60),Color("d7bc79"),4,true)
			draw_circle(Vector2(0,-60),25,Color(1,0.86,0.5,0.12))
			polygon([Vector2(-20,-46),Vector2(-12,-72),Vector2(12,-72),Vector2(20,-46)],Color("f2dca0"))
		"shelf", "board":
			block(Vector2(0,9),43,18,75,Color("7c6454"))
			if kind == "shelf":
				for j in 5:
					block(Vector2(-27+j*12,-36+j*4),4,4,22,accent.lightened(j*0.07))
			else:
				polygon([Vector2(-36,-61),Vector2(0,-43),Vector2(0,0),Vector2(-36,-18)],Color("294f50"))
				for j in 3:
					draw_line(Vector2(-29,-48+j*11),Vector2(-6,-37+j*11),Color("e8dcb2"),2,true)
		"lounge":
			block(Vector2(0,8),48,24,22,accent.darkened(0.2))
			block(Vector2(0,-13),44,10,35,accent)
			block(Vector2(-26,12),13,10,10,Color("eadab7"))
		"art":
			draw_line(Vector2(-23,20),Vector2(0,-65),Color("b88d54"),5,true)
			draw_line(Vector2(25,20),Vector2(0,-65),Color("b88d54"),5,true)
			polygon([Vector2(-26,-60),Vector2(27,-48),Vector2(27,-4),Vector2(-26,-16)],Color("f2e6c7"))
			draw_circle(Vector2(3,-32),13,accent)
			draw_line(Vector2(-16,-22),Vector2(17,-41),Color("6ba592"),5,true)
		_:
			block(Vector2(0,15),35,18,24,Color("715d4b"))
			block(Vector2(0,-4),49,26,7,Color("bc9d71"))
			if kind == "lab":
				for j in 3:
					draw_line(Vector2(-20+j*19,-24),Vector2(-20+j*19,-46),Color("d1e9e6"),6,true)
					draw_circle(Vector2(-20+j*19,-24),8,Color("74cfc6"))
			elif kind == "tools":
				draw_line(Vector2(-20,-25),Vector2(20,-42),Color("d4dedc"),5,true)
				draw_arc(Vector2(20,-42),9,0,PI*1.5,20,Color("d4dedc"),4,true)
			elif kind == "tea":
				draw_circle(Vector2(0,-28),12,Color("ecce96"))
				for j in 2:
					draw_arc(Vector2(0,-48-j*9),6,0,PI,12,Color(1,1,1,0.4),1.5,true)
			elif kind == "desk":
				block(Vector2(0,-30),19,10,22,Color("3f6267"))
				block(Vector2(0,36),16,9,12,accent)
			else:
				polygon([Vector2(-21,-30),Vector2(0,-40),Vector2(22,-29),Vector2(0,-19)],Color("e9dfbc"))
	draw_set_transform(Vector2.ZERO)

func paint_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 40:
		var a := TAU*i/40.0
		points.append(center+Vector2(cos(a),sin(a))*radius)
	draw_colored_polygon(points,color)

func _draw() -> void:
	if world == null:
		return
	var accent: Color = TINTS[role]
	var a := iso(-0.7,-0.7)
	var b := iso(4.7,-0.7)
	var c := iso(4.7,3.7)
	var d := iso(-0.7,3.7)
	paint_ellipse(Vector2(425,345),Vector2(370,205),Color(0,0,0,0.18))
	polygon([a,d,d-Vector2(0,130),a-Vector2(0,130)],Color("354e50"))
	polygon([a,b,b-Vector2(0,130),a-Vector2(0,130)],Color("476064"))
	polygon([a,b,c,d],Color("bdad88"))
	for x in 6:
		draw_line(iso(x-0.5,-0.7),iso(x-0.5,3.7),Color("a49473"),1,true)
	for y in 5:
		draw_line(iso(-0.7,y-0.5),iso(4.7,y-0.5),Color("a49473"),1,true)
	draw_polyline(PackedVector2Array([d,c,b]),Color("e7d8b2"),5,true)
	# Tall sunlit window and brass department medallion.
	var w := iso(2,-0.7)-Vector2(0,88)
	polygon([w+Vector2(-37,-26),w+Vector2(37,11),w+Vector2(37,60),w+Vector2(-37,23)],Color("94c5c4"))
	draw_line(w+Vector2(0,-7),w+Vector2(0,41),Color("ddcda9"),3,true)
	draw_circle(iso(-0.7,1.5)-Vector2(0,67),22,accent)
	draw_string(font,iso(-0.7,1.5)-Vector2(7,60),role.left(1),HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("152c34"))
	var office: Dictionary = world.offices[role]
	var arranged: Array = office.items.duplicate()
	arranged.sort_custom(func(left, right): return int(left.slot)/4+int(left.slot)%4 < int(right.slot)/4+int(right.slot)%4)
	for item in arranged:
		var slot := int(item.slot)
		furnishing(str(item.kind),iso(slot%4+0.3,slot/4+0.2))
	if not office.project.is_empty() and office.project.action == "build":
		var p := iso(int(office.project.slot)%4+0.3,int(office.project.slot)/4+0.2)
		block(p,43,22,9,Color("dbb971"))
		for j in 3:
			draw_line(p+Vector2(-28+j*24,7),p+Vector2(-28+j*24,-55),Color("edcf91"),3,true)
		draw_string(font,p+Vector2(-45,-65),"BUILDING",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("fff0c5"))
	var members: Array = [{"name":role+" lead"}]+office.team
	var texture: Texture2D = load("res://assets/"+role.to_lower()+".png") if ResourceLoader.exists("res://assets/"+role.to_lower()+".png") else null
	for i in members.size():
		var p := iso(0.2+i*1.1,3.0)+Vector2(sin(elapsed*0.6+i)*8,0)
		paint_ellipse(p+Vector2(0,4),Vector2(20,9),Color(0,0,0,0.2))
		if texture != null:
			draw_texture_rect(texture,Rect2(p-Vector2(26,80),Vector2(52,80)),false,Color.WHITE if i == 0 else accent.lightened(0.3))
		else:
			draw_circle(p-Vector2(0,34),12,Color("f2d4ac"))
			block(p,15,8,28,accent)
		draw_string(font,p+Vector2(-35,26),str(members[i].name).substr(0,15),HORIZONTAL_ALIGNMENT_LEFT,110,12,Color("fff0cd"))


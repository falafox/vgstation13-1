datum/computer/file/embedded_program
	var/list/memory = list()
	var/state
	var/obj/machinery/embedded_controller/master

	proc
		post_signal(datum/signal/signal, comm_line)
			if(master)
				master.post_signal(signal, comm_line)
			else
				del(signal)

		receive_user_command(command)

		receive_signal(datum/signal/signal, receive_method, receive_param)
			return null

		process()
			return 0

obj/machinery/embedded_controller
	var/datum/computer/file/embedded_program/program

	name = "Embedded Controller"
	icon = 'icons/obj/airlock_machines.dmi'
	icon_state = "airlock_control_build0"
	density = 0
	anchored = 1

	var/on = 1

	var/build=2        // Build state
	var/boardtype=null // /obj/item/weapon/circuitboard/ecb
	var/obj/item/weapon/circuitboard/_circuitboard
	New(turf/loc, var/ndir, var/building=0)
		..()

		// offset 24 pixels in direction of dir
		// this allows the APC to be embedded in a wall, yet still inside an area
		if (building)
			dir = ndir

			//src.tdir = dir		// to fix Vars bug
			//dir = SOUTH

			pixel_x = (dir & 3)? 0 : (dir == 4 ? 24 : -24)
			pixel_y = (dir & 3)? (dir ==1 ? 24 : -24) : 0

			build=0
			stat |= MAINT
			src.update_icon()

	attack_hand(mob/user)
		if(build<2) return 1
		user << browse(return_text(), "window=computer")
		user.set_machine(src)
		onclose(user, "computer")

	attackby(var/obj/item/W as obj, var/mob/user as mob)
		if(type==/obj/machinery/embedded_controller)
			switch(build)
				if(0) // Empty hull
					if(istype(W, /obj/item/weapon/screwdriver))
						usr << "You begin removing screws from \the [src] backplate..."
						if(do_after(user, 50))
							usr << "\blue You unscrew \the [src] from the wall."
							playsound(src.loc, 'sound/items/Screwdriver.ogg', 50, 1)
							new /obj/item/airlock_controller_frame(get_turf(src))
							del(src)
						return 1
					if(istype(W, /obj/item/weapon/circuitboard))
						var/obj/item/weapon/circuitboard/C=W
						if(C.board_type!="embedded controller")
							user << "\red You cannot install this type of board into an embedded controller."
							return
						usr << "You begin to insert \the [C] into \the [src]."
						if(do_after(user, 10))
							usr << "\blue You secure \the [C]!"
							user.drop_item()
							_circuitboard=C
							C.loc=src
							playsound(src.loc, 'sound/effects/pop.ogg', 50, 0)
							build++
							update_icon()
						return 1
				if(1) // Circuitboard installed
					if(istype(W, /obj/item/weapon/crowbar))
						usr << "You begin to pry out \the [W] into \the [src]."
						if(do_after(user, 10))
							playsound(src.loc, 'sound/effects/pop.ogg', 50, 0)
							build--
							update_icon()
							var/obj/item/weapon/circuitboard/C
							if(_circuitboard)
								_circuitboard.loc=get_turf(src)
								C=_circuitboard
								_circuitboard=null
							else
								C=new boardtype(get_turf(src))
							user.visible_message(\
								"\red [user.name] has removed \the [C]!",\
								"You add cables to \the [C].")
						return 1
					if(istype(W, /obj/item/weapon/cable_coil))
						var/obj/item/weapon/cable_coil/C=W
						user << "You start adding cables to \the [src]..."
						playsound(src.loc, 'sound/items/Deconstruct.ogg', 50, 1)
						if(do_after(user, 20) && C.amount >= 10)
							C.use(5)
							build++
							update_icon()
							user.visible_message(\
								"\red [user.name] has added cables to \the [src]!",\
								"You add cables to \the [src].")
				if(2) // Circuitboard installed, wired.
					if(istype(W, /obj/item/weapon/wirecutters))
						usr << "You begin to remove the wiring from \the [src]."
						if(do_after(user, 50))
							new /obj/item/weapon/cable_coil(loc,5)
							user.visible_message(\
								"\red [user.name] cut the cables.",\
								"You cut the cables.")
							build--
							update_icon()
						return 1
					if(istype(W, /obj/item/weapon/screwdriver))
						user << "You begin to complete \the [src]..."
						playsound(src.loc, 'sound/items/Screwdriver.ogg', 50, 1)
						if(do_after(user, 20))
							if(!_circuitboard)
								_circuitboard=new boardtype(src)
							var/obj/machinery/embedded_controller/EC=new _circuitboard.build_path(get_turf(src))
							EC.dir=dir
							EC.pixel_x=pixel_x
							EC.pixel_y=pixel_y
							user.visible_message(\
								"\red [user.name] has finished \the [src]!",\
								"You finish \the [src].")
							del(src)
						return 1
		if(build<2)
			return ..()

		if(istype(W,/obj/item/device/multitool))
			update_multitool_menu(user,W)
		else
			..()

	update_icon()
		icon_state="airlock_control_build[build]"

	proc/return_text()

	proc/post_signal(datum/signal/signal, comm_line)
		return 0

	receive_signal(datum/signal/signal, receive_method, receive_param)
		if(!signal || signal.encryption) return

		if(program)
			program.receive_signal(signal, receive_method, receive_param)
			//spawn(5) program.process() //no, program.process sends some signals and machines respond and we here again and we lag -rastaf0

	Topic(href, href_list)
		if(..())
			return 0

		var/processed=0
		if(program)
			processed=program.receive_user_command(href_list["command"])
			spawn(5)
				program.process()
		if(processed)
			usr.set_machine(src)
			src.updateUsrDialog()
		return processed

	process()
		if(program)
			program.process()

		update_icon()
		//src.updateUsrDialog()

	radio
		var/frequency
		var/datum/radio_frequency/radio_connection

		initialize()
			set_frequency(frequency)

		post_signal(datum/signal/signal)
			signal.transmission_method = TRANSMISSION_RADIO
			if(radio_connection)
				return radio_connection.post_signal(src, signal)
			else
				del(signal)

		proc
			set_frequency(new_frequency)
				radio_controller.remove_object(src, frequency)
				frequency = new_frequency
				radio_connection = radio_controller.add_object(src, frequency)

	proc/multitool_menu(var/mob/user,var/obj/item/device/multitool/P)
		return "<b>NO MULTITOOL_MENU!</b>"

	proc/format_tag(var/label,var/varname)
		var/value = vars[varname]
		if(!value || value=="")
			value="-----"
		return "<b>[label]:</b> <a href=\"?src=\ref[src];set_tag=[varname]\">[value]</a>"

	proc/update_multitool_menu(mob/user as mob,var/obj/item/device/multitool/P)
		var/dat = {"<html>
	<head>
		<title>[name] Access</title>
		<style type="text/css">
html,body {
	font-family:courier;
	background:#999999;
	color:#333333;
}

a {
	color:#000000;
	text-decoration:none;
	border-bottom:1px solid black;
}
		</style>
	</head>
	<body>
		<h3>[name]</h3>
"}
		dat += multitool_menu(user,P)
		if(P)
			if(P.buffer)
				var/id="???"
				if(istype(P.buffer, /obj/machinery/telecomms))
					id=P.buffer:id
				else
					id=P.buffer:id_tag
				dat += "<p><b>MULTITOOL BUFFER:</b> [P.buffer] ([id])"
				if(!istype(P.buffer, /obj/machinery/telecomms))
					dat += " <a href='?src=\ref[src];link=1'>\[Link\]</a> <a href='?src=\ref[src];flush=1'>\[Flush\]</a>"
				dat += "</p>"
			else
				dat += "<p><b>MULTITOOL BUFFER:</b> <a href='?src=\ref[src];buffer=1'>\[Add Machine\]</a></p>"
		dat += "</body></html>"
		user << browse(dat, "window=mtcomputer")
		user.set_machine(src)
		onclose(user, "mtcomputer")
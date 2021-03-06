/obj/item/clothing/suit/storage
	var/list/can_only_hold = new/list() //List of objects which this item can store (if set, it can't store anything else)
	var/list/cant_hold = new/list() //List of objects which this item can't store (even if it's in the can_only_hold list)
	var/fits_max_w_class = W_CLASS_SMALL //Max size of objects that this object can store (in effect even if can_only_hold is set)
	var/max_combined_w_class = 4 //The sum of the w_classes of all the items in this storage item.
	var/storage_slots = 2 //The number of storage slots in this container.
	var/obj/screen/storage/boxes = null
	var/obj/screen/close/closer = null
	body_parts_covered = FULL_TORSO|ARMS


/obj/item/clothing/suit/storage/proc/return_inv()


	var/list/L = list(  )

	L += src.contents

	for(var/obj/item/weapon/storage/S in src)
		L += S.return_inv()
	for(var/obj/item/weapon/gift/G in src)
		L += G.gift
		if (istype(G.gift, /obj/item/weapon/storage))
			L += G.gift:return_inv()
	return L

/obj/item/clothing/suit/storage/proc/show_to(mob/user as mob)
	user.client.screen -= src.boxes
	user.client.screen -= src.closer
	user.client.screen -= src.contents
	user.client.screen += src.boxes
	user.client.screen += src.closer
	user.client.screen += src.contents
	user.s_active = src
	return

/obj/item/clothing/suit/storage/proc/hide_from(mob/user as mob)


	if(!user.client)
		return
	user.client.screen -= src.boxes
	user.client.screen -= src.closer
	user.client.screen -= src.contents
	return

/obj/item/clothing/suit/storage/proc/close(mob/user as mob)


	src.hide_from(user)
	user.s_active = null
	return

//This proc draws out the inventory and places the items on it. tx and ty are the upper left tile and mx, my are the bottm right.
//The numbers are calculated from the bottom-left The bottom-left slot being 1,1.
/obj/item/clothing/suit/storage/proc/orient_objs(tx, ty, mx, my)
	var/cx = tx
	var/cy = ty
	src.boxes.screen_loc = text("[tx],[ty] to [mx],[my]")
	for(var/obj/O in src.contents)
		O.screen_loc = text("[cx],[cy]")
		O.hud_layerise()
		cx++
		if (cx > mx)
			cx = tx
			cy--
	src.closer.screen_loc = text("[mx+1],[my]")
	return

//This proc draws out the inventory and places the items on it. It uses the standard position.
/obj/item/clothing/suit/storage/proc/standard_orient_objs(var/rows,var/cols)
	var/cx = 4
	var/cy = 2+rows
	src.boxes.screen_loc = text("4:[WORLD_ICON_SIZE/2],2:[WORLD_ICON_SIZE/2] to [4+cols]:[WORLD_ICON_SIZE/2],[2+rows]:[WORLD_ICON_SIZE/2]")
	for(var/obj/O in src.contents)
		O.screen_loc = text("[cx]:[WORLD_ICON_SIZE/2],[cy]:[WORLD_ICON_SIZE/2]")
		O.hud_layerise()
		cx++
		if (cx > (4+cols))
			cx = 4
			cy--
	src.closer.screen_loc = text("[4+cols+1]:[WORLD_ICON_SIZE/2],2:[WORLD_ICON_SIZE/2]")
	return

//This proc determins the size of the inventory to be displayed. Please touch it only if you know what you're doing.
/obj/item/clothing/suit/storage/proc/orient2hud(mob/user as mob)
	//var/mob/living/carbon/human/H = user
	var/row_num = 0
	var/col_count = min(7,storage_slots) -1
	if (contents.len > 7)
		row_num = round((contents.len-1) / 7) // 7 is the maximum allowed width.
	src.standard_orient_objs(row_num,col_count)
	return

//This proc is called when you want to place an item into the storage item.
/obj/item/clothing/suit/storage/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if(istype(W,/obj/item/weapon/evidencebag) && src.loc != user)
		return

	..()
	if(isrobot(user))
		if(isMoMMI(user))
			var/mob/living/silicon/robot/mommi/M = user
			if(M.is_in_modules(W))
				to_chat(user, "<span class='notice'>You can't throw away something built into you.</span>")
				return //Mommis cant give away their modules but can place other items
		else
			to_chat(user, "<span class='notice'>You're a robot. No.</span>")
			return //Robots can't interact with storage items.

	if(src.loc == W)
		return //Means the item is already in the storage item

	if(contents.len >= storage_slots)
		to_chat(user, "<span class='warning'>The [src] is full, make some space.</span>")
		return //Storage item is full

	if(can_only_hold.len)
		var/ok = 0
		for(var/A in can_only_hold)
			if(istype(W, text2path(A) ))
				ok = 1
				break
		if(!ok)
			to_chat(user, "<span class='warning'>The [src] cannot hold \the [W].</span>")
			return

	for(var/A in cant_hold) //Check for specific items which this container can't hold.
		if(istype(W, text2path(A) ))
			to_chat(user, "<span class='warning'>The [src] cannot hold \the [W].</span>")
			return

	if (W.w_class > fits_max_w_class)
		to_chat(user, "<span class='warning'>The [W] is too big for \the [src].</span>")
		return

	var/sum_w_class = W.w_class
	for(var/obj/item/I in contents)
		sum_w_class += I.w_class //Adds up the combined w_classes which will be in the storage item if the item is added to it.

	if(sum_w_class > max_combined_w_class)
		to_chat(user, "<span class='warning'>The [src] is full, make some space.</span>")
		return

	if(W.w_class >= src.w_class && (istype(W, /obj/item/weapon/storage)))
		if(!istype(src, /obj/item/weapon/storage/backpack/holding))	//bohs should be able to hold backpacks again. The override for putting a boh in a boh is in backpack.dm.
			to_chat(user, "<span class='warning'>The [src] cannot hold \the [W] as it's a storage item of the same size.</span>")
			return //To prevent the stacking of the same sized items.

	user.u_equip(W,1)
	playsound(get_turf(src), "rustle", 50, 1, -5)
	W.forceMove(src)
	if ((user.client && user.s_active != src))
		user.client.screen -= W
	src.orient2hud(user)
	//W.dropped(user)
	add_fingerprint(user)
	show_to(user)

/obj/item/clothing/suit/storage/MouseDrop(atom/over_object)
	if(ishuman(usr))
		var/mob/living/carbon/human/M = usr
		if (!( istype(over_object, /obj/screen/inventory) ))
			return ..()
		playsound(get_turf(src), "rustle", 50, 1, -5)
		if (M.wear_suit == src && !M.incapacitated() && Adjacent(M))
			var/obj/screen/inventory/OI = over_object

			if(OI.hand_index && M.put_in_hand_check(src, OI.hand_index))
				M.u_equip(src, 0)
				M.put_in_hand(OI.hand_index, src)
				M.update_inv_wear_suit()
				src.add_fingerprint(usr)

			return
		if( (over_object == usr && in_range(src, usr) || usr.contents.Find(src)) && usr.s_active)
			usr.s_active.close(usr)
		src.show_to(usr)
	return

/obj/item/clothing/suit/storage/attack_paw(mob/user as mob)
	//playsound(get_turf(src), "rustle", 50, 1, -5) // what
	return src.attack_hand(user)

/obj/item/clothing/suit/storage/attack_hand(mob/user as mob)
	playsound(get_turf(src), "rustle", 50, 1, -5)
	src.orient2hud(user)
	if (src.loc == user)
		if (user.s_active)
			user.s_active.close(user)
		src.show_to(user)
	else
		..()
		for(var/mob/M in range(1))
			if (M.s_active == src)
				src.close(M)
	src.add_fingerprint(user)
	return

/obj/item/clothing/suit/storage/New()
	. = ..()
	boxes = getFromPool(/obj/screen/storage)
	boxes.name = "storage"
	boxes.master = src
	boxes.icon_state = "block"
	boxes.screen_loc = "7,7 to 10,8"
	boxes.layer = HUD_BASE_LAYER
	closer = getFromPool(/obj/screen/close)
	closer.master = src
	closer.icon_state = "x"
	closer.layer = HUD_ITEM_LAYER
	orient2hud()

/obj/item/clothing/suit/emp_act(severity)
	if(!istype(src.loc, /mob/living))
		for(var/obj/O in contents)
			O.emp_act(severity)
	..()
/*
/obj/item/clothing/suit/hear_talk(mob/M, var/msg)
	for (var/atom/A in src)
		if(istype(A,/obj/))
			var/obj/O = A
			O.hear_talk(M, msg)
*/

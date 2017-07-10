pico-8 cartridge // http://www.pico-8.com
version 8
__lua__
--picolossal adventure
--version 2.0
--by mike killewald

--evil magician pixel art and animation by don behm
--add/drop sounds by dw817 (david w.)
--string->table unpacker by cheepicus

--a remake of and tribute to adventure by warren robinett for the atari video computer system

--code structure, construct definitions, sprite movement, collision, and animation routines copied from and/or
--very heavily influenced by dom8verse (by haunted tie)

--change log:
--2.0 code cleanup, token savings, changed chalice and secret room color cycle routines,
--    changed message in secret room, added new secrets with new ending and extended storyline,
--    added timer and statistics for new ending. 
--1.6 added collision flicker, grab object inside wall at edge of wall fix,
--    movement in belly of the beast fix, bridge grab-in-use fix, string->table unpacker provided
--    by cheepicus (thanks!!!), code clean up, and token reduction
--1.5 add/drop sound effect correction by dw817 (thanks, dude!)
--1.4 in game menu created, fix to black castle maze, nmsg transparency
--1.3 difficulty switch init fix, blue maze fix, code cleanup
--1.2 exits to nowhere peek fix
--1.1 exits to nowhere fix
--1.0 first release

debugstring = ""

-- wall sprite flags
fwall,hwall=0,1 -- full wall (red sprite flag), half wall (orange sprite flag)

-- color lists
allc,dragc={0,1,2,3,4,5,7,8,9,10,11,12,13,14,15},{0,1,2,4,7,9,13,14,15}

-- skin buffer for collision detection
skin=0.001

-- begin object constructs
_ball=function(rm,x,y)
	local obj=createobj(rm,x,y)
	obj.prm,obj.py,obj.hit.w,obj.hit.h,obj.spd=k[rm],y,4,4,2
	
	obj.update=function(this) 
		this.dir={x=0,y=0}
		-- player input detections
		if not displaymenu then
			if (btnp(5) and btnp(4)) displaymenu=true
			if (btn(0) and not btn(1)) this.dir.x=-1
			if (btn(1) and not btn(0)) this.dir.x=1
			if (btn(2) and not btn(3)) this.dir.y=-1
			if (btn(3) and not btn(2)) this.dir.y=1
			if btnp(4) and not btn(5) and obj.eqp then
				-- drop object at current position and play sound effect.
				obj.eqp=false
				sfx(1)
			end
		else
			-- in-game menu input detection
			if (btnp(0) or btnp(1)) displaymenu=false activeline=0
			if (btnp(2)) activeline-=1
			if (btnp(3)) activeline+=1
		end
		this.grab(this)
		-- added a small window where knubberrub is not grabbable by the player
		if ((knubberrub.fedup==0 or knubberrub.fedup>8) and not knubberrub.t and collide(this,knubberrub)) grab(this,knubberrub)
		if not this.dead then
			if exit(this) then
				scr=this.rm.scr
				if (wall(this) and not collide(this,bridge)) this.stuck=true
			end
			-- exit to nowhere fix
			if this.stuck then
				if this.dir.y!=0 then
					this.shake,this.pos.y=true,this.py-this.spd*this.dir.y						
				else
					this.pos.y,this.rm,this.stuck,this.shake=this.py,this.prm,false,false
					scr=this.rm.scr
				end
			end
			-- end exit to nowhere fix
			if (not wall(this) and not this.stuck) this.shake=false
			if not (em and em.atk) then  -- will freeze player when shot by em
				plcollision(this,true) -- move and check collisions on x axis
			  plcollision(this)	-- move and check collisions on y axis
			end
		else
 			-- player dead 
 			-- place player in stomach of murderous dragon
 			this.pos.x,this.pos.y=this.killedby.pos.x+2,this.killedby.pos.y+10 
 			-- when bat picks up murderous dragon, make sure we go with it
 			this.rm,this.shake=this.killedby.rm,true
 			scr=this.rm.scr
 		end
	end
	
	obj.grab=function(this)
		foreach(grabobj, function(obj)
			if (knubberrub.eqp!=obj and collide(this,obj)) grab(this,obj)
		end)
		if (knubberrub.eqp!=bridge and collide(this,bridge) and transparent(bridge)) grab(this,bridge) sfx(0)
	end
	
	obj.draw=function(this)
		if this.rm.dark then
			this.col=6 -- use this color for invisble/dark rooms
		else
			this.col=pget(0,16) -- get color of top left pixel of screen
		end
		local dx,dy=0,0
		if (this.shake and frame!=0) dx,dy=2,2
		rectfill(this.pos.x+this.dir.x*dx,this.pos.y+this.dir.y*dy,this.pos.x+3+this.dir.x*dx,this.pos.y+3+this.dir.y*dy,this.col)
	end
	
	return obj
end

_key=function(rm,x,y,c)
	local obj=createobj(rm,x,y)
	obj.col,obj.c,obj.spr,obj.hit.h,obj.type=c,0,16,3,"item"

	obj.draw=function(this)
		pal(14,this.col,0)
	end
	
	return obj
end

_sword=function(rm,x,y)
	local obj=createobj(rm,x,y)
	obj.spr,obj.hit.h,obj.type=49,5,"item"

	obj.draw=function(this)
		pal(14,10,0)
	end
	
	return obj
end

_magnet=function(rm,x,y)
	local obj=createobj(rm,x,y)
	obj.spr,obj.hit.h,obj.type=34,8,"item"

	obj.update=function(this)
		this.seek(this)
		exit(this)
	end
	
	obj.seek=function(this)
		foreach(this.want, function(obj)
			if not this.busy and obj.rm==this.rm then
				this.wanted=obj
				obj.attract,this.busy=true,true
			end
		end)
	end
	
	return obj
end

_bridge=function(rm,x,y)
	local obj=createobj(rm,x,y)
	obj.spr,obj.sprw,obj.sprh,obj.hit.w,obj.hit.h,obj.type=13,3,3,24,24,"item"
	
	return obj
end

_chalice=function(rm,x,y)
	local obj=createobj(rm,x,y)
	obj.spr,obj.sprh,obj.hit.h,obj.lvl3,obj.type,obj.cnt=32,2,9,{19,26},"item",0
	
	obj.update=function(this)
		this.col=randomcol(allc)
		rgate.col=this.col
		if pl.rm==k[30] and this.rm==k[30] then
			if (secrets==1) secrets=2
			k[30].exit.r=31
		elseif not em and not this.t and pl.rm==k[37] and pl.eqp==this and pl.pos.y<96 then
			if (secrets==2) secrets=3
			this.t=1
		end
		if this.t==1 then
			transform(49,1,5,2)
		elseif this.t==3 then
			 transform(32,2,9,false)
		end
		if (this.cnt==0 and this.t==2 and pl.eqp==this and not pl.dead) this.shoot(this)
		magnetism(this)
		exit(this)
	end

	obj.draw=function(this)
		pal(14,this.col,0)
	end
	
	obj.shoot=function(this)
		local x=7
		if (this.pos.x<pl.pos.x) x=0
		if (btnp(5)) b=_b(45,this.pos.x+x,this.pos.y+2) b.rm=this.rm this.cnt+=1 fired+=1
  end
  	
	return obj
end

_bat=function(rm,x,y)
	local obj=createobj(rm,x,y)
	obj.spd,obj.spr,obj.sprh,obj.sproff,obj.animspd,obj.frames,obj.hit.h,obj.fedup,obj.type=2,1,2,0,0.25,2,11,0,"item" -- typed as an item so player can grab it

	obj.update=function(this)
		if this.fedup==0 then
			this.seek=true
		else 
			this.fedup+=1
			if (this.fedup==230) this.fedup=0
		end
		this.anim(this)
		if (pl.eqp!=this) move(this)
		if this.seek then
			foreach(this.want, function(obj)
				if (not this.wanted and obj.rm==this.rm and this.eqp!=obj) this.wanted=obj
			end)
			if this.wanted and this.wanted.rm==this.rm and this.eqp!=this.wanted then
				this.steal(this)
			else
				this.wanted=false
			end
		end
		if ykey.t==1 then
			ykey.shake=true
			ykey.c+=1
			if ykey.c>=25 then
				ykey.t,ykey.spr,ykey.shake,this.t,this.cnt=2,0,false,3,0
				em=_em(45,ykey.pos.x-3,ykey.pos.y-10)
			end 
		end
		if not em and pl.rm==k[45] and not this.t then
			if (secrets==3) secrets=4
			this.rm=ykey.rm
			this.fedup,this.want,this.t=0,{ykey},1
		elseif this.eqp==ykey and this.t==1 then
			this.rm=k[45]
			this.pos.x,this.pos.y,this.dir.x,this.dir.y,this.t=0,54,1,0,2
		elseif this.t==2 and ykey.pos.x>58 then
			this.eqp,this.want,this.dir.x,this.dir.y=false,{},1,-1
			del(grabobj,ykey)
			if (this.pos.x==90) ykey.t=1 
		elseif this.t==3 then
			this.cnt+=1
			if (this.cnt>240 and this.rm!=pl.rm) this.dir.x,this.dir.y,this.cnt=flr(rnd(3)-1),sgn(sin(rnd(1))),0
			if (this.eqp==chalice) this.t=4
		end
		if exit(this) then
			if this.t==3 and pl.dead and this.eqp!=chalice then
				this.fedup,this.want,this.rm=0,{chalice},chalice.rm
			elseif this.t==4 then
				repeat
					this.rm=k[garden[flr(rnd(5)+1)]]
				until this.rm!=pl.rm
				chalice.rm,this.eqp,this.want,this.t=this.rm,false,{},6
				repeat 
					randompos(chalice)
				until not wall(chalice)
			elseif this.t==7 and not chalice.t then
				this.fedup,this.want,this.rm=0,{chalice,sword,bridge,ykey,wkey,bkey,rhindle,yorgle,grundle,magnet},chalice.rm
				if (this.eqp==chalice) this.rm,this.t=k[2],false
			end
		end
	end

	obj.steal=function(this)
		local i=this.wanted
		if pl.eqp!=this then
			this.dir.x=getdir(this.spd,i.pos.x,this.pos.x)
			this.dir.y=getdir(this.spd,i.pos.y,this.pos.y)
		end
		if collide(this,i) then
			if (pl.eqp==i) pl.eqp=false
			grab(this,i)
			this.seek,this.wanted,this.fedup=false,false,1
		end
	end

	obj.anim=function(this)
		this.sproff+=this.animspd
		-- fly animation contains 2 frames, so %2
		this.spr=1+this.sproff%2
		if (this.sproff==2) this.sproff=0
	end

	return obj
end

_dragon=function(rm,x,y,c)
	local obj=createobj(rm,x,y)
	obj.col,obj.spr,obj.sprh,obj.sproff,obj.animspd,obj.frames,obj.hit.h,obj.fear,obj.fi,obj.want,obj.wi,obj.weak,obj.type=c,3,3,0,0.25,2,20,{},1,{pl},1,sword,"dragon"

	obj.update=function(this)
		if (pl.rm==this.rm) this.wi=1 
		if not this.dead then
			if ldiff=="a" then
				this.atkwait=6 -- about 1.5 seconds
			else
				this.atkwait=15 -- about 3 seconds
			end
			if not this.atk then
				if pl.rm==this.rm and not pl.dead and this.weak then
					if collide(this,this.weak) then
						this.dead,this.hit.h=true,17 
						sfx(2)
					end
				end
				if not this.killedplayer then
					this.spr=3
					if (knubberrub.eqp!=this) move(this)
					if (this.want[this.wi].rm==this.rm) this.guard(this)
					if (#this.fear>0 and this.fear[this.fi].rm==this.rm) this.flee(this)
					if collide(this,pl) then 
						this.atk,this.pos.x,this.pos.y=true,pl.pos.x,pl.pos.y
						sfx(3)
					end
				end
			else
				-- attack!
				this.sproff+=this.animspd
				if this.sproff>this.atkwait then
					this.kill(this)
					this.atk,this.sproff=false,0
				end
			end
			if #this.fear>0 then
				if (this.fear[this.fi].rm!=this.rm) this.fi+=1 
				if (this.fi>#this.fear) this.fi=1
			end
			if (this.want[this.wi].rm!=this.rm) this.wi+=1
			if (this.wi>#this.want) this.wi=1
		end
		if (exit(this)) this.fi=1 this.wi=1
		if (this.update2) this.update2(this)
	end
	
	obj.draw=function(this)
		pal(14,this.col,0) 
		if not this.dead then
			if this.atk then
				this.spr=4
				palt(15,true)
			else
				this.spr,this.eat=3,false
			end
		else
			-- dragon slayed
			this.spr=5
			palt(15, true)
		end
	end
	
	obj.flee=function(this)
		this.dir.x=getdir(this.spd,this.pos.x,this.fear[this.fi].pos.x)
		this.dir.y=getdir(this.spd,this.pos.y,this.fear[this.fi].pos.y)
	end
	
	obj.guard=function(this)
		this.dir.x=getdir(this.spd,this.want[this.wi].pos.x,this.pos.x)
		this.dir.y=getdir(this.spd,this.want[this.wi].pos.y,this.pos.y,false,true)
	end
	
	obj.kill=function(this)
		if collide(this,pl) then
			sfx(4)
			pl.dead,this.killedplayer,pl.killedby=true,true,this
		end
	end
	add(collideobj,obj)
	return obj
end

-- stone dragons
_sd=function(rm,x,y,c)
	local obj=_dragon(rm,x,y,c)
	obj.weak,obj.spd,obj.type2=false,0,"stone"
	
	obj.update2=function(this)
		trigd(this)
		if chalice.t==2 and this.spd!=0 then
			if rdiff=="a" then
				this.fear={chalice}
			else
				this.fear={}
			end			
		end
	end
end

-- frozen dragons
_fd=function(rm,x,y,c)
	local obj=_dragon(rm,x,y,c)
	obj.weak,obj.spd,obj.type2=false,0,"frozen"
	
	obj.update2=function(this)
		trigd(this)
		if not this.t and pl.rm==this.rm and pl.pos.x>=30 and pl.pos.x<=94 and pl.pos.y>=42 and pl.pos.y<=80 then
			if (this.sproff==0) this.atk=true sfx(3)
		end
	end
end

_gate=function(k,rm,x,y,c)
	local obj=createobj(rm,x,y)
	obj.col,obj.spr,obj.hit.w,obj.hit.h,obj.locked,obj.type,obj.animspd,obj.off,obj.drawoverride=c,33,7,16,true,"gate",0.25,3,true

	obj.update=function(this)
		if not this.locked then
			this.hit.h=4 
			unlock(this)
			-- roll up the gate
			if this.off>0 then 
				this.off-=this.animspd
			elseif this.off<=0 and collide(this,k) and pl.dir.y==1 then
				this.locked=true
			end
		end
		if this.locked then
			lock(this)
			-- roll down the gate
			if this.off<3 then
				this.off+=this.animspd
			else
				this.hit.h=16
				if collide(this,k) then
					this.locked=false
				end
			end
		end
	end
	
	obj.draw=function(this)
		pal(14,this.col,0)
		for i=0,this.off do
			spr(this.spr,this.pos.x,this.pos.y+4*i,1,1)
		end
	end

	return obj
end

_missile=function(rm,x,y)
	local obj=createobj(rm,x,y)
	obj.spr,obj.hit.w,obj.hit.h,obj.col,obj.type,obj.update,obj.drawoverride=50,2,96,0,"wall",false,true

	obj.draw=function(this)
		pal(14,this.col,0) 
		for i=0,11 do
			spr(this.spr,this.pos.x,this.pos.y+i*8,1,1)
		end
		pal(14,14,0) 
	end

	return obj
end

_dot=function(rm,x,y)
	local obj=createobj(rm,x,y)
	obj.hit={x=-1,y=-1,w=3,h=3}
	obj.type="dot"          

	obj.update=function(this)
		exit(this)
	end
	
	obj.draw=function(this)
		pal(14,6,0)
		circ(this.pos.x,this.pos.y,0,14) 
		pal(14,14,0)
	end

	return obj
end

_msg=function(rm,x,y)
	local obj=createobj(rm,x,y)
	obj.hit.y,obj.hit.h,obj.coloff,obj.colspd,obj.col,obj.update,obj.drawoverride=2,94,0,0.35,{12,12,13,2,1,1,2,13,12},false,true

	obj.draw=function(this)
		-- cycle colors
		this.coloff+=this.colspd
		pal(14,this.col[flr(this.coloff%9)],0)
		if this.coloff<48 then
			this.spr={64,65,66}
		elseif this.coloff>=48 and this.coloff<96 then
			this.spr={67,68,69}
		end
		spr(this.spr[1],this.pos.x,this.pos.y,1,4)
		spr(this.spr[2],this.pos.x,this.pos.y+32,1,4)
		spr(this.spr[3],this.pos.x,this.pos.y+64,1,4)
		if (this.coloff>=96) this.coloff=0
		pal(14,14,0)
	end
	
	return obj
end

-- magic bullet
_b=function(rm,x,y)
	local obj=createobj(rm,x,y)
	obj.hit.w,obj.hit.h,obj.spd=1,1,3
	
	obj.update=function(this)
		if (pl.eqp==chalice) obj.dir.x=getdir(this.spd,chalice.pos.x,pl.pos.x,true)
		move(this)
		if exit(this) or wall(this) then 
			this.del(this)
		elseif em and em.t==1 and collide(this,em) then
			hit+=1
			em.shot=true
			this.del(this)
		end
	end
	
	obj.draw=function(this)
		rectfill(this.pos.x,this.pos.y,this.pos.x+1,this.pos.y+1,randomcol(allc))
	end
	
	obj.del=function(this)
		del(objects,this)
		if (chalice.cnt!=0) chalice.cnt-=1
	end
	
	return obj
end

-- evil magician	
_em=function(rm,x,y)
	local obj=createobj(rm,x,y)
	obj.spr,obj.sproff,obj.animspd,obj.c,obj.atkc,obj.hit.x,obj.hit.w,obj.hit.h,obj.sprh,obj.sprw,obj.s,obj.shake=72,0,1,0,0,4,10,16,2,2,0,true
		
	obj.update=function(this)
		this.c+=1
		if not this.t and this.c>30 then
			randompos(this)
			this.t,this.spr,this.c,this.shake=1,70,0,false
	  end
	  if this.t==1 then
			if pl.pos.x>this.pos.x+this.hit.x+this.hit.w then
				obj.fx=true
			elseif pl.pos.x+3<this.pos.x then 
				obj.fx=false
			end
			if this.shot then 
				this.s+=1
				this.atk,this.shot=true,false
			end
			if this.atk then
				this.shake,this.spr=true,74
				this.atkc+=1			
			else
				this.shake,this.spr,this.atkc=false,70,0
			end
			if (this.atkc>15) this.atk=false
			if this.atkc==10 then
				pl.eqp=false
				if level==3 then
					-- level 3: place chalice/sword in random lair room 
				  while chalice.rm==pl.rm do
					  chalice.rm=k[lair[flr(rnd(6)+1)]]
				  end
				end
				-- place chalice/sword in random position in the room, but don't place it inside a wall
				repeat
					randompos(chalice)
				until not wall(chalice)	
			end
	 		foreach(lair,function(o)
	 			if (pl.rm==k[o] and not this.atk) this.rm=pl.rm
	 		end)
	 		if (this.s==5) this.t,this.c,this.atk=2,0,false  -- 5 shots needed to kill em
	 		if (collide(this,pl) or collide(this,chalice)) randompos(this)
			if this.c==15 or this.c==30 then 
				if (not this.shot and not this.atk) randompos(this)
				if this.c==30 then
					this.c=0
					if pl.rm==this.rm and not pl.dead then
						bd=_dragon(45,this.pos.x,this.pos.y,randomcol(dragc))
				 		bd.rm,bd.weak,bd.type2,bd.dcnt=this.rm,chalice,"boss",0
				 	end
				end
			end
		elseif this.t==2 then
			this.shake,this.spr,this.pos.x,this.pos.y=true,72,56,55
			if (this.c>25) this.c,this.t=0,3
		elseif this.t==3 then
			this.shake=false
			if this.spr!=109 then
				 this.anim(this)
			else
				ykey.rm,ykey.pos.x,ykey.pos.y,ykey.spr,chalice.t,this.t,knubberrub.t,k[50].exit.l,k[49].exit.b=this.rm,this.pos.x+3,this.pos.y+12,16,3,4,7,37,37
				add(grabobj,ykey)
		 	end
		end
	end
	
	obj.draw2=function(this)
		if this.atk and this.t==1 and chalice.rm==this.rm then
			if frame!=0 and this.atkc<10 then
				local xoff=2
				if (this.fx) xoff=12
				line(this.pos.x+xoff,this.pos.y+7,chalice.pos.x+4,chalice.pos.y+2,randomcol(allc))
			end
		end
	end
	
	obj.anim=function(this)
		if (this.spr<103) this.spr=103
		this.sproff+=this.animspd
		-- animation contains 4 frames, so %4
		if this.sproff%4==0 then
			this.spr+=2
		end
	end
	
	return obj
end
-- end object constructs


-- create a defualt object
function createobj(r,x,y)
	local o={}
	--further token savings can be done here if needed.
	o.rm=k[r]
	o.pos={x=x,y=y}
	o.off={x=0,y=0}
	o.grab={x=0,y=0}
	o.dir={x=0,y=0}
	o.spd=1 -- default speed for magnet attract
	o.hit={x=0,y=0,w=8}
	o.sprw=1
	o.sprh=1
	o.lvl3={1,29}
	
	-- defining update inside a construct overrides this
	o.update=function(this)
		magnetism(this)
		exit(this)
	end
	
	add(objects,o)
	return o
end

-- cond3==true for bullets only
-- cond4==true for hop (only on dragon movement)
function getdir(spd,cond1,cond2,cond3,cond4)
	local dir
	if cond1<cond2 and cond2-cond1>=spd then
		dir=-1
	elseif cond3 or (cond1>cond2 and cond1-cond2>=spd) then
		dir=1
	elseif cond4 and cond1==cond2 then
		dir=1
	else
		dir=0 
	end
	return dir
end

function move(o)
	o.pos.x+=o.dir.x*o.spd
	o.pos.y+=o.dir.y*o.spd	
end

function equip(p,o)
	if p.eqp==o then
		o.rm=p.rm		
		o.pos.x=p.pos.x-o.off.x+4*o.grab.x
		o.pos.y=p.pos.y-o.off.y+4*o.grab.y
	end
end

function grab(p,o)
	p.eqp=o
	o.off.x=p.pos.x-o.pos.x
	o.off.y=p.pos.y-o.pos.y
	if p.dir.x==0 and p.dir.y==0 then
		o.grab=o.dir
	else 
		o.grab=p.dir
	end
	if (p==pl) sfx(0)
end

function unlock(o)
	o.rm.exit.ci=o.rm.ci -- make castle in available
	k[o.rm.ci].exit.co=o.rm.co -- make castle out available
end

function lock(o)
	o.rm.exit.ci=false -- make castle in unavailable
	k[o.rm.ci].exit.co=false -- make castle out unavailble
end

-- cond1==true for x-axis
function plcollision(o,cond1)
	local buffer
	local collision
	if cond1 then
		buffer=o.pos.x
		o.pos.x+=o.dir.x*o.spd
	else
		buffer=o.pos.y
		o.pos.y+=o.dir.y*o.spd
	end
	if cond1 or not collide(o,bridge) or o.eqp==bridge or knubberrub.eqp==bridge then 
		if wall(o) then
			--debugstring="wall()"
			o.grab(o)
			o.shake,collision=true,true
		end
	end
	foreach(collideobj, function(obj)
		if obj.type=="gate" and not obj.locked then
			-- skip gate collision when unlocked
		elseif cond1 and obj==k3 and secret() then
			if (secrets==0) secrets=1
			k[3].exit.r=30
			-- skip k3 barrier x collision
		elseif (obj.type!="dragon" and collide(o,obj)) or
		((obj.spr==4 or (obj.spr==5 and not o.eqp)) and collide(o,obj) and transparent(obj)) then
			-- allows for collisions with locked gates, "missle" barriers, and thng
			-- allows for transparent collisions with dragon attack/dead sprites
			--debugstring="collide()"
			o.shake,collision=true,true
		end
	end)
	if collision and cond1 then
		o.pos.x=buffer
	elseif collision then
		o.pos.y=buffer
	end
end

-- detect collision on full or half wall map tiles
function wall(o)
	local d=false
	local scrx,scry=o.rm.scr.x*16,o.rm.scr.y*12 -- generate sprx values 0-15, generate spry values 0-15
	-- top left corner
	mspr=mget(flr((o.pos.x + o.hit.x)/8 + scrx + skin),flr((o.pos.y + o.hit.y)/8 + scry + skin)) -- get map tile sprite
	if (o.pos.x+o.hit.x>=0 and o.pos.y+o.hit.y>=16) d=chktile(o,mspr,0)
	-- top right corner
	if d==false then
		mspr=mget(flr((o.pos.x + o.hit.x + o.hit.w)/8 + scrx - skin),flr((o.pos.y + o.hit.y)/8 + scry + skin))
		if (o.pos.x+o.hit.x+o.hit.w<=128 and o.pos.y+o.hit.y>=16) d=chktile(o,mspr,1)
	end
	-- bottom left corner
	if d==false then
		mspr=mget(flr((o.pos.x + o.hit.x)/8 + scrx + skin),flr((o.pos.y + o.hit.y + o.hit.h)/8 + scry - skin))
		if (o.pos.x+o.hit.x>=0 and o.pos.y+o.hit.y+o.hit.h<=112) d=chktile(o,mspr,2)
	end
	-- bottom right corner
	if d==false then
		mspr=mget(flr((o.pos.x + o.hit.x + o.hit.w)/8 + scrx - skin),flr((o.pos.y + o.hit.y + o.hit.h)/8 + scry - skin))
		if (o.pos.x+o.hit.x+o.hit.w<=128 and o.pos.y+o.hit.y+o.hit.h<=112) d=chktile(o,mspr,3)
	end
	return d
end

-- takes a map tile sprite and returns true if fwall flag set. if hwall flag is set, check pixel color under each corner of 
-- player and returns true if pixel color is not transparent (color 6 light grey) before any color cycling
function chktile(o,spr,corner)
	if fget(spr,fwall) then
		return true
	elseif fget(spr,hwall) then
		local pcol,sprx,spry=0,spr%16,flr(spr/16) -- generate sprx values 0-15, generate spry values 0-15
		if corner==0 then -- top left corner
			pcol=sget(sprx*8+o.pos.x%8,spry*8+o.pos.y%8)
		elseif corner==1 then --top right corner
			pcol=sget(sprx*8+(o.pos.x+3)%8,spry*8+o.pos.y%8)
		elseif corner==2 then -- bottom left corner
			pcol=sget(sprx*8+o.pos.x%8,spry*8+(o.pos.y+3)%8)
		else -- bottom right corner
			pcol=sget(sprx*8+(o.pos.x+3)%8,spry*8+(o.pos.y+3)%8)
		end
		if (pcol!=6) return true
	end
	return false
end

-- this is used for checking transparancy when player collides with another object's sprite
function transparent(o)
	-- locate o.spr on sprite sheet and determine sprx,spry coordinates
	-- sprite sheet is 16 sprites wide (sprx) by 16 sprites high (spry)
	-- and calculate player top left position within sprite
	local sprx,spry=o.spr%16,flr(o.spr/16)
	local pcol,x,y,w,h=6,pl.pos.x-(o.pos.x+o.hit.x),pl.pos.y-(o.pos.y+o.hit.y),o.hit.w-1,o.hit.h-1
	-- check pl top left corner
	if x>=0 and x<=w and y>=0 and y<=h then
		pcol=sget(sprx*8+x+o.hit.x,spry*8+y+o.hit.y)
	end
	-- check pl top right corner
	if pcol==6 and x+3>=0 and x+3<=w and y>=0 and y<=h then
		pcol=sget(sprx*8+x+3+o.hit.x,spry*8+y+o.hit.y)
	end
	-- check pl bottom left corner
	if pcol==6 and x>=0 and x<=w and y+3>=0 and y+3<=h then
		pcol=sget(sprx*8+x+o.hit.x,spry*8+y+3+o.hit.y)
	end
	-- check pl bottom right corner
	if pcol==6 and x+3>=0 and x+3<=w and y+3>=0 and y+3<=h then
		pcol=sget(sprx*8+x+3+o.hit.x,spry*8+y+3+o.hit.y)
	end
	if pcol!=6 then
		return true
	else
		return false
	end
end
	
-- detect if 2 objects with hitbox are colliding
function collide(o, o2)
	if o.rm == o2.rm and o2.pos.x+o2.hit.x+o2.hit.w > o.pos.x+o.hit.x and -- o2 right edge > o left edge and
		o2.pos.y+o2.hit.y+o2.hit.h > o.pos.y+o.hit.y and -- o2 bottom edge > o top edge and 
		o2.pos.x+o2.hit.x < o.pos.x+o.hit.x+o.hit.w and -- o2 left edge < o right edge and
		o2.pos.y+o2.hit.y < o.pos.y+o.hit.y+o.hit.h then -- o2 top edge < o bottom edge
		return true
	else
		return false
	end
end

-- moves desired object toward magnet
function magnetism(o)
	if not magnet.busy or o.attract then
		if magnet.wanted==o and o.rm==magnet.rm and pl.eqp!=o and knubberrub.eqp!=o then
			o.attract=true
			magnet.busy=true
			o.dir.x=getdir(o.spd,magnet.pos.x,o.pos.x)
			o.dir.y=getdir(o.spd,magnet.pos.y+8,o.pos.y)
			move(o)
			if o.pos.x==magnet.pos.x and o.pos.y==magnet.pos.y+8 then
				magnet.busy=false
			end
		end
		-- handle case where magnet leaves the room
		if o.rm!=magnet.rm then 
			o.attract=false
			magnet.busy=false 
		end
	end
end

function exit(o)
	-- check left exit
	if o.rm.exit.l and o.pos.x+o.hit.x<0 then
		if (o.prm) o.prm=o.rm
		o.rm=k[o.rm.exit.l]
		o.pos.x=128-o.hit.w-o.hit.x
		return true
	-- check right exit
	elseif o.rm.exit.r and o.pos.x+o.hit.x>124 then
		if (o.prm) o.prm=o.rm
		o.rm=k[o.rm.exit.r]
		o.pos.x=0-o.hit.x
		return true
	-- check top exit
	elseif o.rm.exit.t and o.pos.y+o.hit.y<16 then
		if (o.prm) o.prm=o.rm
		if (o.py) o.py=16
		o.rm=k[o.rm.exit.t]
		o.pos.y=112-o.hit.h-o.hit.y
		return true
	-- check castle entrance
	elseif o.rm.exit.ci and o.pos.x>=60 and o.pos.x<=64 and o.pos.y<=72 and o.pos.y>56 then
		if (o.prm) o.prm=o.rm
		o.rm=k[o.rm.exit.ci]
		o.pos.y=112-o.hit.h-o.hit.y
		return true
	-- check castle exit
	elseif o.rm.exit.co and o.pos.x+o.hit.x>=48 and o.pos.x+o.hit.x<=76 and o.pos.y+o.hit.y>108 then
		if (o.prm) o.prm=o.rm
		o.rm=k[o.rm.exit.co]
		o.pos.x=62 o.pos.y=74
		return true
	-- check bottom exit
	elseif o.rm.exit.b and o.pos.y+o.hit.y>108 then
		if (o.prm) o.prm=o.rm
		if (o.py) o.py=108
		o.rm=k[o.rm.exit.b]
		o.pos.y=16-o.hit.y
		return true
	else
		return false
	end
end

function secret()
	local s=false
	if pl.rm==k[3] and md.rm==k[3] then
		foreach(objects, function(obj)
			if (obj.rm==k[3] and (obj.type=="item" or obj.type=="dragon")) s=true
		end)
	end
	return s
end

function transform(endspr,endsprh,endhith,endt)
	if not chalice.c then
		chalice.c,chalice.shake=0,true
		pl.eqp=false
		del(grabobj,chalice)
	end
	chalice.c+=1
	if chalice.c>30 and chalice.c<=60 then
		if frame!=0 then
			chalice.spr,chalice.sprh=32,2
		else
			chalice.spr,chalice.sprh=102,2
		end
	elseif chalice.c>60 and chalice.c<=90 then
		chalice.spr,chalice.sprh,chalice.hit.h,chalice.fx=endspr,endsprh,endhith,1
		add(grabobj,chalice)
	elseif chalice.c>90 then
		chalice.t,chalice.shake,chalice.c=endt,false,false
	end
end
	
function trigd(o)
	if (o.t==1) awoken+=1 o.t=2
	if (not o.t and o.atk) o.spd=1 o.col=randomcol(dragc)
	if (not o.t and not o.atk and o.spd!=0) o.t=1
	if (chalice.t==2 and o.spd!=0) o.weak=chalice
	if (not chalice.t) o.weak=false
end

function randompos(o)
	local nx,ny=flr(rnd(112))+6,flr(rnd(68))+22
	o.pos.x,o.pos.y=nx,ny
end 

function randomcol(clist)
	return clist[flr(rnd(#clist)+1)]
end

function reincarnate()
	reinc+=1
	pl.shake,pl.rm=false,k[17]
	pl.prm=pl.rm
	scr=pl.rm.scr
	pl.pos.x,pl.pos.y,pl.dir.x,pl.dir.y=62,90,0,0
	pl.py=pl.pos.y
	pl.dead,pl.eqp,pl.killedby=false,false,false
	if (knubberrub.t==6) knubberrub.t=3
	if (em and em.s<5) em.s=0
	foreach(objects, function(obj)
		if obj.type2=="stone" or obj.type2=="frozen" or obj.type2=="boss" then
			del(objects, obj)
			del(collideobj,obj)
		elseif obj.type=="dragon" then
			obj.dead=false obj.killedplayer=false obj.hit.h=20
		end
	end)
	initdragons()
end

function toggleldiff()
	if ldiff=="a" then
		ldiff,ldiffstr="b",ldiffstrb
	else
		ldiff,ldiffstr="a",ldiffstra
	end
end

function togglerdiff()
	if rdiff=="a" then
		rdiff,rdiffstr="b",rdiffstrb
		yorgle.fi,yorgle.fear=1,{ykey}
		grundle.fi,grundle.fear=1,{}
		rhindle.fi,rhindle.fear=1,{}
	else
		rdiff,rdiffstr="a",rdiffstra
		yorgle.fi,yorgle.fear=1,{sword,ykey}
		grundle.fi,grundle.fear=1,{sword}
		rhindle.fi,rhindle.fear=1,{sword}
	end
end

function center(s,y,c)
	print(s,(128-#s*4)/2,y,c)
end

function showmenu()
	local menux,menuy=31,42
	local menutxt={"reincarnate",ldiffstr,rdiffstr,"reset cart","exit menu"}
	local line,linecolor=0,0
	if (not activeline) activeline=0
  if (activeline < 0) activeline=#menutxt-1
  if (activeline > #menutxt-1) activeline=0
  if btnp(4) and not btn(5) then
		if activeline==0 then
			reincarnate()
			displaymenu,activeline=false,false
		elseif activeline==1 then
			toggleldiff()
		elseif activeline==2 then
			togglerdiff()
		elseif activeline==3 then
			displaymenu,activeline=false,false
			_init()
		else
			displaymenu,activeline=false,false
		end				
	end
	rectfill(menux,menuy,menux+64,menuy+#menutxt*6+6,13)
	rect(menux,menuy,menux+64,menuy+#menutxt*6+6,5)
	foreach (menutxt, function(obj)
		if line==activeline then
			if pl.col==6 then
				linecol=9
			else
				linecol=pl.col
			end
		else
			linecol=6
		end
		center(obj,menuy+4+line*6,linecol)
		line+=1
	end)
end

function _update()
	debugstring="mem:"..stat(0)
	if rungame then
		if not endgame then
			if (timer < 32400) timer += 1/30
			foreach(objects, function(obj) 
				if (obj.update) obj.update(obj)
				if (obj.type=="item" or obj.type=="dot") equip(pl,obj)
				if (obj.type=="item" or obj.type=="dragon") equip(knubberrub,obj)
				if obj.type2=="boss" then
					if (em.t==2) obj.dead=true
					if obj.dead then
						 obj.dcnt+=1
						 if (em.t==1) slayed+=1
					end
					if (obj.dcnt>8) del(objects,obj) del(collideobj,obj)
					if (not pl.dead and obj.killedplayer) obj.killedplayer=false
				end
				if em and em.t==4 and ykey.t==2 then
					if obj!=yorgle and obj.type=="dragon" then
						foreach(obj.fear,function(obj2)
							if (obj2==ykey) obj.r=true
						end) 
						if (not obj.r) add(obj.fear,ykey)
					end
				end		
			end)
		else
			-- end game
			chalice.update(chalice)
			if (btnp(4) and btnp(5)) _init()
		end
	else
		-- menu screen input detection
		if btnp(5) then
			if level==3 then
				level=1
			else
				level+=1
			end
		elseif btnp(4) then
			scr=pl.rm.scr 
			rungame=true
			initgame()
		end 
	end
	if endgame and playmusic==true then
		playmusic=false
		music(0)
	end	
end

function _draw()
	cls(6) -- light grey
	palt(0,false) -- black not transparent
	palt(6, true) -- light grey is transparent 
	if rungame then
		if frame==0 then
			frame+=1
		else
			frame=0
		end
		-- check if invisible/dark room
		if pl.rm.dark then
			rectfill(pl.pos.x-16,pl.pos.y-16,pl.pos.x+19,pl.pos.y+19,9) -- turn on "flashlight" 
			drawobjects() -- draw all objects so they are "under" the map (accurate to original)
			pal(14,6,0)
			drawmap()
			pal(14,14,0)
		else
			-- regular non-invisible rooms
			drawmap()
			drawobjects() -- draw objects last so they are "on top" of the map
		end
	else
		-- draw level select screen
		scr={x=7,y=1} 
		drawmap()
		spr(50+level,60,56,1,1)
	end

	-- achieve 4:3
	rectfill(0,0,127,15,0)
	rectfill(0,112,127,127,0)
	
	-- draw boss health bar
	if em and em.s < 5 then 
		if em.s == 4 then
			barcolor = 10
		else
			barcolor = 13
		end
		rectfill(102,8,127,12,5)
		rectfill(102,8,127-em.s*6,12,barcolor)
	end
	--print(timer,100,8,13)
	if (displaymenu) showmenu()
	if (endgame and secrets!=0) theend()
end

function drawmap()
	-- draw room from kingdom map
	-- check if chalice in yellow castle
	if chalice.rm==k[18] and pl.rm==k[18] then
		-- cycle yellow castle wall color before map is drawn
		ycoff+=ycspd
		yc=ycoff%16
		pal(10,yc,0) 
		endgame=true
	end
	map(0+scr.x*16,2+scr.y*12,0,16,16,12)
	pal(10,10,0) -- yellow back to yellow 
end

function drawobjects()
	-- launch draw() method on each object
	foreach(objects, function(obj) 
		if pl.rm==obj.rm and obj!=em then
			if (obj.draw) obj.draw(obj) -- get object specific pre-draw code
			-- and also do this, if conditions apply
			if obj.spr and not obj.drawoverride then
				drawspr(obj)
			end
		end
	end)
	if (em and pl.rm==em.rm) drawspr(em) -- place em on top of all other objects
end

function drawspr(obj)
	local ox=0
	local oy=0
	local s=flr(rnd(4))
	if obj.shake then
		ox=flr(rnd(2))
		oy=flr(rnd(2))
  	if (s==1) ox=-ox
  	if (s==2) ox,oy=-ox,-oy
  	if (s==3) oy=-oy
  end
	spr(obj.spr,obj.pos.x+ox,obj.pos.y+oy,obj.sprw,obj.sprh,obj.fx,obj.fy) 
	if (obj.draw2) obj.draw2(obj)
	pal(14,14,0)
	palt(15,false)
end

function theend()
	seconds=timer
	hours=0
	minutes=0
	while seconds>3599 do
		seconds-=3600
		hours+=1
	end
	while seconds>59 do
		seconds-=60
		minutes+=1	
	end
	elapsed=""
	if hours !=0 then
		elapsed=hours..":"
		if (minutes<10) elapsed=elapsed.."0"
		elapsed=elapsed..minutes..":"
		if (seconds<10) elapsed=elapsed.."0"
	elseif minutes !=0 then
		elapsed=minutes..":"
		if (seconds<10) elapsed=elapsed.."0"
	end 
	elapsed=elapsed..seconds
	padding = ""
	for i=1,15-#elapsed do
		padding = padding.." "
	end
	if secrets>1 then
		center("level: "..level..padding..elapsed,29,13)
		center("secrets found: "..secrets.."/4",41,13)
		center("reincarnations: "..reinc,47,13)
		center("dragons awoken: "..awoken,53,13)
		if secrets>2 then
			center("shots fired/hit: "..fired.."/"..hit,65,13)
			if (fired!=0) accuracy=hit/fired*100
			center("accuracy: "..accuracy.."%",71,13)
			if (secrets>3) center("boss dragons slayed: "..slayed,83,13)
		end
	end
end

function initdragons()
	-- further token savings available here
	sd1,sd2,sd3,sd4,sd5,sd6,sd7,sd8,sd9=_sd(31,111,33,5),_sd(31,111,75,5),_sd(32,15,55,5),_sd(32,105,55,5),_sd(35,23,68,5),_sd(35,97,68,5),_sd(36,89,54,5),_sd(34,47,48,5),_sd(34,79,64,5) -- token saving
	fd1=_fd(37,17,74,12)
	fd2,fd3,fd4,fd5=fdg(38,4)
	fd6,fd7,fd8,fd9=fdg(39,4)
	fd10,fd11,fd12,fd13=fdg(40,4)
	fd14,fd15,fd16,fd17=fdg(41,4)
	fd18,fd19,fd20=fdg(42,3)
	fd21,fd22,fd23=fdg(43,3)
	fd24,fd25,fd26=fdg(44,3)
end

function fdg(r,n)
	local f1=_fd(r,17,34,12)
	local f2=_fd(r,103,34,12)
	local f3=_fd(r,103,74,12)
	if n==4 then
		local f4=_fd(r,17,74,12)
		return f1,f2,f3,f4
	else
		return f1,f2,f3
	end
end

function initgame()
	if level==2 then
		restorekingdom()
		-- set level2 object locations 
		ykey.rm,bkey.rm,wkey.rm,sword.rm,bridge.rm,chalice.rm,magnet.rm,knubberrub.rm,yorgle.rm,rhindle.rm,grundle.rm=k[9],k[25],k[6],k[17],k[11],k[20],k[14],k[2],k[25],k[20],k[4] -- token saving
	elseif level==3 then
		restorekingdom() 
		foreach({ykey,bkey,wkey,sword,bridge,chalice,magnet,knubberrub,yorgle,grundle,rhindle}, function(obj)
			-- generate random number, check if within limits, set room number
			local room=0
			while room<obj.lvl3[1] or room>obj.lvl3[2] do
				room=flr(rnd(30))
			end
			obj.rm=k[room]
		end)
	end
end

function restorekingdom()
	-- further token savings available here
	k[1].exit.b,k[2].exit.b,k[3].exit.b,k[28].exit.b,k[29].exit.t,k[27].exit=15,17,10,12,12,{l=22,r=22,t=22,b=22,co=16} -- token saving
	ykey.pos.x,ykey.pos.y,bkey.pos.x,bkey.pos.y,wkey.pos.x,wkey.pos.y,sword.pos.x,sword.pos.y,bridge.pos.x,bridge.pos.y,chalice.pos.x,chalice.pos.y,magnet.pos.x,magnet.pos.y=22,56,23,56,20,58,20,88,52,66,36,88,96,88 -- token saving
	knubberrub.pos.x,knubberrub.pos.y,knubberrub.dir.x,knubberrub.dir.y,yorgle.pos.x,yorgle.pos.y,yorgle.dir.x,yorgle.dir.y,rhindle.pos.x,rhindle.pos.y,rhindle.dir.x,rhindle.dir.y,grundle.pos.x,grundle.pos.y,grundle.dir.x,grundle.dir.y=48,72,-1,1,56,88,-1,1,56,88,-1,1,88,88,-1,1 -- token saving
end

-- string->table unpacker provided by cheepicus (thanks again!!) to reduce tokens
function unpack(s)
	local a={}
	local key,val,l,vi,c,j,i
	l=1 vi=1 i=1
	repeat
		if i==#s+1 then c=","
		else c=sub(s,i,i) end
		if c=="{" then
			-- recurse and advance
			val,j=unpack(sub(s,i+1))
			i=l+j-1
			l=i
			-- note val is carried over and processed with the "," which should follow
		elseif c=="=" then
			key=sub(s,l,i-1)
			l=i+1
		elseif c=="," or c=="}" then
			if not val then
	 			val=sub(s,l,i-1)
				local fc=sub(val,1,1)
				if fc=="-" or (fc>="0" and fc<="9") then
					val=val*1
					-- cover for a bug in string conversion
					if(val<0) val=band(val,bnot(shr(1,16)))
				elseif val=="#t" or val=="#f" then
					val= (val=="#t")
				end
			end
			l=i+1
			if not key then
				key=vi
				vi+=1
			end
			if val!="" then
				a[key]=val
			end
			if(c=="}") return a,i+1
			key=false
			val=false
		end
		i+=1
	until i>#s+1
	return a
end

function _init()
	-- global timer set up
	timer=0
	
	--further token savings avail in this function if needed
	--yellow castle color cycling at end of game
	yc,ycoff,ycspd,frame,rungame,endgame,playmusic,level,ldiff,ldiffstra,ldiffstrb,rdiff,rdiffstra,rdiffstrb=0,0,0.5,0,false,false,true,1,"a","instant attack","delayed attack","a","all fear sword","no sword fear" -- token saving
	ldiffstr,rdiffstr=ldiffstra,rdiffstra -- token saving
	 
	k={}
	k[1]=unpack("scr={x=3,y=4},exit={t=8,r=2,b=16,l=3}") -- light green hall under blue maze
	k[2]=unpack("scr={x=4,y=4},exit={t=17,r=3,b=5,l=1}") -- dark green hall below yellow castle
	k[3]=unpack("scr={x=5,y=4},exit={t=6,r=1,b=29,l=2}") -- dark orange hall above invisible maze
	k[4]=unpack("scr={x=2,y=2},exit={t=16,r=5,b=7,l=6}") -- blue maze top center 
	k[5]=unpack("scr={x=1,y=4},exit={t=29,r=6,b=8,l=4}") -- blue maze left side
	k[6]=unpack("scr={x=2,y=4},exit={t=7,r=4,b=3,l=5}") -- blue maze bottom center
	k[7]=unpack("scr={x=2,y=3},exit={t=4,r=8,b=6,l=8}") -- blue maze center 
	k[8]=unpack("scr={x=3,y=3},exit={t=5,r=7,b=1,l=7}") -- entrance to blue maze
	k[9]=unpack("scr={x=6,y=1},exit={t=10,r=10,b=11,l=10},dark=1") -- invisible maze center
	k[10]=unpack("scr={x=6,y=0},exit={t=3,r=9,b=9,l=9},dark=1") -- entrance to invisible maze
	k[11]=unpack("scr={x=6,y=2},exit={t=9,r=12,b=28,l=13},dark=1") -- invisible maze bottom
	k[12]=unpack("scr={x=7,y=2},exit={t=28,r=13,b=29,l=11}") -- a blue side hall 
	k[13]=unpack("scr={x=5,y=2},exit={t=15,r=11,b=14,l=12}") -- side hall below white castle 
	k[14]=unpack("scr={x=5,y=3},exit={t=13,r=16,b=15,l=16}") -- wyatt, your kitchen is blue! (top entry room)
	k[15]=unpack("scr={x=5,y=1},exit={t=14,r=15,b=13,l=15,ci=false},ci=26,co=15") -- white castle (crave case?)
	k[16]=unpack("scr={x=2,y=1},exit={t=1,r=28,b=4,l=28,ci=false},ci=27,co=16") -- black castle
	k[17]=unpack("scr={x=4,y=3},exit={t=6,r=3,b=2,l=1,ci=false},ci=18,co=17") -- yellow castle
	k[18]=unpack("scr={x=4,y=2},exit={t=18,r=18,b=18,l=18,co=17}") -- yellow castle interior
	k[19]=unpack("scr={x=0,y=0},exit={t=21,r=20,b=21,l=22},dark=1") -- black castle maze top left
	k[20]=unpack("scr={x=1,y=0},exit={t=22,r=21,b=22,l=19},dark=1") -- black castle maze top right
	k[21]=unpack("scr={x=0,y=1},exit={t=19,r=22,b=19,l=20},dark=1") -- black castle maze bottom left
	k[22]=unpack("scr={x=1,y=1},exit={t=20,r=19,b=27,l=21},dark=1") -- entrance to black castle invisible maze
	k[23]=unpack("scr={x=3,y=0},exit={t=25,r=24,b=25,l=24}") -- white castle maze top left
	k[24]=unpack("scr={x=4,y=0},exit={t=26,r=23,b=26,l=23}") -- white castle maze top right
	k[25]=unpack("scr={x=3,y=1},exit={t=23,r=26,b=23,l=26}") -- white castle maze bottom left
	k[26]=unpack("scr={x=4,y=1},exit={t=24,r=25,b=24,l=25,co=15}") -- white castle maze entrance
	k[27]=unpack("scr={x=2,y=0},exit={t=28,r=28,b=28,l=28,co=16}") -- black castle foyer
	k[28]=unpack("scr={x=7,y=1},exit={t=29,r=7,b=27,l=8}") -- the other purple room
	k[29]=unpack("scr={x=7,y=3},exit={t=3,r=1,b=16,l=3}") -- nothing to see here (red top entry room)
	k[30]=unpack("scr={x=6,y=4},exit={t=6,r=1,b=6,l=3}") -- roll credits
	k[31]=unpack("scr={x=0,y=2},exit={t=32,r=33,b=32,l=30}") -- entrance to magician's garden
	k[32]=unpack("scr={x=0,y=3},exit={t=31,r=34,b=31,l=34}") -- magician's garden lower left
	k[33]=unpack("scr={x=1,y=2},exit={t=36,r=35,b=36,l=31}") -- magician's garden top right
	k[34]=unpack("scr={x=1,y=3},exit={t=36,r=32,b=35,l=32}") -- magician's garden bottom right
	k[35]=unpack("scr={x=0,y=4},exit={t=36,r=32,b=36,l=33,ci=false},ci=37,co=35") -- magician's castle
	k[36]=unpack("scr={x=3,y=2},exit={t=33,r=3,b=33,l=1}") -- magician's garden expansion
	k[37]=unpack("scr={x=7,y=4},exit={t=37,r=37,b=37,l=38,co=35}") --r37 easy r50 magician's castle entrance
	k[38]=unpack("scr={x=7,y=4},exit={t=39,r=37,b=37,l=37}") -- magician's castle maze
	k[39]=unpack("scr={x=7,y=4},exit={t=40,r=37,b=37,l=37}") -- magician's castle maze
	k[40]=unpack("scr={x=7,y=4},exit={t=41,r=37,b=37,l=37}") -- magician's castle maze
	k[41]=unpack("scr={x=7,y=4},exit={t=42,r=37,b=37,l=37}") -- magician's castle maze
	k[42]=unpack("scr={x=7,y=4},exit={t=37,r=43,b=37,l=37}") -- magician's castle maze
	k[43]=unpack("scr={x=7,y=4},exit={t=37,r=44,b=37,l=37}") -- magician's castle maze
	k[44]=unpack("scr={x=7,y=4},exit={t=37,r=50,b=37,l=37}") -- magician's castle maze
	k[45]=unpack("scr={x=6,y=3},exit={t=46,r=47,b=49,l=50}") -- evil magician's lair
	k[46]=unpack("scr={x=5,y=0},exit={t=48,r=45,b=45,l=45}") -- vert bridge 1 
	k[47]=unpack("scr={x=7,y=0},exit={t=45,r=48,b=45,l=45}") -- horiz bridge 1
	k[48]=unpack("scr={x=7,y=4},exit={t=49,r=50,b=46,l=47}") -- inner sanctum
	k[49]=unpack("scr={x=5,y=0},exit={t=45,r=45,b=48,l=45}") -- vert bridge 2 
	k[50]=unpack("scr={x=7,y=0},exit={t=45,r=45,b=45,l=48}") -- horiz bridge 2
	
	objects={}
	
	k1=_missile(1,6,16)
	k3=_missile(3,120,16)
	k13=_missile(13,6,16)
	k12=_missile(12,120,16)
	
	md=_dot(21,64,104)
	--md=_dot(3,64,104) -- for testing
	
	thng=_msg(30,60,16)
	pl=_ball(17,62,90) 
	
	-- spawn objects and set level 1 object positions
	knubberrub=_bat(26,48,72)
	magnet=_magnet(27,96,88)
	
	chalice=_chalice(28,36,88)
	--chalice=_chalice(30,36,88) -- for testing
 	
 	bridge=_bridge(4,28,68)
 	--bridge=_bridge(36,43,32) -- for testing
	
	sword=_sword(18,20,88)
	bkey=_key(29,23,56,0)
	bkey.lvl3={1,18}
	wkey=_key(14,20,58,7) 
	wkey.lvl3={1,22}
	ykey=_key(17,14,58,10)
	ygate=_gate(ykey,17,60,72,0)
	bgate=_gate(bkey,16,60,72,0)
	wgate=_gate(wkey,15,60,72,0)
	rgate=_gate(chalice,35,60,72,14)	
	collideobj={ygate,wgate,bgate,rgate,k1,k3,k13,k12,thng}
	yorgle=_dragon(1,56,88,10)
	grundle=_dragon(29,88,88,11)
	rhindle=_dragon(14,56,88,8)
	rhindle.spd=2 
	yorgle.fear,yorgle.want={sword, ykey},{pl,chalice}
	grundle.fear,grundle.want={sword},{pl,chalice,bridge,magnet,bkey}
	rhindle.fear,rhindle.want={sword},{pl,chalice,wkey}
	knubberrub.want={chalice,sword,bridge,ykey,wkey,bkey,rhindle,yorgle,grundle,magnet}
	magnet.want={ykey,wkey,bkey,sword,bridge,chalice}
	grabobj={sword,ykey,wkey,bkey,magnet,chalice,md}
	initdragons()
	lair,garden={45,46,47,48,49,50},{31,32,33,34,36}
	secrets,fired,hit,accuracy,awoken,slayed,reinc,em=0,0,0,0,0,0,0,false
end


__gfx__
66666666066666606666666066666ee6e66666666666eef655555555eeeeeeeeaaaaaaaacccccccc777777770000000088888888222222666666666666222222
6666666606666660066666666666eeee6e6666666666eef655555555eeeeeeeeaaaaaaaacccccccc777777770000000088888888222222666666666666222222
666666660066660066666660eeee66ee66e66ee66666eef655555555eeeeeeeeaaaaaaaacccccccc777777770000000088888888222222666666666666222222
666666660066660006666666eeeeeee6666eeeee6666eeef55555555eeeeeeeeaaaaaaaacccccccc777777770000000088888888222222666666666666222222
6666666600000000660000666666eee66666efee666eefee55555555eeeeeeeeaaaaaaaacccccccc777777770000000088888888666222666666666666222666
66666666606006066060060666666e666666eee66eeeeeee55555555eeeeeeeeaaaaaaaacccccccc777777770000000088888888666222666666666666222666
66666666600660066006600666666e66666eeee6eeffeee655555555eeeeeeeeaaaaaaaacccccccc777777770000000088888888666222666666666666222666
666666666666666600666600666eeee666effef6effffff655555555eeeeeeeeaaaaaaaacccccccc777777770000000088888888666222666666666666222666
66666eee666666660666666066eeeeee6efffef6eeeeeef6cccc55556666eeee6666aaaa6666cccc666677776666000066668888666222666666666666222666
eeeeee6e66666666066666606eeeeeeeefffeee6eeeeeee6cccc55556666eeee6666aaaa6666cccc666677776666000066668888666222666666666666222666
e6e66eee6666666606666660eee666ee6ffeeee6eeeeeee6cccc55556666eeee6666aaaa6666cccc666677776666000066668888666222666666666666222666
666666666666666666666666ee6666ee6feeeeee6eeeeee6cccc55556666eeee6666aaaa6666cccc666677776666000066668888666222666666666666222666
666666666666666666666666ee6666ee6eeeeeee6eeeeff6cccc55556666eeee6666aaaa6666cccc666677776666000066668888666222666666666666222666
666666666666666666666666ee666eee6eeeeeee6feffff6cccc55556666eeee6666aaaa6666cccc666677776666000066668888666222666666666666222666
666666666666666666666666eeeeeeee6eeeeeee6eefeee6cccc55556666eeee6666aaaa6666cccc666677776666000066668888666222666666666666222666
66666666666666666666666666eeee666eeeeeee6effffe6cccc55556666eeee6666aaaa6666cccc666677776666000066668888666222666666666666222666
e666666eeeeeeee6660000666666e6666feeeee66eeeeee65555cccceeee6666aaaa6666cccc6666777766660000666688886666666222666666666666222666
e666666ee6e6e6e660000006e666eeee6ffeee66666666665555cccceeee6666aaaa6666cccc6666777766660000666688886666666222666666666666222666
ee6666eeeeeeeee600066000eee6666e6fffe666666666665555cccceeee6666aaaa6666cccc6666777766660000666688886666666222666666666666222666
6eeeeee6e6e6e6e60066660066eeeeeeeeeee666666666665555cccceeee6666aaaa6666cccc6666777766660000666688886666666222666666666666222666
6eeeeee6666666660066660066666666eff66666666666665555cccceeee6666aaaa6666cccc6666777766660000666688886666222222666666666666222222
66eeee66666666660066660066666666eee66666666666665555cccceeee6666aaaa6666cccc6666777766660000666688886666222222666666666666222222
666ee66666666666006666006666666666666666666666665555cccceeee6666aaaa6666cccc6666777766660000666688886666222222666666666666222222
666ee66666666666006666006666666666666666666666665555cccceeee6666aaaa6666cccc6666777766660000666688886666222222666666666666222222
6eeeeee666e66666ee666666666636666663336666633366666666662222222233333333bbbbbbbb44444444333366666666333366666666cccccccc55555555
666666666e666666ee666666666336666636663666366636666666662222222233333333bbbbbbbb44444444333366666666333366666666cccccccc55555555
66666666eeeeeeeeee666666666636666666663666666636666666662222222233333333bbbbbbbb44444444333366666666333366666666cccccccc55555555
666666666e666666ee666666666636666666636666663366666666662222222233333333bbbbbbbb44444444333366666666333366666666cccccccc55555555
6666666666e66666ee666666666636666666366666666636666666662222222233333333bbbbbbbb4444444433336666666633336666666655555555cccccccc
6666666666666666ee666666666636666663666666366636666666662222222233333333bbbbbbbb4444444433336666666633336666666655555555cccccccc
6666666666666666ee666666666333666633333666633366666666662222222233333333bbbbbbbb4444444433336666666633336666666655555555cccccccc
6666666666666666ee666666666666666666666666666666666666662222222233333333bbbbbbbb4444444433336666666633336666666655555555cccccccc
66666666eee66666e666e6666666666666666e6e666666666666666606666666666666606666666666666666606666666e666666666666666666e66666666666
eeee66666666666eeee6eee6eeee6666e6666eeee666666e66666660066666666dd666606666dd666666666006666666666666666666e6666666666666666666
e666666666e666666666e6e6e66e6666ee6e666ee6e6666e66666600066666666dd666000666dd666666660006666666666e66e666e666666e66666666666666
e666666666e66666e666eee6eeee6666e6e6e6eeee66666e6666000000066666006666000666600666666000000066666666e6666ee6666ee666666666666666
e6666666eee66666eee66666e6666666e6e6e666e6e6666e66666ada00666666006660000066600666666ada006666666666eee66eee6eee666e666666666666
eeee6e66e6e66666e6e66e66e6666eee6666666e66666666666666dd00666666000000ada0000006666666dd0066666666666eeeeeeeeee66e66666666666666
66666e66eee66666e6e66e6666666e6eeee66666eee66eee6666660000666666000000ddd0000006666600000006666666e66eeeeeeeeeee6666666666666666
e6666eee6666666e66666e66e6666eeee6e66666e6e66e6e66666000000666666600000d00000666dd00dd0000066666666666eeeeeeeeee6666666666666666
eee66e6e6666666ee666666666666e6eeeee6666eee66eee66666000000666666600000000000666dd00dd000006666666666eeeeeeeeeeee6e6666666666666
e6666eeee666e6666666e666e6666eee6666666ee6666e666666600000066666666660000066666660066000000666666666eeeeeeeeeeeee666666666666666
e6666666e6e6e6666666eee6e6666666e6666666eee66eee66666dd000dd666666666000006666666006600000066666666eeee6eeeee66e6666666666666666
66666e6ee6e6e6666666e6e66666666ee6e666666666666666666dd000dd666666660000000666666666666000006666666ee6666eee66666666e66666666666
eee66e6ee6e6e6666666e6e6eee66666ee666666666e666e66666600000006666666000000066666666666000000666666e666666eee6666e666666666666666
e6e66eeeeeeee666e6666666e6666666e6e66666666e6e6e6666660000000066666600000006666666666600000006666666666666e666666e66666666666666
eee6666e6666666e6666eee6eee666666666666e666e6e6e666666066660666666606666666066666666660000000666e6666666666666e66666666666666666
e6666eeeeee666666666e6e66666666eeee666666666e6e666666660666606666660666666606666666666606666606666666666e66666666666666666666666
eee66666e6e666666666eee6eee66666e6e66666e66666666666666e666666666666666666666666666666666666666666666666666666666666666666666666
6666666eeeee66666666e666e6e66666eee6e66e6666eee6e6666666666660006666666666666666666666666666666666666666666666666666666666666666
eee666666666666e6666eee6eee66666e666e6e66666e6e6ee6666ee666600066606666666666666666666666666666666666666666666666666666666666666
e6e66666e6666666e66666666666666eeee6ee666666eeee6e6eeee6666600000066666666666660666666666666666666666666666666666666666666666666
eeee6666eee6666666666e666666666e6666e6e6e666666666ee66e6660000006666666666666006666666666666666666666666666666666666666666666666
6666666ee666eeee6666eee6eeee66666666e66e6666666e66e6ee666666ada00666666666660006666666666666666666666666666666666666666666666666
6e666666e666e66e66666e66e66e6666eeee66666666666e6666e66666660dd00006666666660000006666666666666666666666666666666666666666666666
eee666666666eeee66666e66eeee6666e6e6e66e6666666e666ee666666000000000066660000000666666666666660666666666666666666666666666666666
6e666666e666e6e666666e66e6e66666e6e6e6666666666e6e6e6ee666600dd0000000006666ada0006666666666660666666666666666666666666666666666
6e666666eee6e66ee6666666e66e6e66e6e6e66ee666666666666666600000000000000666660dd0000066666666600666666666666666066666666666666666
6e666666e666666666666e6666666e66e666e66e6666666e666666660dd00000dd00006666600000000006666666000006666666666660066666666666666666
6666666ee666eee66666eee6eee66eee666666666666666e666666660dd06606dd00600660000000000000066600000000000666666600066666666666666666
eee666666666e6e666666e66e6e66e6ee666666e66666eee6666666666666066666666060dd000d00dd000000000adda00000000660000000666666666666666
e6e66666eee6eee666666e66eee66eee6666666e66666e6e66666666666666666666666666666666666666666666666666666666666666666666666666666666
eee66666e6e6666666666e66e6666666e666666e66666eee66666666666666666666666666666666666666666666666666666666666666666666666666666666
e6666666eee6e66666666666eee66e6ee666666e6666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
00000000000083b300c30000000000000000008383838383838383838383000090009192000000000000000091920090830000830000000000c3830000838383
80000000000000000000000000000080000000000000000000000000000000000000000000000071720000000000000000000000000000000000000000000000
0000000000008383b3c3000000000000000000838383b3000000000000000000909090909090900000909090909090908300008383838383b3c3830000000083
80000000000000000000000000000080000000000000000000000000000000000000707070700071720070707070000000000000000000000000000000000000
0000000000008383b3c3000000000083830000000083b3c38383838383830000909090909090900000909090909090908300008383838383b3c3838383830083
80000000000000000000000000000080000000000000000000000000000000000000707070700071720070707070000000000000000000000000000000000000
0000000000008383b3c3000000000083830000000083b3c383838383838300000000900000009000009000000090000083000083000000c3b3c3830000000083
80000000000000000000000000000080000000000000000000000000000000000000700000000071720000000070000000000000000000000000000000000000
00000000000000c3b3c3000000008383838383830083b3c3b3000000838383000000900000009000009000000090000083000083000000c3b3c3830000000083
80000000000000000000000000000080000000000000000000000000000000000000700000000071720000000070000000000000000000000000000000000000
838383838383b3c3b3c3838383838383830000830083b3c3b3c383008383838390009000909090000090909000900090830000830083b3c3b3c3830083838383
80808080808000000000808080808080939393939393000000009393939393937070707070707070707070707070707090909090909000000000909090909090
838383838383b3c3b3c3838383838383838383838383838383838383838383839000900090909000009090900090009090909000900092919291009000909090
808080828282820000818181818080809090909090900000000090909090909090909090606000000000606090909090c0c0c0c0c0c000000000c0c0c0c0c0c0
00000000000000c3b3c3000000000000000000838300000000000000000000000000900000919000009092000090000000009000900092000091009000900000
800000808080820000818080800000809000000000000000000000000000009090909090906000000000609090909090c00000000000000000000000000000c0
00000000000000c3b3c3000000000000000000838300000000000000000000000000900000919000009092000090000000009000900092000091009000900000
800000808080820000818080800000809000000000000000000000000000009060909090906060000060609090909060c00000000000000000000000000000c0
8383838383008383b3c3008383838383830000838300008383838383838383839090909092919000009092919090909090009000900090909090009000900090
800000808080808080808080800000809000000000000000000000000000009060606060e3616000006062e360606060c00000000000000000000000000000c0
000000838300000000c3008383000000000000838300008383000000000000009090909092919000009092919090909090009000900090909090009000900090
800000808080808080808080800000809000000000000000000000000000009000000060606000000000606060000000c00000000000000000000000000000c0
83000083830083838383008383000083838383838300008383000083838383830000009192919000009092919200000000009000900000000000009000900000
800000008080808080808080000000809000000000000000000000000000009000000000000000000000000000000000c00000000000000000000000000000c0
83000083830083000083008383000083838383838300008383000083838383830000009192919000009092919200000000009000900000000000009000900000
800000008080808080808080000000809000000000000000000000000000009000000000000000000000000000000000c00000000000000000000000000000c0
00000083830083838383008383000000000000000000008383000083830000009000929192919000009092919291009090909000909090909090909000909090
800000008080800000808080000000809000000000000000000000000000009000000060606000000000606060000000c00000000000000000000000000000c0
83838383830083838383008383838383838383838383838383000083830000839000929192919000009092919291009090909000909090909090909000909090
800000008080800000808080000000809000000000000000000000000000009060606060f3616000006062f360606060c00000000000000000000000000000c0
00000000000000c3b300000000000000000000000000000000000083830000000000929192910000000092919291000000000000000000000000000000000000
800000000000000000000000000000809000000000000000000000000000009060909090906060000060609090909060c00000000000000000000000000000c0
00000000000000c3b300000000000000000000000000000000000083830000000000929192910000000092919291000000000000000000000000000000000000
800000000000000000000000000000809000000000000000000000000000009090909090906000000000609090909090c00000000000000000000000000000c0
838383838383b3c3b3c3838383838383838383838383838383838383838383839090929192910000000092919291909090909090909000000000909090909090
808080808080000000008080808080809090909090909090909090909090909090909090606000000000606090909090c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c2c2c2c20000c1c1c1c1c0c0c0909090909090909090909090909090909090929192910000000092919291909093939393939300000000939393939393
83838383838300000000838383838383a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a37373737373730000000073737373737390909090906000000000609090909090
000000c0c0c0c20000c1c0c0c00000c0000000000000000000000000000000000000920000910000000092000091000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000090606060606000000000606060606090
000000c0c0c0c20000c1c0c0c00000c0000000000000000000000000000000000000920000910000000092000091000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000090600000000000000000000000006090
000000c0c0c0c0c0c0c0c0c0c00000c0909090900090909090909000909090909000909090900000000090909090009000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060600000000000000000000000006060
000000c0c0c0c0c0c0c0c0c0c00000c0909090900090909090909000909090909000909090900000000090909090009000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000c0c0c0c0c0c0c0c0000000c0900000000000009192000000000000909000000000000000000000000000009000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000c0c0c0c0c0c0c0c0000000c0900000000000009192000000000000909000000000000000000000000000009000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000c0c0c00000c0c0c0000000c0900090909090929192919090909000909090900000000000000000000090909000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000c0c0c00000c0c0c0000000c0900090909090929192919090909000909090900000000000000000000090909000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060600000000000000000000000006060
000000000000000000000000000000c0000090000000929192910000009000000000900000000000000000000090000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000090600000000000000000000000006090
000000000000000000000000000000c0000090000000929192910000009000000000900000000000000000000090000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000090606060606000000000606060606090
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0909090009000929192910090009090909090909090909090909090909090909093939393939393939393939393939393
83838383838383838383838383838383a3a3a3a3a3a300000000a3a3a3a3a3a37373737373737373737373737373737390909090906000000000609090909090
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0000000000000101010101010100000000000000000002020202020202000000000000000000020202020202020000000000000000000001010101020200020200000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07070700000707070707070000070707070707070707070707070707070707070c0c0c0c0c0c000000000c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c090909090606000000000606090909090707070707070000000007070707070709090909090909090909090909090909
00000000000707070707070000000000000000000000000000070000000000070c00000000000000000000000000000c00000000000000000000000000000000000000000000000c0c00000000000000090909090906000000000609090909090000070000000000000000000007000009090909090909090909090909090909
00000000000700000000070000000000000000000000000000070000000000070c00000000000000000000000000000c00000000000000000000000000000000000000000000000c0c00000000000000090909090906060000060609090909090000070000000000000000000007000006090909090909090909090909090906
07070707070700000000070707070707070707070707070700070707070700070c00000000000000000000000000000c0c0c0c0c0c0c000000000c0c0c0c0c0c0c0c0c0c0c0c000c0c000c0c0c0c0c0c0909090909160600000626090909090907000700070707070707070700070007060606063e3e3e3e3e3e3e3e06060606
07070707070700000000070707070707070707070707070700070707070700070c00000000000000000000000000000c0c0c0c0c0c0c000000000c0c0c0c0c0c0c0c0c0c0c0c000c0c000c0c0c0c0c0c090909090916060000062609090909090700070007070707070707070007000700000006060606060606060606000000
00000000000000000000000000000000000000000000000700000000000700000c00000000000000000000000000000c00000000000c000000000c000000000000000000000c000c0c000c0000000000090909090916060000062609090909090000070000000017270000000007000000000000000000000000000000000000
00000000000000000000000000000000000000000000000700000000000700000c00000000000000000000000000000c00000000000c000000000c000000000000000000000c000c0c000c0000000000090909090916060000062609090909090000070000000017270000000007000000000000000000000000000000000000
07000707070707070707070707000007070700170707070707070017070707070c00000000000000000000000000000c0c0c0c0c000c000000000c000c0c0c0c0c000c0c0c0c0c0c0c0c0c0c0c0c000c090909090916060000062609090909090707070027000017270000170007070700000006060606060606060606000000
07000707070707070707070707000007070700170707070707070017070707070c00000000000000000000000000000c0c0c0c0c0c0c000000000c0c0c0c0c0c0c000c0c0c0c0c0c0c0c0c0c0c0c000c0909090909160600000626090909090907070700270000172700001700070707060606063f3f3f3f3f3f3f3f06060606
00000700000000000000000007000000000000172700000700000017270000070c00000000000000000000000000000c0c0000000c0c000c0c000c0c0000000c0c000c0c00000000000000000c0c000c090909090906060000060609090909090000000027000017270000170000000006090909090909090909090909090906
00000700000000000000000007000000000000172700000700000017270000070c00000000000000000000000000000c0c0000000c0c000c0c000c0c0000000c0c000c0c00000000000000000c0c000c090909090906000000000609090909090000000027000017270000170000000009090909090909090909090909090909
07070700000707070707000007070707070027172717000707002717271700070c0c0c0c0c0c000000000c0c0c0c0c0c0c000c000c0c000c0c000c0c000c000c0c000c0c000c000000000c000c0c000c090909090606000000000606090909090707070727172717271727170707070709090909090909090909090909090909
07070700000707070707000007070707070027172717000707002717271700070b0b0b2b2b2b2b00001b1b1b1b0b0b0b0c000c000c0c000c0c000c0c000c000c0c000c0c000c000000000c000c0c000c0a0a0a2a2a2a2a00001a1a1a1a0a0a0a0707070727172717271727170707070737373737373737373737373737373737
07000000000000070000000000000000000027000017000000002700001700000b00000b0b0b2b00001b0b0b0b00000b0c000c000000000000000000000c000c0c000000000c000000000c000000000c0a00000a0a0a2a00001a0a0a0a00000a0000000000172717271727000000000037000000000000000000000000000037
07000000000000070000000000000000000027000017000000002700001700000b00000b0b0b2b00001b0b0b0b00000b0c000c000000000000000000000c000c0c000000000c000000000c000000000c0a00000a0a0a2a00001a0a0a0a00000a0000000000172717271727000000000037000000000000000000000000000037
07000707070707070000070707070707070707070707000000000707070707070b00000b0b0b0b0b0b0b0b0b0b00000b0c000c000c0c0c0c0c0c0c0c000c000c0c0c0c0c0c0c000000000c0c0c0c0c0c0a00000a0a0a0a0a0a0a0a0a0a00000a0707000007072717271707070000070737000000000000000000000000000037
07000707070707070000070707070707070707070707000000000707070707070b00000b0b0b0b0b0b0b0b0b0b00000b0c000c000c0c0c0c0c0c0c0c000c000c0c0c0c0c0c0c000000000c0c0c0c0c0c0a00000a0a0a0a0a0a0a0a0a0a00000a0707000007072717271707070000070737000000000000000000000000000037
00000700000000000000070000000000000000000000000000000000000000000b0000000b0b0b0b0b0b0b0b0000000b00000c000c0000000000000c000c00000000000c00000000000000000c0000000a0000000a0a0a0a0a0a0a0a0000000a0000000007000000000000070000000037000000000000000000000000000037
00000700000000000000070000000000000000000000000000000000000000000b0000000b0b0b0b0b0b0b0b0000000b00000c000c0000000000000c000c00000000000c00000000000000000c0000000a0000000a0a0a0a0a0a0a0a0000000a0000000007000000000000070000000037000000000000000000000000000037
07070700000707070707070000070707070707070707000000000707070707070b0000000b0b0b00000b0b0b0000000b0c0c0c0c0c0000000000000c0c0c0c0c0c0c000c00000000000000000c000c0c0a0000000a0a0a00000a0a0a0000000a0707070007000707070700070007070737000000000000000000000000000037
07070700000707070707070000070707070707070707000000000707070707070b0000000b0b0b00000b0b0b0000000b0c0c0c0c0c0000000000000c0c0c0c0c0c0c000c00000000000000000c000c0c0a0000000a0a0a00000a0a0a0000000a0707070007000707070700070007070737000000000000000000000000000037
07000000000700000700000000070000000000000000000000000000000000000b00000000000000000000000000000b000000000000000000000000000000000000000c00000000000000000c0000000a00000000000000000000000000000a0000070007002700001700070007000037000000000000000000000000000037
07000000000700000700000000070000000000000000000000000000000000000b00000000000000000000000000000b000000000000000000000000000000000000000c00000000000000000c0000000a00000000000000000000000000000a0000070007002700001700070007000037000000000000000000000000000037
07070700000707070707070000070707070707070707000000000707070707070b0b0b0b0b0b000000000b0b0b0b0b0b0c0c0c0c0c0c000000000c0c0c0c0c0c0c0c0c0c0c0c000000000c0c0c0c0c0c0a0a0a0a0a0a000000000a0a0a0a0a0a0700070007002717271700070007000737373737373700000000373737373737
3838383838383b3c3b3c3838383838383800003800383b3c3b3c380038383838090909090909000000000909090909093800003800383b3c3b3c38003838383808080808080808080808080808080808393939393939000000003939393939390700070007002717271700070007000709090909090900000000090909090909
0000000000003b3c3b000000000038383800003800383b00003c380038383800000019290009000000000900192900003800003800383b3c3b3c38000000003808000000000000000000000000000008000000000000000000000000000000000000070000002717271700000007000000000000000000000000000000000000
0000000000003b3c383800000000003838000038003838383838380038383800000019290009000000000900192900003800003800383b3c3b3c38000000003808000000000000000000000000000008000000000000000000000000000000000000070000002717271700000007000000000000000000000000000000000000
0000000000003b3c3838000000000038380000380000000000000000383838000900192900090900000909001929000938000038003838383b3c38383838003808000000000000000000000000000008000000000000000000000000000000000000070707072717271707070707000000000000000000000000000000000000
0000000000003b3c3838000000000000000000383800000000000038383800000900192900090900000909001929000938000038003838383b3c38000000003808000000000000000000000000000008000000000000000000000000000000000000070707072717271707070707000000000000000000000000000000000000
0000000000003b003c3800000000000000000038383838383838383838380000090019290000000000000000192900093800003800000000003c38000038383808000000000000000000000000000008000000000000000000000000000000000000000000000017270000000000000000000000000000000000000000000000
__sfx__
00060000171601c16023160241002a10001000100000e000000000000000000000000000000000000000000000000000000000000000170000700000000000000000000000000000000000000000000000000000
00060000231601c16017160121002a10001000100000e000000000000000000000000000000000000000000000000000000000000000170000700000000000000000000000000000000000000000000000000000
000500002f0702f0702e0602e0602d0502d0502c0402c0402b0302b0302a0202a0202901029010290002800000000000000000000000000000000000000000000000000000000000000000000000000000000000
000e000004660036600264002620016102c6002a600276002460023600216001e6001e6001d6001b6001960018600166001560013600126001260011600000000000000000000000000000000000000000000000
000700002c07027070211501e1501a1401714013130101300d1200b12009120071100611005110051100510005100051000510001700000000000000000000000000000000000000000000000000000000000000
000800000265004250060500805004120086500b2500d0500f050041200f650112501305015050041201565017250190501b050041201b6501d2501f050210500412021650232502505027050051202765029250
000800002b0502d050041202d6502f250310503305004120061002920029200292002920029200292002920029200292002920029200292002920029200292002920029200292002920029200292002920029200
001000002607000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 05434344
00 06434344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344


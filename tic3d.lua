-- title:   game title
-- author:  game developer, email, etc.
-- desc:    short description
-- site:    website link
-- license: MIT License (change this to your license of choice)
-- version: 0.1
-- script:  lua

SW=240
SH=136
VW=SW/SH
VH=1

models={
	cube={
		v={
			{-1,-1,2},
			{1,-1,2},
			{1,1,2},
			{-1,1,2},
			{-1,-1,4},
			{1,-1,4},
			{1,1,4},
			{-1,1,4},
		},
		t={
			--v1,v2,v3,color
			--front
			{1,2,3,2},
			{3,4,1,2},
			--back
			{7,6,5,3},
			{5,8,7,3},
			--left/right
			{2,6,7,5},
			{7,3,2,5},
			{8,5,1,6},
			{1,4,8,6},
			--top/bottom
			{4,3,7,9},
			{7,8,4,9},
			{6,2,1,10},
			{1,5,6,10},
		}
	},
	tetrahedron={
		v={
			{5,2,3},
			{7,2,3},
			{6,2,1.27},
			{6,0.5,2.135},
		},
		t={
			{1,3,2,11},
			{1,4,3,8},
			{3,4,2,10},
			{2,4,1,9},
		},
	}
}

scene={
	"cube",
	"tetrahedron",
}

fov=90
d=VW/(VH*2*math.tan(math.rad(fov)/2))

cam={0,0,0}
camMatrix={{1,0,0},{0,1,0},{0,0,1}}

zbuffer={}

triCount=0
pixCount=0
ovrCount=0
function TIC()
	start_t=time()
	tick()
	cls(0)
	draw()
	print(string.format(
	"FPS: %d",(1000/(time()-start_t))//1),
	0,0,12)
	print("Tris: "..triCount,0,8,12)
	print("Pix: "..pixCount,0,16,12)
	print("Overdraw: "..ovrCount,0,24,12)
end

--Generic utility
function getX(p)
	return p[1]
end

function getY(p)
	return p[2]
end

function getZ(p)
	return p[3]
end

function setX(p,x)
	p[1]=x
end

function setY(p,y)
	p[2]=y
end

function setZ(p,z)
	p[3]=z
end

function getXCol(mat)
	return {mat[1][1],mat[2][1],mat[3][1]}
end

function getYCol(mat)
	return {mat[1][2],mat[2][2],mat[3][2]}
end

function getZCol(mat)
	return {mat[1][3],mat[2][3],mat[3][3]}
end

function lerp(v0,v1,t)
	return v0+(v1-v0)*t
end

function detMat2(m11,m12,m21,m22)
	--Determinant of 2x2 matrix
	return m11*m22-m12*m21
end

function detMat3(mat)
	--Determinant of 3x3 matrix
	return mat[1][1]*mat[2][2]*mat[3][3]
	+mat[1][2]*mat[2][3]*mat[3][1]
	+mat[1][3]*mat[2][1]*mat[3][2]
	-mat[1][1]*mat[2][3]*mat[3][2]
	-mat[1][2]*mat[2][1]*mat[3][3]
	-mat[1][3]*mat[2][2]*mat[3][1]
end

function inverseMat3(mat)
	--Inverse of 3x3 matrix
	local invDet=1/detMat3(mat)
	local newmat={{0,0,0},{0,0,0},{0,0,0}}
	
	newmat[1][1]=detMat2(mat[2][2],mat[2][3],mat[3][2],mat[3][3])
	newmat[1][2]=detMat2(mat[1][3],mat[1][2],mat[3][3],mat[3][2])
	newmat[1][3]=detMat2(mat[1][2],mat[1][3],mat[2][2],mat[2][3])
	newmat[2][1]=detMat2(mat[2][3],mat[2][1],mat[3][3],mat[3][1])
	newmat[2][2]=detMat2(mat[1][1],mat[1][3],mat[3][1],mat[3][3])
	newmat[2][3]=detMat2(mat[1][3],mat[1][1],mat[2][3],mat[2][1])
	newmat[3][1]=detMat2(mat[2][1],mat[2][2],mat[3][1],mat[3][2])
	newmat[3][2]=detMat2(mat[1][2],mat[1][1],mat[3][2],mat[3][1])
	newmat[3][3]=detMat2(mat[1][1],mat[1][2],mat[2][1],mat[2][2])
	
	for _,rowVec in ipairs(newmat) do
		for col,_ in ipairs(rowVec) do
			rowVec[col]=invDet*rowVec[col]
		end
	end
	return newmat
end

function translate(p,v)
	return {getX(p)+getX(v),
	getY(p)+getY(v),
	getZ(p)+getZ(v)}
end

function scale(v,s)
	return {v[1]*s,v[2]*s,v[3]*s}
end

function dot3(u,v)
	return u[1]*v[1]+u[2]*v[2]+u[3]*v[3]
end

function transform(mat,p)
	--Multiply matrix by point
	return {dot3(mat[1],p),
	dot3(mat[2],p),
	dot3(mat[3],p)}
end

function transformSpace(mat,space)
	local col1=transform(mat,getXCol(space))
	local col2=transform(mat,getYCol(space))
	local col3=transform(mat,getZCol(space))
	return {{col1[1],col2[1],col3[1]},
	{col1[2],col2[2],col3[2]},
	{col1[3],col2[3],col3[3]}}
end

function rotMatX(t)
	return {{1,0,0},{0,math.cos(t),-math.sin(t)},{0,math.sin(t),math.cos(t)}}
end

function rotMatY(t)
	return {{math.cos(t),0,math.sin(t)},{0,1,0},{-math.sin(t),0,math.cos(t)}}
end

function rotMatZ(t)
	return {{math.cos(t),-math.sin(t),0},{math.sin(t),math.cos(t),0},{0,0,1}}
end

--3D engine
function camTransform(v)
	return transform(inverseMat3(camMatrix),
	{getX(v)-getX(cam),
	getY(v)-getY(cam),
	getZ(v)-getZ(cam)})
end

function project(v)
	local newV=camTransform(v)
	local x,y,z=getX(newV),getY(newV),
	getZ(newV)
	--Project
	local r=d/z
	local cw=SW/VW
	local ch=SH/VH
	return {x*r*cw+SW/2,-y*r*ch+SH/2}
end

function triClipped(modelId,vIds)
	local v1=camTransform(models[modelId].v[vIds[1]])
	local v2=camTransform(models[modelId].v[vIds[2]])
	local v3=camTransform(models[modelId].v[vIds[3]])
	
	return getZ(v1)<d or getZ(v2)<d or getZ(v3)<d
end

function drawTri(triX,col,depth)
	triCount=triCount+1
	local p1=triX[1]
	local	p2=triX[2]
 local	p3=triX[3]
	if getY(p1)>getY(p2) then
		p1,p2=p2,p1
		depth[1],depth[2]=depth[2],depth[1]
	end
	if getY(p2)>getY(p3) then
		p2,p3=p3,p2
		depth[2],depth[3]=depth[3],depth[2]
	end
	if getY(p1)>getY(p2) then
		p1,p2=p2,p1
		depth[1],depth[2]=depth[2],depth[1]
	end
	
	local t3,z
	for y=getY(p1),getY(p2) do
		local t2=(y-getY(p1))/(getY(p2)-getY(p1))
		t3=(y-getY(p1))/(getY(p3)-getY(p1))
		
		local ix=lerp(getX(p1),getX(p3),t3)
		local fx=lerp(getX(p1),getX(p2),t2)
		local inv_iz=lerp(1/depth[1],1/depth[3],t3)
		local inv_fz=lerp(1/depth[1],1/depth[2],t2)
		if fx<ix then
			ix,fx=fx,ix
			inv_iz,inv_fz=inv_fz,inv_iz
		end
		
		for x=ix//1,fx//1 do
			if y//1>=0 and y//1<=SH-1 and x>=0 and x<=SW-1 then
				z=1/lerp(inv_iz,inv_fz,(x-ix//1)/(fx//1-ix//1))
				if z<zbuffer[x+(y//1)*SW] then
					if zbuffer[x+(y//1)*SW]~=math.huge then
						ovrCount=ovrCount+1
					end
					zbuffer[x+(y//1)*SW]=z
					pix(x,y//1,col)
					pixCount=pixCount+1
				end
			end
		end
	end
	local mx=lerp(getX(p1),getX(p3),t3)
	local inv_mz=lerp(1/depth[1],1/depth[3],t3)
	for y=getY(p2),getY(p3) do
		local t=(y-getY(p2))/(getY(p3)-getY(p2))
		
		local ix=lerp(mx,getX(p3),t)
		local fx=lerp(getX(p2),getX(p3),t)
		local inv_iz=lerp(inv_mz,1/depth[3],t)
		local inv_fz=lerp(1/depth[2],1/depth[3],t)
		if fx<ix then
			ix,fx=fx,ix
			inv_iz,inv_fz=inv_fz,inv_iz
		end
		
		for x=ix//1,fx//1 do
			if y//1>=0 and y//1<=SH-1 and x>=0 and x<=SW-1 then
				z=1/lerp(inv_iz,inv_fz,(x-ix//1)/(fx//1-ix//1))
				if z<zbuffer[x+(y//1)*SW] then
					if zbuffer[x+(y//1)*SW]~=math.huge then
						ovrCount=ovrCount+1
					end
					zbuffer[x+(y//1)*SW]=z
					pix(x,y//1,col)
					pixCount=pixCount+1
				end
			end
		end
	end
end

--Main
function tick()

	if btn(6) then
		if btn(0) then
			cam=translate(cam,scale(getYCol(camMatrix),0.1))
		elseif btn(1) then
			cam=translate(cam,scale(getYCol(camMatrix),-0.1))
		end
		if btn(2) then
			cam=translate(cam,scale(getXCol(camMatrix),-0.1))
		elseif btn(3) then
			cam=translate(cam,scale(getXCol(camMatrix),0.1))
		end
	else
		if btn(0) then
			camMatrix=transformSpace(camMatrix,rotMatX(-0.05))
		elseif btn(1) then
			camMatrix=transformSpace(camMatrix,rotMatX(0.05))
		end
		if btn(2) then
			camMatrix=transformSpace(rotMatY(-0.05),camMatrix)
		elseif btn(3) then
			camMatrix=transformSpace(rotMatY(0.05),camMatrix)
		end
	end
	
	if btn(4) then
		cam=translate(cam,scale(getZCol(camMatrix),0.1))
	elseif btn(5) then
		cam=translate(cam,scale(getZCol(camMatrix),-0.1))
	end
end

function draw()
	triCount,pixCount,ovrCount=0,0,0

	for y=0,SH-1 do
		for x=0,SW-1 do
			zbuffer[x+y*SW]=math.huge
		end
	end
	
	for _,model in ipairs(scene) do
		for _,t in ipairs(models[model].t) do
			if not triClipped(model,t) then
				local v1,v2,v3=models[model].v[t[1]],
				models[model].v[t[2]],models[model].v[t[3]]
			
				local p1,p2,p3=project(v1),
				project(v2),project(v3)
				--trib(getX(p1),getY(p1),
				--getX(p2),getY(p2),
				--getX(p3),getY(p3),12)
				drawTri({p1,p2,p3},t[4],
				{getZ(camTransform(v1)),
				getZ(camTransform(v2)),
				getZ(camTransform(v3))})
			end
		end
	end
end
-- <TILES>
-- 001:eccccccccc888888caaaaaaaca888888cacccccccacc0ccccacc0ccccacc0ccc
-- 002:ccccceee8888cceeaaaa0cee888a0ceeccca0ccc0cca0c0c0cca0c0c0cca0c0c
-- 003:eccccccccc888888caaaaaaaca888888cacccccccacccccccacc0ccccacc0ccc
-- 004:ccccceee8888cceeaaaa0cee888a0ceeccca0cccccca0c0c0cca0c0c0cca0c0c
-- 017:cacccccccaaaaaaacaaacaaacaaaaccccaaaaaaac8888888cc000cccecccccec
-- 018:ccca00ccaaaa0ccecaaa0ceeaaaa0ceeaaaa0cee8888ccee000cceeecccceeee
-- 019:cacccccccaaaaaaacaaacaaacaaaaccccaaaaaaac8888888cc000cccecccccec
-- 020:ccca00ccaaaa0ccecaaa0ceeaaaa0ceeaaaa0cee8888ccee000cceeecccceeee
-- </TILES>

-- <WAVES>
-- 000:00000000ffffffff00000000ffffffff
-- 001:0123456789abcdeffedcba9876543210
-- 002:0123456789abcdef0123456789abcdef
-- </WAVES>

-- <SFX>
-- 000:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000304000000000
-- </SFX>

-- <TRACKS>
-- 000:100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- </TRACKS>

-- <PALETTE>
-- 000:1a1c2c5d275db13e53ef7d57ffcd75a7f07038b76425717929366f3b5dc941a6f673eff7f4f4f494b0c2566c86333c57
-- </PALETTE>


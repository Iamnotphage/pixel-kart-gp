from PIL import Image, ImageDraw
import math,random,json,wave,struct
from pathlib import Path
p=Path(__file__).resolve().parent.parent/'assets'
random.seed(913)
pal=['#ff665b','#6bdfd5','#c6a0ff','#ffce52','#81d36b','#62a7fa','#ed91c9','#fb984d']
for c in range(2):
    im=Image.new('RGB',(1024,1024),'#318b63' if c==0 else '#b88964'); d=ImageDraw.Draw(im)
    bg=['#2a805a','#389367','#40996d'] if c==0 else ['#b0815d','#be906c','#c89971']
    for _ in range(14000):
        x=random.randrange(1024)//3*3;y=random.randrange(1024)//3*3
        d.rectangle((x,y,x+2,y+1),fill=random.choice(bg))
    points=[]
    for i in range(180):
        a=math.tau*i/180
        x=1024+680*math.cos(a)+60*math.cos(3*a) if c==0 else 1024+630*math.cos(a)+160*math.cos(2*a)
        y=1024+640*math.sin(a) if c==0 else 1024+650*math.sin(a)-75*math.sin(3*a)
        points.append((x/2,y/2))
    loop=points+[points[0]]
    d.line(loop,fill='#ddc992',width=112,joint='curve')
    d.line(loop,fill='#f6ead0',width=103,joint='curve')
    for i in range(180):
        if i%4<2: d.line([points[i],points[(i+1)%180]],fill='#e96757',width=103)
    d.line(loop,fill='#555971' if c==0 else '#74616c',width=94,joint='curve')
    d.line(loop,fill='#62677b' if c==0 else '#826d77',width=87,joint='curve')
    for i in range(180):
        if i%5==0: d.line([points[i],points[(i+1)%180]],fill='#ddcca2',width=2)
    # Start line perpendicular to local tangent, checkerboard.
    sx,sy=points[0]
    for xx in range(-47,48,8):
        for yy in range(-8,8,8):
            d.rectangle((int(sx+xx),int(sy+yy),int(sx+xx+7),int(sy+yy+7)), fill='#fff1cf' if (xx//8+yy//8)%2 else '#233048')
    # Water garden or sandstone infield, strictly away from road.
    if c==0:
        d.ellipse((310,340,665,710),fill='#236c82'); d.ellipse((317,347,658,703),fill='#388b9c')
        for _ in range(160):
            x=random.randrange(340,640);y=random.randrange(375,680)
            if ((x-488)/145)**2+((y-525)/145)**2<1:d.line((x,y,x+random.randrange(4,18),y),fill='#60b5b1',width=2)
        d.rectangle((422,480,560,496),fill='#be9969')
    else:
        for x,y,r in [(400,440,90),(550,620,75),(610,400,55)]:
            d.ellipse((x-r,y-r,x+r,y+r),fill='#986657');d.ellipse((x-r+8,y-r+5,x+r-10,y+r-8),fill='#d4a271')
            d.line((x-r+25,y,x+r-25,y),fill='#e9bb86',width=5)
    im=im.resize((2048,2048),Image.Resampling.NEAREST)
    im.save(p/f'course_{c}.png')
# Karts each pixel-original 32x40, rear view.
for i,col in enumerate(pal):
    im=Image.new('RGBA',(32,40));d=ImageDraw.Draw(im)
    d.ellipse((2,31,29,39),fill='#14263899')
    d.rectangle((1,24,7,35),fill='#101827');d.rectangle((25,24,31,35),fill='#101827')
    d.rectangle((2,25,4,33),fill='#526072');d.rectangle((27,25,29,33),fill='#526072')
    d.rectangle((7,18,25,32),fill='#222d43');d.rectangle((5,24,27,33),fill=col)
    d.rectangle((7,25,25,27),fill='#fff0c1');d.rectangle((9,30,23,33),fill=col)
    d.rectangle((12,32,20,35),fill='#f9d56e');d.rectangle((14,33,18,34),fill='#38314b')
    d.rectangle((10,15,22,26),fill=col);d.rectangle((11,18,21,23),fill='#353b5d')
    d.rectangle((8,7,24,17),fill='#12273c');d.rectangle((10,4,22,18),fill=col)
    d.rectangle((8,8,24,14),fill=col);d.rectangle((11,5,15,8),fill='#fff2d3')
    d.rectangle((9,13,23,17),fill='#283853');d.rectangle((12,14,20,15),fill='#98e8dc')
    im.save(p/f'kart_{i}.png')
# Eight-bit original melody loop, synthesized triangle/square voices.
sr=22050; bpm=140; step=60/bpm/2
notes=[64,67,71,76,74,71,67,69,72,76,79,76,74,72,69,67,64,67,71,76,79,78,76,74,72,69,67,64,62,64,67,71]
frames=[]
for k,n in enumerate(notes):
    f=440*2**((n-69)/12);bass=440*2**(([40,45,43,47][k//8]-69)/12)
    for j in range(int(sr*step)):
        t=j/sr; env=min(t/.006,1)*max(0,1-t/step)
        lead=(2*abs(2*((t*f)%1)-1)-1)*.13*env
        low=(1 if (t*bass)%1<.5 else -1)*.045*env
        beat=(random.random()*2-1)*.055*math.exp(-t*65) if k%2==0 else 0
        frames.append(struct.pack('<h',int((lead+low+beat)*32767)))
with wave.open(str(p/'pixel_parade.wav'),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(sr);w.writeframes(b''.join(frames))
print('Original course maps, kart sprites and music created')

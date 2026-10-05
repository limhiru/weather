"""Draw the original droplet mark. Optional tooling: Pillow (not an app dependency)."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFilter
ROOT=Path(__file__).resolve().parent.parent
S=1024
image=Image.new('RGB',(S,S))
pixels=image.load()
for y in range(S):
    for x in range(S):
        glow=max(0,1-((x-730)**2+(y-240)**2)**0.5/850)
        pixels[x,y]=(int(12+18*glow),int(48+92*glow+15*y/S),int(84+110*glow))

def curve(a,b,c,d):
    return [((1-t)**3*a[0]+3*(1-t)**2*t*b[0]+3*(1-t)*t*t*c[0]+t**3*d[0],(1-t)**3*a[1]+3*(1-t)**2*t*b[1]+3*(1-t)*t*t*c[1]+t**3*d[1]) for t in [i/100 for i in range(101)]]
points=curve((512,170),(490,310),(240,465),(260,650))+curve((260,650),(282,893),(743,909),(766,650))+curve((766,650),(788,459),(550,303),(512,170))
layer=Image.new('RGBA',(S,S))
draw=ImageDraw.Draw(layer)
draw.polygon(points,fill=(164,233,255,43))
draw.line(points,fill=(205,246,255,195),width=9,joint='curve')
draw.arc((317,487,708,816),15,158,fill=(192,240,255,170),width=11)
draw.line(curve((492,260),(448,352),(337,454),(319,566)),fill=(244,255,255,215),width=17,joint='curve')
draw.ellipse((672,225,797,350),fill=(255,224,161,255))
image=Image.alpha_composite(image.convert('RGBA'),layer).convert('RGB')
assets=ROOT/'ios_app/Weather/Assets.xcassets/AppIcon.appiconset'
assets.mkdir(parents=True,exist_ok=True)
image.save(assets/'AppIcon.png')
(assets/'Contents.json').write_text(json.dumps({'images':[{'filename':'AppIcon.png','idiom':'universal','platform':'ios','size':'1024x1024'}],'info':{'author':'xcode','version':1}},indent=2))
(assets.parent/'Contents.json').write_text('{"info":{"author":"xcode","version":1}}\n')
for density,size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    path=ROOT/f'android_app/android/app/src/main/res/mipmap-{density}/ic_launcher.png'
    image.resize((size,size),Image.Resampling.LANCZOS).save(path)
image.resize((512,512),Image.Resampling.LANCZOS).save(ROOT/'docs/app-icon.png')

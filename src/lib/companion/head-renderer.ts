import {Application,Assets,Container,Graphics,MeshPlane,Sprite,Texture} from "pixi.js";
import {createPortraitAnimation,type HeadMood} from "./portrait-animation";
export type {HeadMood} from "./portrait-animation";

const SIZE=1280;
const ART={neutral:"/companion/hen-fade-neutral.png",blink:"/companion/hen-fade-blink.png",speaking:"/companion/hen-fade-speaking.png"};

/** Render the approved artwork unchanged, then animate only its facial regions. */
export async function createHeadRenderer(host:HTMLElement){
 const app=new Application();
 await app.init({resizeTo:host,backgroundAlpha:0,antialias:true,autoDensity:true,resolution:Math.min(devicePixelRatio,2),preference:"webgl",autoStart:false,powerPreference:"low-power"});
 let textures:Texture[];
 try{textures=await Promise.all(Object.values(ART).map(path=>Assets.load<Texture>(path)))}catch(error){app.destroy({removeView:true},{children:true});throw error}
 const [neutral,blink,speaking]=textures;
 app.canvas.setAttribute("aria-hidden","true");host.appendChild(app.canvas);
 const root=new Container(),face=new Container();root.addChild(face);app.stage.addChild(root);face.pivot.set(SIZE/2,SIZE/2);
 const portrait=new MeshPlane({texture:neutral,verticesX:65,verticesY:65});
 for(let i=0;i<portrait.geometry.positions.length;i++)portrait.geometry.positions[i]*=SIZE/(i%2?neutral.height:neutral.width);
 portrait.geometry.getBuffer("aPosition").update();face.addChild(portrait);
 const maskTextures:Texture[]=[];
 function featherMask(x:number,y:number,rx:number,ry:number){
  const canvas=document.createElement("canvas");canvas.width=canvas.height=SIZE;const ctx=canvas.getContext("2d")!;
  ctx.translate(x,y);ctx.scale(rx,ry);const gradient=ctx.createRadialGradient(0,0,.60,0,0,1);gradient.addColorStop(0,"white");gradient.addColorStop(1,"rgba(255,255,255,0)");ctx.fillStyle=gradient;ctx.fillRect(-1,-1,2,2);
  const texture=Texture.from(canvas);maskTextures.push(texture);const mask=new Sprite(texture);face.addChild(mask);return mask;
 }
 function region(texture:Texture,x:number,y:number,rx:number,ry:number){const sprite=new Sprite(texture);sprite.width=SIZE;sprite.height=SIZE;face.addChild(sprite);sprite.mask=featherMask(x,y,rx,ry);return sprite}
 // Eye and mouth textures are composited only inside feathered local masks.
 const left=region(blink,493,684,139,112),right=region(blink,818,686,139,112),mouth=region(speaking,640,984,194,111);
 const dots=new Graphics();root.addChild(dots);
 const vertices=portrait.geometry.positions,original=new Float32Array(vertices),weights=new Float32Array(vertices.length/2*5);
 const points=[[496,678,63,57],[814,682,63,57],[495,571,149,53],[814,572,149,53],[640,967,164,70]];
 for(let i=0;i<vertices.length;i+=2)for(let j=0;j<points.length;j++){const [x,y,rx,ry]=points[j];weights[i/2*5+j]=Math.exp(-(((original[i]-x)/rx)**2+((original[i+1]-y)/ry)**2)*2)}
 const rig=createPortraitAnimation();let clock=0,visible=true,disposed=false;
 const reduced=matchMedia("(prefers-reduced-motion: reduce)");
 function draw(){
  const pose=rig.sample(clock,reduced.matches),w=host.clientWidth,h=host.clientHeight;
  const scale=Math.min(w,h)/SIZE;
  root.position.set(w/2,h/2);root.scale.set(scale);face.position.set(pose.offX*25,pose.offY*25);face.rotation=pose.roll;face.scale.set(1,pose.breath);
  // Local pupil and eyebrow warping leaves the approved hair, fade and jaw intact.
  for(let i=0;i<vertices.length;i+=2){const k=i/2*5,pupils=weights[k]+weights[k+1],brows=weights[k+2]+weights[k+3];vertices[i]=original[i]+pupils*pose.gazeX*16;vertices[i+1]=original[i+1]+pupils*pose.gazeY*8-brows*Math.abs(pose.gazeY)*3}
  portrait.geometry.getBuffer("aPosition").update();
  left.alpha=pose.leftClosure;right.alpha=pose.rightClosure;mouth.alpha=pose.mouth;
  dots.clear();for(const dot of pose.thinkingDots)dots.circle(dot.x*2,-SIZE*.46,dot.r*.22).fill({color:0x13b8d5,alpha:dot.opacity});
  host.dataset.animationState=pose.state;host.dataset.eyesClosed=Math.max(pose.leftClosure,pose.rightClosure).toFixed(2);
 }
 function renderStatic(){draw();app.render()}
 function syncPlayback(){if(disposed)return;if(reduced.matches||document.hidden||!visible){app.stop();if(!document.hidden&&visible)renderStatic()}else app.start()}
 function pointer(event:PointerEvent){if(event.pointerType==="touch"||reduced.matches)return;const rect=host.getBoundingClientRect();rig.look((event.clientX-rect.left-rect.width/2)/Math.max(300,innerWidth/2),(event.clientY-rect.top-rect.height/2)/Math.max(300,innerHeight/2),clock)}
 function leave(){rig.release(clock)}
 const resize=new ResizeObserver(()=>{if(!disposed)renderStatic()});resize.observe(host);
 const observer=new IntersectionObserver(([entry])=>{visible=entry.isIntersecting;syncPlayback()});observer.observe(host);
 document.addEventListener("visibilitychange",syncPlayback);reduced.addEventListener("change",syncPlayback);window.addEventListener("pointermove",pointer,{passive:true});document.documentElement.addEventListener("pointerleave",leave);
 app.ticker.maxFPS=30;app.ticker.add(ticker=>{clock+=Math.min(ticker.deltaMS/1000,.08);draw()});renderStatic();syncPlayback();
 return {setMood(mood:HeadMood){rig.setMood(mood,clock);if(reduced.matches)renderStatic()},react(){rig.react(clock);if(reduced.matches)renderStatic()},dispose(){disposed=true;observer.disconnect();resize.disconnect();document.removeEventListener("visibilitychange",syncPlayback);reduced.removeEventListener("change",syncPlayback);window.removeEventListener("pointermove",pointer);document.documentElement.removeEventListener("pointerleave",leave);app.destroy({removeView:true},{children:true,texture:false,textureSource:false});maskTextures.forEach(texture=>texture.destroy(true))}};
}

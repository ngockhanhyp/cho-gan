/* Original implementation after directly observing the showcase's continuous depth conveyor. */
window.initMemoryCollage=function(gsap,ScrollTrigger){
 const section=document.querySelector('.memory-collage');if(!section)return;
 const canvas=section.querySelector('.collage-canvas'),cards=[...section.querySelectorAll('.stream-card')],mobile=matchMedia('(max-width:700px)').matches;
 const spacing=.47,travel=mobile?1.95:3.2,total=(cards.length-1)*spacing+travel*.55;
 const tl=gsap.timeline({scrollTrigger:{trigger:section,start:mobile?'top 65px':'top 75px',end:'bottom bottom',scrub:.2,invalidateOnRefresh:true}});
 gsap.set(cards,{xPercent:-50,yPercent:-50,autoAlpha:0});
 tl.fromTo('.collage-title',{opacity:1,scale:1,y:0},{opacity:0,scale:.88,y:-25,duration:.8,ease:'power2.in'},0);
 cards.forEach((card,i)=>{
  const start=i*spacing-.65,lane=Number(card.dataset.lane),angle=Number(card.dataset.angle),isNote=card.classList.contains('stream-note');
  const range=()=>canvas.clientWidth*(mobile?.9:.67),height=()=>canvas.clientHeight*(mobile?.23:.24);
  const y=(phase)=>()=>lane*height()+(phase-.5)*canvas.clientHeight*(mobile?.08:.12);
  const flight=gsap.timeline();
  // New plates are born tiny on the right, come into focus, pass the center, and recede left.
  // Each plate has a different offset, so the stream keeps replacing itself all the way through.
  flight.fromTo(card,{x:range,y:y(0),z:-750,scale:.08,rotationZ:angle*.4,rotationY:-8,autoAlpha:0,zIndex:2},{x:()=>range()*.53,y:y(.2),z:-300,scale:.38,rotationZ:angle*.7,rotationY:-4,autoAlpha:1,zIndex:5,duration:travel*.24,ease:'none'})
   .to(card,{x:()=>range()*.13,y:y(.43),z:0,scale:mobile?(isNote?1:.94):1,rotationZ:angle,rotationY:0,zIndex:16,duration:travel*.24,ease:'none'})
   .to(card,{x:()=>-range()*.23,y:y(.62),z:15,scale:mobile?(isNote?1:.94):1.04,rotationZ:angle*.65,rotationY:3,zIndex:18,duration:travel*.2,ease:'none'})
   .to(card,{x:()=>-range()*.65,y:y(.85),z:-350,scale:.42,rotationZ:angle*.35,rotationY:5,zIndex:7,duration:travel*.21,ease:'none'})
   .to(card,{x:()=>-range(),y:y(1),z:-750,scale:.08,autoAlpha:0,zIndex:1,duration:travel*.11,ease:'none'});
  tl.add(flight,start);
 });
 // The end deliberately retains the last passing cards as the next section scrolls in.
 tl.to({}, {duration:.01},total);
 return tl;
};

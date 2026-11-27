window.initBearLifecycle=function(gsap,ScrollTrigger,section,chapters,selectChapter){
  const q=selector=>section.querySelectorAll(selector),mobile=matchMedia('(max-width:700px)').matches;
  const tl=gsap.timeline({scrollTrigger:{trigger:section,start:mobile?'top 65px':'top 75px',end:'bottom bottom',scrub:.2,onUpdate:self=>selectChapter(self.progress<.34?0:self.progress<.68?1:2)}});
  gsap.set(q('.life-closet,.life-closet-door,.life-box-front,.life-message,.life-new-toys,.life-plant,.life-garland'),{autoAlpha:0});
  gsap.set(q('.life-tent'),{transformOrigin:'50% 100%'});
  gsap.set(q('.life-handnote'),{opacity:.75});
  chapters.forEach((chapter,i)=>{
    const at=[0,3.4,6.8][i];
    if(i){tl.fromTo(chapter,{autoAlpha:0},{autoAlpha:1,duration:.1},at);
      tl.from(chapter.querySelectorAll('.v2-word'),{rotationX:-70,rotationZ:j=>j%2?4:-4,yPercent:105,opacity:0,stagger:.045,duration:.6,ease:'power3.out'},at);
      tl.from(chapter.querySelector('p'),{y:12,opacity:0,duration:.4},at+.3);
    }
    if(i)tl.fromTo(chapter.querySelectorAll('em .v2-letter'),{color:'#879a7c'},{color:'#354d40',stagger:.02,duration:.3,ease:'none'},at+.2);
    tl.fromTo(chapter.querySelector('em'),{'--life-ink':0},{'--life-ink':1,duration:.65,ease:'power2.inOut'},at+.25);
    if(i<2){const exit=[3.17,6.57][i];tl.to(chapter.querySelectorAll('.v2-letter'),{yPercent:-70,rotationZ:j=>(j%3-1)*8,opacity:0,stagger:{amount:.12,from:'end'},duration:.18,ease:'power2.in'},exit);tl.to(chapter,{autoAlpha:0,duration:.1},exit+.12);}
  });
  // The toy itself has no motion tween: memories and surroundings carry every transition.
  tl.fromTo(q('.life-growth .growth-extra'),{opacity:0},{opacity:1,duration:1.2},.4)
    .fromTo(q('.life-tent'),{scaleY:.2,rotation:-7,opacity:0},{scaleY:1,rotation:0,opacity:1,duration:1.2,ease:'power2.out'},.4)
    .to(q('.life-sun'),{y:-10,x:4,duration:2.5,ease:'none'},0)
    .to(q('.life-ray'),{opacity:.4,duration:2.4},.2)
    .to(q('.life-tent'),{x:70,rotation:10,opacity:0,duration:.8,ease:'power2.in'},2.4)
    .to(q('.life-books'),{x:-20,y:10,opacity:0,duration:.8},2.5)
    .to(q('.life-bed'),{x:-75,opacity:0,duration:.9,ease:'power2.inOut'},2.5)
    .to(q('.life-window'),{x:-35,opacity:.2,duration:.9},2.7)
    .to(q('.life-photo'),{y:20,rotation:-7,opacity:0,duration:.8},2.8)
    .to(q('.life-closet'),{autoAlpha:1,duration:.5},3)
    .from(q('.life-closet'),{scaleX:.75,transformOrigin:'50% 50%',duration:.7,ease:'power2.out'},3)
    .to(q('.life-box-front'),{autoAlpha:1,duration:.4},3.2)
    .from(q('.life-box-front'),{y:80,duration:.65,ease:'power2.out'},3.2)
    .to(q('.life-closet-door'),{autoAlpha:1,duration:.3},3.45)
    .from(q('.life-closet-door'),{x:-105,duration:.8,ease:'power2.out'},3.45)
    .to(q('.life-shade'),{opacity:.3,duration:.6},3.4)
    .to(q('.life-rug'),{opacity:.3,duration:.6},3.3)
    .to(q('.life-handnote'),{opacity:0,duration:.3},3)
    .to(q('.life-closet-door'),{x:-130,autoAlpha:0,duration:.8,ease:'power2.inOut'},5)
    .to(q('.life-shade'),{opacity:0,duration:.6},5.1)
    .to(q('.life-message'),{autoAlpha:1,duration:.01},5.2)
    .from(q('.life-message'),{y:-35,rotation:20,scale:.9,duration:.7,ease:'power3.out'},5.2)
    .to(q('.life-closet,.life-box-front'),{y:45,autoAlpha:0,duration:.8,ease:'power2.inOut'},5.8)
    .to(q('.life-wall'),{fill:'#f2d8c6',duration:1.3},5.8)
    .to(q('.life-floor'),{fill:'#d5b89c',duration:1.3},5.8)
    .to(q('.life-window'),{x:0,opacity:1,duration:.8},6.1)
    .to(q('.life-sky'),{fill:'#d1dfc7',duration:.8},6.1)
    .to(q('.life-curtain'),{fill:'#b7c8a7',stroke:'#8c9d7a',duration:.8},6.1)
    .to(q('.life-blanket'),{fill:'#adc2a1',duration:.8},6.1)
    .to(q('.life-bed'),{x:0,opacity:1,duration:.9,ease:'power2.out'},6.2)
    .to(q('.life-photo'),{y:0,rotation:0,opacity:1,duration:.8},6.3)
    .to(q('.life-photo-color'),{fill:'#e6ba9a',duration:.7},6.3)
    .to(q('.life-rug'),{fill:'#e2b2a5',stroke:'#c58d7d',opacity:1,duration:.8},6.3)
    .to(q('.life-new-toys,.life-plant,.life-garland'),{autoAlpha:1,duration:.1},6.5)
    .from(q('.life-new-toys,.life-plant'),{y:55,rotation:8,transformOrigin:'50% 100%',stagger:.12,duration:.9,ease:'power3.out'},6.5)
    .from(q('.life-garland'),{y:-40,duration:.9,ease:'power2.out'},6.7)
    .to(q('.life-growth'),{y:48,opacity:.7,duration:.8},6.5)
    .to(q('.life-message'),{y:-18,autoAlpha:0,duration:.5},7)
    .to(q('.life-handnote'),{opacity:1,duration:.6},7.2)
    .to(q('.life-ray'),{opacity:1,duration:.8},7.1)
    .to({}, {duration:1.4},8.6);
};

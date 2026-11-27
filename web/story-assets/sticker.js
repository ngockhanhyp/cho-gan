(() => {
  'use strict';
  const {gsap,ScrollTrigger}=window;if(!gsap||!ScrollTrigger)return;
  gsap.registerPlugin(ScrollTrigger);gsap.ticker.lagSmoothing(0);
  const desktop=matchMedia('(min-width:701px)'),fine=matchMedia('(hover:hover) and (pointer:fine)'),reduce=matchMedia('(prefers-reduced-motion:reduce)');
  const segmenter=typeof Intl.Segmenter==='function'?new Intl.Segmenter('vi',{granularity:'grapheme'}):null;
  let enabled=!reduce.matches,ctx,lenis;const cleanup=[];
  function split(element){
    const readable=element.cloneNode(true);readable.querySelectorAll('br').forEach(br=>br.replaceWith(' '));
    element.setAttribute('aria-label',readable.textContent.replace(/✳/g,'').replace(/\s+/g,' ').trim());
    const walker=document.createTreeWalker(element,NodeFilter.SHOW_TEXT),nodes=[];
    while(walker.nextNode())if(walker.currentNode.textContent.trim()&&!walker.currentNode.parentElement.closest('[aria-hidden="true"]'))nodes.push(walker.currentNode);
    nodes.forEach(node=>{const frag=document.createDocumentFragment();node.textContent.split(/(\s+)/).forEach(word=>{
      if(!word.trim()){frag.append(document.createTextNode(word));return;}
      const wrapper=document.createElement('span');wrapper.className='v2-word';wrapper.setAttribute('aria-hidden','true');
      const glyphs=segmenter?[...segmenter.segment(word)].map(x=>x.segment):Array.from(word);
      glyphs.forEach(glyph=>{const letter=document.createElement('span');letter.className='v2-letter';letter.textContent=glyph;wrapper.append(letter);});frag.append(wrapper);
    });node.replaceWith(frag);});
  }
  document.querySelectorAll('#hero-title,.memory-copy h2,.journey-intro h2,.lifecycle .bear-chapter h3,.neighborhood-copy h2,.people h2,.invitation h2').forEach(split);
  const memoryWords=[...document.querySelectorAll('.memory-copy h2 .v2-word')];
  memoryWords.slice(-4).forEach(word=>{const line=document.createElement('i');line.className='v2-underline';word.append(line);});
  const bearSection=document.querySelector('.bear-story'),chapters=[...document.querySelectorAll('.bear-chapter')];
  function selectChapter(index){chapters.forEach((chapter,i)=>chapter.setAttribute('aria-hidden',String(i!==index)));}
  function motion(){
    ctx=gsap.context(()=>{
      const heroLetters=document.querySelectorAll('#hero-title .v2-letter');
      gsap.from(heroLetters,{yPercent:115,rotationZ:12,rotationX:-65,opacity:0,stagger:.018,duration:1.15,ease:'power4.out',delay:.1});
      gsap.from('.postcard',{y:80,rotationZ:-18,opacity:0,duration:1.3,ease:'power4.out',delay:.2});
      gsap.from('.round-stamp',{scale:.25,rotationZ:60,opacity:0,duration:.85,ease:'back.out(1.45)',delay:.85});
      gsap.from('.handnote',{y:20,opacity:0,duration:.8,ease:'power3.out',delay:1});
      gsap.to(heroLetters,{y:(index)=>-25-(index%5)*10,rotationZ:index=>(index%5-2)*9,opacity:0,stagger:{amount:.3,from:'end'},ease:'none',scrollTrigger:{trigger:'.hero',start:'20% top',end:'bottom 15%',scrub:.75}});
      gsap.to('.hero-art',{y:-55,rotationZ:5,ease:'none',scrollTrigger:{trigger:'.hero',start:'top top',end:'bottom top',scrub:1}});
      gsap.to('.shoe',{y:-14,rotationZ:3,duration:3.2,repeat:-1,yoyo:true,ease:'sine.inOut'});
      gsap.to('.title-star',{rotation:360,duration:28,repeat:-1,ease:'none'});
      gsap.to('.ticker>div',{xPercent:-50,duration:36,repeat:-1,ease:'none'});
      gsap.fromTo('.memory-copy h2 .v2-letter',{rotationX:-75,yPercent:80,opacity:.15},{rotationX:0,yPercent:0,opacity:1,stagger:.025,ease:'none',scrollTrigger:{trigger:'.memory-copy h2',start:'top 85%',end:'bottom 40%',scrub:.7}});
      gsap.to('.v2-underline',{scaleX:1,stagger:.1,ease:'power2.out',scrollTrigger:{trigger:'.memory-copy h2',start:'top 48%',end:'bottom 25%',scrub:.5}});
      gsap.from('.memory-label',{rotationZ:-8,y:45,opacity:0,duration:1,ease:'back.out(1.15)',scrollTrigger:{trigger:'.memory',start:'top 75%'}});
      gsap.from('.memory-copy p,.memory-copy .caption',{y:25,opacity:0,stagger:.12,duration:.8,ease:'power3.out',scrollTrigger:{trigger:'.memory-copy',start:'top 60%'}});
      window.initBearLifecycle(gsap,ScrollTrigger,bearSection,chapters,selectChapter);
      window.initMemoryCollage(gsap,ScrollTrigger);
      const cards=[];
      gsap.fromTo('.neighborhood-copy h2 .v2-word',{x:index=>index%2?70:-70,rotationZ:index=>index%2?6:-6,opacity:0},{x:0,rotationZ:0,opacity:1,stagger:.07,ease:'power2.out',scrollTrigger:{trigger:'.neighborhood',start:'top 82%',end:'top 25%',scrub:.7}});
      gsap.from('.house-one',{y:80,rotationZ:-25,opacity:0,duration:1.1,ease:'back.out(1.2)',scrollTrigger:{trigger:'.neighborhood-art',start:'top 80%'}});
      gsap.from('.house-two',{y:80,rotationZ:25,opacity:0,duration:1.1,ease:'back.out(1.2)',delay:.2,scrollTrigger:{trigger:'.neighborhood-art',start:'top 80%'}});
      gsap.from('.map-route',{scaleX:0,transformOrigin:'left center',duration:1.2,ease:'power2.inOut',scrollTrigger:{trigger:'.neighborhood-art',start:'top 60%'}});
      gsap.fromTo('.people h2 .v2-word',{rotationX:-70,y:40,opacity:.1},{rotationX:0,y:0,opacity:1,stagger:.08,ease:'none',scrollTrigger:{trigger:'.people',start:'top 80%',end:'top 25%',scrub:.65}});
      gsap.to('.people h2 em',{'--people-line':1,ease:'power2.out',scrollTrigger:{trigger:'.people',start:'top 50%',end:'top 25%',scrub:.5}});
      gsap.from('.people-marks span',{y:70,rotationZ:index=>index%2?-20:20,opacity:0,stagger:.15,duration:1.1,ease:'back.out(1.15)',scrollTrigger:{trigger:'.people-bottom',start:'top 85%'}});
      gsap.fromTo('.invitation h2 .v2-letter',{x:index=>(index%7-3)*12,y:90,rotationZ:index=>(index%5-2)*12,opacity:0},{x:0,y:0,rotationZ:0,opacity:1,stagger:{amount:.5,from:'center'},ease:'power3.out',scrollTrigger:{trigger:'.invitation',start:'top 85%',end:'top 20%',scrub:.8}});
      if(fine.matches){
        const art=document.querySelector('.hero-art'),postcard=document.querySelector('.postcard');
        const rx=gsap.quickTo(postcard,'rotationX',{duration:.8,ease:'power3.out'}),ry=gsap.quickTo(postcard,'rotationY',{duration:.8,ease:'power3.out'});
        const move=event=>{const r=art.getBoundingClientRect();rx(-((event.clientY-r.top)/r.height-.5)*8);ry(((event.clientX-r.left)/r.width-.5)*9);};const leave=()=>{rx(0);ry(0);};
        art.addEventListener('pointermove',move);art.addEventListener('pointerleave',leave);cleanup.push(()=>{art.removeEventListener('pointermove',move);art.removeEventListener('pointerleave',leave);});
        cards.forEach(card=>{
          const sticker=card.querySelector('.scrap-sticker'),photo=card.querySelector('.scrap-photo');
          const rotate=gsap.quickTo(photo,'rotationZ',{duration:.65,ease:'power3.out'}),lift=gsap.quickTo(sticker,'y',{duration:.65,ease:'power3.out'});
          const enter=()=>{rotate(-2);lift(-14);};const exit=()=>{rotate(0);lift(0);};card.addEventListener('pointerenter',enter);card.addEventListener('pointerleave',exit);cleanup.push(()=>{card.removeEventListener('pointerenter',enter);card.removeEventListener('pointerleave',exit);});
        });
      }
    });
    if(window.Lenis&&desktop.matches){lenis=new Lenis({lerp:.16,smoothWheel:true,wheelMultiplier:1.05});lenis.on('scroll',ScrollTrigger.update);}
    requestAnimationFrame(()=>ScrollTrigger.refresh());
  }
  function setMotion(value){enabled=value;if(ctx){ctx.revert();ctx=null;}cleanup.splice(0).forEach(fn=>fn());lenis?.destroy();lenis=null;
    document.body.classList.toggle('v2-static',!value);document.body.classList.toggle('v2-active',value&&desktop.matches);
    const toggle=document.getElementById('v2-motion-toggle');toggle.setAttribute('aria-pressed',String(!value));toggle.textContent=value?'Giảm chuyển động':'Bật chuyển động';
    chapters.forEach(chapter=>chapter.removeAttribute('aria-hidden'));if(value)motion();
  }
  gsap.ticker.add(time=>lenis?.raf(time*1000));
  setMotion(enabled);
  document.getElementById('v2-motion-toggle').addEventListener('click',()=>setMotion(!enabled));
  reduce.addEventListener('change',event=>setMotion(!event.matches));desktop.addEventListener('change',()=>setMotion(enabled));
  document.fonts.ready.then(()=>{ScrollTrigger.refresh();if(['#bear-story','#journey'].includes(location.hash)){const target=document.querySelector(location.hash);const top=target.getBoundingClientRect().top+scrollY-(desktop.matches?75:65);if(lenis)lenis.scrollTo(top,{immediate:true});else scrollTo({top,behavior:'instant'});}});
  document.querySelectorAll('.scrap-card').forEach(card=>card.addEventListener('click',()=>{
    if(!enabled)return;gsap.fromTo(card.querySelector('.scrap-sticker'),{scale:.88},{scale:1,duration:.6,ease:'back.out(1.8)'});
    gsap.fromTo(card.querySelector('.object-after'),{y:8,opacity:.3},{y:0,opacity:1,duration:.5,ease:'power3.out'});
  }));
  document.querySelectorAll('.team-tabs button').forEach(button=>button.addEventListener('click',()=>{if(!enabled)return;const panel=document.querySelector('.team-panel:not([hidden])');gsap.fromTo(panel.querySelector('.team-text'),{y:20,opacity:.2},{y:0,opacity:1,duration:.6,ease:'power3.out'});requestAnimationFrame(()=>ScrollTrigger.refresh());}));
  document.getElementById('team-more').addEventListener('toggle',()=>requestAnimationFrame(()=>ScrollTrigger.refresh()));
  document.querySelectorAll('a[href^="#"]').forEach(link=>link.addEventListener('click',event=>{const target=document.querySelector(link.getAttribute('href'));if(target&&lenis){event.preventDefault();lenis.scrollTo(target,{offset:-85,duration:1.1});}}));
})();





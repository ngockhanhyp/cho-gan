(() => {
 'use strict';
 const dictionary=window.PassyTranslations||{},languages={vi:'Tiếng Việt',en:'English',ko:'한국어'};
 let saved='vi';try{saved=JSON.parse(localStorage.getItem('flutter.passy.language')||'null')||localStorage.getItem('passy.language')||'vi';}catch(_){}
 const requested=new URL(location.href).searchParams.get('lang');
 const code=languages[requested]?requested:languages[saved]?saved:'vi';
 const t=value=>code==='vi'?value:(dictionary[value]?.[code==='ko'?1:0]||value);
 const store=language=>{try{localStorage.setItem('passy.language',language);localStorage.setItem('flutter.passy.language',JSON.stringify(language));}catch(_){}};
 window.PassyLanguage={code,t};store(code);
 document.documentElement.lang=code;document.body.dataset.language=code;
 const walker=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT),nodes=[];
 while(walker.nextNode())if(!walker.currentNode.parentElement.closest('script,style,noscript,textarea'))nodes.push(walker.currentNode);
 for(const node of nodes){const original=node.textContent,trimmed=original.trim();if(trimmed&&t(trimmed)!==trimmed)node.textContent=original.replace(trimmed,t(trimmed));}
 document.querySelectorAll('[alt],[aria-label],[placeholder],[title]').forEach(element=>{for(const attribute of ['alt','aria-label','placeholder','title'])if(element.hasAttribute(attribute))element.setAttribute(attribute,t(element.getAttribute(attribute)));});
 document.querySelectorAll('meta[name="description"],meta[property="og:title"],meta[property="og:description"]').forEach(meta=>meta.content=t(meta.content));
 document.title=t(document.title);
 document.querySelectorAll('a[href]').forEach(link=>{const url=new URL(link.href,location.href);if(url.origin!==location.origin&&url.hostname!=='passy.id.vn')return;if(url.hash&&url.pathname===location.pathname)return;if(['/', '/index.html','/story.html','/privacy.html','/terms.html'].includes(url.pathname)){url.searchParams.set('lang',code);link.href=url.href;}});
 const host=document.querySelector('.nav,header');if(host){const label=document.createElement('label');label.className='story-language-label';const select=document.createElement('select');select.setAttribute('aria-label',code==='ko'?'언어':code==='en'?'Language':'Ngôn ngữ');for(const [value,name]of Object.entries(languages)){const option=document.createElement('option');option.value=value;option.textContent=name;select.append(option);}select.value=code;select.addEventListener('change',()=>{store(select.value);const url=new URL(location.href);url.searchParams.set('lang',select.value);location.assign(url.href);});label.append(select);const brand=host.querySelector('a');if(brand)brand.after(label);else host.append(label);}
})();

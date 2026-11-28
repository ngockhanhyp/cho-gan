(() => {
 const languages=['vi','en','ko'];let saved='vi';
 try{saved=JSON.parse(localStorage.getItem('flutter.passy.language')||'null')||localStorage.getItem('passy.language')||'vi';}catch(_){}
 const requested=new URL(location.href).searchParams.get('lang');const code=languages.includes(requested)?requested:languages.includes(saved)?saved:'vi';
 document.documentElement.lang=code;
 document.title=code==='ko'?'Passy – 내 주변 중고거래':code==='en'?'Passy – Secondhand finds nearby':'Passy – Mua bán đồ cũ gần bạn';
 document.getElementById('splash')?.setAttribute('aria-label',code==='ko'?'Passy를 불러오는 중':code==='en'?'Loading Passy':'Đang tải Passy');
})();

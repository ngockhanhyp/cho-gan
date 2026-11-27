(() => {
  'use strict';
  const seenKey = 'passy.story.seen.v1';
  const markSeen = () => { try { localStorage.setItem(seenKey, '1'); } catch (_) {} };
  markSeen();
  const teamTabs = [...document.querySelectorAll('[role="tab"]')];
  const teamPanels = [...document.querySelectorAll('.team-panel')];
  const nextChapter = document.getElementById('team-next');
  let teamChapter = 0;
  const selectTeamChapter = (index, focus = false) => {
    teamChapter = (index + teamTabs.length) % teamTabs.length;
    teamTabs.forEach((tab, i) => {
      tab.setAttribute('aria-selected', String(i === teamChapter));
      tab.tabIndex = i === teamChapter ? 0 : -1;
      teamPanels[i].hidden = i !== teamChapter;
    });
    nextChapter.innerHTML = teamChapter === teamTabs.length - 1 ? 'Về chặng đầu <span aria-hidden="true">↺</span>' : 'Chặng tiếp theo <span aria-hidden="true">＋</span>';
    if (focus) teamTabs[teamChapter].focus();
    if (!matchMedia('(prefers-reduced-motion: reduce)').matches && teamPanels[teamChapter].animate) {
      teamPanels[teamChapter].animate([{opacity:0,transform:'translateY(14px)'},{opacity:1,transform:'translateY(0)'}], {duration:480,easing:'cubic-bezier(.22,1,.36,1)'});
    }
  };
  teamTabs.forEach((tab, i) => {
    tab.addEventListener('click', () => selectTeamChapter(i));
    tab.addEventListener('keydown', event => {
      const index = event.key === 'ArrowRight' ? i + 1 : event.key === 'ArrowLeft' ? i - 1 : event.key === 'Home' ? 0 : event.key === 'End' ? teamTabs.length - 1 : null;
      if (index !== null) { event.preventDefault(); selectTeamChapter(index, true); }
    });
  });
  nextChapter.addEventListener('click', () => {
    selectTeamChapter(teamChapter + 1, true);
    teamTabs[teamChapter].scrollIntoView({block:'nearest',behavior:'instant'});
  });
  document.querySelectorAll('.market').forEach(link => link.addEventListener('click', markSeen));
  const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const passing = document.querySelector('.passing');
  const scene = document.querySelector('.passing-scene');
  const steps = [...document.querySelectorAll('.passing-steps button')];
  const chapters = [
    ['Đã từng<br>được yêu quý.', 'Rồi nằm yên, vì mình không còn dùng nữa.'],
    ['Được trao lại.<br>Thật gần.', 'Một người đăng. Một người tìm thấy. Một cuộc gặp.'],
    ['Lại có ích.<br>Lại được thương.', 'Thêm một góc nhà, thêm một câu chuyện để thuộc về.'],
  ];
  let phase = -1;
  const setChapter = next => {
    if (phase === next) return;
    phase = next; scene.dataset.phase = String(next);
    scene.querySelector('h2').innerHTML = chapters[next][0];
    scene.querySelector('.passing-copy p').textContent = chapters[next][1];
    if (!reduced && scene.querySelector('.passing-copy').animate) {
      scene.querySelector('.passing-copy').animate([
        { opacity: 0, marginTop: '14px' }, { opacity: 1, marginTop: '0px' },
      ], { duration: 520, easing: 'cubic-bezier(.22,1,.36,1)' });
    }
    steps.forEach((step, i) => step.setAttribute('aria-pressed', String(i === next)));
  };
  const chapterFromScroll = () => {
    const rect = passing.getBoundingClientRect();
    if (rect.bottom < 0 || rect.top > innerHeight) return;
    const travel = Math.max(1, rect.height - innerHeight);
    setChapter(Math.min(2, Math.floor(Math.max(0, -rect.top / travel) * 3)));
  };
  setChapter(0);
  steps.forEach((step, i) => step.addEventListener('click', () => {
    setChapter(i);
    if (!reduced) {
      const travel = Math.max(0, passing.offsetHeight - innerHeight);
      window.scrollTo({ top: passing.offsetTop + travel * (i / 3 + .03), behavior: 'instant' });
    }
  }));
  if (!reduced) addEventListener('scroll', chapterFromScroll, { passive: true });
  if (!reduced && matchMedia('(hover:hover) and (pointer:fine)').matches) {
    const art = document.querySelector('.hero-art');
    const card = document.querySelector('.postcard');
    let tx = 0, ty = 0, x = 0, y = 0, frame;
    const tilt = () => {
      x += (tx - x) * .09; y += (ty - y) * .09;
      card.style.transform = `perspective(1000px) rotateX(${-y}deg) rotateY(${x}deg) rotate(-8deg)`;
      if (Math.abs(tx-x) + Math.abs(ty-y) > .02) frame = requestAnimationFrame(tilt); else frame = null;
    };
    art.addEventListener('pointermove', e => {
      const r = art.getBoundingClientRect();
      tx = ((e.clientX-r.left)/r.width-.5)*10;
      ty = ((e.clientY-r.top)/r.height-.5)*8;
      if (!frame) frame = requestAnimationFrame(tilt);
    });
    art.addEventListener('pointerleave', () => { tx = 0; ty = 0; if (!frame) frame = requestAnimationFrame(tilt); });
  }
  if (!reduced && 'IntersectionObserver' in window) {
    const observer = new IntersectionObserver(entries => {
      entries.forEach(entry => {
        if (entry.isIntersecting) { entry.target.classList.add('visible'); observer.unobserve(entry.target); }
      });
    }, { threshold: 0.08 });
    document.documentElement.classList.add('motion-ready');
    document.querySelectorAll('.reveal').forEach(el => observer.observe(el));
  }
  if (!reduced) {
    const progress = document.createElement('div');
    progress.className = 'progress'; progress.setAttribute('aria-hidden', 'true'); document.body.append(progress);
    let queued = false;
    const update = () => {
      const distance = document.documentElement.scrollHeight - innerHeight;
      progress.style.transform = `scaleX(${distance > 0 ? Math.min(1, scrollY / distance) : 0})`;
      queued = false;
    };
    addEventListener('scroll', () => { if (!queued) { queued = true; requestAnimationFrame(update); } }, { passive: true });
    update();
  }
  document.querySelectorAll('.object-card').forEach(card => {
    card.addEventListener('click', () => {
      const expanded = card.getAttribute('aria-expanded') !== 'true';
      card.setAttribute('aria-expanded', String(expanded));
      card.querySelector('.object-hint').innerHTML = expanded
        ? 'Một khởi đầu khác <b aria-hidden="true">−</b>'
        : 'Chạm để tiếp chuyện <b aria-hidden="true">＋</b>';
    });
  });
  document.getElementById('share').addEventListener('click', async () => {
    const url = new URL('story.html', location.href).href;
    const status = document.getElementById('share-status');
    status.textContent = '';
    try {
      if (navigator.share) {
        await navigator.share({ title: 'Passy — Món đồ cũ. Một khởi đầu mới.', text: 'Người cần món đồ ấy có thể ở ngay gần bạn. Cùng mình khám phá Passy nhé!', url });
        return;
      }
      if (!navigator.clipboard) throw new Error('Clipboard unavailable');
      await navigator.clipboard.writeText(url);
      status.textContent = 'Đã sao chép đường dẫn. Gửi cho một người bạn nhé!';
    } catch (error) {
      if (error.name === 'AbortError') return;
      document.getElementById('copy-fallback').hidden = false;
      const input = document.getElementById('share-url');
      input.value = url; input.focus(); input.select();
      status.textContent = 'Bạn có thể sao chép đường dẫn bên dưới.';
    }
  });
})();

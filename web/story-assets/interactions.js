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
    const url = 'https://passy.id.vn/story.html';
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

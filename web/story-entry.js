// Only a plain first visit gets the introduction. Auth and deep links go to the app.
(() => {
  const url = new URL(location.href);
  const plainPath = url.pathname.endsWith('/') || url.pathname.endsWith('/index.html');
  if (!plainPath || url.search || url.hash) return;
  try {
    if (localStorage.getItem('passy.story.seen.v1')) return;
    location.replace(new URL('story.html', url));
  } catch (_) { /* Storage unavailable: prefer immediate access to the marketplace. */ }
})();

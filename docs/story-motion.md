# Passy story page

`web/story.html` is the public first-visit introduction and the destination of the app's “Câu chuyện Passy” / “Về chúng tôi” links. `web/story-entry.js` preserves direct app/auth links and skips the introduction for returning visitors.

Approved motion design: mint-green teddy lifecycle, then a continuous stream of 16 AI sample photos and six text/illustrative quote plates. Fictional stories and sample feedback are labeled. Twelve new 512px JPEGs plus the four earlier sample views are included locally; no reference-site images or paid effect code are copied.

Runtime source is in `web/story-assets/`: `sticker.js` owns motion setup and reduced-motion handling; `bear-lifecycle.js` keeps the bear fixed while changing its surroundings; `memory-collage.js` implements the scroll-linked depth stream; `interactions.js` owns team tabs, first-visit tracking and sharing. Static reading layout is the initial fallback until motion initializes. Shared GSAP/ScrollTrigger and Lenis files retain their upstream headers in `vendor/`.

The implementation was informed by direct observation of the Made With GSAP showcase. A normal wheel movement brings small plates from the right, enlarges them near the center and shrinks them toward the left. The stream uses independent image and text plates rather than pairing every image with a testimonial.

Validation includes the release web build, local asset-reference checks, script syntax checks, 11 first-visit/auth/deep-link checks, and desktop/mobile visual checks. A motion toggle and OS reduced-motion preference expose the full story and all sample plates without scroll-linked animation.

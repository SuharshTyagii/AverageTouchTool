/* AverageTouchTool landing — interactions.
   The detection pad mirrors the app's real classification: normalize travel to
   0..1, decide direction from the dominant axis, threshold 0.10 for a swipe and
   <0.06 (and quick) for a tap. */

(() => {
  "use strict";

  // ---------- detection pad ----------
  const pad = document.getElementById("pad");
  const canvas = document.getElementById("pad-canvas");
  if (pad && canvas) {
    const ctx = canvas.getContext("2d");
    const css = getComputedStyle(document.documentElement);
    const COL = {
      grid: "rgba(18,22,27,0.07)",
      trace: css.getPropertyValue("--trace").trim() || "#1F5AE6",
      contact: css.getPropertyValue("--contact").trim() || "#E0457B",
    };
    const SWIPE = 0.10, TAP_TRAVEL = 0.06, TAP_MS = 400;

    const out = {
      gesture: document.getElementById("r-gesture"),
      fingers: document.getElementById("r-fingers"),
      travel: document.getElementById("r-travel"),
      delta: document.getElementById("r-delta"),
      cursor: document.getElementById("r-cursor"),
    };

    let fingers = 3;
    let W = 0, H = 0, dpr = 1;
    let drawing = false;
    let path = []; // {x,y} in css px
    let startT = 0;
    let hover = null;

    function resize() {
      const r = pad.getBoundingClientRect();
      W = r.width; H = r.height;
      dpr = Math.min(window.devicePixelRatio || 1, 2);
      canvas.width = Math.round(W * dpr);
      canvas.height = Math.round(H * dpr);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      render();
    }

    function grid() {
      ctx.clearRect(0, 0, W, H);
      ctx.strokeStyle = COL.grid;
      ctx.lineWidth = 1;
      const step = 26;
      ctx.beginPath();
      for (let x = step; x < W; x += step) { ctx.moveTo(x, 0); ctx.lineTo(x, H); }
      for (let y = step; y < H; y += step) { ctx.moveTo(0, y); ctx.lineTo(W, y); }
      ctx.stroke();
    }

    function render() {
      grid();

      // crosshair on hover
      if (hover && !drawing) {
        ctx.strokeStyle = "rgba(18,22,27,0.25)";
        ctx.setLineDash([4, 4]);
        ctx.beginPath();
        ctx.moveTo(hover.x, 0); ctx.lineTo(hover.x, H);
        ctx.moveTo(0, hover.y); ctx.lineTo(W, hover.y);
        ctx.stroke();
        ctx.setLineDash([]);
      }

      if (path.length) {
        // trace
        ctx.strokeStyle = COL.trace;
        ctx.lineWidth = 3;
        ctx.lineJoin = "round";
        ctx.lineCap = "round";
        ctx.beginPath();
        ctx.moveTo(path[0].x, path[0].y);
        for (const p of path) ctx.lineTo(p.x, p.y);
        ctx.stroke();

        // contact dots spread across the leading edge to suggest finger count
        const tip = path[path.length - 1];
        drawContacts(tip);
        // start marker
        dot(path[0].x, path[0].y, 4, "rgba(18,22,27,0.4)");
      }
    }

    function dot(x, y, r, fill) {
      ctx.fillStyle = fill;
      ctx.beginPath();
      ctx.arc(x, y, r, 0, Math.PI * 2);
      ctx.fill();
    }

    function drawContacts(tip) {
      const spread = 13;
      const offset = (fingers - 1) / 2;
      for (let i = 0; i < fingers; i++) {
        const dx = (i - offset) * spread;
        dot(tip.x + dx, tip.y, 5.5, COL.contact);
      }
    }

    function norm(p0, p1) {
      return { dx: (p1.x - p0.x) / W, dy: (p1.y - p0.y) / H };
    }

    function classify() {
      if (path.length < 2) {
        const dur = performance.now() - startT;
        if (dur < TAP_MS) return finalize("tap", 0, 0, 0);
        return finalize("—", 0, 0, 0);
      }
      const { dx, dy } = norm(path[0], path[path.length - 1]);
      const travel = Math.hypot(dx, dy);
      const dur = performance.now() - startT;

      if (travel >= SWIPE) {
        let g;
        if (Math.abs(dx) > Math.abs(dy)) g = dx > 0 ? "swipe →" : "swipe ←";
        else g = dy > 0 ? "swipe ↓" : "swipe ↑"; // screen y grows downward
        return finalize(g, travel, dx, dy);
      }
      if (travel < TAP_TRAVEL && dur < TAP_MS) return finalize("tap", travel, dx, dy);
      return finalize("no gesture", travel, dx, dy);
    }

    function finalize(g, travel, dx, dy) {
      out.gesture.textContent = g;
      out.travel.textContent = travel.toFixed(3);
      out.delta.textContent = `${dx.toFixed(2)} / ${dy.toFixed(2)}`;
    }

    function pos(e) {
      const r = pad.getBoundingClientRect();
      return {
        x: Math.max(0, Math.min(W, e.clientX - r.left)),
        y: Math.max(0, Math.min(H, e.clientY - r.top)),
      };
    }

    pad.addEventListener("pointerdown", (e) => {
      pad.setPointerCapture(e.pointerId);
      pad.classList.add("is-active");
      drawing = true;
      path = [pos(e)];
      startT = performance.now();
      out.gesture.textContent = "tracking";
      render();
    });

    pad.addEventListener("pointermove", (e) => {
      const p = pos(e);
      hover = p;
      out.cursor.textContent = `${(p.x / W).toFixed(2)}, ${(1 - p.y / H).toFixed(2)}`;
      if (drawing) { path.push(p); render(); }
      else render();
    });

    function end() {
      if (!drawing) return;
      drawing = false;
      classify();
      render();
    }
    pad.addEventListener("pointerup", end);
    pad.addEventListener("pointercancel", end);
    pad.addEventListener("pointerleave", () => { hover = null; if (!drawing) render(); });

    // finger picker
    document.querySelectorAll(".finger-picker button").forEach((b) => {
      b.addEventListener("click", () => {
        fingers = parseInt(b.dataset.fingers, 10);
        document.querySelectorAll(".finger-picker button").forEach((x) => {
          x.classList.toggle("is-active", x === b);
          x.setAttribute("aria-pressed", x === b ? "true" : "false");
        });
        out.fingers.textContent = String(fingers);
        if (path.length) render();
      });
    });

    window.addEventListener("resize", resize);
    resize();
  }

  // ---------- copy install command ----------
  const copyBtn = document.getElementById("copy-install");
  if (copyBtn) {
    copyBtn.addEventListener("click", async () => {
      const cmd = "git clone https://github.com/SuharshTyagii/AverageTouchTool.git\ncd AverageTouchTool\n./package.sh";
      try {
        await navigator.clipboard.writeText(cmd);
        copyBtn.textContent = "Copied";
        copyBtn.classList.add("is-done");
        setTimeout(() => { copyBtn.textContent = "Copy"; copyBtn.classList.remove("is-done"); }, 1600);
      } catch { copyBtn.textContent = "Copy failed"; }
    });
  }

  // ---------- scroll reveal ----------
  if (matchMedia("(prefers-reduced-motion: no-preference)").matches && "IntersectionObserver" in window) {
    const targets = document.querySelectorAll(".block");
    targets.forEach((t) => t.classList.add("reveal"));
    const io = new IntersectionObserver((entries) => {
      for (const e of entries) {
        if (e.isIntersecting) { e.target.classList.add("is-in"); io.unobserve(e.target); }
      }
    }, { threshold: 0.12 });
    targets.forEach((t) => io.observe(t));
  }
})();

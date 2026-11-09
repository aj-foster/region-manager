const hooks = new Set();
let patchPending = false;
let queuedToggles = [];

function patchNextToggle() {
  if (patchPending) return;

  const toggle = queuedToggles.shift();
  if (!toggle) return;
  if (!hooks.has(toggle.hook) || toggle.path !== window.location.pathname) {
    patchNextToggle();
    return;
  }

  const { hook } = toggle;
  const url = new URL(window.location.href);
  const next = !hook.expanded(url);

  if (next === hook.defaultExpanded()) {
    url.searchParams.delete(hook.el.dataset.queryParam);
  } else {
    url.searchParams.set(hook.el.dataset.queryParam, String(next));
  }

  patchPending = true;
  hook.js().patch(url.href);
}

export default {
  mounted() {
    this.onToggle = () => {
      queuedToggles.push({ hook: this, path: window.location.pathname });
      patchNextToggle();
    };

    this.onNavigate = (event) => {
      this.sync(new URL(event.detail.href, window.location.href));
      if (event.detail.patch) {
        if (patchPending) {
          patchPending = false;
          queueMicrotask(patchNextToggle);
        }
      } else {
        queuedToggles = [];
        patchPending = false;
      }
    };

    hooks.add(this);
    this.el.addEventListener("query-reveal:toggle", this.onToggle);
    window.addEventListener("phx:navigate", this.onNavigate);
    this.sync(new URL(window.location.href));
  },

  updated() {
    this.sync(new URL(window.location.href));
  },

  disconnected() {
    queuedToggles = [];
    patchPending = false;
  },

  reconnected() {
    this.sync(new URL(window.location.href));
  },

  destroyed() {
    this.el.removeEventListener("query-reveal:toggle", this.onToggle);
    window.removeEventListener("phx:navigate", this.onNavigate);
    hooks.delete(this);
    queuedToggles = queuedToggles.filter(({ hook }) => hook !== this);
    if (hooks.size === 0) patchPending = false;
  },

  defaultExpanded() {
    return this.el.dataset.defaultExpanded === "true";
  },

  expanded(url) {
    const value = url.searchParams.get(this.el.dataset.queryParam);
    if (value === "true") return true;
    if (value === "false") return false;
    return this.defaultExpanded();
  },

  sync(url) {
    const attribute = this.expanded(url) ? "data-reveal-show" : "data-reveal-hide";
    this.js().exec(this.el.getAttribute(attribute));
  },
};

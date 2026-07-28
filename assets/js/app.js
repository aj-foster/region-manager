import "phoenix_html";
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";
import MarkdownEditor from "./hooks/markdown_editor";

//
// Hooks
//

let Hooks = {
  MarkdownEditor,
};

Hooks.DragDropStyle = {
  mounted() {
    this.el.addEventListener("dragover", () => {
      this.el.dataset.drag = "active";
    });

    this.el.addEventListener("dragleave", () => {
      delete this.el.dataset.drag;
    });

    this.el.addEventListener("drop", () => {
      delete this.el.dataset.drag;
    });
  },
};

Hooks.AutoClearFlash = {
  mounted() {
    if (["client-error", "server-error"].includes(this.el.id)) return;

    this.hideTimer = setTimeout(() => {
      this.el.style.opacity = 0;
      delete this.hideTimer;
    }, 5000);

    this.clearTimer = setTimeout(() => {
      this.pushEvent("lv:clear-flash");
      delete this.clearTimer;
    }, 5500);
  },
  destroyed() {
    if (["client-error", "server-error"].includes(this.el.id)) return;

    if (this.hideTimer) clearTimeout(this.hideTimer);
    if (this.clearTimer) clearTimeout(this.clearTimer);
  },
  updated() {
    if (["client-error", "server-error"].includes(this.el.id)) return;

    this.destroyed();
    this.mounted();
  },
};

//
// Live Socket
//

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  params: {
    _csrf_token: csrfToken,
    timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
  },
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

//
// Events
//

// See RMWeb.Live.Util.push_js/3
window.addEventListener("phx:js-exec", ({ detail: { to, attr } }) => {
  document.querySelectorAll(to).forEach((el) => {
    liveSocket.execJS(el, el.getAttribute(attr));
  });
});

// See RMWeb.Live.Util.copy/2
window.addEventListener("phx:copy", (event) => {
  let content;
  let copyAttribute = event.target.getAttribute("data-copy");
  let contentType = event.target.getAttribute("data-copy-type");

  if (copyAttribute != null) {
    content = copyAttribute;
  } else if (event.target instanceof HTMLInputElement) {
    content = event.target.value;
  } else {
    content = event.target.innerText;
  }

  if (contentType != null) {
    const blob = new Blob([content], { contentType });
    const data = [new ClipboardItem({ [contentType]: blob })];

    navigator.clipboard.write(data);
  } else {
    navigator.clipboard.writeText(content);
  }
});

window.addEventListener("phx:window-open", ({ detail: { url } }) => {
  window.open(url, "_blank", "noopener noreferrer");
});

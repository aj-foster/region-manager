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

const putHtmlPreview = (el) => {
  const content = el.innerText || "";

  const iframes = document.querySelectorAll(el.dataset.iframe);
  if (!iframes.length) return;

  for (let i = 0; i < iframes.length; i++) {
    const iframe = iframes[i];
    const resizeIframe = () => {
      const doc = iframe.contentDocument;
      if (!doc || !doc.body || !doc.documentElement) return;

      const body = doc.body;
      const html = doc.documentElement;
      const contentHeight = Math.max(
        body.scrollHeight,
        body.offsetHeight,
        body.clientHeight,
        html.scrollHeight,
        html.offsetHeight,
        html.clientHeight,
      );

      const heightPx = Math.max(contentHeight, 320);
      iframe.style.height = `${heightPx}px`;
      iframe.setAttribute("height", String(heightPx));
    };

    // Avoid the browser fallback default iframe height (150px) while content is written.
    iframe.style.height = "320px";
    iframe.setAttribute("height", "320");

    const doc = iframe.contentDocument;
    doc.open();
    doc.write(content);
    doc.close();

    // Force previewed links to open in a new tab rather than navigating the iframe/parent.
    doc.querySelectorAll("a[href]").forEach((link) => {
      link.setAttribute("target", "_blank");
      link.setAttribute("rel", "noopener noreferrer");
    });

    // Ensure iframe document root can grow with content.
    if (doc.head) {
      const style = doc.createElement("style");
      style.textContent = "html, body { height: auto !important; min-height: 0 !important; }";
      doc.head.appendChild(style);
    }

    // Resize immediately and on later layout changes (images/fonts).
    resizeIframe();
    iframe.contentWindow.requestAnimationFrame(resizeIframe);
    iframe.contentWindow.setTimeout(resizeIframe, 50);
    iframe.contentWindow.setTimeout(resizeIframe, 200);

    const images = doc.images ? Array.from(doc.images) : [];
    images.forEach((img) => {
      if (!img.complete) {
        img.addEventListener("load", resizeIframe, { once: true });
        img.addEventListener("error", resizeIframe, { once: true });
      }
    });
  }
};

Hooks.HtmlPreview = {
  mounted() {
    putHtmlPreview(this.el);
  },
  updated() {
    putHtmlPreview(this.el);
  },
};

Hooks.MarkdownLinkDialog = {
  mounted() {
    this.dialog = this.el.querySelector("dialog");
    this.form = this.el.querySelector("form");
    this.hrefInput = this.el.querySelector("[name='href']");
    this.titleInput = this.el.querySelector("[name='title']");
    this.cancelButton = this.el.querySelector("[data-action='cancel']");
    this.skipCancelDispatch = false;

    if (!this.dialog || !this.form || !this.hrefInput || !this.titleInput || !this.cancelButton) return;

    this.dispatchUpdateLink = (detail) => {
      window.dispatchEvent(new CustomEvent("update-link", { detail }));
    };

    this.handleShow = (event) => {
      const detail = event.detail || {};

      this.hrefInput.value = detail.href || "";
      this.titleInput.value = detail.title || "";

      if (!this.dialog.open) {
        this.dialog.showModal();
      }

      this.hrefInput.focus();
      this.hrefInput.select();
    };

    this.handleSubmit = (event) => {
      event.preventDefault();

      const href = this.hrefInput.value.trim();
      const title = this.titleInput.value.trim();

      this.dispatchUpdateLink({
        cancel: false,
        href,
        title: title === "" ? null : title,
      });

      this.skipCancelDispatch = true;
      this.dialog.close();
    };

    this.handleCancelClick = (event) => {
      event.preventDefault();
      this.dialog.close();
    };

    this.handleClose = () => {
      if (this.skipCancelDispatch) {
        this.skipCancelDispatch = false;
        return;
      }

      this.dispatchUpdateLink({ cancel: true });
    };

    this.el.addEventListener("x-show", this.handleShow);
    this.form.addEventListener("submit", this.handleSubmit);
    this.cancelButton.addEventListener("click", this.handleCancelClick);
    this.dialog.addEventListener("close", this.handleClose);
  },

  destroyed() {
    if (this.dialog?.open) {
      this.skipCancelDispatch = true;
      this.dialog.close();
    }

    if (this.el && this.handleShow) this.el.removeEventListener("x-show", this.handleShow);
    if (this.form && this.handleSubmit) this.form.removeEventListener("submit", this.handleSubmit);
    if (this.cancelButton && this.handleCancelClick) {
      this.cancelButton.removeEventListener("click", this.handleCancelClick);
    }
    if (this.dialog && this.handleClose) this.dialog.removeEventListener("close", this.handleClose);
  },
};

Hooks.MarkdownButtonDialog = {
  mounted() {
    this.dialog = this.el.querySelector("dialog");
    this.form = this.el.querySelector("form");
    this.hrefInput = this.el.querySelector("[name='href']");
    this.textInput = this.el.querySelector("[name='text']");
    this.cancelButton = this.el.querySelector("[data-action='cancel']");
    this.skipCancelDispatch = false;

    if (!this.dialog || !this.form || !this.hrefInput || !this.textInput || !this.cancelButton) return;

    this.dispatchUpdateButton = (detail) => {
      window.dispatchEvent(new CustomEvent("update-button", { detail }));
    };

    this.handleShow = (event) => {
      const detail = event.detail || {};

      this.hrefInput.value = detail.href || "";
      this.textInput.value = detail.text || "Button";

      if (!this.dialog.open) {
        this.dialog.showModal();
      }

      this.hrefInput.focus();
      this.hrefInput.select();
    };

    this.handleSubmit = (event) => {
      event.preventDefault();

      const href = this.hrefInput.value.trim();
      const text = this.textInput.value.trim();

      this.dispatchUpdateButton({
        cancel: false,
        href,
        text,
      });

      this.skipCancelDispatch = true;
      this.dialog.close();
    };

    this.handleCancelClick = (event) => {
      event.preventDefault();
      this.dialog.close();
    };

    this.handleClose = () => {
      if (this.skipCancelDispatch) {
        this.skipCancelDispatch = false;
        return;
      }

      this.dispatchUpdateButton({ cancel: true });
    };

    this.el.addEventListener("x-show", this.handleShow);
    this.form.addEventListener("submit", this.handleSubmit);
    this.cancelButton.addEventListener("click", this.handleCancelClick);
    this.dialog.addEventListener("close", this.handleClose);
  },

  destroyed() {
    if (this.dialog?.open) {
      this.skipCancelDispatch = true;
      this.dialog.close();
    }

    if (this.el && this.handleShow) this.el.removeEventListener("x-show", this.handleShow);
    if (this.form && this.handleSubmit) this.form.removeEventListener("submit", this.handleSubmit);
    if (this.cancelButton && this.handleCancelClick) {
      this.cancelButton.removeEventListener("click", this.handleCancelClick);
    }
    if (this.dialog && this.handleClose) this.dialog.removeEventListener("close", this.handleClose);
  },
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

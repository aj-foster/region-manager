import { MarkdownEditor as KeilaMarkdownEditor } from "../../../deps/keila/assets/js/campaign-editors/markdown/index.js";
import markdownit from "markdown-it";

const MarkdownEditor = {
  mounted() {
    const place = this.el.querySelector(".editor");
    const source = document.querySelector("#campaign_text_body");
    const preview = this.el.querySelector(".markdown-preview");

    if (!place || !source || !preview) return;

    this.place = place;
    this.source = source;
    this.preview = preview;
    this.previewVisible = false;
    this.md = markdownit("commonmark", { html: false, linkify: true });
    this.editor = new KeilaMarkdownEditor(place, source);

    this.handleTogglePreview = () => {
      this.previewVisible = !this.previewVisible;

      if (this.previewVisible) {
        this.preview.innerHTML = this.md.render(this.source.value || "");
      }

      this.place.classList.toggle("hidden", this.previewVisible);
      this.preview.classList.toggle("hidden", !this.previewVisible);

      const toggleButton = this.el.querySelector("[data-action='toggle-preview']");
      if (toggleButton) {
        toggleButton.textContent = this.previewVisible ? "Edit" : "Preview";
      }
    };

    this.el.addEventListener("x-toggle-preview", this.handleTogglePreview);
  },

  destroyed() {
    if (this.el && this.handleTogglePreview) {
      this.el.removeEventListener("x-toggle-preview", this.handleTogglePreview);
    }

    if (this.editor) {
      this.editor.destroy();
      delete this.editor;
    }
  },
};

export default MarkdownEditor;

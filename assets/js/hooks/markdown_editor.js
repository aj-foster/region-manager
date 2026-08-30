import { MarkdownEditor as KeilaMarkdownEditor } from "../../../deps/keila/assets/js/campaign-editors/markdown/index.js";

const MarkdownEditor = {
  mounted() {
    const source = document.querySelector("#campaign_text_body");

    this.place = this.el.querySelector(".editor");
    this.preview = this.el.querySelector(".markdown-preview");

    if (!this.place || !source || !this.preview) return;

    this.previewVisible = false;
    this.editor = new KeilaMarkdownEditor(this.place, source);

    this.applyPreviewState = () => {
      if (!this.place || !this.preview) return;

      this.place.classList.toggle("hidden", this.previewVisible);
      this.preview.classList.toggle("hidden", !this.previewVisible);

      const eyeIcon = this.el.querySelector("#toggle-preview-icon-eye");
      const pencilIcon = this.el.querySelector("#toggle-preview-icon-pencil");
      if (eyeIcon) eyeIcon.style.display = this.previewVisible ? "none" : "";
      if (pencilIcon) pencilIcon.style.display = this.previewVisible ? "" : "none";
    };

    this.handleTogglePreview = () => {
      this.previewVisible = !this.previewVisible;
      this.applyPreviewState();
    };

    this.el.addEventListener("x-toggle-preview", this.handleTogglePreview);
  },

  updated() {
    // LiveView patches can reset classes on the preview pane.
    // Re-query elements and reapply visibility state.
    this.place = this.el.querySelector(".editor");
    this.preview = this.el.querySelector(".markdown-preview");

    if (this.applyPreviewState) {
      this.applyPreviewState();
    }
  },

  destroyed() {
    if (this.el && this.handleTogglePreview) {
      this.el.removeEventListener("x-toggle-preview", this.handleTogglePreview);
    }

    if (this.editor) {
      this.editor.view.destroy();
      delete this.editor;
    }
  },
};

export default MarkdownEditor;

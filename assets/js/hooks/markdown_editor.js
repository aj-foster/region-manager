import { MarkdownEditor as KeilaMarkdownEditor } from "../../../deps/keila/assets/js/campaign-editors/markdown/index.js";

const MarkdownEditor = {
  mounted() {
    const place = this.el.querySelector(".editor");
    const source = document.querySelector("#campaign_text_body");

    if (!place || !source) return;

    this.editor = new KeilaMarkdownEditor(place, source);
  },

  destroyed() {
    if (this.editor) {
      this.editor.destroy();
      delete this.editor;
    }
  },
};

export default MarkdownEditor;

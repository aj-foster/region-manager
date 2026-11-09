import assert from "node:assert/strict";
import { afterEach, test } from "node:test";
import QueryReveal from "../js/hooks/query_reveal.js";

class TestWindow extends EventTarget {
  constructor(href) {
    super();
    this.location = new URL(href);
  }

  navigate(href, patch = true) {
    this.location = new URL(href, this.location);
    this.dispatchEvent(new CustomEvent("phx:navigate", {
      detail: { href: this.location.href, patch },
    }));
  }
}

function mount(param, defaultExpanded = false) {
  const el = new EventTarget();
  el.dataset = { queryParam: param, defaultExpanded: String(defaultExpanded) };
  el.getAttribute = (name) => name;
  const hook = {
    ...QueryReveal,
    el,
    commands: [],
    patches: [],
    js() {
      return {
        exec: (command) => this.commands.push(command),
        patch: (href) => this.patches.push(href),
      };
    },
  };
  hook.mounted();
  return hook;
}

function toggle(hook) {
  hook.el.dispatchEvent(new Event("query-reveal:toggle"));
}

afterEach(() => {
  delete globalThis.window;
});

test("deep links, history, updates, and teardown synchronize visibility", () => {
  globalThis.window = new TestWindow("https://example.test/teams?inactive=true#list");
  const hook = mount("inactive");
  assert.equal(hook.commands.at(-1), "data-reveal-show");

  window.navigate("/teams");
  assert.equal(hook.commands.at(-1), "data-reveal-hide");
  window.navigate("/teams?inactive=true");
  assert.equal(hook.commands.at(-1), "data-reveal-show");
  hook.updated();
  assert.equal(hook.commands.at(-1), "data-reveal-show");
  window.navigate("/teams", false);
  assert.equal(hook.commands.at(-1), "data-reveal-hide");

  hook.destroyed();
  const count = hook.commands.length;
  window.navigate("/teams");
  toggle(hook);
  assert.equal(hook.commands.length, count);
  assert.equal(hook.patches.length, 0);
});

test("toggles preserve other query parameters and serialize simultaneous patches", async () => {
  globalThis.window = new TestWindow("https://example.test/teams?other=keep#list");
  const intent = mount("intend_to_return");
  const inactive = mount("inactive");

  toggle(intent);
  toggle(inactive);
  toggle(intent);
  assert.equal(inactive.patches.length, 0);
  assert.equal(intent.patches.length, 1);
  assert.equal(intent.patches[0], "https://example.test/teams?other=keep&intend_to_return=true#list");

  window.navigate(intent.patches[0]);
  await Promise.resolve();
  assert.equal(inactive.patches[0], "https://example.test/teams?other=keep&intend_to_return=true&inactive=true#list");
  window.navigate(inactive.patches[0]);
  await Promise.resolve();
  assert.equal(intent.patches[1], "https://example.test/teams?other=keep&inactive=true#list");
  window.navigate(intent.patches[1]);
  await Promise.resolve();
  assert.equal(intent.commands.at(-1), "data-reveal-hide");
  assert.equal(inactive.commands.at(-1), "data-reveal-show");

  toggle(inactive);
  assert.equal(inactive.patches[1], "https://example.test/teams?other=keep#list");
  window.navigate(inactive.patches[1]);
  intent.destroyed();
  inactive.destroyed();
});

test("an expanded default uses false to represent the non-default state", () => {
  globalThis.window = new TestWindow("https://example.test/teams");
  const hook = mount("details", true);
  assert.equal(hook.commands.at(-1), "data-reveal-show");
  toggle(hook);
  assert.equal(hook.patches[0], "https://example.test/teams?details=false");
  window.navigate(hook.patches[0]);
  assert.equal(hook.commands.at(-1), "data-reveal-hide");
  toggle(hook);
  assert.equal(hook.patches[1], "https://example.test/teams");
  window.navigate(hook.patches[1]);
  hook.destroyed();
});

test("disconnecting clears pending toggles and reconnecting restores URL state", () => {
  globalThis.window = new TestWindow("https://example.test/teams");
  const hook = mount("inactive");
  toggle(hook);
  toggle(hook);
  assert.equal(hook.patches.length, 1);
  hook.disconnected();
  window.location = new URL("https://example.test/teams?inactive=true");
  hook.reconnected();
  assert.equal(hook.commands.at(-1), "data-reveal-show");
  toggle(hook);
  assert.equal(hook.patches[1], "https://example.test/teams");
  window.navigate(hook.patches[1]);
  hook.destroyed();
});

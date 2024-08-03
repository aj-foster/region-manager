// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  params: {
    _csrf_token: csrfToken,
    timezone: Intl.DateTimeFormat().resolvedOptions().timeZone
  }
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// See RMWeb.Live.Util.push_js/3
window.addEventListener("phx:js-exec", ({ detail: {to, attr} }) => {
  document.querySelectorAll(to).forEach(el => {
    liveSocket.execJS(el, el.getAttribute(attr))
  })
})

// See RMWeb.Live.Util.copy/2
window.addEventListener("phx:copy", (event) => {
  let content;
  let copyAttribute = event.target.getAttribute("data-copy");
  let contentType = event.target.getAttribute("data-copy-type");

  if (copyAttribute != null) {
    content = copyAttribute;
  } else if (event.target instanceof HTMLInputElement) {
    content = event.target.value
  } else {
    content = event.target.innerText;
  }

  if (contentType != null) {
    const blob = new Blob([content], { contentType });
    const data = [new ClipboardItem({ [contentType]: blob })];

    navigator.clipboard.write(data)
  } else {
    navigator.clipboard.writeText(content)
  }
})

window.addEventListener("phx:window-open", ({ detail: { url } }) => {
  window.open(url, "_blank", "noopener noreferrer")
})

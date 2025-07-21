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
import NavigationState from "./navigation"
// Import vanilla navigation for non-LiveView pages
import "./navigation-vanilla"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {NavigationState}
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

// Code block copy functionality
window.copyToClipboard = function(elementId) {
  const codeElement = document.getElementById(elementId + '-content');
  if (!codeElement) {
    console.error('Code element not found:', elementId + '-content');
    return;
  }
  
  const text = codeElement.textContent || codeElement.innerText;
  
  if (navigator.clipboard) {
    navigator.clipboard.writeText(text).then(() => {
      showCopyFeedback(elementId);
    }).catch(err => {
      console.error('Failed to copy text: ', err);
      fallbackCopyTextToClipboard(text, elementId);
    });
  } else {
    fallbackCopyTextToClipboard(text, elementId);
  }
}

function fallbackCopyTextToClipboard(text, elementId) {
  const textArea = document.createElement("textarea");
  textArea.value = text;
  textArea.style.top = "0";
  textArea.style.left = "0";
  textArea.style.position = "fixed";
  textArea.style.opacity = "0";
  
  document.body.appendChild(textArea);
  textArea.focus();
  textArea.select();
  
  try {
    const successful = document.execCommand('copy');
    if (successful) {
      showCopyFeedback(elementId);
    }
  } catch (err) {
    console.error('Fallback: Could not copy text: ', err);
  }
  
  document.body.removeChild(textArea);
}

function showCopyFeedback(elementId) {
  const button = document.querySelector(`[onclick="copyToClipboard('${elementId}')"]`);
  if (button) {
    const originalText = button.innerHTML;
    button.innerHTML = '<svg class="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg><span>Copied!</span>';
    button.classList.add('text-green-600');
    
    setTimeout(() => {
      button.innerHTML = originalText;
      button.classList.remove('text-green-600');
    }, 2000);
  }
}


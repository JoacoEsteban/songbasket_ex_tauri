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
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";
import { Menu, Submenu } from "@tauri-apps/api/menu";
import { getCurrentWindow } from "@tauri-apps/api/window";
import { WebviewWindow } from "@tauri-apps/api/webviewWindow";
import { getCurrent, onOpenUrl } from "@tauri-apps/plugin-deep-link";
import { open, ask } from "@tauri-apps/plugin-dialog";
import Hooks from "./_hooks";

const appWindow = getCurrentWindow();

const MyHooks = {
  App: {
    async mounted() {
      onOpenUrl((url) => {
        this.pushEvent("open_url", { url });
      });

      getCurrent().then((urls) => {
        for (const url of urls) {
          this.pushEvent("current_open_url", { url });
        }
      });

      const submenu = await Submenu.new({
        text: "",
        items: [
          {
            text: "Quit Songbasket",
            enabled: true,
            action: () => {
              this.pushEvent("quit", {});
            },
          },
        ],
      });

      const submenu2 = await Submenu.new({
        text: "Real Actions",
        items: [
          {
            text: "Add one",
            enabled: true,
            action: () => {
              this.pushEvent("increment", {});
            },
          },
          {
            text: "Alert",
            enabled: true,
            action: () => {
              alert("Test");
            },
          },
        ],
      });

      const menu = await Menu.new({
        items: [submenu, submenu2],
      });

      await menu.setAsAppMenu();

      window.addEventListener("phx:relay", ({ detail }) => {
        const { id, e, p } = detail;
        console.log(document.getElementById(id), detail);
        document
          .getElementById(id)
          .dispatchEvent(new CustomEvent("phx:" + e, { detail: p }));
      });

      window.addEventListener("phx:dialog", async (...args) => {
        console.log(this, args);
        const { detail } = args[0];
        this.pushEvent("dialog-answer", [await open(detail), detail]);
      });

      window.addEventListener("phx:window", ({ detail }) => {
        const webview = createWindow(detail);

        console.log(webview);

        window.currentWebview = webview;

        webview.once("tauri://created", () => {
          // Window successfully created
          console.log("created");
        });

        webview.once("tauri://error", (e) => {
          // Error during creation
          console.log("error", e);
        });

        setTimeout(() => webview.close(), 5000);
      });
    },
  },
  Header: {
    async mounted() {
      console.log(">> mounted header", this);
      this.el.addEventListener("dblclick", () => {
        console.log("max");

        appWindow.toggleMaximize();
      });
    },
  },
};

function createWindow({
  url,
  label = Date.now().toString(),
  title = "Songbasket",
}) {
  return new WebviewWindow(label, {
    url,
    title,
  });
}

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: { ...Hooks, ...MyHooks },
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

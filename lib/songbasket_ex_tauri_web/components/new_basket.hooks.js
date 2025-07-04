import { open, ask } from "@tauri-apps/plugin-dialog";

export default {
  mounted() {
    // alert("mounted");
    console.log("!", this);

    window.targ = this;

    this.el.addEventListener("phx:a_dialog", async ({ detail }) => {
      this.pushEventTo(this.el, "dialog-answer", [await open(detail), detail]);
    });
  },
};

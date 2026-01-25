// Phoenix LiveView setup
import "phoenix_html";
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";

// Countdown Hook - updates countdown every second on the client
let Hooks = {};
Hooks.Countdown = {
  mounted() {
    console.log("[Countdown] Hook mounted");
    this.updateCountdown();
    this.timer = setInterval(() => this.updateCountdown(), 1000 * 60);
  },
  updated() {
    console.log("[Countdown] Hook updated");
    this.updateCountdown();
  },
  destroyed() {
    console.log("[Countdown] Hook destroyed");
    if (this.timer) {
      clearInterval(this.timer);
    }
  },
  updateCountdown() {
    try {
      const nextPrayerTime = this.el.dataset.nextPrayerTime;
      console.log("[Countdown] Next prayer time:", nextPrayerTime);

      if (!nextPrayerTime) {
        console.warn("[Countdown] No next prayer time found");
        return;
      }

      const now = new Date();
      const target = new Date(nextPrayerTime);

      console.log("[Countdown] Now:", now.toISOString(), "Target:", target.toISOString());

      // Check if date is valid
      if (isNaN(target.getTime())) {
        console.error("[Countdown] Invalid date format:", nextPrayerTime);
        return;
      }

      const diffMs = target - now;

      if (diffMs <= 0) {
        this.el.textContent = "0m";
        console.log("[Countdown] Time has passed");
        return;
      }

      const hours = Math.floor(diffMs / (1000 * 60 * 60));
      const minutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));

      const formatted = hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m`;
      this.el.textContent = formatted;
      console.log("[Countdown] Updated to:", formatted);
    } catch (error) {
      console.error("[Countdown] Error updating countdown:", error);
    }
  },
};

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
  timeout: 30000, // Increase timeout for slower Pi
  reconnectAfterMs: (tries) => [1000, 2000, 5000, 10000][tries - 1] || 10000, // Retry connection
});

// Connect to LiveView
liveSocket.connect();

// Expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

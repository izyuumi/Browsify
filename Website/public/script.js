const routes = {
  work: {
    source: "Slack",
    title: "Pull request",
    url: "github.com/izyuumi/Browsify/pull/42",
    destination: "Chrome · Work",
    reason: "Rule: github.com from Slack",
  },
  personal: {
    source: "Messages",
    title: "Weekend plans",
    url: "maps.apple.com/place/coffee",
    destination: "Safari · Personal",
    reason: "Rule: Apple links from Messages",
  },
  meeting: {
    source: "Calendar",
    title: "Design review",
    url: "zoom.us/j/8430921746",
    destination: "Zoom",
    reason: "Rule: zoom.us opens in Zoom",
  },
  picker: {
    source: "Mail",
    title: "A new link",
    url: "example.com/something-new",
    destination: "Your picker",
    reason: "No rule matched · choose with one key",
  },
};

const shell = document.querySelector("[data-demo-shell]");
const routeButtons = document.querySelectorAll("[data-route]");
const fields = {
  source: document.querySelector("#source-label"),
  title: document.querySelector("#source-title"),
  url: document.querySelector("#source-url"),
  destination: document.querySelector("#destination-title"),
  reason: document.querySelector("#destination-reason"),
};

function showRoute(routeName) {
  const route = routes[routeName];
  if (!route || !shell) return;

  shell.classList.remove("is-routing");
  void shell.offsetWidth;
  Object.entries(fields).forEach(([key, element]) => {
    if (element) element.textContent = route[key];
  });
  shell.classList.add("is-routing");

  routeButtons.forEach((button) => {
    button.setAttribute("aria-selected", String(button.dataset.route === routeName));
  });
}

routeButtons.forEach((button) => {
  button.addEventListener("click", () => showRoute(button.dataset.route));
});

shell?.addEventListener("pointermove", (event) => {
  const bounds = shell.getBoundingClientRect();
  shell.style.setProperty("--pointer-x", `${event.clientX - bounds.left}px`);
  shell.style.setProperty("--pointer-y", `${event.clientY - bounds.top}px`);
});

shell?.addEventListener("pointerleave", () => {
  shell.style.setProperty("--pointer-x", "50%");
  shell.style.setProperty("--pointer-y", "40%");
});

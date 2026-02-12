// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "./controllers"

document.addEventListener("turbo:load", () => {
  if (window.gtag) {
    window.gtag("event", "page_view", {
      page_path: window.location.pathname,
      page_location: window.location.href,
      page_title: document.title
    });
  }
});

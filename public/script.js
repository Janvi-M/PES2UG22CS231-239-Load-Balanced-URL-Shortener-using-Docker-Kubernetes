document.addEventListener("DOMContentLoaded", () => {
    const form = document.getElementById("urlForm");
    const urlInput = document.getElementById("urlInput");
    const shortcodeInput = document.getElementById("shortcodeInput");
    const result = document.getElementById("result");
    const urlList = document.getElementById("urlList");
  
    const backendBase = "http://localhost:8000"; // Go server
  
    form.addEventListener("submit", async (e) => {
      e.preventDefault();
      const url = urlInput.value;
      const shortcode = shortcodeInput.value;
  
      const payload = {
        url,
      };
      if (shortcode) payload.shortcode = shortcode;
  
      const res = await fetch(`${backendBase}/urls`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
  
      const data = await res.json();
      result.innerHTML = `<p>Short URL: <a href="${backendBase}/${data.shortcode}" target="_blank">${backendBase}/${data.shortcode}</a></p>`;
      loadUrls();
    });
  
    async function loadUrls() {
      const res = await fetch(`${backendBase}/urls`);
      const urls = await res.json();
      urlList.innerHTML = "";
  
      urls.forEach(({ shortcode, url }) => {
        const li = document.createElement("li");
        li.innerHTML = `<a href="${backendBase}/${shortcode}" target="_blank">${backendBase}/${shortcode}</a> ➡️ ${url}`;
        urlList.appendChild(li);
      });
    }
  
    loadUrls();
  });
  
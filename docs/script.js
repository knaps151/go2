(() => {
  const typed = document.getElementById("typed");
  const command = "go2 pi";
  const lines = document.querySelectorAll(".t-line");
  const lateCursor = document.querySelector(".cursor--late");

  const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

  async function playTerminal() {
    if (!typed) return;

    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      typed.textContent = command;
      lines.forEach((line) => line.classList.add("is-on"));
      lateCursor?.classList.add("is-on");
      return;
    }

    await sleep(450);
    for (const char of command) {
      typed.textContent += char;
      await sleep(70 + Math.random() * 50);
    }

    await sleep(280);
    for (const line of lines) {
      line.classList.add("is-on");
      await sleep(140);
    }
    lateCursor?.classList.add("is-on");
  }

  playTerminal();

  const copyBtn = document.getElementById("copy-install");
  const installCode = document.querySelector(".install__code code");
  if (copyBtn && installCode) {
    copyBtn.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(installCode.textContent.trim());
        const original = copyBtn.textContent;
        copyBtn.textContent = copyBtn.dataset.copied || "Copied";
        copyBtn.classList.add("is-copied");
        setTimeout(() => {
          copyBtn.textContent = original;
          copyBtn.classList.remove("is-copied");
        }, 1600);
      } catch {
        copyBtn.textContent = "Select & copy";
      }
    });
  }
})();

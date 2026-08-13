let Hooks = {}

Hooks.ScrollBottom = {
  mounted() {
    this.scrollToBottom()
    this.observer = new MutationObserver(() => this.scrollToBottom())
    this.observer.observe(this.el, { childList: true, subtree: true })
  },
  updated() {
    this.scrollToBottom()
  },
  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight
  },
  destroyed() {
    if (this.observer) this.observer.disconnect()
  }
}

Hooks.StreamingText = {
  mounted() {
    this.renderWords(this.el.dataset.text || "")
  },
  updated() {
    this.renderWords(this.el.dataset.text || "")
  },
  renderWords(text) {
    if (!text) {
      this.el.innerHTML = ""
      return
    }
    const words = text.split(/(\s+)/)
    const prevCount = this.el.querySelectorAll("span.word").length
    let html = ""
    let wordIndex = 0
    for (let i = 0; i < words.length; i++) {
      if (words[i].match(/^\s+$/)) {
        html += words[i]
      } else {
        const isNew = wordIndex >= prevCount
        const cls = isNew ? "word word-fade" : "word"
        html += `<span class="${cls}">${this.escapeHtml(words[i])}</span>`
        wordIndex++
      }
    }
    this.el.innerHTML = html
  },
  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}

Hooks.ThemeToggle = {
  mounted() {
    this.updateState()
    this.el.addEventListener("click", () => {
      const html = document.documentElement
      const next = html.getAttribute("data-theme") === "dark" ? "light" : "dark"
      html.setAttribute("data-theme", next)
      try { localStorage.setItem("nutria_theme", next) } catch (e) {}
      this.updateState()
    })
  },
  updateState() {
    const dark = document.documentElement.getAttribute("data-theme") === "dark"
    this.el.querySelectorAll(".settings-theme-state").forEach(function(state) {
      state.textContent = dark ? "Ativado" : "Desativado"
    })
  }
}

Hooks.ProfileDropdown = {
  mounted() {
    var btn = this.el.querySelector(".user-profile")
    if (btn) {
      btn.addEventListener("click", function(e) {
        var menu = document.getElementById("profile-dropdown-menu")
        if (menu) {
          menu.classList.toggle("open")
        }
      })
    }
  }
}

document.addEventListener("click", function(e) {
  var menu = document.getElementById("profile-dropdown-menu")
  if (!menu) return
  var wrapper = document.getElementById("profile-dropdown")
  if (!wrapper || !wrapper.contains(e.target)) {
    menu.classList.remove("open")
  }
})

document.addEventListener("keydown", function(e) {
  if (e.key === "Escape") {
    var menu = document.getElementById("profile-dropdown-menu")
    if (menu) menu.classList.remove("open")
  }
})

let csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
let liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

liveSocket.connect()

window.liveSocket = liveSocket

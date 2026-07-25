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

Hooks.ThemeToggle = {
  mounted() {
    this.el.addEventListener("click", () => {
      this.pushEvent("toggle_theme", {})
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

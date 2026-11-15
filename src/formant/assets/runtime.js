(function () {
  "use strict";

  const P = (window.formant = window.formant || {});
  const empty = {};

  function send(type, name, values) {
    if (typeof window.formant_event !== "function") {
      return;
    }
    try {
      window.formant_event({
        type: type || "",
        name: name || "",
        values: values || empty,
      });
    } catch (err) {
      /* a missing or stale binding must never break the page */
    }
  }

  function formOf(el) {
    if (!el) return null;
    return el.closest("form[data-fm-form]");
  }

  function hasCustomDecorations() {
    return document.documentElement.classList.contains("fm-custom-decorations");
  }

  function windowCall(action, arg) {
    const fn = window.formant_window;
    if (typeof fn !== "function") return Promise.resolve(null);
    try {
      return Promise.resolve(fn({ action: action, arg: arg == null ? 0 : arg }));
    } catch (err) {
      return Promise.resolve(null);
    }
  }

  function syncMaximized(state) {
    const maximized = state === true || state === "true";
    const button = document.querySelector('[data-fm-window="maximize"]');
    if (button) {
      button.classList.toggle("fm-maximized", maximized);
    }
    document.documentElement.classList.toggle("fm-window-maximized", maximized);
  }

  function syncTitlebarHeight() {
    const bar = document.querySelector(".fm-headerbar");
    if (bar) {
      windowCall("titlebar-height", Math.round(bar.getBoundingClientRect().height));
    }
  }

  P.syncWindowState = function () {
    if (!hasCustomDecorations()) return;
    windowCall("state").then(syncMaximized);
  };

  function collect(form) {
    const values = {};
    if (!form) return values;
    const fields = form.querySelectorAll(
      "input[name], textarea[name], select[name]",
    );
    for (let i = 0; i < fields.length; i++) {
      const el = fields[i];
      const name = el.name;
      if (!name) continue;
      if (el.type === "checkbox") {
        values[name] = !!el.checked;
      } else if (el.type === "radio") {
        if (el.checked) values[name] = el.value;
      } else if (el.type === "number" || el.type === "range") {
        values[name] = el.value === "" ? "" : Number(el.value);
      } else if (el.type === "file") {
        values[name] = el.files && el.files.length ? el.files[0].name : "";
      } else if (el.tagName === "SELECT" && el.multiple) {
        values[name] = Array.prototype.map.call(
          el.selectedOptions,
          function (o) {
            return o.value;
          },
        );
      } else {
        values[name] = el.value;
      }
    }
    return values;
  }

  function submit(form, action) {
    if (!form) return;
    if (!form.hasAttribute("data-fm-no-validate") && !form.checkValidity()) {
      form.reportValidity();
      return;
    }
    send(
      "submit",
      action || form.getAttribute("data-fm-name") || "",
      collect(form),
    );
  }

  function findByField(name) {
    return document.querySelector('[data-fm-field="' + cssEscape(name) + '"]');
  }

  function byName(name) {
    const list = document.querySelectorAll("[name]");
    const out = [];
    for (let i = 0; i < list.length; i++) {
      if (list[i].name === name) out.push(list[i]);
    }
    return out;
  }

  function cssEscape(value) {
    if (window.CSS && CSS.escape) return CSS.escape(value);
    return String(value).replace(/["\\]/g, "\\$&");
  }

  function clearError(name) {
    const field = findByField(name);
    if (!field) return;
    field.classList.remove("fm-invalid");
    const box = field.querySelector(".fm-error");
    if (box) box.textContent = "";
  }

  P.setValue = function (name, value) {
    const list = byName(name);
    for (let i = 0; i < list.length; i++) {
      const el = list[i];
      if (el.type === "checkbox") {
        el.checked = !!value;
      } else if (el.type === "radio") {
        el.checked = el.value === String(value);
      } else {
        el.value = value == null ? "" : String(value);
      }
      el.dispatchEvent(new Event("input", { bubbles: true }));
      el.dispatchEvent(new Event("change", { bubbles: true }));
    }
    clearError(name);
  };

  P.setChecked = function (name, value) {
    const list = byName(name);
    for (let i = 0; i < list.length; i++) {
      if (list[i].type === "checkbox" || list[i].type === "radio") {
        list[i].checked = !!value;
        list[i].dispatchEvent(new Event("change", { bubbles: true }));
      }
    }
  };

  P.setError = function (name, message) {
    const field = findByField(name);
    if (!field) return;
    field.classList.add("fm-invalid");
    const box = field.querySelector(".fm-error");
    if (box) box.textContent = message || "Check this field.";
  };

  P.clearError = clearError;

  P.clearErrors = function () {
    const fields = document.querySelectorAll(".fm-field.fm-invalid");
    for (let i = 0; i < fields.length; i++) {
      fields[i].classList.remove("fm-invalid");
      const box = fields[i].querySelector(".fm-error");
      if (box) box.textContent = "";
    }
  };

  P.toast = function (message, kind) {
    const host = document.querySelector(".fm-toasts");
    if (!host) return;
    const item = document.createElement("div");
    item.className = "fm-toast fm-toast-" + (kind || "info");
    item.textContent = message || "";
    host.appendChild(item);
    window.setTimeout(function () {
      item.style.opacity = "0";
      item.style.transform = "translateY(6px)";
      item.style.transition = "opacity 160ms ease, transform 160ms ease";
      window.setTimeout(function () {
        if (item.parentNode) item.parentNode.removeChild(item);
      }, 180);
    }, 3800);
  };

  P.openDialog = function (id) {
    const dlg = document.getElementById(id);
    if (!dlg) return;
    dlg.classList.add("fm-open");
    const focusable = dlg.querySelector("input,textarea,select,button");
    if (focusable) focusable.focus();
  };

  P.closeDialog = function (id) {
    if (id) {
      const dlg = document.getElementById(id);
      if (dlg) dlg.classList.remove("fm-open");
      return;
    }
    const open = document.querySelectorAll(".fm-dialog-backdrop.fm-open");
    for (let i = 0; i < open.length; i++) open[i].classList.remove("fm-open");
  };

  P.setBusy = function (busy) {
    const form = document.querySelector("form[data-fm-form]");
    if (!form) return;
    if (busy) form.classList.add("fm-busy");
    else form.classList.remove("fm-busy");
  };

  P.focus = function (name) {
    const list = byName(name);
    if (list.length) list[0].focus();
  };

  P.scrollTo = function (name) {
    const field = findByField(name);
    if (field) field.scrollIntoView({ behavior: "smooth", block: "center" });
  };

  P.setProgress = function (name, value) {
    const el = document.querySelector(
      'progress[name="' + cssEscape(name) + '"]',
    );
    if (el) el.value = Number(value);
  };

  P.setTitle = function (title) {
    document.title = title || document.title;
  };

  document.addEventListener("submit", function (event) {
    const form = formOf(event.target);
    if (!form) return;
    event.preventDefault();
    submit(form, "");
  });

  document.addEventListener("click", function (event) {
    const target = event.target;

    const windowControl = target.closest("[data-fm-window]");
    if (windowControl) {
      event.preventDefault();
      const action = windowControl.getAttribute("data-fm-window") || "";
      if (action === "minimize") {
        windowCall("minimize");
      } else if (action === "maximize") {
        windowCall("toggle-maximize").then(syncMaximized);
      } else if (action === "close") {
        windowCall("close");
      }
      return;
    }

    const dialogClose = target.closest("[data-fm-close]");
    if (dialogClose) {
      event.preventDefault();
      P.closeDialog(dialogClose.getAttribute("data-fm-close") || "");
      return;
    }

    const dialogOpen = target.closest("[data-fm-open]");
    if (dialogOpen) {
      event.preventDefault();
      P.openDialog(dialogOpen.getAttribute("data-fm-open") || "");
      return;
    }

    const tab = target.closest("[data-fm-tab]");
    if (tab) {
      event.preventDefault();
      const wrap = tab.closest(".fm-tabs");
      if (wrap) {
        const key = tab.getAttribute("data-fm-tab");
        const tabs = wrap.querySelectorAll("[data-fm-tab]");
        for (let i = 0; i < tabs.length; i++) {
          tabs[i].classList.toggle("fm-active", tabs[i] === tab);
        }
        const panels = wrap.querySelectorAll("[data-fm-panel]");
        for (let i = 0; i < panels.length; i++) {
          panels[i].classList.toggle(
            "fm-active",
            panels[i].getAttribute("data-fm-panel") === key,
          );
        }
      }
      return;
    }

    const menuTrigger = target.closest(".fm-menu-trigger");
    if (menuTrigger) {
      event.preventDefault();
      const menu = menuTrigger.closest(".fm-menu");
      if (menu) menu.classList.toggle("fm-open");
      return;
    }

    const action = target.closest("[data-fm-action]");
    if (action) {
      event.preventDefault();
      const form = formOf(action);
      const name = action.getAttribute("data-fm-action") || "";
      const values = collect(form);
      if (action.hasAttribute("data-fm-submit")) {
        submit(form, name);
      } else {
        send("click", name, values);
        if (form) send("change", name, values);
      }
      return;
    }

    if (target.classList && target.classList.contains("fm-dialog-backdrop")) {
      target.classList.remove("fm-open");
      return;
    }

    const openMenus = document.querySelectorAll(".fm-menu.fm-open");
    for (let i = 0; i < openMenus.length; i++) {
      if (!openMenus[i].contains(target))
        openMenus[i].classList.remove("fm-open");
    }
  });

  document.addEventListener("pointerdown", function (event) {
    if (!hasCustomDecorations() || event.button !== 0) return;

    const resize = event.target.closest("[data-fm-resize]");
    if (resize) {
      event.preventDefault();
      windowCall("resize", Number(resize.getAttribute("data-fm-resize") || "0"));
      return;
    }

    const bar = event.target.closest(".fm-headerbar");
    if (!bar) return;
    if (
      event.target.closest(
        "button, input, select, textarea, a, [data-fm-window], [data-fm-action], .fm-menu, .fm-menu-trigger",
      )
    ) {
      return;
    }

    event.preventDefault();
    if (event.detail >= 2) {
      windowCall("toggle-maximize").then(syncMaximized);
      return;
    }
    windowCall("move");
  });

  document.addEventListener("input", function (event) {
    const el = event.target;
    if (!el || !el.name) return;
    if (el.type === "range") {
      const min = Number(el.min || 0);
      const max = Number(el.max || 100);
      if (max > min) {
        const pct = Math.max(
          0,
          Math.min(100, ((Number(el.value) - min) / (max - min)) * 100),
        );
        el.style.setProperty("--fm-range-value", pct + "%");
      }
      const row = el.closest(".fm-range-row");
      if (row) {
        const out = row.querySelector("output");
        if (out) out.textContent = el.value;
      }
    }
    clearError(el.name);
  });

  document.addEventListener("keydown", function (event) {
    if (event.key === "Escape") {
      P.closeDialog("");
      const openMenus = document.querySelectorAll(".fm-menu.fm-open");
      for (let i = 0; i < openMenus.length; i++)
        openMenus[i].classList.remove("fm-open");
    }
  });

  let windowStateTimer = 0;
  window.addEventListener("resize", function () {
    if (!hasCustomDecorations()) return;
    syncTitlebarHeight();
    window.clearTimeout(windowStateTimer);
    windowStateTimer = window.setTimeout(function () {
      P.syncWindowState();
    }, 120);
  });

  if (hasCustomDecorations()) {
    syncTitlebarHeight();
    P.syncWindowState();
  }
})();

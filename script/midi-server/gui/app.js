// ─── Global Error Handler ──────────────────────────────
window.addEventListener("error", (e) => console.error("[JS Error]", e.error));
window.addEventListener("unhandledrejection", (e) => console.error("[Unhandled]", e.reason));

// ─── State ────────────────────────────────────────────
let config = null;
let editingPadId = null;
let editingGroupId = null;
let ws = null;
let reconnectTimer = null;
let hasUnsavedChanges = false;

// ─── WebSocket ────────────────────────────────────────
function connectWS() {
  const wsUrl = `ws://localhost:8765`;
  console.log("[WS] Connecting to", wsUrl);
  updateWsStatus("Connecting");

  try {
    ws = new WebSocket(wsUrl);
  } catch (e) {
    console.error("[WS] Error:", e);
    updateWsStatus("Error");
    scheduleReconnect();
    return;
  }

  ws.onopen = () => {
    console.log("[WS] Connected!");
    updateWsStatus("Online");
    clearTimeout(reconnectTimer);
    reconnectTimer = null;
  };

  ws.onclose = () => {
    console.log("[WS] Disconnected");
    updateWsStatus("Offline");
    scheduleReconnect();
  };

  ws.onerror = (e) => console.error("[WS] Error:", e);

  ws.onmessage = (event) => {
    try {
      const msg = JSON.parse(event.data);
      handleMessage(msg);
    } catch (e) {
      console.warn("[WS] Parse error:", event.data);
    }
  };
}

function updateWsStatus(status) {
  const el = document.getElementById("wsStatus");
  if (!el) return;
  el.textContent = status;
  el.className = status === "Online" ? "badge online" : "badge offline";
}

function scheduleReconnect() {
  if (reconnectTimer) return;
  reconnectTimer = setTimeout(() => {
    reconnectTimer = null;
    connectWS();
  }, 3000);
}

function send(data) {
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(data));
  }
}

function handleMessage(msg) {
  console.log("[MSG]", msg.type);
  switch (msg.type) {
    case "connected":
      if (msg.config) {
        config = msg.config;
        renderAll();
      }
      break;
    case "config":
      config = msg.config;
      renderAll();
      break;
    case "configSaved":
      // Server auto-saved config → clear unsaved badge
      hasUnsavedChanges = false;
      updateSaveBadge();
      break;
  }
}

function updateSaveBadge() {
  const badge = document.getElementById("saveBadge");
  if (!badge) return;
  if (hasUnsavedChanges) {
    badge.textContent = "● Unsaved";
    badge.className = "badge unsaved";
  } else {
    badge.textContent = "✓ Saved";
    badge.className = "badge saved";
  }
}

// ─── Render ────────────────────────────────────────────
function renderAll() {
  if (!config) return;
  renderGroups();
  renderChannels();
  renderPads();
  renderLayoutRadios();
}

function renderGroups() {
  const container = document.getElementById("layerList");
  if (!container) return;
  container.innerHTML = "";

  config.groups.forEach((g) => {
    const div = document.createElement("div");
    div.className = `layer-item ${g.id === config.activeGroupId ? "active" : ""}`;
    div.dataset.id = g.id;
    const chNames = g.channels.map((c) => c.name).join(", ");
    div.innerHTML = `<span>${g.name}</span><span class="channel-names">${chNames}</span>`;
    div.addEventListener("click", () => selectGroup(g.id));
    div.addEventListener("dblclick", () => openGroupModal(g.id));
    container.appendChild(div);
  });
}

function renderChannels() {
  const container = document.getElementById("channelList");
  if (!container) return;
  container.innerHTML = "";

  // Hiển thị channels của TẤT CẢ groups
  config.groups.forEach((group) => {
    const groupLabel = document.createElement("div");
    groupLabel.style.cssText = "font-size:11px;color:var(--primary);font-weight:600;letter-spacing:1px;margin-top:8px;margin-bottom:4px;";
    groupLabel.textContent = group.name.toUpperCase();
    container.appendChild(groupLabel);

    group.channels.forEach((ch) => {
      const div = document.createElement("div");
      div.className = "channel-item";
      div.innerHTML = `<label>${ch.name}</label><input type="text" value="${ch.name}" data-group="${group.id}" data-id="${ch.id}" />`;
      div.querySelector("input").addEventListener("change", (e) => {
        ch.name = e.target.value;
        hasUnsavedChanges = true;
        updateSaveBadge();
        renderGroups();
        sendConfigUpdate();
      });
      container.appendChild(div);
    });
  });
}

function renderPads() {
  const container = document.getElementById("padGrid");
  if (!container) return;
  container.className = `pad-grid ${config.padLayout}`;
  container.innerHTML = "";

  config.pads.forEach((pad) => {
    const div = document.createElement("div");
    div.className = `pad-item ${pad.imageUrl ? "has-image" : ""}`;
    div.dataset.id = pad.id;
    if (pad.color) div.style.borderColor = pad.color;

    div.innerHTML = `
      <span class="pad-index">${pad.id + 1}</span>
      ${pad.imageUrl ? `<img src="${pad.imageUrl}" alt="${pad.name}" />` : ""}
      <span class="pad-name">${pad.name}</span>
    `;
    div.addEventListener("click", () => openPadModal(pad.id));
    container.appendChild(div);
  });
}

function renderLayoutRadios() {
  document.querySelectorAll('input[name="padLayout"]').forEach((r) => {
    r.checked = r.value === config.padLayout;
  });
}

// ─── Group Actions ─────────────────────────────────────
function selectGroup(id) {
  config.activeGroupId = id;
  config.groups.forEach((g) => (g.isActive = g.id === id));
  hasUnsavedChanges = true;
  updateSaveBadge();
  renderGroups();
  renderChannels();
  sendConfigUpdate();
}

function openGroupModal(id) {
  editingGroupId = id;
  const g = config.groups.find((g) => g.id === id);
  if (!g) return;

  document.getElementById("layerNameInput").value = g.name;
  document.getElementById("btnDeleteLayer").classList.toggle("hidden", config.groups.length <= 1);
  document.getElementById("layerModalTitle").textContent = g.id < 0 ? "Add Group" : `Edit Group "${g.name}"`;
  document.getElementById("layerModal").classList.remove("hidden");
}

document.getElementById("btnAddLayer")?.addEventListener("click", () => {
  if (config.groups.length >= 5) {
    alert("Maximum 5 groups allowed");
    return;
  }
  const newId = Date.now(); // unique temp id
  editingGroupId = newId;
  document.getElementById("layerNameInput").value = "";
  document.getElementById("layerModalTitle").textContent = "Add Group";
  document.getElementById("btnDeleteLayer").classList.add("hidden");
  document.getElementById("layerModal").classList.remove("hidden");
});

document.getElementById("layerModalClose")?.addEventListener("click", closeGroupModal);
document.getElementById("layerModal")?.addEventListener("click", (e) => {
  if (e.target.id === "layerModal") closeGroupModal();
});

function closeGroupModal() {
  document.getElementById("layerModal")?.classList.add("hidden");
  editingGroupId = null;
}

document.getElementById("btnSaveLayer")?.addEventListener("click", () => {
  const name = document.getElementById("layerNameInput").value.trim();
  if (!name) return;

  const existing = config.groups.find((g) => g.id === editingGroupId);
  if (existing) {
    existing.name = name;
    hasUnsavedChanges = true;
    updateSaveBadge();
  } else {
    hasUnsavedChanges = true;
    updateSaveBadge();
    // Tinh channel base: group 0 = CH 1-3, group 1 = CH 4-6, group 2 = CH 7-9...
    const baseCh = editingGroupId * 3;
    config.groups.push({
      id: editingGroupId,
      name,
      channels: [
        { id: 0, name: `CH ${baseCh + 1}`, color: null },
        { id: 1, name: `CH ${baseCh + 2}`, color: null },
        { id: 2, name: `CH ${baseCh + 3}`, color: null },
      ],
      isActive: false,
    });
    config.activeGroupId = editingGroupId;
    config.groups.forEach((g) => (g.isActive = g.id === editingGroupId));
  }

  closeGroupModal();
  renderAll();
  sendConfigUpdate();
});

document.getElementById("btnDeleteLayer")?.addEventListener("click", () => {
  if (config.groups.length <= 1) return;
  const idx = config.groups.findIndex((g) => g.id === editingGroupId);
  if (idx < 0) return;

  config.groups.splice(idx, 1);
  hasUnsavedChanges = true;
  updateSaveBadge();
  if (config.activeGroupId === editingGroupId) {
    config.activeGroupId = config.groups[0].id;
    config.groups[0].isActive = true;
  }
  closeGroupModal();
  renderAll();
  sendConfigUpdate();
});

// ─── Pad Layout ───────────────────────────────────────
document.querySelectorAll('input[name="padLayout"]').forEach((r) => {
  r.addEventListener("change", (e) => {
    hasUnsavedChanges = true;
    updateSaveBadge();
    const newLayout = e.target.value;
    const layouts = { grid5x3: 15, grid5x4: 20, grid5x5: 25 };
    const newCount = layouts[newLayout];
    const oldCount = layouts[config.padLayout];
    config.padLayout = newLayout;

    if (newCount < oldCount) {
      config.pads = config.pads.slice(0, newCount).map((p, i) => ({ ...p, id: i }));
    } else {
      const extra = Array.from({ length: newCount - oldCount }, (_, i) => ({
        id: oldCount + i,
        name: `PAD ${oldCount + i + 1}`,
        imageUrl: null,
        color: null,
        type: "trigger",
      }));
      config.pads = [...config.pads, ...extra];
    }
    renderAll();
    sendConfigUpdate();
  });
});

// ─── Pad Modal ─────────────────────────────────────────
function openPadModal(id) {
  editingPadId = id;
  const pad = config.pads.find((p) => p.id === id);
  if (!pad) return;

  document.getElementById("padNameInput").value = pad.name;
  document.getElementById("padTypeSelect").value = pad.type || "trigger";
  document.getElementById("padColorInput").value = pad.color || "#00D4FF";
  document.getElementById("padLayerSelect").value = String(pad.layerId ?? 0);
  document.getElementById("modalTitle").textContent = `Edit Pad ${id + 1}`;

  const preview = document.getElementById("padImagePreview");
  const placeholder = document.getElementById("padImagePlaceholder");
  const removeBtn = document.getElementById("btnRemoveImage");

  if (pad.imageUrl) {
    preview.src = pad.imageUrl;
    preview.classList.remove("hidden");
    placeholder?.classList.add("hidden");
    removeBtn?.classList.remove("hidden");
  } else {
    preview.classList.add("hidden");
    placeholder?.classList.remove("hidden");
    removeBtn?.classList.add("hidden");
  }

  document.getElementById("padModal").classList.remove("hidden");
}

document.getElementById("padModalClose")?.addEventListener("click", closePadModal);
document.getElementById("padModal")?.addEventListener("click", (e) => {
  if (e.target.id === "padModal") closePadModal();
});

function closePadModal() {
  document.getElementById("padModal")?.classList.add("hidden");
  editingPadId = null;
}

// ─── Image Paste / Drag & Drop ─────────────────────────
const imageArea = document.getElementById("padImageArea");

imageArea?.addEventListener("dragover", (e) => {
  e.preventDefault();
  imageArea.classList.add("drag-over");
});
imageArea?.addEventListener("dragleave", () => imageArea.classList.remove("drag-over"));
imageArea?.addEventListener("drop", async (e) => {
  e.preventDefault();
  imageArea.classList.remove("drag-over");
  const file = e.dataTransfer?.files[0];
  if (file && file.type.startsWith("image/")) {
    await savePadImage(file);
  }
});

document.addEventListener("paste", async (e) => {
  if (document.getElementById("padModal")?.classList.contains("hidden")) return;
  const items = e.clipboardData?.items;
  if (!items) return;
  for (const item of items) {
    if (item.type.startsWith("image/")) {
      const blob = item.getAsFile();
      if (blob) await savePadImage(blob);
      break;
    }
  }
});

async function savePadImage(blob) {
  if (!blob || editingPadId === null) return;

  const resized = await resizeImage(blob, 256, 256);
  const reader = new FileReader();

  reader.onload = async () => {
    const base64 = reader.result.split(",")[1];
    const ext = blob.type.split("/")[1] || "png";
    const filename = `pad_${editingPadId}_${Date.now()}.${ext}`;

    try {
      const res = await fetch("/save-pad-image", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ filename, data: base64 }),
      });

      if (res.ok) {
        // Lưu URL tương đối — server sẽ convert thành full URL
        const preview = document.getElementById("padImagePreview");
        const placeholder = document.getElementById("padImagePlaceholder");
        const removeBtn = document.getElementById("btnRemoveImage");
        preview.src = `/pads/${filename}`;
        preview.classList.remove("hidden");
        placeholder?.classList.add("hidden");
        removeBtn?.classList.remove("hidden");

        const pad = config.pads.find((p) => p.id === editingPadId);
        if (pad) pad.imageUrl = `/pads/${filename}`;
        hasUnsavedChanges = true;
        updateSaveBadge();
      }
    } catch (e) {
      console.error("Upload error:", e);
    }
  };
  reader.readAsDataURL(resized);
}

async function resizeImage(blob, maxW, maxH) {
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = () => {
      const canvas = document.createElement("canvas");
      let w = img.width, h = img.height;
      if (w > maxW || h > maxH) {
        const r = Math.min(maxW / w, maxH / h);
        w = Math.round(w * r);
        h = Math.round(h * r);
      }
      canvas.width = w;
      canvas.height = h;
      canvas.getContext("2d").drawImage(img, 0, 0, w, h);
      canvas.toBlob(resolve, "image/png", 0.85);
    };
    img.src = URL.createObjectURL(blob);
  });
}

document.getElementById("btnRemoveImage")?.addEventListener("click", () => {
  const pad = config.pads.find((p) => p.id === editingPadId);
  if (pad) pad.imageUrl = null;
  document.getElementById("padImagePreview")?.classList.add("hidden");
  document.getElementById("padImagePlaceholder")?.classList.remove("hidden");
  document.getElementById("btnRemoveImage")?.classList.add("hidden");
});

document.getElementById("btnSavePad")?.addEventListener("click", () => {
  const pad = config.pads.find((p) => p.id === editingPadId);
  if (!pad) return;

  pad.name = document.getElementById("padNameInput")?.value.trim() || pad.name;
  pad.type = document.getElementById("padTypeSelect")?.value || "trigger";
  pad.layerId = parseInt(document.getElementById("padLayerSelect")?.value || "0");
  const color = document.getElementById("padColorInput")?.value;
  pad.color = color && color !== "#00D4FF" ? color : null;
  hasUnsavedChanges = true;
  updateSaveBadge();

  closePadModal();
  renderAll();
  sendConfigUpdate();
});

// ─── Save ─────────────────────────────────────────────
document.getElementById("btnSave")?.addEventListener("click", () => {
  hasUnsavedChanges = false;
  updateSaveBadge();
  sendConfigUpdate();
  const el = document.getElementById("saveStatus");
  if (el) {
    el.textContent = "Saved!";
    setTimeout(() => (el.textContent = ""), 2000);
  }
});

function sendConfigUpdate() {
  send({ type: "updateConfig", config });
}

// ─── Init ─────────────────────────────────────────────
window.addEventListener("load", () => connectWS());

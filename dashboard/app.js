/**
 * TacNet Command Dashboard — Frontend
 * Connects to server.py via WebSocket, renders live mesh state.
 */

// ── State ──
const state = {
    ws: null,
    tree: null,
    messages: [],
    peers: {},
    demoMode: false,
    connected: false,
    autoScroll: true,
    totalMessages: 0,
    totalBroadcasts: 0,
    totalCompactions: 0,
    latestSitrep: null,
    latestSitrepTime: null,
};

// ── Landing ──
function enterDashboard() {
    const landing = document.getElementById('landing');
    landing.classList.add('dismissed');
    // Remove from DOM after transition to free up video memory
    setTimeout(() => {
        const video = document.getElementById('landing-video');
        if (video) { video.pause(); video.src = ''; }
        landing.remove();
    }, 900);
}

// ── WebSocket ──
function connect() {
    const ws = new WebSocket(`ws://localhost:8081`);

    ws.onopen = () => {
        state.ws = ws;
        state.connected = true;
        updateConnectionStatus('connected');
        console.log('[WS] Connected');
    };

    ws.onclose = () => {
        state.ws = null;
        state.connected = false;
        updateConnectionStatus('disconnected');
        console.log('[WS] Disconnected — reconnecting in 2s');
        setTimeout(connect, 2000);
    };

    ws.onerror = () => {
        ws.close();
    };

    ws.onmessage = (event) => {
        const data = JSON.parse(event.data);
        handleEvent(data);
    };
}

// ── Event Router ──
function handleEvent(event) {
    switch (event.type) {
        case 'snapshot':
            state.tree = event.tree;
            state.messages = event.messages || [];
            state.peers = event.peers || {};
            state.demoMode = event.demo_mode || false;
            recountStats();
            renderAll();
            break;
        case 'message':
            state.messages.push(event.message);
            state.totalMessages++;
            if (event.message.type === 'BROADCAST') {
                state.totalBroadcasts++;
            } else if (event.message.type === 'COMPACTION') {
                state.totalCompactions++;
                state.latestSitrep = event.message.payload?.summary || null;
                state.latestSitrepTime = event.message.timestamp;
            }
            renderMessage(event.message);
            renderStats();
            renderSitrep();
            break;
        case 'tree_update':
            state.tree = event.tree;
            renderTree();
            renderNetworkInfo();
            break;
        case 'peers_update':
            state.peers = event.peers || {};
            renderNodes();
            renderStats();
            break;
        case 'demo_mode':
            state.demoMode = event.active;
            updateDemoButton();
            break;
    }
}

function recountStats() {
    state.totalMessages = state.messages.length;
    state.totalBroadcasts = state.messages.filter(m => m.type === 'BROADCAST').length;
    state.totalCompactions = state.messages.filter(m => m.type === 'COMPACTION').length;
    const lastComp = [...state.messages].reverse().find(m => m.type === 'COMPACTION');
    if (lastComp) {
        state.latestSitrep = lastComp.payload?.summary || null;
        state.latestSitrepTime = lastComp.timestamp;
    }
}

// ── Render Functions ──

function renderAll() {
    renderTree();
    renderNodes();
    renderFeed();
    renderStats();
    renderSitrep();
    renderNetworkInfo();
    updateDemoButton();
}

// ── Tree ──
function renderTree() {
    const container = document.getElementById('tree-view');
    if (!state.tree?.tree) {
        container.innerHTML = `
            <div class="empty-state">
                <div class="scan-ring"></div>
                <div class="empty-state-title">No network</div>
                <div class="empty-state-desc">Scanning for TacNet devices or enable demo mode</div>
            </div>`;
        return;
    }
    container.innerHTML = renderTreeNode(state.tree.tree, true);
}

function renderTreeNode(node, isRoot = false) {
    const isOnline = isNodeOnline(node);
    const dotClass = isRoot ? 'root' : (isOnline ? 'online' : 'offline');
    const claimedBy = node.claimed_by ? `claimed` : 'open';
    const children = (node.children || [])
        .map(child => renderTreeNode(child))
        .join('');

    return `
        <div class="tree-node">
            <div class="tree-node-row">
                <div class="tree-node-dot ${dotClass}"></div>
                <span class="tree-node-label">${esc(node.label)}</span>
                <span class="tree-node-meta">${claimedBy}</span>
            </div>
            ${children ? `<div class="tree-children">${children}</div>` : ''}
        </div>`;
}

function isNodeOnline(node) {
    if (!node.claimed_by) return false;
    const peer = state.peers[node.claimed_by];
    if (!peer) return false;
    return peer.connected !== false;
}

// ── Nodes ──
function renderNodes() {
    const container = document.getElementById('node-stats');
    const entries = Object.entries(state.peers);

    if (entries.length === 0) {
        container.innerHTML = `<div style="padding:8px;color:var(--text-dim);font-family:var(--mono);font-size:11px;">No nodes connected</div>`;
        return;
    }

    container.innerHTML = entries.map(([id, peer]) => {
        const dotColor = peer.connected ? 'background:var(--cyan)' : 'background:var(--text-dim)';
        const name = peer.role || peer.name || id.slice(0, 8);
        const lastSeen = peer.last_seen ? formatTime(peer.last_seen) : '—';
        return `
            <div class="node-stat-row">
                <div class="node-stat-left">
                    <div class="node-stat-dot" style="${dotColor}"></div>
                    <span class="node-stat-name">${esc(name)}</span>
                </div>
                <span class="node-stat-value">
                    <span class="msg-count">${peer.msg_count || 0}</span> msg · ${lastSeen}
                </span>
            </div>`;
    }).join('');
}

// ── Feed ──
function renderFeed() {
    const container = document.getElementById('feed');
    if (state.messages.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <div class="empty-state-title">Awaiting transmissions</div>
                <div class="empty-state-desc">Messages will appear here as they flow through the mesh</div>
            </div>`;
        return;
    }
    container.innerHTML = '';
    // Render last 200 messages
    const recent = state.messages.slice(-200);
    recent.forEach(msg => renderMessage(msg, false));
    scrollFeed();
}

function renderMessage(msg, animate = true) {
    const feed = document.getElementById('feed');

    // Remove empty state if present
    const empty = feed.querySelector('.empty-state');
    if (empty) empty.remove();

    const isBroadcast = msg.type === 'BROADCAST';
    const typeClass = isBroadcast ? 'broadcast' : 'compaction';
    const content = isBroadcast
        ? (msg.payload?.transcript || '—')
        : (msg.payload?.summary || '—');
    const role = msg.sender_role || '?';
    const time = formatTime(msg.timestamp);
    const badge = isBroadcast ? 'voice' : 'sitrep';

    // Location line
    const loc = msg.payload?.location;
    let locLine = '';
    if (loc && !loc.is_fallback && loc.lat !== 0) {
        locLine = `<div class="msg-location">${loc.lat.toFixed(4)}, ${loc.lon.toFixed(4)} ±${loc.accuracy.toFixed(0)}m</div>`;
    }

    const el = document.createElement('div');
    el.className = `msg ${typeClass}`;
    if (!animate) el.style.animation = 'none';
    el.innerHTML = `
        <div class="msg-time">${time}</div>
        <div class="msg-body">
            <div class="msg-header">
                <span class="msg-role">${esc(role)}</span>
                <span class="msg-badge ${typeClass}">${badge}</span>
            </div>
            <div class="msg-content">${esc(content)}</div>
            ${locLine}
        </div>`;

    feed.appendChild(el);

    if (state.autoScroll) {
        scrollFeed();
    }
}

function scrollFeed() {
    const feed = document.getElementById('feed');
    requestAnimationFrame(() => {
        feed.scrollTop = feed.scrollHeight;
    });
}

// ── SITREP ──
function renderSitrep() {
    const content = document.getElementById('sitrep-content');
    const time = document.getElementById('sitrep-time');

    if (!state.latestSitrep) {
        content.className = 'sitrep-content empty';
        content.textContent = 'Awaiting first compaction...';
        time.textContent = '';
        return;
    }

    content.className = 'sitrep-content';
    content.textContent = state.latestSitrep;
    time.textContent = `Updated ${formatTime(state.latestSitrepTime)}`;
}

// ── Stats ──
function renderStats() {
    document.getElementById('stat-nodes').textContent = Object.keys(state.peers).length;
    document.getElementById('stat-messages').textContent = state.totalMessages;
    document.getElementById('stat-broadcasts').textContent = state.totalBroadcasts;
    document.getElementById('stat-compactions').textContent = state.totalCompactions;
}

// ── Network Info ──
function renderNetworkInfo() {
    const container = document.getElementById('network-info');
    if (!state.tree) {
        container.innerHTML = `
            <div class="info-row">
                <span class="info-label">Network</span>
                <span class="info-value">—</span>
            </div>`;
        return;
    }

    const name = state.tree.network_name || '—';
    const version = state.tree.version ?? '—';
    const id = state.tree.network_id ? state.tree.network_id.slice(0, 8) : '—';

    container.innerHTML = `
        <div class="info-row">
            <span class="info-label">Network</span>
            <span class="info-value">${esc(name)}</span>
        </div>
        <div class="info-row">
            <span class="info-label">ID</span>
            <span class="info-value">${esc(id)}…</span>
        </div>
        <div class="info-row">
            <span class="info-label">Version</span>
            <span class="info-value">v${version}</span>
        </div>
        <div class="info-row">
            <span class="info-label">Encryption</span>
            <span class="info-value">${state.tree.encrypted_session_key ? 'AES-GCM' : 'None'}</span>
        </div>`;
}

// ── Connection Status ──
function updateConnectionStatus(status) {
    const dot = document.getElementById('conn-dot');
    const label = document.getElementById('conn-label');

    if (status === 'connected') {
        dot.className = 'status-dot';
        label.textContent = 'Connected';
    } else {
        dot.className = 'status-dot offline';
        label.textContent = 'Reconnecting...';
    }
}

// ── Demo Button ──
function updateDemoButton() {
    const btn = document.getElementById('btn-demo');
    btn.className = state.demoMode ? 'btn-demo active' : 'btn-demo';
    btn.textContent = state.demoMode ? 'Demo: ON' : 'Demo Mode';
}

function toggleDemo() {
    if (state.ws && state.ws.readyState === WebSocket.OPEN) {
        state.ws.send(JSON.stringify({ action: 'toggle_demo' }));
    }
}

// ── Auto-scroll toggle ──
function initScrollLock() {
    const feed = document.getElementById('feed');
    feed.addEventListener('scroll', () => {
        const { scrollTop, scrollHeight, clientHeight } = feed;
        state.autoScroll = scrollHeight - scrollTop - clientHeight < 40;
    });
}

// ── Helpers ──
function formatTime(ts) {
    if (!ts) return '—';
    try {
        const d = new Date(ts);
        return d.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
    } catch {
        return '—';
    }
}

function esc(str) {
    if (!str) return '';
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
}

// ── Boot ──
document.addEventListener('DOMContentLoaded', () => {
    initScrollLock();
    renderAll();
    connect();
});

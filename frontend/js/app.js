// ============================================================
//  app.js — 开发环境仪表盘前端逻辑
// ============================================================

const API_BASE = window.location.origin;

// ---- 状态检测 ----
async function checkStatus() {
    const cards = {
        git:    { el: document.getElementById('card-git'),    cmd: 'git --version' },
        conda:  { el: document.getElementById('card-conda'),  cmd: 'conda --version' },
        node:   { el: document.getElementById('card-node'),   cmd: 'node --version' },
        claude: { el: document.getElementById('card-claude'), cmd: 'claude --version' },
    };

    for (const [key, info] of Object.entries(cards)) {
        const statusEl = info.el.querySelector('.card-status');
        try {
            const res = await fetch(`${API_BASE}/api/status`);
            const data = await res.json();
            // 从配置文件和本地存储获取安装状态
            const installed = checkLocalInstalled(key);
            if (installed) {
                statusEl.textContent = installed;
                statusEl.className = 'card-status installed';
            } else {
                statusEl.textContent = '未检测到';
                statusEl.className = 'card-status missing';
            }
        } catch {
            statusEl.textContent = '未知';
            statusEl.className = 'card-status loading';
        }
    }
}

function checkLocalInstalled(tool) {
    // 读取缓存的配置信息
    const cache = getCachedConfig();
    switch (tool) {
        case 'git':    return cache.hasGit    ? '已安装' : null;
        case 'conda':  return cache.hasConda  ? '已安装' : null;
        case 'node':   return cache.hasNode   ? '已安装' : null;
        case 'claude': return cache.hasClaude ? '已安装' : null;
    }
    return null;
}

// ---- 加载配置 ----
async function loadConfig() {
    try {
        const res = await fetch(`${API_BASE}/api/config`);
        const config = await res.json();
        if (config && Object.keys(config).length > 0) {
            cacheConfig(config);
            renderConfig(config);
        } else {
            renderPlaceholder();
        }
    } catch {
        renderPlaceholder();
    }
}

function cacheConfig(config) {
    sessionStorage.setItem('dev_setup_config', JSON.stringify(config));
}

function getCachedConfig() {
    try {
        return JSON.parse(sessionStorage.getItem('dev_setup_config') || '{}');
    } catch { return {}; }
}

function renderConfig(config) {
    document.getElementById('api-url').value   = config.apiBaseUrl   || '未配置';
    document.getElementById('api-model').value = config.apiModel     || '未配置';
    document.getElementById('proxy-url').value = config.proxyUrl     || '未配置代理';

    // API Key 不展示原文
    const keyInput = document.getElementById('api-key');
    if (config.apiBaseUrl) {
        keyInput.value = '**** (已配置)';
    } else {
        keyInput.value = '未配置';
    }
}

function renderPlaceholder() {
    document.getElementById('api-url').value   = '未配置 (请运行安装脚本)';
    document.getElementById('api-model').value = '未配置';
    document.getElementById('proxy-url').value = '未配置代理';
    document.getElementById('api-key').value   = '未配置';
}

// ---- API 连通性测试 ----
async function testApiConnection() {
    const resultEl = document.getElementById('api-test-result');
    resultEl.textContent = '测试中...';
    resultEl.className = '';

    const config = getCachedConfig();
    if (!config.apiBaseUrl) {
        resultEl.textContent = '未配置后端 URL';
        resultEl.className = 'error';
        return;
    }

    try {
        const start = Date.now();
        const res = await fetch(`${config.apiBaseUrl}/v1/models`, {
            method: 'GET',
            headers: { 'Authorization': `Bearer ${sessionStorage.getItem('api_key') || ''}` }
        });
        const elapsed = Date.now() - start;
        if (res.ok) {
            resultEl.textContent = `连接成功 (${elapsed}ms)`;
            resultEl.className = 'success';
        } else {
            resultEl.textContent = `HTTP ${res.status} (${elapsed}ms)`;
            resultEl.className = 'error';
        }
    } catch (e) {
        resultEl.textContent = `连接失败: ${e.message}`;
        resultEl.className = 'error';
    }
}

// ---- 快捷操作 ----
function openGitBash() {
    const paths = [
        'C:\\Program Files\\Git\\bin\\bash.exe',
        'C:\\Program Files (x86)\\Git\\bin\\bash.exe',
    ];
    for (const p of paths) {
        // 在浏览器中无法直接启动程序，提示用户
    }
    alert('请在开始菜单中搜索 "Git Bash" 打开终端');
}

function openConfig() {
    alert('配置文件位置:\n' +
          '  Git Bash 环境: ~/.bashrc\n' +
          '  安装配置: config\\config.local.json\n' +
          '  仪表盘: frontend\\index.html');
}

// ---- 初始化 ----
document.addEventListener('DOMContentLoaded', () => {
    loadConfig();
    checkStatus();
});

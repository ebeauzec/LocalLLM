/* 
(c) 2025-2026 Eugene Beauzec. All Rights Reserved.
LocalLLM Dashboard Portal - API Wrapper
*/

window.apiLoaded = true;

const OLLAMA_URL = '/ollama/api';
const WEBUI_API = '/api/v1';
const ADMIN_EMAIL = 'admin@localllm.local';
const ADMIN_PASSWORD = 'localllm-admin';

// Auto-authenticate with Open WebUI so /chat never shows a login screen
async function autoLogin() {
    // Check if we already have a valid token
    const existing = localStorage.getItem('token');
    if (existing) {
        try {
            const resp = await fetch(`${WEBUI_API}/auths/`, {
                headers: { 'Authorization': `Bearer ${existing}` }
            });
            if (resp.ok) return existing;
        } catch (e) { /* token expired, re-login */ }
    }

    try {
        const resp = await fetch(`${WEBUI_API}/auths/signin`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email: ADMIN_EMAIL, password: ADMIN_PASSWORD })
        });
        if (resp.ok) {
            const data = await resp.json();
            localStorage.setItem('token', data.token);
            console.log('[LocalLLM] Auto-login successful');
            return data.token;
        }
    } catch (e) {
        console.warn('[LocalLLM] Auto-login failed:', e);
    }
    return null;
}

// Run auto-login immediately on load
autoLogin();

async function fetchWithTimeout(resource, options = {}) {
    const { timeout = 5000 } = options;
    const controller = new AbortController();
    const id = setTimeout(() => controller.abort(), timeout);
    const response = await fetch(resource, {
        ...options,
        signal: controller.signal
    });
    clearTimeout(id);
    return response;
}

async function getModels() {
    try {
        const response = await fetchWithTimeout(`${OLLAMA_URL}/tags`);
        if (!response.ok) throw new Error('Network response was not ok');
        const data = await response.json();
        return data.models || [];
    } catch (error) {
        console.error('Error fetching models:', error);
        return [];
    }
}

async function getStatus() {
    try {
        const response = await fetchWithTimeout(`${OLLAMA_URL}/tags`, { method: 'HEAD' });
        return response.ok;
    } catch (error) {
        return false;
    }
}

async function getKnowledgeSources() {
    // Mock for now, would typically ping a backend endpoint for RAG status
    return [
        { id: 1, name: 'Local Docs', status: 'active' },
        { id: 2, name: 'Codebase', status: 'indexing' }
    ];
}

window.initApiDashboard = async function() {
    
    const statModels = document.getElementById('statModels');
    const modelSelect = document.getElementById('defaultModelSelect');
    const statusIndicator = document.getElementById('statusIndicator');
    const LITELLM_KEY = 'sk-localllm-7f2b5d7966042cc842ff6949653e9db1';

    async function refreshUsageStats() {
        const statLocal = document.getElementById('statLocal');
        const statCloud = document.getElementById('statCloud');
        const statSpend = document.getElementById('statSpend');
        
        if (!statLocal) return;

        try {
            const resp = await fetchWithTimeout('/litellm/spend/logs', {
                headers: { 'Authorization': `Bearer ${LITELLM_KEY}` },
                timeout: 5000,
            });
            if (resp.ok) {
                const logs = await resp.json();
                let localCount = 0, cloudCount = 0, totalSpend = 0;
                
                for (const entry of logs) {
                    const model = (entry.model || '').toLowerCase();
                    const provider = (entry.custom_llm_provider || entry.model_group || '').toLowerCase();
                    const spend = parseFloat(entry.spend) || 0;
                    
                    if (provider.includes('ollama') || model.includes('ollama')) {
                        localCount++;
                    } else {
                        cloudCount++;
                        totalSpend += spend;
                    }
                }
                
                statLocal.textContent = localCount;
                statCloud.textContent = cloudCount;
                statSpend.textContent = totalSpend.toFixed(2);
                
                // Color the spend red if above $1
                statSpend.style.color = totalSpend > 1 ? '#ef4444' : '#f59e0b';
            }
        } catch (e) {
            console.warn('[LocalLLM] Usage stats unavailable:', e.message);
        }
    }

    async function refreshData() {
        const isOnline = await getStatus();
        
        if (isOnline) {
            statusIndicator.innerHTML = '<span class="dot green"></span> All Systems Operational';
            const models = await getModels();
            
            // Update stats
            statModels.textContent = models.length;

            // Populate dropdown if not already populated
            if (modelSelect.options.length <= 1) {
                modelSelect.innerHTML = '';
                if(models.length === 0) {
                     modelSelect.innerHTML = '<option value="">No models found</option>';
                } else {
                    models.forEach(model => {
                        const opt = document.createElement('option');
                        opt.value = model.name;
                        opt.textContent = model.name;
                        modelSelect.appendChild(opt);
                    });
                }
            }
        } else {
            statusIndicator.innerHTML = '<span class="dot" style="background:red"></span> System Offline';
            statModels.textContent = '0';
            modelSelect.innerHTML = '<option value="">Cannot connect to engine</option>';
        }

        // Mock RAM/CPU updates for realism
        document.getElementById('statRam').textContent = (Math.random() * (16 - 8) + 8).toFixed(1) + ' GB';
        
        // Refresh usage tracking
        await refreshUsageStats();
    }

    // Initial fetch
    await refreshData();

    // Auto-refresh every 30 seconds
    setInterval(refreshData, 30000);
};

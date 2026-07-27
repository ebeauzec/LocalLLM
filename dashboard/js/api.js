/* 
(c) 2025-2026 Eugene Beauzec. All Rights Reserved.
LocalLLM Dashboard Portal - API Wrapper
*/

window.apiLoaded = true;

const OLLAMA_URL = '/ollama/api'; // Assuming reverse proxy is set up

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
    }

    // Initial fetch
    await refreshData();

    // Auto-refresh every 30 seconds
    setInterval(refreshData, 30000);
};

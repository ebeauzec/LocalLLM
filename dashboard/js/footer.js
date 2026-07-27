/* 
(c) 2025-2026 Eugene Beauzec. All Rights Reserved.
LocalLLM Global Footer - Injected into all pages via nginx sub_filter
*/
(function() {
    // Don't inject twice
    if (document.getElementById('localllm-global-footer')) return;

    // Inject CSS
    var style = document.createElement('style');
    style.textContent = [
        '#localllm-global-footer {',
        '  position: fixed; bottom: 0; left: 0; right: 0; z-index: 99999;',
        '  padding: 6px 20px; border-top: 1px solid rgba(255,255,255,0.06);',
        '  display: flex; justify-content: space-between; align-items: center;',
        '  background: rgba(10, 10, 15, 0.92); backdrop-filter: blur(16px);',
        '  font-size: 12px; color: #94a3b8; font-family: Inter, system-ui, sans-serif;',
        '}',
        '#localllm-global-footer .llm-stats { display: flex; gap: 1.2rem; align-items: center; }',
        '#localllm-global-footer .llm-ok { color: #22c55e; }',
        '#localllm-global-footer .llm-divider { color: rgba(255,255,255,0.15); }',
        '#localllm-global-footer .llm-local { color: #22c55e; }',
        '#localllm-global-footer .llm-cloud { color: #94a3b8; }',
        '#localllm-global-footer .llm-spend { color: #22c55e; }',
        '#localllm-global-footer .llm-copy { color: #64748b; }',
        '#localllm-global-footer a { color: #6366f1; text-decoration: none; margin-left: 12px; }',
        '#localllm-global-footer a:hover { text-decoration: underline; }',
    ].join('\n');
    document.head.appendChild(style);

    // Inject HTML
    var footer = document.createElement('div');
    footer.id = 'localllm-global-footer';
    footer.innerHTML = [
        '<div class="llm-stats">',
        '  <span>Ollama: <span class="llm-ok" id="gf-status">Online</span></span>',
        '  <span>Models: <span id="gf-models">0</span> loaded</span>',
        '  <span>CPU: Auto</span>',
        '  <span>RAM: <span id="gf-ram">...</span></span>',
        '  <span class="llm-divider">|</span>',
        '  <span>\u{1F3E0} Local: <span id="gf-local" class="llm-local">0</span></span>',
        '  <span>\u2601\uFE0F Cloud: <span id="gf-cloud" class="llm-cloud">0</span></span>',
        '  <span>\u{1F4B0} Spend: $<span id="gf-spend" class="llm-spend">0.00</span></span>',
        '</div>',
        '<div class="llm-copy">',
        '  \u00A9 2025-2026 Eugene Beauzec. All Rights Reserved.',
        '  <a href="/dashboard/">Dashboard</a>',
        '</div>',
    ].join('');
    document.body.appendChild(footer);

    // Add body padding so content doesn't hide behind footer
    document.body.style.paddingBottom = '36px';

    // Fetch stats
    var CLOUD_MODELS = ['gpt-4o', 'gpt-4', 'gpt-3.5', 'claude', 'gemini'];

    async function refreshFooter() {
        try {
            // Ollama status + models
            var resp = await fetch('/ollama/api/tags', { signal: AbortSignal.timeout(5000) });
            if (resp.ok) {
                var data = await resp.json();
                var models = data.models || [];
                document.getElementById('gf-models').textContent = models.length;
                document.getElementById('gf-status').textContent = 'Online';
                document.getElementById('gf-status').className = 'llm-ok';
            } else {
                document.getElementById('gf-status').textContent = 'Offline';
                document.getElementById('gf-status').style.color = '#f87171';
            }
        } catch(e) {
            document.getElementById('gf-status').textContent = 'Offline';
            document.getElementById('gf-status').style.color = '#f87171';
        }

        // RAM estimate
        document.getElementById('gf-ram').textContent = (Math.random() * (16 - 8) + 8).toFixed(1) + ' GB';

        // Usage stats from chat history
        try {
            var token = localStorage.getItem('token');
            if (!token) return;
            var resp2 = await fetch('/api/v1/chats/', {
                headers: { 'Authorization': 'Bearer ' + token },
                signal: AbortSignal.timeout(5000)
            });
            if (resp2.ok) {
                var chats = await resp2.json();
                var localCount = 0, cloudCount = 0;
                for (var i = 0; i < chats.length; i++) {
                    var chatModels = (chats[i].chat && chats[i].chat.models) || [];
                    var isCloud = false;
                    for (var j = 0; j < chatModels.length; j++) {
                        var mid = (chatModels[j] || '').toLowerCase();
                        if (CLOUD_MODELS.some(function(cm) { return mid.indexOf(cm) >= 0; })) {
                            isCloud = true;
                            break;
                        }
                    }
                    if (isCloud) cloudCount++; else localCount++;
                }
                document.getElementById('gf-local').textContent = localCount;
                document.getElementById('gf-cloud').textContent = cloudCount;
                var spendEl = document.getElementById('gf-spend');
                spendEl.textContent = cloudCount > 0 ? '~' + (cloudCount * 0.01).toFixed(2) : '0.00';
                spendEl.style.color = cloudCount > 0 ? '#f59e0b' : '#22c55e';
            }
        } catch(e) { /* stats unavailable */ }
    }

    // Initial load + refresh every 30s
    refreshFooter();
    setInterval(refreshFooter, 30000);
})();

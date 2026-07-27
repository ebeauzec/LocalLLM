/* 
(c) 2025-2026 Eugene Beauzec. All Rights Reserved.
LocalLLM Dashboard Portal - Main App Logic
*/

document.addEventListener('DOMContentLoaded', () => {
    
    // Theme Toggle
    const themeToggleBtn = document.getElementById('themeToggle');
    const htmlEl = document.documentElement;
    const savedTheme = localStorage.getItem('theme') || 'dark';
    htmlEl.setAttribute('data-theme', savedTheme);

    themeToggleBtn.addEventListener('click', () => {
        const currentTheme = htmlEl.getAttribute('data-theme');
        const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
        htmlEl.setAttribute('data-theme', newTheme);
        localStorage.setItem('theme', newTheme);
    });

    // Search Personas
    const personaSearch = document.getElementById('personaSearch');
    const cards = document.querySelectorAll('.persona-card');
    const categories = document.querySelectorAll('.category');

    personaSearch.addEventListener('input', (e) => {
        const term = e.target.value.toLowerCase();
        
        categories.forEach(cat => {
            const catCards = cat.querySelectorAll('.persona-card');
            let hasVisible = false;
            
            catCards.forEach(card => {
                const name = card.getAttribute('data-name').toLowerCase();
                const desc = card.getAttribute('data-desc').toLowerCase();
                if (name.includes(term) || desc.includes(term)) {
                    card.style.display = 'flex';
                    hasVisible = true;
                } else {
                    card.style.display = 'none';
                }
            });
            
            cat.style.display = hasVisible ? 'block' : 'none';
        });
    });

    // Category Collapsing
    const categoryTitles = document.querySelectorAll('.category-title');
    categoryTitles.forEach(title => {
        title.addEventListener('click', () => {
            const targetId = title.getAttribute('data-target');
            const targetGrid = document.getElementById(targetId);
            targetGrid.classList.toggle('collapsed');
            title.classList.toggle('collapsed');
        });
    });

    // Card Click -> Ensure auth then navigate to Open WebUI chat
    cards.forEach(card => {
        card.addEventListener('click', async () => {
            // Ensure we're authenticated before navigating
            if (typeof autoLogin === 'function') {
                await autoLogin();
            }
            window.location.href = '/chat';
        });
    });

    // Helper: navigate to chat with auth
    async function goToChat() {
        if (typeof autoLogin === 'function') await autoLogin();
        window.location.href = '/chat';
    }

    // New Chat & Upload Doc buttons
    document.getElementById('btnNewChat').addEventListener('click', goToChat);
    document.getElementById('btnUploadDoc').addEventListener('click', goToChat);

    // Quick Prompts Modal
    const modal = document.getElementById('promptsModal');
    const btnQuickPrompts = document.getElementById('btnQuickPrompts');
    const closePromptsBtn = document.getElementById('closePromptsBtn');
    const promptSearch = document.getElementById('promptSearch');
    const promptItems = document.querySelectorAll('.prompt-item');

    function openModal() { modal.classList.add('active'); promptSearch.focus(); }
    function closeModal() { modal.classList.remove('active'); }

    btnQuickPrompts.addEventListener('click', openModal);
    closePromptsBtn.addEventListener('click', closeModal);
    modal.addEventListener('click', (e) => { if (e.target === modal) closeModal(); });

    promptSearch.addEventListener('input', (e) => {
        const term = e.target.value.toLowerCase();
        promptItems.forEach(item => {
            const text = item.textContent.toLowerCase();
            item.style.display = text.includes(term) ? 'flex' : 'none';
        });
        
        // Hide empty categories
        document.querySelectorAll('.prompt-category').forEach(cat => {
            const visibleItems = Array.from(cat.querySelectorAll('.prompt-item')).filter(i => i.style.display !== 'none');
            cat.style.display = visibleItems.length ? 'block' : 'none';
        });
    });

    // Copy to clipboard logic
    const toast = document.getElementById('toast');
    function showToast() {
        toast.classList.add('show');
        setTimeout(() => toast.classList.remove('show'), 2000);
    }

    promptItems.forEach(item => {
        item.addEventListener('click', () => {
            const textToCopy = item.getAttribute('data-prompt');
            navigator.clipboard.writeText(textToCopy).then(() => {
                closeModal();
                showToast();
            });
        });
    });

    // Settings Panel
    const settingsPanel = document.getElementById('settingsPanel');
    const settingsBtn = document.getElementById('settingsBtn');
    const btnModelManager = document.getElementById('btnModelManager');
    const closeSettingsBtn = document.getElementById('closeSettingsBtn');

    function openSettings() { settingsPanel.classList.add('active'); }
    function closeSettings() { settingsPanel.classList.remove('active'); }

    settingsBtn.addEventListener('click', openSettings);
    btnModelManager.addEventListener('click', openSettings);
    closeSettingsBtn.addEventListener('click', closeSettings);

    // Initial load APIs (from api.js if available)
    if (typeof window.apiLoaded !== 'undefined') {
        window.initApiDashboard();
    }
});

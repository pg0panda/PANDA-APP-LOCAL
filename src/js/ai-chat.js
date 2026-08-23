document.addEventListener('DOMContentLoaded', () => {
    const openBtn = document.getElementById('ai-open-btn');
    const chatBox = document.getElementById('ai-chat-box');
    const sendBtn = document.getElementById('send-ai-btn');
    const input = document.getElementById('ai-input');
    const messages = document.getElementById('ai-messages');

    let stopBtn = document.getElementById('stop-ai-btn');
    if (!stopBtn) {
        stopBtn = document.createElement('button');
        stopBtn.id = 'stop-ai-btn';
        stopBtn.innerHTML = '⏹';
        stopBtn.title = 'Stop';
        stopBtn.style.cssText = `
            display: none;
            background: #c0392b;
            color: #363636ff;
            border: none;
            border-radius: 8px;
            padding: 6px 10px;
            cursor: pointer;
            font-size: 20px;
            margin-left: 4px;
        `;
        if (sendBtn?.parentNode) {
            sendBtn.parentNode.insertBefore(stopBtn, sendBtn.nextSibling);
        }
    }

    let isGenerating = false;
    let stopRequested = false;

    let userScrolledUp = false;
    messages?.addEventListener('scroll', () => {
        const threshold = 40;
        const atBottom = messages.scrollHeight - messages.scrollTop - messages.clientHeight < threshold;
        userScrolledUp = !atBottom;
    });

    function autoScroll() {
        if (!userScrolledUp) {
            messages.scrollTop = messages.scrollHeight;
        }
    }

    if (chatBox) {
        chatBox.style.display = 'none';
    }

    openBtn?.addEventListener('click', () => {
        if (chatBox?.style.display === 'flex') {
            chatBox.style.display = 'none';
        } else {
            chatBox.style.display = 'flex';
        }
    });

    stopBtn?.addEventListener('click', () => {
        stopRequested = true;
        stopBtn.style.display = 'none';
        if (sendBtn) {
            sendBtn.style.display = '';
        }
    });

    function normalizeText(text = '') {
        return text
            .toLowerCase()
            .replace(/[\u{1F000}-\u{1FFFF}]/gu, '')
            .replace(/[^\p{L}\p{N}\s]/gu, '')
            .replace(/\s+/g, ' ')
            .trim();
    }

    function highlightTool(toolName) {
        const buttons = document.querySelectorAll('.download-btn');
        const search = normalizeText(toolName);
        let found = false;

        buttons.forEach(btn => {
            const btnText = normalizeText(btn.textContent);
            const matched = btnText.includes(search) ||
                search.includes(btnText) ||
                search.split(' ').some(word => btnText.includes(word));

            if (matched) {
                found = true;
                btn.classList.add('highlight-tool');
                btn.scrollIntoView({ behavior: 'smooth', block: 'center' });
                setTimeout(() => btn.classList.remove('highlight-tool'), 3000);
            }
        });

        console.log('[AI Highlight]', { search, found });
    }

    function handleAIActions(text) {
        text = text.replace(/\*\*/g, '');
        const actions = {};

        const openSectionRegex = /\[ACTION:OPEN_SECTION:\s*(.*?)\s*\]/i;
        const openMatch = text.match(openSectionRegex);
        if (openMatch) {
            actions.section = openMatch[1];
        }

        const highlightRegex = /\[ACTION:HIGHLIGHT:\s*(.*?)\s*\]/gi;
        const tools = [];
        let match;

        while ((match = highlightRegex.exec(text)) !== null) {
            tools.push(match[1]);
        }
        actions.tools = tools;

        const cleanText = text
            .replace(openSectionRegex, '')
            .replace(/\[ACTION:HIGHLIGHT:\s*(.*?)\s*\]/gi, '');

        return { cleanText, actions };
    }

    async function highlightToolsSequentially(tools) {
        for (const tool of tools) {
            highlightTool(tool);
            await new Promise(resolve => setTimeout(resolve, 3000));
        }
    }

    function escapeHtml(text) {
        return text
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;');
    }

    function formatAI(text) {
        text = escapeHtml(text);

        text = text.replace(/```([\s\S]*?)```/g, (_, code) => `
<pre class="ai-code"><code>${code}</code></pre>
`);

        text = text.replace(/`(.*?)`/g, '<code class="inline-code">$1</code>');
        text = text.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');
        text = text.replace(/^# (.*$)/gim, '<h1>$1</h1>');
        text = text.replace(/^## (.*$)/gim, '<h2>$1</h2>');
        text = text.replace(/^### (.*$)/gim, '<h3>$1</h3>');
        text = text.replace(/^- (.*$)/gim, '• $1');
        text = text.replace(/\n/g, '<br>');

        return text;
    }

    async function sendMessage() {
        if (isGenerating) return;

        const text = input?.value?.trim();
        if (!text) return;

        const userEl = document.createElement('div');
        userEl.className = 'user-msg';
        userEl.textContent = text;
        try {
            userEl.style.userSelect = 'text';
            userEl.style.webkitUserSelect = 'text';
            userEl.style.MozUserSelect = 'text';
            userEl.style.msUserSelect = 'text';
        } catch (e) {}
        messages.appendChild(userEl);
        if (input) input.value = '';
        userScrolledUp = false;
        autoScroll();

        const prevTyping = document.getElementById('typing-msg');
        if (prevTyping) prevTyping.remove();

        const typingEl = document.createElement('div');
        typingEl.className = 'ai-msg';
        typingEl.id = 'typing-msg';
        const base = document.createElement('span');
        base.textContent = 'Typing';
        typingEl.appendChild(base);
        const dots = document.createElement('span');
        dots.style.marginLeft = '6px';
        typingEl.appendChild(dots);
        messages.appendChild(typingEl);
        autoScroll();

        let dotsIdx = 0;
        const dotsInterval = setInterval(() => {
            try {
                dots.textContent = '.'.repeat((dotsIdx % 3) + 1);
                dotsIdx++;
            } catch (e) {}
        }, 400);

        function stopTypingPlaceholder() {
            clearInterval(dotsInterval);
            try { typingEl.remove(); } catch (e) {}
        }

        isGenerating = true;
        stopRequested = false;
        if (sendBtn) sendBtn.style.display = 'none';
        if (stopBtn) stopBtn.style.display = '';

        function finishGenerating() {
            isGenerating = false;
            stopRequested = false;
            if (sendBtn) sendBtn.style.display = '';
            if (stopBtn) stopBtn.style.display = 'none';
        }

        function addCopyButton() {
            try {
                const copyBtn = document.createElement('button');
                copyBtn.className = 'ai-copy-btn';
                copyBtn.type = 'button';
                copyBtn.title = 'Copy response';
                copyBtn.textContent = 'نسخ';
                copyBtn.onclick = async () => {
                    try {
                        await navigator.clipboard.writeText(fullAIText);
                        const orig = copyBtn.textContent;
                        copyBtn.textContent = 'تم النسخ!';
                        setTimeout(() => { copyBtn.textContent = orig; }, 1400);
                    } catch (e) {
                        try {
                            const range = document.createRange();
                            range.selectNodeContents(aiMsgEl);
                            const sel = window.getSelection();
                            sel.removeAllRanges();
                            sel.addRange(range);
                            document.execCommand('copy');
                            sel.removeAllRanges();
                            const orig = copyBtn.textContent;
                            copyBtn.textContent = 'تم النسخ!';
                            setTimeout(() => { copyBtn.textContent = orig; }, 1200);
                        } catch (_) {}
                    }
                };
                let actWrap = aiMsgEl.querySelector('.ai-actions');
                if (!actWrap) {
                    actWrap = document.createElement('div');
                    actWrap.className = 'ai-actions';
                    aiMsgEl.appendChild(document.createElement('br'));
                    aiMsgEl.appendChild(actWrap);
                }
                actWrap.appendChild(copyBtn);
            } catch (e) {
                console.warn('addCopyButton failed', e);
            }
        }

        const aiMsgEl = document.createElement('div');
        aiMsgEl.className = 'ai-msg';
        try {
            aiMsgEl.style.userSelect = 'text';
            aiMsgEl.style.webkitUserSelect = 'text';
            aiMsgEl.style.MozUserSelect = 'text';
            aiMsgEl.style.msUserSelect = 'text';
            aiMsgEl.style.pointerEvents = 'auto';
        } catch (e) {}

        let fullAIText = '';

        function appendTextChunk(chunk) {
            fullAIText += chunk;
            aiMsgEl.innerHTML = formatAI(fullAIText);
            autoScroll();
        }

        messages.appendChild(aiMsgEl);

        try {
            if (window.electronAPI && typeof window.electronAPI.askAIStream === 'function') {
                await window.electronAPI.askAIStream(
                    text,
                    (chunk) => {
                        try { appendTextChunk(String(chunk)); } catch (e) {}
                    },
                    (err) => {
                        stopTypingPlaceholder();
                        if (err) appendTextChunk('\n[خطأ في الاستقبال]');
                    }
                );
            } else {
                const result = await window.electronAPI.askAI(text);
                stopTypingPlaceholder();

                const full = (result && result.reply) ? String(result.reply) : '[لا يوجد رد]';
                const parsed = handleAIActions(full);
                const cleanedReply = parsed.cleanText;
                const actions = parsed.actions;

                const words = cleanedReply.split(' ');
                let index = 0;

                await new Promise((resolve) => {
                    const revealTimer = setInterval(() => {
                        if (stopRequested) {
                            clearInterval(revealTimer);
                            finishGenerating();
                            resolve();
                            return;
                        }

                        if (index >= words.length) {
                            clearInterval(revealTimer);

                            if (actions.section || (actions.tools && actions.tools.length)) {
                                const actionBtn = document.createElement('button');
                                actionBtn.className = 'ai-action-btn';
                                actionBtn.textContent = 'Go There';
                                actionBtn.onclick = () => {
                                    if (actions.section && typeof window.showSection === 'function') {
                                        window.showSection(actions.section);
                                    }

                                    if (actions.tools && actions.tools.length) {
                                        setTimeout(() => {
                                            highlightToolsSequentially(actions.tools);
                                        }, 300);
                                    }
                                };

                                aiMsgEl.appendChild(document.createElement('br'));
                                aiMsgEl.appendChild(actionBtn);
                            }

                            autoScroll();
                            finishGenerating();
                            resolve();
                            return;
                        }

                        appendTextChunk(words[index] + ' ');
                        index++;
                    }, 25);

                    try { addCopyButton(); } catch (e) { console.warn('copy attach failed', e); }
                });
            }
        } catch (e) {
            stopTypingPlaceholder();
            appendTextChunk('\n[فشل في جلب الرد]');
        } finally {
            stopTypingPlaceholder();
            try { addCopyButton(); } catch (e) {}
            finishGenerating();
        }
    }

    sendBtn?.addEventListener('click', sendMessage);

    input?.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            sendMessage();
        }

        if (e.key === 'Enter' && e.shiftKey) {
            e.preventDefault();
            const start = input.selectionStart;
            const end = input.selectionEnd;
            input.value = input.value.substring(0, start) + '\n' + input.value.substring(end);
            input.selectionStart = input.selectionEnd = start + 1;
        }
    });
});

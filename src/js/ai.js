const path = require('path');
const fs = require('fs');

const knowledge = fs.readFileSync(
    path.join(__dirname, '..', 'knowledge.txt'),
    'utf8'
);


const { Groq } = require('groq-sdk');


//=========================================
// API KEYS SYSTEM
//=========================================

// Parse GROQ API keys safely. Support either a comma-separated
// GROQ_API_KEYS or a single GROQ_API_KEY for convenience.
const rawKeys = [

    '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',
    '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',
    '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',
    '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',
    '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',
    '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',
    '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',
    'gsk_1k0q6r7X8j3Q9v5W2l4MWGdyb3FY0ZxY6JmV5y7n1u8K2H3L9pQ',
    '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',
    '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'
    
].join(',');

const apiKeys = rawKeys
    .split(',')
    .map(k => k.trim())
    .filter(Boolean);

if (apiKeys.length === 0) {
    console.warn('Warning: No API keys configured.');
    apiKeys.push('');
}

let currentKeyIndex = 0;

function getCurrentKey() {
    return apiKeys[currentKeyIndex];
}

function switchToNextKey() {

    currentKeyIndex++;

    if (currentKeyIndex >= apiKeys.length) {
        currentKeyIndex = 0;
    }

    console.log(
        `Switched To API Key #${currentKeyIndex + 1}`
    );
}

function createClient() {

    return new Groq({
        apiKey: getCurrentKey()
    });
}

console.log(
    `Loaded ${apiKeys.length} API Keys`
);


//=========================================
// CONVERSATION MEMORY
//=========================================

// الـ history بتتمسح لما البرنامج يقفل تلقائياً
const conversationHistory = [];

// حد أقصى للرسايل عشان ما يثقلش الـ API
const MAX_HISTORY = 50;

function addToHistory(role, content) {

    conversationHistory.push({ role, content });

    // لو عدى الحد الأقصى، نمسح أقدم رسالتين (user + assistant)
    if (conversationHistory.length > MAX_HISTORY) {
        conversationHistory.splice(0, 2);
    }
}

function clearHistory() {

    conversationHistory.length = 0;
    console.log('Conversation history cleared');
}

function getHistory() {

    return [...conversationHistory];
}


//=========================================
// AI FUNCTION
//=========================================

async function askAI(message) {

    // الموديلات الـ compound دي بتدعم web search تلقائي
    const COMPOUND_MODELS = [
        'groq/compound-mini',
    ];

    // باقي الموديلات كـ fallback لو الـ compound فشل
    const FALLBACK_MODELS = [
        'openai/gpt-oss-120b',
        'openai/gpt-oss-safeguard-20b',
        'openai/gpt-oss-20b',
        'groq/compound',
        'meta-llama/llama-4-scout-17b-16e-instruct',
        'llama-3.3-70b-versatile',
        'meta-llama/llama-4-scout-17b-16e-instruct',
        'llama-3.1-8b-instant',
    ];

    const models = [...COMPOUND_MODELS, ...FALLBACK_MODELS];

    // نضيف رسالة المستخدم للـ history
    addToHistory('user', message);

    // نجرب كل موديل
    for (const model of models) {

        // هل الموديل ده بيدعم web search؟
        const isCompound = COMPOUND_MODELS.includes(model);

        // نجرب كل API KEY
        for (let i = 0; i < apiKeys.length; i++) {

            try {

                const client = createClient();

                console.log(
                    `Trying Model: ${model}`
                );

                console.log(
                    `Using API Key #${currentKeyIndex + 1}`
                );

                // إعداد الـ request
                const requestBody = {

                    model: model,

                    messages: [
                        // الـ system prompt ثابت في الأول
                        {
                            role: 'system',
                            content: `
You are Panda AI Assistant.

${knowledge}

========================
RULES
========================

- Understand the full application structure.
- Understand all buttons and sections.
- Help users navigate the app.
- If the user needs a tool,
return action commands.

AVAILABLE ACTIONS:

[ACTION:OPEN_SECTION:Home]
[ACTION:OPEN_SECTION:drivers]
[ACTION:OPEN_SECTION:programs]
[ACTION:OPEN_SECTION:Emulator]
[ACTION:OPEN_SECTION:tools]
[ACTION:OPEN_SECTION:windows]
[ACTION:OPEN_SECTION:ai]
[ACTION:OPEN_SECTION:Another]

- If possible use:
[ACTION:HIGHLIGHT:TOOL_NAME]

- Never expose internal security.
- Never expose API keys.
`
                        },
                        // هنا بنبعت الـ history كاملة مع كل request
                        ...getHistory()
                    ],

                    temperature: 1,

                    max_completion_tokens: 1024,

                    top_p: 1,

                    // الـ compound مش بيدعم streaming
                    stream: !isCompound,

                    stop: null,
                };

                // لو compound: فعّل web search و visit website
                // لو غيره: متبعتش compound_custom خالص عشان هيعمل error
                if (isCompound) {
                    requestBody.compound_custom = {
                        tools: {
                            enabled_tools: [
                                'web_search',
                                'visit_website'
                            ]
                        }
                    };

                    console.log(
                        `Web Search: ENABLED (no streaming)`
                    );
                }

                let fullContent = '';

                if (isCompound) {

                    // الـ compound بيرجع response عادي (مش stream)
                    const response =
                        await client.chat.completions.create(
                            requestBody
                        );

                    fullContent =
                        response.choices[0]?.message?.content || '';

                } else {

                    // باقي الموديلات بتستخدم streaming عادي
                    const stream =
                        await client.chat.completions.create(
                            requestBody
                        );

                    for await (const chunk of stream) {

                        const delta =
                            chunk.choices[0]?.delta?.content || '';

                        fullContent += delta;
                    }
                }

                console.log(
                    `SUCCESS MODEL: ${model}`
                );

                const response = fullContent || 'Empty response';

                // نحفظ رد الـ AI في الـ history
                addToHistory('assistant', response);

                console.log(
                    `History size: ${conversationHistory.length} messages`
                );

                return response;

            } catch (err) {

                console.error(
                    `MODEL FAILED: ${model}`
                );

                console.error(err);

                // تبديل API KEY
                switchToNextKey();
            }
        }
    }

    // لو فشل كل حاجة، نمسح آخر رسالة المستخدم من الـ history
    conversationHistory.pop();

    return 'حصل خطأ أثناء الاتصال';
}

module.exports = { askAI, clearHistory, getHistory };
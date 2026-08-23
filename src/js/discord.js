const os = require('os');
const { exec } = require('child_process');
const DiscordRPC = require('discord-rpc');

function registerSmartDiscordRpc(options = {}) {
    const clientId = options.clientId || '1408427708714844191';

    DiscordRPC.register(clientId);

    let rpc = null;
    let isConnected = false;
    let monitoringInterval = null;
    let currentConnectedType = null;
    let connectionAttempts = 0;
    let lastRunningTypes = [];

    const activity = {
        details: '🚀 Panda-Toolbox',
        state: '🔥 All you need for your Windows',
        startTimestamp: Date.now(),
        largeImageKey: 'embedded_cover',
        largeImageText: 'PANDA',
        buttons: [
            { label: 'Join Discord🚪', url: 'https://discord.gg/jDnKNUawjM' },
            { label: 'Download APP⬇️', url: 'https://github.com/pg0panda/panda-app/releases/download/v5.3.3/Panda-Toolbox-Setup-5.3.3.exe' }
        ],
        instance: false,
    };

    const CONNECTION_PRIORITY = [
        'Discord Stable',
        'Discord PTB',
        'Discord Canary',
        'Discord Development',
        'Discord Web'
    ];

    function getAllRunningDiscordTypes() {
        return new Promise((resolve) => {
            const platform = os.platform();
            let runningTypes = [];

            if (platform === 'win32') {
                const commands = [
                    { cmd: 'tasklist /FI "IMAGENAME eq Discord.exe" /FO CSV | find "Discord.exe"', type: 'Discord Stable' },
                    { cmd: 'tasklist /FI "IMAGENAME eq DiscordPTB.exe" /FO CSV | find "DiscordPTB.exe"', type: 'Discord PTB' },
                    { cmd: 'tasklist /FI "IMAGENAME eq DiscordCanary.exe" /FO CSV | find "DiscordCanary.exe"', type: 'Discord Canary' },
                    { cmd: 'tasklist /FI "IMAGENAME eq DiscordDevelopment.exe" /FO CSV | find "DiscordDevelopment.exe"', type: 'Discord Development' }
                ];

                let completed = 0;

                const executeCommand = ({ cmd, type }) => {
                    exec(cmd, (error, stdout) => {
                        completed++;
                        if (!error && stdout.trim().length > 0) {
                            runningTypes.push(type);
                        }

                        if (completed === commands.length) {
                            checkDiscordWeb().then(hasWeb => {
                                if (hasWeb) runningTypes.push('Discord Web');
                                runningTypes.sort((a, b) => {
                                    const aIndex = CONNECTION_PRIORITY.indexOf(a);
                                    const bIndex = CONNECTION_PRIORITY.indexOf(b);
                                    return aIndex - bIndex;
                                });
                                resolve(runningTypes);
                            });
                        }
                    });
                };

                if (commands.length === 0) {
                    checkDiscordWeb().then(hasWeb => {
                        if (hasWeb) runningTypes.push('Discord Web');
                        resolve(runningTypes);
                    });
                } else {
                    commands.forEach(executeCommand);
                }
            } else {
                resolve(['Discord Client']);
            }
        });
    }

    function checkDiscordWeb() {
        return new Promise((resolve) => {
            if (os.platform() !== 'win32') {
                resolve(false);
                return;
            }

            const command = 'powershell "Get-Process | Where-Object {$_.MainWindowTitle -like \'*Discord*\'} | Select-Object ProcessName, MainWindowTitle"';

            exec(command, (error, stdout) => {
                if (error) {
                    resolve(false);
                } else {
                    const hasDiscordWindow = stdout.toLowerCase().includes('discord');
                    resolve(hasDiscordWindow);
                }
            });
        });
    }

    function connectToDiscordSmart(preferredTypes = null) {
        if (rpc) {
            try {
                rpc.destroy();
            } catch (err) {
                console.warn('Warning destroying old RPC:', err.message);
            }
            rpc = null;
        }

        console.log('🔗 Smart connecting to Discord RPC...');
        connectionAttempts++;

        rpc = new DiscordRPC.Client({ transport: 'ipc' });

        rpc.on('ready', async () => {
            console.log('✅ RPC Connected as', rpc.user.username);

            const runningTypes = await getAllRunningDiscordTypes();
            currentConnectedType = runningTypes[0] || 'Unknown';

            if (runningTypes.length > 1) {
                console.log('🔥 Multiple Discord instances running:');
                runningTypes.forEach((type, index) => {
                    const icon = index === 0 ? '📡' : '⏸️';
                    console.log(`   ${icon} ${type} ${index === 0 ? '(CONNECTED)' : '(STANDBY)'}`);
                });
                console.log('💡 RPC will auto-switch if active Discord closes');
            } else {
                console.log(`🎯 Connected to: ${currentConnectedType}`);
            }

            isConnected = true;
            connectionAttempts = 0;

            rpc.setActivity(activity)
                .then(() => {
                    console.log('✅ Activity set successfully - PANDA APP is now showing!');
                })
                .catch(err => {
                    console.error('❌ Error setting activity:', err.message);
                });
        });

        rpc.on('error', (err) => {
            console.error('❌ RPC Error:', err.message);
            isConnected = false;
            currentConnectedType = null;
        });

        rpc.on('disconnected', () => {
            console.log('⚠️ RPC Disconnected from Discord');
            isConnected = false;
            currentConnectedType = null;
        });

        rpc.login({ clientId }).catch(err => {
            console.warn('⚠️ Connection attempt failed:', err.message);
            isConnected = false;
            currentConnectedType = null;

            if (connectionAttempts < 5) {
                console.log('🔄 Will retry in next monitoring cycle...');
            }
        });
    }

    async function smartMonitorDiscord() {
        const runningTypes = await getAllRunningDiscordTypes();
        const hasAnyDiscord = runningTypes.length > 0;

        const typesChanged = JSON.stringify(runningTypes) !== JSON.stringify(lastRunningTypes);
        if (typesChanged) {
            lastRunningTypes = [...runningTypes];

            if (runningTypes.length > 1) {
                console.log(`🔄 Discord instances changed: ${runningTypes.join(', ')}`);
            }
        }

        if (hasAnyDiscord && !isConnected) {
            if (runningTypes.length > 1) {
                console.log(`🎯 Attempting smart connection to ${runningTypes.length} Discord instances...`);
            }
            connectToDiscordSmart(runningTypes);
        } else if (!hasAnyDiscord && isConnected) {
            console.log('⚠️ All Discord instances closed. Disconnecting RPC...');
            discordCleanup(false);
        } else if (hasAnyDiscord && isConnected) {
            if (currentConnectedType && !runningTypes.includes(currentConnectedType)) {
                console.log(`🔄 ${currentConnectedType} closed. Switching to ${runningTypes[0]}...`);
                connectToDiscordSmart(runningTypes);
            }

            if (runningTypes.length > 1 && typesChanged) {
                console.log('📊 Multiple Discord Status:');
                runningTypes.forEach((type, index) => {
                    const status = type === currentConnectedType ? '🟢 ACTIVE' : '🟡 STANDBY';
                    console.log(`   ${status} ${type}`);
                });
            }
        }
    }

    function startSmartMonitoring() {
        console.log('🧠 Starting Smart Discord Monitoring...');
        console.log('💡 Features:');
        console.log('🔄 Auto-switch between Discord types');
        console.log('📊 Multiple instance management');
        console.log('🎯 Priority-based connection');
        console.log('🔗 Seamless reconnection');
        console.log('🔍 Supported Discord types:');
        CONNECTION_PRIORITY.forEach((type, index) => {
            console.log(`${index + 1}. ${type} (Priority ${index + 1})`);
        });

        monitoringInterval = setInterval(smartMonitorDiscord, 30000);
    }

    function discordCleanup(exitProcess = true) {
        if (monitoringInterval) {
            clearInterval(monitoringInterval);
            monitoringInterval = null;
        }

        if (rpc) {
            try {
                if (rpc.transport && rpc.transport.socket) {
                    rpc.clearActivity().catch(() => {});
                }

                const destroyPromise = rpc.destroy();
                if (destroyPromise && typeof destroyPromise.catch === 'function') {
                    destroyPromise.catch(() => {});
                }
            } catch (err) {
                if (!err.message.includes('write')) {
                    console.warn('Warning during Discord cleanup:', err.message);
                }
            }
            rpc = null;
        }

        isConnected = false;
        currentConnectedType = null;

        if (exitProcess) {
            console.log('🧹 Cleaning up...');
            console.log('👋 PANDA APP Smart RPC stopped. Goodbye!');
            process.exit(0);
        }
    }

    process.on('SIGINT', () => discordCleanup(true));
    process.on('SIGTERM', () => discordCleanup(true));
    process.on('exit', () => discordCleanup(false));

    process.on('uncaughtException', (error) => {
        console.error('❌ Uncaught Exception:', error.message);
        discordCleanup(true);
    });

    process.on('unhandledRejection', (reason) => {
        console.error('❌ Unhandled Rejection:', reason);
    });

    console.log('🐼 PANDA APP Smart Discord RPC Started!');
    console.log('🚀 Advanced multi-Discord management');
    console.log('📱 Auto-switching between Discord types');
    console.log('⏹️  Press Ctrl+C to stop');
    console.log('─'.repeat(65));

    smartMonitorDiscord();
    startSmartMonitoring();

    return {
        discordCleanup,
        getAllRunningDiscordTypes,
        smartMonitorDiscord
    };
}

module.exports = { registerSmartDiscordRpc };

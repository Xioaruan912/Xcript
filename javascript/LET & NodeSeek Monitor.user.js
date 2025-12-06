// ==UserScript==
// @name         LET Monitor V40.0 (Add Crunchbits)
// @namespace    http://tampermonkey.net/
// @version      40.0
// @description  四巨头监控(FAT32/Kuroit/Tom/Crunchbits)。售卖链接前台跳，日常回复后台跳。黑五智能过滤。
// @author       Gemini
// @match        *://*/*
// @grant        GM_setValue
// @grant        GM_getValue
// @grant        GM_xmlhttpRequest
// @grant        GM_openInTab
// @grant        GM_addStyle
// @grant        GM_setClipboard
// @grant        GM_addValueChangeListener
// @connect      translate.googleapis.com
// @connect      lowendtalk.com
// @connect      www.nodeseek.com
// @connect      nodeseek.com
// ==/UserScript==

(function() {
    'use strict';

    // ==========================================
    //               配置区域
    // ==========================================

    const CHECK_INTERVAL = 5000;
    const AUTO_REFRESH = true;
    const ENABLE_SOUND = true;
    const POPUP_DISPLAY_TIME = 10000; // 默认停留 10s
    const LEAVE_DELAY = 3000;         // 鼠标移开后缓冲 3s

    // --- 监控目标配置 ---
    const TARGETS = [
        // 1. 黑五大促帖子
        {
            name: "🔥 黑五大促 (精选)",
            type: "thread",
            id: "212154",
            host: "lowendtalk.com",
            url: "https://lowendtalk.com/discussion/212154/2025-black-friday-cyber-monday-flash-sale-megathread-the-trade-war",
            detectLink: true,
            detectCode: true,
            filterRichContent: true, // 只推含链接/代码的回复
            forcePopup: true,        // 强制弹窗
            autoJump: true,          // 自动跳转
            prioritizeSalesLink: true // 优先跳购买链接
        },
        // 2. FAT32 监控
        {
            name: "👀 FAT32 监控",
            type: "let_user",
            id: "fat32_monitor",
            host: "lowendtalk.com",
            url: "https://lowendtalk.com/profile/comments/FAT32",
            detectLink: true,
            detectCode: true,
            forcePopup: true,
            autoJump: true,
            prioritizeSalesLink: true
        },
        // 3. Kuroit 监控
        {
            name: "🐧 Kuroit 监控",
            type: "let_user",
            id: "kuroit_monitor",
            host: "lowendtalk.com",
            url: "https://lowendtalk.com/profile/comments/kuroit",
            detectLink: true,
            detectCode: true,
            forcePopup: true,
            autoJump: true,
            prioritizeSalesLink: true
        },
        // 4. itsTomHarper 监控
        {
            name: "🎩 itsTomHarper 监控",
            type: "let_user",
            id: "tom_monitor",
            host: "lowendtalk.com",
            url: "https://lowendtalk.com/profile/comments/itsTomHarper",
            detectLink: true,
            detectCode: true,
            forcePopup: true,
            autoJump: true,
            prioritizeSalesLink: true
        },
        // 5. Crunchbits 监控 (【新增】)
        {
            name: "🍪 Crunchbits 监控",
            type: "let_user",
            id: "crunchbits_monitor",
            host: "lowendtalk.com",
            url: "https://lowendtalk.com/profile/comments/crunchbits",
            detectLink: true,
            detectCode: true,
            forcePopup: true,
            autoJump: true,
            prioritizeSalesLink: true
        }
    ];

    // ==========================================
    //              核心逻辑代码
    // ==========================================

    const KEY_LAST_CHECK_TIME = "gm_v40_last_check";
    const KEY_BROADCAST_MSG = "gm_v40_broadcast";
    const KEY_DATA_STORE = "gm_v40_store";

    // CSS 样式
    GM_addStyle(`
        #let-monitor-container {
            position: fixed; top: 20px; right: 20px;
            width: 460px; z-index: 2147483647;
            display: flex; flex-direction: column; gap: 15px;
            pointer-events: none;
        }
        .let-popup-card {
            background: rgba(26, 26, 26, 0.98);
            border-left: 5px solid #ffcc00;
            color: #e0e0e0;
            box-shadow: 0 10px 30px rgba(0,0,0,0.9);
            padding: 0; font-family: "Segoe UI", "Microsoft YaHei", sans-serif;
            border-radius: 6px; overflow: hidden;
            backdrop-filter: blur(5px); pointer-events: auto;
            opacity: 0; transform: translateX(50px);
            transition: opacity 0.3s, transform 0.3s;
            max-height: 85vh; display: flex; flex-direction: column;
            font-size: 13px;
        }
        .let-popup-card.alert-mode { border-left: 5px solid #ff3333 !important; box-shadow: 0 0 15px rgba(255, 51, 51, 0.3); }
        .let-popup-card.show { opacity: 1; transform: translateX(0); }
        .m-header { padding: 8px 12px; background: rgba(255,255,255,0.05); border-bottom: 1px solid #333; display: flex; justify-content: space-between; align-items: center; }
        .m-title { font-weight: bold; color: #fff; font-size: 13px; }
        .m-meta-group { display: flex; align-items: center; gap: 10px; }
        .m-meta { font-size: 11px; color: #888; }
        .let-close-btn { font-size: 18px; line-height: 1; color: #888; cursor: pointer; padding: 0 4px; transition: color 0.2s; }
        .let-close-btn:hover { color: #ff5555; }
        .m-body { padding: 12px; overflow-y: auto; display: flex; flex-direction: column; gap: 10px; flex: 1; }
        .m-author { font-size: 14px; font-weight: bold; color: #ffcc00; margin-bottom: 4px; display: flex; align-items: center; gap: 5px; }
        .m-content { line-height: 1.5; word-break: break-word; }
        .m-content code, .m-content pre { background: #333; color: #aaffaa; font-family: Consolas, monospace; padding: 2px 4px; border-radius: 3px; border: 1px solid #444; }
        .alert-mode .m-content code, .alert-mode .m-content pre { border-color: #ff5555; background: #2a1111; }
        .m-footer { padding: 8px 12px; background: rgba(0,0,0,0.3); border-top: 1px solid #333; display: flex; gap: 10px; flex-wrap: wrap; }
        .let-btn { background: #444; color: #fff; border: 1px solid #555; padding: 4px 10px; border-radius: 3px; cursor: pointer; font-size: 12px; transition: background 0.2s; flex: 1; text-align: center; }
        .let-btn:hover { background: #555; }
        .let-btn-primary { background: #005f99; border-color: #0077cc; }
        .let-btn-primary:hover { background: #0077cc; }
        .let-quote-box { background: #2a2a2a; border: 1px dashed #444; margin-bottom: 10px; padding: 5px; border-radius: 4px; font-size: 12px; color: #aaa; }
        .let-quote-box summary { cursor: pointer; color: #69b4ff; font-weight: bold; list-style: none; padding: 2px 5px; }
        .let-quote-box summary:hover { text-decoration: underline; }
        .let-quote-box summary::before { content: '» '; color: #888; }
        .let-quote-content { padding: 8px; border-top: 1px solid #333; margin-top: 5px; background: #222; }
        .m-content img { max-width: 100%; height: auto; border-radius: 3px; display: block; margin: 5px 0; border: 1px solid #444; }
        .m-content a { color: #5dade2; text-decoration: none; }
        .m-content a:hover { text-decoration: underline; }
        .let-popup-card ::-webkit-scrollbar { width: 5px; }
        .let-popup-card ::-webkit-scrollbar-thumb { background: #555; border-radius: 3px; }
    `);

    // --- UI ---
    let container = document.getElementById('let-monitor-container');
    if (!container) {
        container = document.createElement('div');
        container.id = 'let-monitor-container';
        document.body.appendChild(container);
    }

    function translateText(text, callback) {
        if (!text || text.length < 2 || /[\u4e00-\u9fa5]/.test(text)) { callback(text); return; }
        const cleanText = text.replace(/\n/g, ' ').slice(0, 1000);
        const apiUrl = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=zh-CN&dt=t&q=${encodeURIComponent(cleanText)}`;
        GM_xmlhttpRequest({
            method: "GET", url: apiUrl,
            onload: function(res) {
                try {
                    const data = JSON.parse(res.responseText);
                    let result = "";
                    if (data && data[0]) data[0].forEach(i => { if(i[0]) result += i[0]; });
                    callback(result || text);
                } catch(e) { callback(text); }
            },
            onerror: () => callback(text)
        });
    }

    function createPopup(data) {
        const currentHostname = window.location.hostname;
        const msgHost = data.host;
        const isSameSite = currentHostname.includes(msgHost);
        const isForcePopup = data.forcePopup;

        // === 同站/同页 跳转逻辑 ===
        if (isSameSite && data.autoJump) {
            const targetUrl = (data.salesLink && data.salesLink.length > 0) ? data.salesLink : data.jumpUrl;

            // 1. 售卖链接 -> 前台直接跳转 (New Tab)
            if (data.salesLink && data.salesLink.length > 0) {
                window.location.href = targetUrl;
                return;
            }

            // 2. 普通帖子更新 -> 检查是否当前页
            const currentBase = window.location.href.split('#')[0].split('?')[0];
            const targetBase = targetUrl.split('#')[0].split('?')[0];

            if (currentBase === targetBase) {
                console.log("🚀 [AutoJump] Same thread detected, refreshing to latest...");
                window.location.href = targetUrl; // 先改hash
                window.location.reload(); // 后刷新
                return;
            }
        }

        if (isSameSite && !isForcePopup) {
            if (AUTO_REFRESH) window.location.reload();
            return;
        }

        const card = document.createElement('div');
        card.className = 'let-popup-card';
        if (data.isAlert) card.classList.add('alert-mode');

        let footerHtml = '';
        const hasCodes = data.extractedCodes && data.extractedCodes.length > 0;
        const hasLinks = data.extractedLinks && data.extractedLinks.length > 0;

        if (hasCodes || hasLinks) {
            footerHtml = '<div class="m-footer">';
            if (hasCodes) footerHtml += `<div class="let-btn" id="btn-copy-code">📋 复制所有代码</div>`;
            if (hasLinks) {
                footerHtml += `<div class="let-btn" id="btn-copy-link">🔗 复制所有链接</div>`;
                footerHtml += `<div class="let-btn let-btn-primary" id="btn-visit-link">🚀 访问首个链接</div>`;
            }
            footerHtml += '</div>';
        }

        card.innerHTML = `
            <div class="m-header">
                <span class="m-title" style="${data.isAlert ? 'color:#ff5555;' : ''}">${data.title}</span>
                <div class="m-meta-group">
                    <span class="m-meta">${new Date(data.ts).toLocaleTimeString()}</span>
                    <span class="let-close-btn" title="关闭">×</span>
                </div>
            </div>
            <div class="m-body">
                <div class="m-author">
                     <span>${data.author}</span>
                     <span style="font-size:12px; color:#666; font-weight:normal;">:</span>
                </div>
                <div class="m-content">${data.htmlContent}</div>
            </div>
            ${footerHtml}
        `;
        container.prepend(card);

        if (ENABLE_SOUND) try { new AudioContext().createOscillator().start(); } catch(e){}
        requestAnimationFrame(() => card.classList.add('show'));

        let closeTimer;

        const closePopup = () => {
            card.classList.remove('show');
            setTimeout(() => card.remove(), 300);
            if (closeTimer) clearTimeout(closeTimer);
        };

        const startTimer = (delay) => {
            if (closeTimer) clearTimeout(closeTimer);
            closeTimer = setTimeout(closePopup, delay);
        };

        // 初始启动定时器
        startTimer(POPUP_DISPLAY_TIME);

        card.onclick = (e) => {
            if (e.target.closest('.m-footer') || e.target.classList.contains('let-close-btn') || window.getSelection().toString().length || e.target.tagName === 'SUMMARY' || e.target.closest('details')) return;
            const targetUrl = (data.salesLink && data.salesLink.length > 0) ? data.salesLink : data.jumpUrl;
            GM_openInTab(targetUrl, { active: true });
            closePopup();
        };

        card.querySelector('.let-close-btn').onclick = (e) => { e.stopPropagation(); closePopup(); };

        if (hasCodes) {
            card.querySelector('#btn-copy-code').onclick = (e) => {
                e.stopPropagation();
                GM_setClipboard(data.extractedCodes.join('\n\n'));
                e.target.innerText = "✅ 已复制";
                setTimeout(() => e.target.innerText = "📋 复制所有代码", 2000);
            };
        }
        if (hasLinks) {
            card.querySelector('#btn-copy-link').onclick = (e) => {
                e.stopPropagation();
                GM_setClipboard(data.extractedLinks.join('\n'));
                e.target.innerText = "✅ 已复制";
                setTimeout(() => e.target.innerText = "🔗 复制所有链接", 2000);
            };
            card.querySelector('#btn-visit-link').onclick = (e) => {
                e.stopPropagation();
                const targetUrl = (data.salesLink && data.salesLink.length > 0) ? data.salesLink : (data.extractedLinks[0] || data.jumpUrl);
                GM_openInTab(targetUrl, { active: true });
            };
        }

        // 鼠标悬停逻辑
        card.onmouseenter = () => {
            if (closeTimer) clearTimeout(closeTimer);
            card.style.opacity = "1";
            if (data.isAlert) card.style.borderLeft = "5px solid #ff8888";
            else card.style.borderLeft = "5px solid #fff";
        };
        card.onmouseleave = () => {
            if (data.isAlert) card.style.borderLeft = "5px solid #ff3333";
            else card.style.borderLeft = "5px solid #ffcc00";
            startTimer(LEAVE_DELAY);
        };
    }

    GM_addValueChangeListener(KEY_BROADCAST_MSG, (n,o,newVal) => {
        if(newVal && (!o || newVal.ts !== o.ts)) createPopup(newVal);
    });

    function tryCheck() {
        const now = Date.now();
        const last = GM_getValue(KEY_LAST_CHECK_TIME, 0);
        if (now - last < CHECK_INTERVAL) return;
        GM_setValue(KEY_LAST_CHECK_TIME, now);
        checkAll();
    }

    function checkAll() {
        TARGETS.forEach(target => {
            if (target.type === 'board') checkNodeSeekBoard(target);
            else if (target.type === 'let_user') checkLetUser(target);
            else checkLetThread(target);
        });
    }

    function resolveUrl(baseDomain, rawUrl) {
        if (!rawUrl) return "";
        if (rawUrl.startsWith('http')) return rawUrl;
        return baseDomain + rawUrl;
    }

    // === 核心解析：HTML结构化处理 + 强力过滤 ===
    function parseLetMessage(liElement) {
        const msgDiv = liElement.querySelector('.Message');
        if (!msgDiv) return { html: "", text: "", hasLink: false, hasCode: false, codes: [], links: [], salesLink: "" };

        const clone = msgDiv.cloneNode(true);
        let hasLink = false;
        let hasCode = false;
        let salesLink = "";
        const extractedCodes = [];
        const extractedLinks = [];

        // 售卖链接关键词正则
        const salesRegex = /cart\.php|aff\.php|billing|clientarea|order\.php|checkout|store|basket|buy/i;

        // 1. 链接提取 & 过滤
        clone.querySelectorAll('a').forEach(el => {
            // === 关键：引用块内的链接忽略 ===
            if (el.closest('.Quote') || el.closest('blockquote')) return;

            const rawHref = el.getAttribute('href');
            if (rawHref) {
                const fullUrl = resolveUrl("https://lowendtalk.com", rawHref);
                el.href = fullUrl;
                el.target = "_blank";

                if (fullUrl.includes('lowendtalk.com/profile/')) return;

                const cleanUrl = fullUrl.split('?')[0].toLowerCase();
                const isImageExt = /\.(jpg|jpeg|png|gif|webp|svg|bmp|tiff|ico)$/i.test(cleanUrl);
                const isImageHost = /imgur\.com|ibb\.co|imgbb\.com|postimg\.cc|gyazo\.com|prnt\.sc|catbox\.moe|giphy\.com|tenor\.com|cloudinary\.com|twimg\.com/i.test(cleanUrl);
                const isLetUpload = /\/uploads\/(editor|FileUpload)\//i.test(cleanUrl);

                if (!isImageExt && !isImageHost && !isLetUpload) {
                    hasLink = true;
                    extractedLinks.push(fullUrl);

                    // 检测售卖链接
                    if (!salesLink && salesRegex.test(fullUrl) && !fullUrl.includes("lowendtalk.com/discussion")) {
                        salesLink = fullUrl;
                    }
                }
            }
        });

        clone.querySelectorAll('img').forEach(el => {
            if (el.getAttribute('src')) {
                el.src = resolveUrl("https://lowendtalk.com", el.getAttribute('src'));
            }
        });

        // 2. 代码提取 & 过滤
        clone.querySelectorAll('code, pre').forEach(el => {
            // === 关键：引用块内的代码忽略 ===
            if (el.closest('.Quote') || el.closest('blockquote')) return;

            const rawText = el.innerText;
            extractedCodes.push(rawText);
            const cleanText = rawText.trim();
            const isShort = cleanText.length < 50;
            const isSingleLine = !cleanText.includes('\n');
            if (isShort && isSingleLine) hasCode = true;
        });

        const quotes = clone.querySelectorAll('.Quote, blockquote');
        quotes.forEach(quote => {
            const authorEl = quote.querySelector('.QuoteAuthor, .Author');
            let authorName = "Someone";
            if (authorEl) {
                authorName = authorEl.innerText.replace(' said:', '').trim();
                authorEl.remove();
            }
            const details = document.createElement('details');
            details.className = 'let-quote-box';
            const summary = document.createElement('summary');
            summary.innerText = `${authorName} said: show previous quotes`;
            const contentDiv = document.createElement('div');
            contentDiv.className = 'let-quote-content';
            contentDiv.innerHTML = quote.innerHTML;
            details.appendChild(summary);
            details.appendChild(contentDiv);
            quote.parentNode.replaceChild(details, quote);
        });

        let textToTranslate = "";
        clone.childNodes.forEach(node => {
            if (node.nodeType === Node.TEXT_NODE || (node.nodeType === Node.ELEMENT_NODE && !node.classList.contains('let-quote-box'))) {
                textToTranslate += node.textContent + " ";
            }
        });

        return {
            fullHtml: clone.innerHTML,
            plainText: textToTranslate.trim(),
            hasLink: hasLink,
            hasCode: hasCode,
            codes: extractedCodes,
            links: extractedLinks,
            salesLink: salesLink
        };
    }

    function checkNodeSeekBoard(target) {
        GM_xmlhttpRequest({
            method: "GET", url: target.url,
            onload: function(res) {
                if (res.status !== 200) return;
                const doc = new DOMParser().parseFromString(res.responseText, "text/html");
                const links = doc.querySelectorAll('a[href^="/post-"]');
                let maxId = 0, latestData = { url: "", title: "", author: "NodeSeeker" };
                links.forEach(link => {
                    const rawHref = link.getAttribute('href');
                    const match = rawHref.match(/\/post-(\d+)-/);
                    if (match) {
                        const id = parseInt(match[1]);
                        if (id > maxId) {
                            maxId = id;
                            latestData.url = resolveUrl("https://www.nodeseek.com", rawHref);
                            latestData.title = link.innerText.trim();
                            try {
                                const container = link.closest('div') || link.closest('li');
                                if (container) {
                                    const authorEl = container.querySelector('.username') || container.querySelector('.user-name');
                                    if (authorEl) latestData.author = authorEl.innerText.trim();
                                }
                            } catch(e) {}
                        }
                    }
                });
                if (maxId > 0) processUpdate(target, maxId, latestData, true);
            }
        });
    }

    function checkLetUser(target) {
        GM_xmlhttpRequest({
            method: "GET", url: target.url,
            onload: function(res) {
                if (res.status !== 200) return;
                const doc = new DOMParser().parseFromString(res.responseText, "text/html");
                const comments = doc.querySelectorAll('li[id^="Comment_"]');
                if (!comments.length) return;
                let maxId = 0, latestComm = null;
                comments.forEach(comm => {
                    const id = parseInt(comm.id.replace('Comment_', ''));
                    if (id > maxId) { maxId = id; latestComm = comm; }
                });

                if (latestComm) {
                    let realUrl = target.url;
                    const specificLink = latestComm.querySelector(`a[href*="#Comment_${maxId}"]`);
                    if (specificLink) realUrl = resolveUrl("https://lowendtalk.com", specificLink.getAttribute('href'));
                    else {
                        const titleLink = latestComm.querySelector('.Title a');
                        if (titleLink) realUrl = resolveUrl("https://lowendtalk.com", titleLink.getAttribute('href'));
                    }
                    latestComm.realUrl = realUrl;
                    processUpdate(target, maxId, latestComm, false);
                }
            }
        });
    }

    function checkLetThread(target) {
        GM_xmlhttpRequest({
            method: "GET", url: target.url,
            onload: function(res) {
                if (res.status !== 200) return;
                const doc = new DOMParser().parseFromString(res.responseText, "text/html");
                const pagers = doc.querySelectorAll('.Pager a, .p-pagination a');
                let lastUrl = target.url;
                if (pagers.length) {
                    const rawHref = pagers[pagers.length - 1].getAttribute('href');
                    lastUrl = resolveUrl("https://lowendtalk.com", rawHref);
                }
                GM_xmlhttpRequest({
                    method: "GET", url: lastUrl,
                    onload: function(pageRes) {
                        if (pageRes.status !== 200) return;
                        const pageDoc = new DOMParser().parseFromString(pageRes.responseText, "text/html");
                        const comments = pageDoc.querySelectorAll('li[id^="Comment_"]');
                        if (!comments.length) return;
                        const lastComm = comments[comments.length - 1];
                        const id = parseInt(lastComm.id.replace('Comment_', ''));
                        lastComm.tempUrl = lastUrl;
                        processUpdate(target, id, lastComm, false);
                    }
                });
            }
        });
    }

    function processUpdate(target, remoteId, dataObj, isBoardMode) {
        let store = JSON.parse(GM_getValue(KEY_DATA_STORE, "{}"));
        let localId = store[target.id] || 0;
        if (localId === 0) { store[target.id] = remoteId; GM_setValue(KEY_DATA_STORE, JSON.stringify(store)); return; }

        if (remoteId > localId) {
            store[target.id] = remoteId;
            GM_setValue(KEY_DATA_STORE, JSON.stringify(store));

            if (isBoardMode) {
                translateText(dataObj.title, (transTitle) => {
                    const broadcastData = {
                        ts: Date.now(),
                        title: target.name,
                        targetId: target.id,
                        host: target.host,
                        forcePopup: target.forcePopup,
                        author: dataObj.author,
                        htmlContent: `<div style="font-weight:bold; font-size:15px; margin-bottom:5px;">${dataObj.title}</div><div style="color:#aaa;">(中文: ${transTitle})</div>`,
                        jumpUrl: dataObj.url,
                        isAlert: false
                    };
                    GM_setValue(KEY_BROADCAST_MSG, broadcastData);
                });
            } else {
                const li = dataObj;
                let author = "User";
                try {
                    const authorEl = li.querySelector('.Author');
                    if (authorEl) author = authorEl.innerText;
                    else if (target.type === 'let_user') {
                        if (target.id.includes("fat32")) author = "FAT32";
                        else if (target.id.includes("kuroit")) author = "Kuroit";
                        else if (target.id.includes("tom")) author = "itsTomHarper";
                        else if (target.id.includes("crunchbits")) author = "Crunchbits";
                    }
                } catch(e){}

                let url = "";
                if (li.realUrl) url = li.realUrl;
                else url = li.tempUrl + "#Item_" + remoteId;

                const parsed = parseLetMessage(li);
                const foundLink = target.detectLink && parsed.hasLink;
                const foundCode = target.detectCode && parsed.hasCode;
                const hasRichContent = foundLink || foundCode;

                if (target.filterRichContent && !hasRichContent) return;

                // === 后台跳转逻辑 (非同站) ===
                if (target.autoJump && !window.location.hostname.includes(target.host)) {
                    if (target.prioritizeSalesLink && parsed.salesLink) {
                        GM_openInTab(parsed.salesLink, { active: true, insert: true });
                    } else {
                        GM_openInTab(url, { active: false, insert: true });
                    }
                }

                let isAlert = false;
                let displayTitle = target.name;

                if (hasRichContent) {
                    isAlert = true;
                    let alerts = [];
                    if(foundLink) alerts.push("链接");
                    if(foundCode) alerts.push("代码");
                    displayTitle = `🚨 发现[${alerts.join('+')}]: ${target.name}`;
                }

                translateText(parsed.plainText, (transText) => {
                    let finalHtml = parsed.fullHtml;
                    if (transText && transText !== parsed.plainText) {
                        finalHtml += `<div style="margin-top:12px; padding-top:8px; border-top:1px dashed #555; color:#00ff41;"><span style="background:#333; padding:2px 4px; border-radius:3px; font-size:10px; margin-right:5px;">AI 翻译</span>${transText}</div>`;
                    }

                    const broadcastData = {
                        ts: Date.now(),
                        title: displayTitle,
                        targetId: target.id,
                        host: target.host,
                        forcePopup: target.forcePopup,
                        author: author,
                        htmlContent: finalHtml,
                        jumpUrl: url,
                        salesLink: parsed.salesLink,
                        isAlert: isAlert,
                        extractedCodes: parsed.codes,
                        extractedLinks: parsed.links,
                        autoJump: target.autoJump
                    };
                    GM_setValue(KEY_BROADCAST_MSG, broadcastData);
                });
            }
        }
    }

    setInterval(tryCheck, 2000);
    console.log("V40.0 Add Crunchbits Started");

})();
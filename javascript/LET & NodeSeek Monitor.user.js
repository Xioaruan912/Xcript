// ==UserScript==
// @name         LET & NodeSeek Monitor V13.1 (URL Fix)
// @namespace    http://tampermonkey.net/
// @version      13.1
// @description  全网监控修复版。修复跨站运行时URL拼接错误的问题。图文并排展示。
// @author       Gemini
// @match        *://*/*
// @grant        GM_setValue
// @grant        GM_getValue
// @grant        GM_xmlhttpRequest
// @grant        GM_openInTab
// @grant        GM_addStyle
// @grant        GM_addValueChangeListener
// @connect      translate.googleapis.com
// @connect      lowendtalk.com
// @connect      www.nodeseek.com
// @connect      nodeseek.com
// ==/UserScript==

(function() {
    'use strict';

    // === 配置区域 ===
    const CHECK_INTERVAL = 8000;
    const AUTO_REFRESH = true;
    const ENABLE_SOUND = true;
    const POPUP_DISPLAY_TIME = 10000;
    const LEAVE_DELAY = 3000;
    const TYPING_SPEED = 5;

    // 监控目标
    const TARGETS = [
        {
            name: "🔥 黑五大促",
            type: "thread",
            id: "212154",
            url: "https://lowendtalk.com/discussion/212154/2025-black-friday-cyber-monday-flash-sale-megathread-the-trade-war"
        },
        {
            name: "💚 GreenCloud",
            type: "thread",
            id: "212077",
            url: "https://lowendtalk.com/discussion/212077/greencloud-bf-cm-2025-flash-sales-return-amd-genoa-nvme-utah-live-giveaways"
        },
        {
            name: "⚡️ NodeSeek",
            type: "board",
            id: "ns_home",
            url: "https://www.nodeseek.com/"
        }
    ];

    const KEY_LAST_CHECK_TIME = "gm_v13_last_check";
    const KEY_BROADCAST_MSG = "gm_v13_broadcast";
    const KEY_DATA_STORE = "gm_v13_store";

    // CSS
    GM_addStyle(`
        #let-monitor-container {
            position: fixed; top: 20px; right: 20px;
            width: 420px; z-index: 2147483647;
            display: flex; flex-direction: column; gap: 15px;
            pointer-events: none;
        }
        .let-popup-card {
            background: rgba(20, 20, 20, 0.95);
            border-left: 5px solid #ffcc00;
            color: #00ff41;
            box-shadow: 0 10px 30px rgba(0,0,0,0.9);
            padding: 0; font-family: "Microsoft YaHei", "Consolas", sans-serif;
            cursor: pointer; border-radius: 4px; overflow: hidden;
            backdrop-filter: blur(4px); pointer-events: auto;
            opacity: 0; transform: translateX(50px);
            transition: opacity 0.4s, transform 0.4s;
            max-height: 60vh; display: flex; flex-direction: column;
        }
        .let-popup-card.show { opacity: 1; transform: translateX(0); }
        .m-header {
            padding: 8px 15px; background: rgba(255,255,255,0.08);
            border-bottom: 1px solid #333; display: flex; justify-content: space-between; flex-shrink: 0;
        }
        .m-title { font-weight: bold; font-size: 14px; color: #fff; }
        .m-meta { font-size: 11px; color: #aaa; }
        .m-body {
            padding: 12px 15px; overflow-y: auto; flex: 1; display: flex; flex-direction: row; gap: 15px;
        }
        .m-content-col { flex: 1; display: flex; flex-direction: column; min-width: 0; }
        .m-image-col {
            flex: 0 0 100px; display: none; flex-direction: column; gap: 8px;
            border-left: 1px dashed #333; padding-left: 10px;
        }
        .m-author {
            font-size: 16px; font-weight: bold; color: #ffcc00;
            margin-bottom: 8px; padding-bottom: 5px; border-bottom: 1px dashed #444;
            text-shadow: 0 0 2px rgba(255, 204, 0, 0.5);
        }
        .m-text { font-size: 14px; line-height: 1.5; white-space: pre-wrap; word-break: break-word; }
        .m-text::after { content: '▋'; display: inline-block; vertical-align: bottom; animation: blink 1s infinite; }
        .m-img { width: 100%; height: auto; border-radius: 4px; border: 1px solid #444; object-fit: cover; display: block; }
        @keyframes blink { 0%, 100% { opacity: 1; } 50% { opacity: 0; } }
        .let-popup-card ::-webkit-scrollbar { width: 4px; }
        .let-popup-card ::-webkit-scrollbar-thumb { background: #444; }
    `);

    let container = document.getElementById('let-monitor-container');
    if (!container) {
        container = document.createElement('div');
        container.id = 'let-monitor-container';
        document.body.appendChild(container);
    }

    function translateText(text, callback) {
        if (!text || text.length < 2 || /[\u4e00-\u9fa5]/.test(text)) { callback(text); return; }
        const apiUrl = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=zh-CN&dt=t&q=${encodeURIComponent(text)}`;
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
        if (AUTO_REFRESH && window.location.href.includes(data.targetId)) {
            window.location.reload();
            return;
        }

        const card = document.createElement('div');
        card.className = 'let-popup-card';
        card.innerHTML = `
            <div class="m-header"><span class="m-title">${data.title}</span><span class="m-meta">${data.meta}</span></div>
            <div class="m-body">
                <div class="m-content-col">
                    <div class="m-author">${data.author} 说:</div>
                    <div class="m-text"></div>
                </div>
                <div class="m-image-col"></div>
            </div>
        `;
        container.prepend(card);

        const imgContainer = card.querySelector('.m-image-col');
        if (data.images && data.images.length > 0) {
            imgContainer.style.display = 'flex';
            data.images.forEach(src => {
                const img = document.createElement('img');
                img.src = src; img.className = 'm-img';
                img.onerror = function(){this.style.display='none'};
                imgContainer.appendChild(img);
            });
        }

        if (ENABLE_SOUND) try { new AudioContext().createOscillator().start(); } catch(e){}
        requestAnimationFrame(() => card.classList.add('show'));

        card.onclick = (e) => {
            if(window.getSelection().toString().length) return;
            GM_openInTab(data.jumpUrl, { active: true });
            closePopup();
        };

        const textEl = card.querySelector('.m-text');
        const bodyEl = card.querySelector('.m-body');
        const content = data.content;
        let charIndex = 0;

        const typingTimer = setInterval(() => {
            textEl.innerText += content.charAt(charIndex++);
            bodyEl.scrollTop = bodyEl.scrollHeight;
            if (charIndex >= content.length) clearInterval(typingTimer);
        }, TYPING_SPEED);

        let closeTimer;
        const closePopup = () => {
            card.classList.remove('show');
            setTimeout(() => card.remove(), 400);
            clearInterval(typingTimer);
        };
        const startTimer = (delay) => {
            if (closeTimer) clearTimeout(closeTimer);
            closeTimer = setTimeout(closePopup, delay);
        };
        startTimer(POPUP_DISPLAY_TIME);

        card.onmouseenter = () => {
            if (closeTimer) clearTimeout(closeTimer);
            card.style.borderLeft = "5px solid #fff";
        };
        card.onmouseleave = () => {
            card.style.borderLeft = "5px solid #ffcc00";
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
            else checkLetThread(target);
        });
    }

    // === URL 修复工具函数 ===
    function resolveUrl(baseDomain, rawUrl) {
        if (!rawUrl) return "";
        if (rawUrl.startsWith('http')) return rawUrl;
        return baseDomain + rawUrl;
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
                    // 使用 getAttribute 获取原始相对路径，避免浏览器自动根据当前域名解析
                    const rawHref = link.getAttribute('href');
                    const match = rawHref.match(/\/post-(\d+)-/);
                    if (match) {
                        const id = parseInt(match[1]);
                        if (id > maxId) {
                            maxId = id;
                            // 强制拼接 NodeSeek 域名，修复拼接错误
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

    function checkLetThread(target) {
        GM_xmlhttpRequest({
            method: "GET", url: target.url,
            onload: function(res) {
                if (res.status !== 200) return;
                const doc = new DOMParser().parseFromString(res.responseText, "text/html");
                const pagers = doc.querySelectorAll('.Pager a, .p-pagination a');
                let lastUrl = target.url;
                if (pagers.length) {
                    // 同样使用 getAttribute 修复 LET 翻页时的潜在解析错误
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
                broadcast(target, "New Thread", dataObj.author, dataObj.title, [], dataObj.url);
            } else {
                const li = dataObj;
                const author = li.querySelector('.Author').innerText;
                let content = li.querySelector('.Message').innerText.trim();
                let imgs = [];
                li.querySelectorAll('.Message img').forEach(img => imgs.push(img.src));
                const url = li.tempUrl + "#latest";
                broadcast(target, "New Reply", author, content, imgs, url);
            }
        }
    }

    function broadcast(target, metaInfo, author, content, imgs, url) {
        translateText(content, (finalText) => {
            GM_setValue(KEY_BROADCAST_MSG, {
                ts: Date.now(),
                title: target.name,
                targetId: target.id,
                meta: metaInfo,
                author: author,
                content: finalText,
                images: imgs,
                jumpUrl: url
            });
        });
    }

    setInterval(tryCheck, 2000);
    console.log("V13.1 URL Fix Started");

})();
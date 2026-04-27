// ==UserScript==
// @name         Messenger Cleaner V22.0 (Ultra-Safe Surgical)
// @namespace    http://tampermonkey.net/
// @version      22.0
// @description  Blokuoja Shorts/Reels/TikTok/FB nuotraukas ir Forwarded nuorodas. Naudoja ultra-saugų metodą, kad nedingtų langai.
// @author       Jules
// @match        https://www.messenger.com/*
// @match        https://www.facebook.com/messages/*
// @match        https://www.facebook.com/*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    console.log("Messenger Cleaner V22.0: Startuoja (Ultra-Safe Surgical)...");

    // --- 1. CSS ---
    const style = document.createElement('style');
    style.innerHTML = `
        [data-cleaner-hidden="true"] {
            display: none !important;
            visibility: hidden !important;
        }
        .cleaner-replaced-text {
            color: #888 !important;
            font-style: italic !important;
            font-size: 0.9em !important;
        }
    `;
    document.head.appendChild(style);

    // --- 2. KONFIGŪRACIJA ---

    const blockedPhrases = [
        "shared a reel", "pasidalijo ritiniu", "shared a video", "pasidalijo vaizdo įrašu",
        "shared a photo", "pasidalijo nuotrauka", "shared a link", "pasidalijo nuoroda",
        "forwarded a link", "forwarded a message", "persiuntė žinutę", "persiuntė nuorodą"
    ];

    const forwardedLabels = ["Forwarded", "Persiųsta", "Persiųsta žinutė", "Persiuntė"];

    const blockedDomains = [
        "tiktok.com", "instagram.com", "youtube.com/shorts", "youtu.be/shorts",
        "facebook.com/reel", "fb.watch", "facebook.com/share", "facebook.com/videos",
        "facebook.com/photo", "fbid=", "facebook.com/story", "facebook.com/posts",
        "facebook.com/permalink", "facebook.com/groups"
    ];

    // --- 3. PAGALBINĖS FUNKCIJOS ---

    function decodeFBUrl(url) {
        try {
            if (url.includes('l.facebook.com/l.php') || url.includes('lm.facebook.com/l.php')) {
                const urlObj = new URL(url);
                const actualUrl = urlObj.searchParams.get('u');
                return actualUrl ? decodeURIComponent(actualUrl) : url;
            }
        } catch (e) {}
        return url;
    }

    function isBadUrl(url) {
        if (!url) return false;
        const decodedUrl = decodeFBUrl(url);
        if (decodedUrl.includes('/messages/t/')) return false;
        if (decodedUrl.includes('/t/')) return false;
        if (decodedUrl === '#' || decodedUrl === '') return false;

        if (decodedUrl.includes('tiktok.com')) return true;
        if (decodedUrl.includes('instagram.com')) return true;
        if ((decodedUrl.includes('youtube.com') || decodedUrl.includes('youtu.be')) && decodedUrl.includes('/shorts/')) return true;
        if (decodedUrl.includes('fb.watch')) return true;

        if (decodedUrl.includes('facebook.com')) {
            try {
                const urlObj = new URL(decodedUrl);
                const path = urlObj.pathname;
                const badPaths = ['/reel/', '/share/', '/videos/', '/photo/', '/story.php', '/posts/', '/permalink.php', '/groups/'];
                if (badPaths.some(bp => path.includes(bp))) return true;
                if (decodedUrl.includes('fbid=')) return true;
            } catch(e) {}
        }
        return false;
    }

    function isInsideSidebar(node) {
        if (!node) return false;
        // Sidebar elementai paprastai turi specifines roles arba tėvus
        return !!(node.closest('[role="gridcell"]') ||
                  node.closest('[data-testid="mwthreadlist-item"]') ||
                  node.closest('[aria-label="Conversations"]') ||
                  node.closest('[aria-label="Pokalbiai"]') ||
                  node.closest('[aria-label="Chats"]') ||
                  node.closest('nav') ||
                  node.closest('[role="navigation"]') ||
                  node.closest('[role="tablist"]'));
    }

    function getSmallMessageContainer(node) {
        // Ieškome TIK labai specifinių žinučių burbulų
        let container = node.closest('[data-testid="message-container"]') ||
                        node.closest('[data-testid="msg_batch"]') ||
                        node.closest('[role="none"].x1n2onr6.x1iyjqo2');

        if (container) {
            // SAUGIKLIAI: niekada neslepiame didelių layout blokų ar elementų su ID
            if (container.id) return null;

            const role = container.getAttribute('role');
            if (role && role !== 'none' && role !== 'gridcell') return null;

            // Tikriname matmenis santykinai su langu
            const rect = container.getBoundingClientRect();
            if (rect.width > (window.innerWidth * 0.7)) return null;
            if (rect.height > (window.innerHeight * 0.7)) return null;
            if (rect.height > 600 || rect.width > 800) return null;

            // Žinutės burbulas neturi turėti per daug vaikų
            if (container.querySelectorAll('*').length > 50) return null;
        }

        return container;
    }

    function maskSidebarRow(node) {
        let row = node.closest('[role="gridcell"]') ||
                  node.closest('[data-testid="mwthreadlist-item"]') ||
                  node.closest('[role="row"]');
        if (!row) return;

        const spans = row.querySelectorAll('span');
        spans.forEach(s => {
            if (s.children.length === 0 && s.innerText.trim().length > 0) {
                const txt = s.innerText.toLowerCase();
                let shouldMask = false;
                for (let d of blockedDomains) { if (txt.includes(d)) { shouldMask = true; break; } }
                if (!shouldMask) {
                    for (let p of blockedPhrases) { if (txt.includes(p.toLowerCase())) { shouldMask = true; break; } }
                }
                if (!shouldMask) {
                    for (let l of forwardedLabels) { if (txt === l.toLowerCase()) { shouldMask = true; break; } }
                }

                if (shouldMask && s.innerText !== "unable receive message") {
                    s.innerText = "unable receive message";
                    s.classList.add('cleaner-replaced-text');
                }
            }
        });
    }

    function performSurgicalHide(node) {
        const container = getSmallMessageContainer(node);
        if (container) {
            container.setAttribute('data-cleaner-hidden', 'true');
            container.style.display = 'none';
        } else {
            // Jei neradome saugaus konteinerio, paslepiame TIK nuorodą
            if (node.tagName === 'A') {
                node.style.display = 'none';
                node.setAttribute('data-cleaner-hidden', 'true');
            }
        }
    }

    // --- 4. PAGRINDINĖ LOGIKA ---

    function cleanMess() {
        try {
            // A. NUORODOS
            const links = document.querySelectorAll('a:not([data-cleaner-processed])');
            links.forEach(link => {
                const href = link.getAttribute('href');
                if (isBadUrl(href)) {
                    if (isInsideSidebar(link)) {
                        maskSidebarRow(link);
                    } else {
                        performSurgicalHide(link);
                    }
                }
                link.setAttribute('data-cleaner-processed', 'true');
            });

            // B. "FORWARDED" ETIKETĖS
            const allSpans = document.querySelectorAll('span:not([data-cleaner-processed])');
            allSpans.forEach(span => {
                if (span.children.length > 0) return;
                const txt = span.innerText.trim();
                if (forwardedLabels.includes(txt)) {
                    if (isInsideSidebar(span)) {
                        maskSidebarRow(span);
                    } else {
                        performSurgicalHide(span);
                    }
                }
                span.setAttribute('data-cleaner-processed', 'true');
            });

            // C. SIDEBARO PERIODINIS VALYMAS
            const sidebarRows = document.querySelectorAll('[role="gridcell"], [data-testid="mwthreadlist-item"]');
            sidebarRows.forEach(row => {
                maskSidebarRow(row);
            });
        } catch (err) {}
    }

    // --- 5. STEBĖJIMAS ---

    let debounceTimer = null;
    const observer = new MutationObserver((mutations) => {
        if (debounceTimer) clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => {
            cleanMess();
        }, 200);
    });

    observer.observe(document.body, {
        childList: true,
        subtree: true
    });

    // Pradiniai paleidimai
    setTimeout(cleanMess, 500);
    setTimeout(cleanMess, 2000);

})();

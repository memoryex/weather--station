// ==UserScript==
// @name         Messenger Cleaner V23.0 (Ultra-Safe Surgical)
// @namespace    http://tampermonkey.net/
// @version      23.0
// @description  Blokuoja Shorts/Reels/TikTok/FB nuotraukas ir Forwarded nuorodas bei susijusias gretimas žinutes.
// @author       Jules
// @match        https://www.messenger.com/*
// @match        https://www.facebook.com/messages/*
// @match        https://www.facebook.com/*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    console.log("Messenger Cleaner V23.0: Startuoja (Ultra-Safe Surgical)...");

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
        "forwarded a link", "forwarded a message", "persiuntė žinutę", "persiuntė nuorodą",
        "youtube shorts", "yt shorts"
    ];

    const forwardedLabels = ["Forwarded", "Persiųsta", "Persiųsta žinutė", "Persiuntė"];

    const blockedDomains = [
        "tiktok.com", "instagram.com",
        "youtube.com/shorts", "youtu.be/shorts", "m.youtube.com/shorts", "youtube.com/hashtag/shorts",
        "facebook.com/reel", "facebook.com/reels", "fb.watch", "facebook.com/share", "facebook.com/videos",
        "facebook.com/photo", "fbid=", "facebook.com/story", "facebook.com/posts",
        "facebook.com/permalink", "facebook.com/groups"
    ];

    // --- 3. PAGALBINĖS FUNKCIJOS ---

    function decodeFBUrl(url) {
        try {
            if (!url) return '';
            if (url.includes('l.facebook.com/l.php') || url.includes('lm.facebook.com/l.php')) {
                const urlObj = new URL(url, window.location.href);
                const actualUrl = urlObj.searchParams.get('u');
                return actualUrl ? decodeURIComponent(actualUrl) : url;
            }
        } catch (e) {}
        return url || '';
    }

    function isBadUrl(url) {
        if (!url) return false;
        const decodedUrl = decodeFBUrl(url);
        if (decodedUrl.includes('/messages/t/') || decodedUrl.includes('/t/')) return false;
        if (decodedUrl === '#' || decodedUrl === '') return false;

        const lower = decodedUrl.toLowerCase();

        // 1. YouTube Shorts (youtube.com/shorts, youtu.be/shorts, m.youtube.com/shorts, hashtag/shorts)
        if (lower.includes('youtube.com') || lower.includes('youtu.be') || lower.includes('youtube-nocookie.com')) {
            if (lower.includes('/shorts/') || lower.includes('/shorts?') || lower.includes('/shorts#') || lower.endsWith('/shorts') || lower.includes('hashtag/shorts')) {
                return true;
            }
        }

        // 2. TikTok
        if (lower.includes('tiktok.com')) return true;

        // 3. Instagram
        if (lower.includes('instagram.com')) return true;

        // 4. FB Watch
        if (lower.includes('fb.watch')) return true;

        // 5. Facebook Reels, Photos, Posts, Groups, Stories, Share
        if (lower.includes('facebook.com')) {
            try {
                const urlObj = new URL(decodedUrl, window.location.href);
                const path = urlObj.pathname.toLowerCase();
                const badPaths = ['/reel/', '/reels/', '/share/', '/videos/', '/photo/', '/photos/', '/story.php', '/posts/', '/permalink.php', '/groups/'];
                if (badPaths.some(bp => path.includes(bp))) return true;
                if (lower.includes('fbid=')) return true;
            } catch(e) {
                if (lower.includes('/reel/') || lower.includes('/reels/') || lower.includes('/share/') || lower.includes('fbid=')) return true;
            }
        }
        return false;
    }

    function isInsideSidebar(node) {
        if (!node) return false;
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
        if (!node || !(node instanceof HTMLElement)) return null;
        // Ieškome TIK labai specifinių žinučių burbulų / konteinerių
        let container = node.closest('[data-testid="message-container"]') ||
                        node.closest('[data-testid="msg_batch"]') ||
                        node.closest('[role="none"].x1n2onr6.x1iyjqo2') ||
                        node.closest('[role="row"]');

        if (container) {
            // SAUGIKLIAI: niekada neslepiame didelių layout blokų ar elementų su ID (išskyrus žinučių elementus)
            if (container.id && !container.getAttribute('data-testid')) return null;

            const role = container.getAttribute('role');
            if (role && role !== 'none' && role !== 'gridcell' && role !== 'row') return null;

            // Tikriname matmenis santykinai su langu
            const rect = container.getBoundingClientRect();
            if (rect.width > (window.innerWidth * 0.75)) return null;
            if (rect.height > (window.innerHeight * 0.75)) return null;
            if (rect.height > 650 || rect.width > 850) return null;

            // Žinutės burbulas neturi turėti per daug vaikų (ne visas pokalbių medis)
            if (container.querySelectorAll('*').length > 60) return null;
        }

        return container;
    }

    // Paslepia gretimas žinutes (pvz., "ziurek ka tau atsiunciau") prieš arba po užblokuotos nuorodos
    function hideAdjacentMessages(container) {
        if (!container || !(container instanceof HTMLElement)) return;

        function isCandidate(node) {
            if (!node || !(node instanceof HTMLElement)) return false;
            if (node.getAttribute('data-cleaner-hidden') === 'true') return false;
            if (isInsideSidebar(node)) return false;

            // Neturi turėti kitų gerų / neblokuojamų nuorodų
            const links = node.querySelectorAll('a[href]');
            for (let a of links) {
                const href = a.getAttribute('href');
                if (href && !isBadUrl(href) && !href.startsWith('#') && !href.includes('/messages/') && !href.includes('/t/')) {
                    return false;
                }
            }

            // Saugumo patikrinimas: dydis ir vaikų skaičius
            const rect = node.getBoundingClientRect();
            if (rect.height > 400 || rect.width > 800) return false;
            if (node.querySelectorAll('*').length > 40) return false;

            // Turi turėti teksto arba atrodyti kaip žinutės elementas
            const text = (node.innerText || '').trim();
            if (text.length > 350) return false; // Neperbraukiame labai ilgų nesusijusių pastraipų

            return true;
        }

        function doHide(node) {
            if (!node) return;
            const target = getSmallMessageContainer(node) || node;
            target.setAttribute('data-cleaner-hidden', 'true');
            target.style.display = 'none';
        }

        // Tikriname iki 2 gretimų elementų aukštyn (prieš nuorodą)
        let prev = container.previousElementSibling;
        for (let i = 0; i < 2 && prev; i++) {
            if (isCandidate(prev)) {
                const toHide = prev;
                prev = prev.previousElementSibling;
                doHide(toHide);
            } else {
                break;
            }
        }

        // Tikriname iki 2 gretimų elementų žemyn (po nuorodos)
        let next = container.nextElementSibling;
        for (let i = 0; i < 2 && next; i++) {
            if (isCandidate(next)) {
                const toHide = next;
                next = next.nextElementSibling;
                doHide(toHide);
            } else {
                break;
            }
        }

        // Jei konteineris yra sub-grupės viduje, patikriname ir pačios sub-grupės kaimynus
        const parent = container.parentElement;
        if (parent && parent.children.length <= 3) {
            let parentPrev = parent.previousElementSibling;
            if (parentPrev && isCandidate(parentPrev)) {
                doHide(parentPrev);
            }
            let parentNext = parent.nextElementSibling;
            if (parentNext && isCandidate(parentNext)) {
                doHide(parentNext);
            }
        }
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
            // Paslepia ir gretimas žinutes (prieš/po aukščiau ir žemiau)
            hideAdjacentMessages(container);
        } else {
            // Jei neradome saugaus konteinerio, paslepiame TIK nuorodą / elementą ir patikriname tėvinį konteinerį
            if (node.tagName === 'A') {
                node.style.display = 'none';
                node.setAttribute('data-cleaner-hidden', 'true');

                const parentMsg = getSmallMessageContainer(node.parentElement);
                if (parentMsg) {
                    parentMsg.setAttribute('data-cleaner-hidden', 'true');
                    parentMsg.style.display = 'none';
                    hideAdjacentMessages(parentMsg);
                }
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

            // B. "FORWARDED" ETIKETĖS IR UŽBLOKUOTOS FRAZĖS ŽINUČIŲ SPAN'UOSE
            const allSpans = document.querySelectorAll('span:not([data-cleaner-processed])');
            allSpans.forEach(span => {
                if (span.children.length > 0) return;
                const txt = span.innerText.trim();
                let isBlocked = forwardedLabels.includes(txt);
                if (!isBlocked && txt.length > 0) {
                    const lowerTxt = txt.toLowerCase();
                    if (lowerTxt.includes('youtube.com/shorts') || lowerTxt.includes('youtu.be/shorts')) {
                        isBlocked = true;
                    }
                }

                if (isBlocked) {
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

    // Expose for testing if needed
    if (typeof window !== 'undefined') {
        window.__cleanMess = cleanMess;
        window.__isBadUrl = isBadUrl;
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

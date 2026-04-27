// ==UserScript==
// @name         Messenger Cleaner V19.0 (Aggressive Forwarded Fix)
// @namespace    http://tampermonkey.net/
// @version      19.0
// @description  Blokuoja Shorts/Reels/TikTok/FB nuotraukas ir Forwarded nuorodas. Patobulintas persiųstų žinučių aptikimas.
// @author       Jules
// @match        https://www.messenger.com/*
// @match        https://www.facebook.com/messages/*
// @match        https://www.facebook.com/*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    console.log("Messenger Cleaner V19.0: Startuoja (Aggressive Forwarded Fix)...");

    // --- 1. CSS INJEKCIJA ---
    const style = document.createElement('style');
    style.innerHTML = `
        /* Paslepia nuorodas tiesiogiai per CSS greičiui */
        a[href*="tiktok.com"],
        a[href*="/shorts/"],
        a[href*="instagram.com"],
        a[href*="fb.watch"],
        a[href*="/videos/"],
        a[href*="/reel/"],
        a[href*="/photo/"],
        a[href*="fbid="],
        a[href*="/share/"],
        a[href*="/story.php"],
        a[href*="/posts/"],
        a[href*="/permalink.php"],
        a[href*="/groups/"] {
            display: none !important;
        }

        [data-v19-cleaned="true"] {
            display: none !important;
        }

        .v19-replaced-text {
            color: #888 !important;
            font-style: italic !important;
            font-size: 0.9em !important;
        }
    `;
    document.head.appendChild(style);

    // --- 2. KONFIGŪRACIJA ---

    const blockedPhrases = [
        "Tadas atsiuntė priedą", "Mindaugas atsiuntė priedą",
        "Ramūnas atsiuntė priedą", "sent an attachment",
        "shared a reel", "pasidalijo ritiniu",
        "atsiuntė ritinį", "atsiuntė nuorodą", "sent a link",
        "forwarded a link", "persiuntė nuorodą",
        "forwarded a message", "persiuntė žinutę",
        "shared a post", "pasidalijo įrašu",
        "shared a video", "pasidalijo vaizdo įrašu",
        "shared a photo", "pasidalijo nuotrauka",
        "shared a link", "pasidalijo nuoroda",
        "Forwarded", "Persiųsta", "Persiųsta žinutė", "Persiuntė"
    ];

    const blockedDomains = [
        "tiktok.com", "instagram.com", "youtube.com/shorts", "youtu.be/shorts",
        "facebook.com/reel", "fb.watch", "facebook.com/share", "facebook.com/videos",
        "facebook.com/photo", "fbid=", "facebook.com/story", "facebook.com/posts",
        "facebook.com/permalink", "facebook.com/groups"
    ];

    // --- 3. PAGALBINĖS FUNKCIJOS ---

    function isSafeNavigation(href) {
        if (!href) return true;
        if (href.includes('/messages/t/')) return true;
        if (href.includes('/t/')) return true;
        if (href.includes('/active_status/')) return true;
        if (href === '#' || href === '') return true;
        return false;
    }

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

        // Dekoduojame FB redirectus
        const decodedUrl = decodeFBUrl(url);

        if (decodedUrl.includes('tiktok.com')) return true;
        if (decodedUrl.includes('instagram.com')) return true;
        if ((decodedUrl.includes('youtube.com') || decodedUrl.includes('youtu.be')) && decodedUrl.includes('/shorts/')) return true;

        if ((decodedUrl.includes('facebook.') || decodedUrl.includes('fb.watch')) && !isSafeNavigation(decodedUrl)) {
            if (decodedUrl.includes('/reel/') || decodedUrl.includes('fb.watch') || decodedUrl.includes('/share/') ||
                decodedUrl.includes('/videos/') || decodedUrl.includes('/photo/') || decodedUrl.includes('fbid=') ||
                decodedUrl.includes('/story.php') || decodedUrl.includes('/posts/') || decodedUrl.includes('/permalink.php') ||
                decodedUrl.includes('/groups/')) {
                return true;
            }
        }
        return false;
    }

    function getContainer(node) {
        // Ieškome bendro žinutės konteinerio
        let container = node.closest('div[role="row"]') ||
                        node.closest('div[data-testid="message-container"]') ||
                        node.closest('div[aria-label^="Žinutė"]') ||
                        node.closest('div[aria-label^="Message"]') ||
                        node.closest('div[data-testid="msg_batch"]');

        if (!container) {
             // Fallback
             if (node.tagName !== 'A' && node.tagName !== 'SPAN') {
                 if (node.parentElement && node.parentElement.tagName === 'DIV') {
                     return node.parentElement;
                 }
             }
             return node;
        }
        return container;
    }

    function cleanElement(element) {
        if (!element) return;
        if (element.getAttribute('data-v19-cleaned') === 'true') return;
        element.setAttribute('data-v19-cleaned', 'true');
        element.style.display = 'none';
    }

    // --- 4. PAGRINDINĖ LOGIKA ---

    function cleanMess() {
        // A. NUORODŲ VALYMAS (CHAT WINDOW)
        const links = document.querySelectorAll('a:not([data-v19-processed])');
        links.forEach(link => {
            const href = link.getAttribute('href');
            if (isBadUrl(href)) {
                let container = getContainer(link);
                cleanElement(container);
            }
            link.setAttribute('data-v19-processed', 'true');
        });

        // B. "FORWARDED" ETIKEČIŲ VALYMAS (CHAT WINDOW)
        // Messenger dažnai rodo "Forwarded" virš žinutės kaip mažą tekstą
        const potentialLabels = document.querySelectorAll('span:not([data-v19-processed]), div:not([data-v19-processed])');
        potentialLabels.forEach(el => {
            if (el.children.length > 0) return; // Tikriname tik lapinius elementus su tekstu
            const txt = el.innerText ? el.innerText.trim() : "";
            if (txt === "Forwarded" || txt === "Persiųsta" || txt === "Persiųsta žinutė" || txt === "Persiuntė") {
                let container = getContainer(el);
                cleanElement(container);
            }
            el.setAttribute('data-v19-processed', 'true');
        });

        // C. SIDEBARO VALYMAS (TEXT REPLACEMENT)
        const sidebarNodes = document.querySelectorAll('div[role="gridcell"] span, div[data-testid="mwthreadlist-item"] span');
        sidebarNodes.forEach(node => {
            if (node.classList.contains('v19-replaced-text')) return;
            const text = node.innerText || "";
            if (text === "unable receive message") return;

            let isBad = false;
            for (let domain of blockedDomains) {
                 if (text.includes(domain)) { isBad = true; break; }
            }
            if (!isBad) {
                for (let phrase of blockedPhrases) {
                    if (text.toLowerCase().includes(phrase.toLowerCase())) { isBad = true; break; }
                }
            }

            if (isBad) {
                node.innerText = "unable receive message";
                node.classList.add('v19-replaced-text');

                // Užtikriname, kad pats sidebar elementas nebūtų paslėptas, tik tekstas pakeistas
                let container = node.closest('div[role="gridcell"]') || node.closest('div[data-testid="mwthreadlist-item"]');
                if (container) {
                    container.style.display = '';
                    container.removeAttribute('data-v19-cleaned');
                }
            }
        });
    }

    // --- 5. STEBĖJIMAS ---

    let debounceTimer = null;
    const observer = new MutationObserver((mutations) => {
        if (debounceTimer) clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => {
            cleanMess();
        }, 100);
    });

    observer.observe(document.body, {
        childList: true,
        subtree: true
    });

    // Pradinis paleidimas
    cleanMess();

})();

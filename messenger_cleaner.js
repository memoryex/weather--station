// ==UserScript==
// @name         Messenger Cleaner V20.0 (Sidebar Fix)
// @namespace    http://tampermonkey.net/
// @version      20.0
// @description  Blokuoja Shorts/Reels/TikTok/FB nuotraukas ir Forwarded nuorodas. Ištaisyta problema su pradingstančiais kontaktais sidebar'e.
// @author       Jules
// @match        https://www.messenger.com/*
// @match        https://www.facebook.com/messages/*
// @match        https://www.facebook.com/*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    console.log("Messenger Cleaner V20.0: Startuoja (Sidebar Fix)...");

    // --- 1. CSS INJEKCIJA ---
    const style = document.createElement('style');
    style.innerHTML = `
        /* Paslepia nuorodas tiesiogiai per CSS greičiui (tik pagrindiniame lange) */
        /* Mes nenaudosime display:none nuorodoms per CSS, nes tai gali paslėpti sidebar elementus netyčia */

        [data-cleaner-hidden="true"] {
            display: none !important;
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

    function isSidebar(node) {
        return !!(node.closest('div[role="gridcell"]') ||
                  node.closest('div[data-testid="mwthreadlist-item"]') ||
                  node.closest('div[aria-label="Conversations"]') ||
                  node.closest('div[aria-label="Pokalbiai"]'));
    }

    function getChatContainer(node) {
        // Ieškome bendro žinutės konteinerio TIK jei tai ne sidebar
        if (isSidebar(node)) return null;

        return node.closest('div[role="row"]') ||
               node.closest('div[data-testid="message-container"]') ||
               node.closest('div[aria-label^="Žinutė"]') ||
               node.closest('div[aria-label^="Message"]') ||
               node.closest('div[data-testid="msg_batch"]');
    }

    function maskSidebarNode(node) {
        // Ieškome artimiausio row konteinerio sidebare, kad rastume visą preview tekstą
        let row = node.closest('div[role="gridcell"]') || node.closest('div[data-testid="mwthreadlist-item"]');
        if (row) {
            // Messenger sidebare preview tekstas dažniausiai yra giliai spanuose
            // Mes norime rasti tą span, kuris rodo žinutės fragmentą
            const spans = row.querySelectorAll('span');
            spans.forEach(s => {
                // Tikriname ar span turi tekstą ir neturi vaikų (lapas)
                if (s.children.length === 0 && s.innerText.length > 0) {
                    const txt = s.innerText.toLowerCase();
                    let isBad = false;
                    for (let domain of blockedDomains) { if (txt.includes(domain)) { isBad = true; break; } }
                    if (!isBad) {
                        for (let phrase of blockedPhrases) { if (txt.includes(phrase.toLowerCase())) { isBad = true; break; } }
                    }

                    if (isBad || s.innerText === "unable receive message") {
                        s.innerText = "unable receive message";
                        s.classList.add('cleaner-replaced-text');
                    }
                }
            });
            return;
        }

        // Fallback jei neradome row
        let span = node.tagName === 'SPAN' ? node : node.querySelector('span');
        if (span) {
            span.innerText = "unable receive message";
            span.classList.add('cleaner-replaced-text');
        }
    }

    function cleanElement(element) {
        if (!element) return;
        if (element.getAttribute('data-cleaner-hidden') === 'true') return;
        element.setAttribute('data-cleaner-hidden', 'true');
        element.style.display = 'none';
    }

    // --- 4. PAGRINDINĖ LOGIKA ---

    function cleanMess() {
        // A. NUORODŲ VALYMAS
        const links = document.querySelectorAll('a:not([data-cleaner-processed])');
        links.forEach(link => {
            const href = link.getAttribute('href');
            if (isBadUrl(href)) {
                if (isSidebar(link)) {
                    maskSidebarNode(link);
                } else {
                    let container = getChatContainer(link);
                    if (container) cleanElement(container);
                    else link.style.display = 'none'; // Fallback paslėpti tik nuorodą jei konteinerio nėra
                }
            }
            link.setAttribute('data-cleaner-processed', 'true');
        });

        // B. "FORWARDED" ETIKEČIŲ VALYMAS
        const potentialLabels = document.querySelectorAll('span:not([data-cleaner-processed]), div:not([data-cleaner-processed])');
        potentialLabels.forEach(el => {
            if (el.children.length > 0) return;
            const txt = el.innerText ? el.innerText.trim() : "";
            if (txt === "Forwarded" || txt === "Persiųsta" || txt === "Persiųsta žinutė" || txt === "Persiuntė") {
                if (isSidebar(el)) {
                    maskSidebarNode(el);
                } else {
                    let container = getChatContainer(el);
                    if (container) cleanElement(container);
                }
            }
            el.setAttribute('data-cleaner-processed', 'true');
        });

        // C. SIDEBARO TEKSTO ANALIZĖ (Bendram saugumui)
        const sidebarSpans = document.querySelectorAll('div[role="gridcell"] span, div[data-testid="mwthreadlist-item"] span');
        sidebarSpans.forEach(span => {
            if (span.classList.contains('cleaner-replaced-text')) return;
            const text = span.innerText || "";
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
                maskSidebarNode(span);
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

    cleanMess();

})();

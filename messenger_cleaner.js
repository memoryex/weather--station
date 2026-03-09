// ==UserScript==
// @name         Messenger Cleaner V18.0 (Forwarded Links Fix)
// @namespace    http://tampermonkey.net/
// @version      18.0
// @description  Blokuoja Shorts/Reels/TikTok/FB nuotraukas ir Forwarded nuorodas. Sidebar tekstas pakeičiamas į "unable receive message".
// @author       Jūs
// @match        https://www.messenger.com/*
// @match        https://www.facebook.com/messages/*
// @match        https://www.facebook.com/*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    console.log("Messenger Cleaner V18.0: Startuoja (Forwarded Links Fix)...");

    // --- 1. CSS INJEKCIJA ---
    const style = document.createElement('style');
    style.innerHTML = `
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

        [data-v18-cleaned="true"] {
            display: none !important;
        }

        .v18-replaced-text {
            color: #888 !important;
            font-style: italic !important;
            font-size: 0.9em !important;
        }
    `;
    document.head.appendChild(style);

    // --- 2. JS LOGIKA ---

    // Praplėstas frazių sąrašas (pridėta Forwarded/Persiuntė)
    const blockedPhrases = [
        "Tadas atsiuntė priedą", "Mindaugas atsiuntė priedą",
        "Ramūnas atsiuntė priedą", "sent an attachment",
        "shared a reel", "pasidalijo ritiniu",
        "atsiuntė ritinį", "atsiuntė nuorodą", "sent a link",
        "forwarded a link", "persiuntė nuorodą",
        "forwarded a message", "persiuntė žinutę",
        "shared a post", "pasidalijo įrašu",
        "shared a video", "pasidalijo vaizdo įrašu",
        "shared a photo", "pasidalijo nuotrauka"
    ];

    // Praplėstas domenų/raktinių žodžių sąrašas
    const blockedDomains = [
        "tiktok.com", "instagram.com", "youtube.com/shorts", "youtu.be/shorts",
        "facebook.com/reel", "fb.watch", "facebook.com/share", "facebook.com/videos",
        "facebook.com/photo", "fbid=", "facebook.com/story", "facebook.com/posts",
        "facebook.com/permalink", "facebook.com/groups"
    ];

    function isSafeNavigation(href) {
        if (!href) return true;
        if (href.includes('/messages/t/')) return true;
        if (href.includes('/t/')) return true;
        if (href.includes('/active_status/')) return true;
        if (href === '#' || href === '') return true;
        return false;
    }

    function cleanElement(element) {
        if (!element) return;
        if (element.getAttribute('data-v18-cleaned') === 'true') return;
        element.setAttribute('data-v18-cleaned', 'true');
        element.style.display = 'none';
    }

    function isBadUrl(url) {
        if (!url) return false;
        if (url.includes('tiktok.com')) return true;
        if (url.includes('instagram.com')) return true; // Blokuojame visą Instagram
        if ((url.includes('youtube.com') || url.includes('youtu.be')) && url.includes('/shorts/')) return true;
        if ((url.includes('facebook.') || url.includes('fb.watch')) && !isSafeNavigation(url)) {
            if (url.includes('/reel/') || url.includes('fb.watch') || url.includes('/share/') ||
                url.includes('/videos/') || url.includes('/photo/') || url.includes('fbid=') ||
                url.includes('/story.php') || url.includes('/posts/') || url.includes('/permalink.php') ||
                url.includes('/groups/')) {
                return true;
            }
        }
        return false;
    }

    function getContainer(node) {
        let row = node.closest('div[role="row"]');
        if (row) return row;
        let msgContainer = node.closest('div[data-testid="message-container"]');
        if (msgContainer) return msgContainer;
        if (node.tagName !== 'A' && node.tagName !== 'SPAN') {
             if (node.parentElement && node.parentElement.tagName === 'DIV') {
                 return node.parentElement;
             }
        }
        return node;
    }

    function checkSidebarItem(node) {
        if (node.classList.contains('v18-replaced-text')) return;

        const text = node.innerText || "";
        if (text === "unable receive message") return;

        let isBad = false;

        // Tikriname domenus/URL dalis tekste
        for (let domain of blockedDomains) {
             if (text.includes(domain)) {
                 isBad = true;
                 break;
             }
        }

        // Tikriname frazes (pvz. "forwarded a link")
        if (!isBad) {
            for (let phrase of blockedPhrases) {
                if (text.toLowerCase().includes(phrase.toLowerCase())) {
                    isBad = true;
                    break;
                }
            }
        }

        if (isBad) {
            // PAKEIČIAME TEKSTĄ SIDEBARE
            node.innerText = "unable receive message";
            node.classList.add('v18-replaced-text');

            let container = node.closest('div[role="gridcell"]') || node.closest('div[data-testid="mwthreadlist-item"]');
            if (container) {
                container.style.display = '';
                container.removeAttribute('data-v18-cleaned');
            }
        }
    }

    function cleanMess() {
        // 1. NUORODŲ VALYMAS (CHAT WINDOW - STRICT HIDE)
        const links = document.querySelectorAll('a:not([data-v18-processed])');
        links.forEach(link => {
            const href = link.getAttribute('href');
            if (isBadUrl(href)) {
                let container = getContainer(link);
                cleanElement(container);
            }
            link.setAttribute('data-v18-processed', 'true');
        });

        // 2. SIDEBARO VALYMAS (TEXT REPLACEMENT)
        const potentialSidebarNodes = document.querySelectorAll('div[role="gridcell"] span, div[data-testid="mwthreadlist-item"] span');

        potentialSidebarNodes.forEach(node => {
            if (node.innerText && node.innerText.length > 2) {
                checkSidebarItem(node);
            }
        });
    }

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

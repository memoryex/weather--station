// ==UserScript==
// @name         Messenger Cleaner V17.0 (Sidebar Text Replacement)
// @namespace    http://tampermonkey.net/
// @version      17.0
// @description  Blokuoja Shorts/Reels/TikTok ir paslepia VISĄ žinutės eilutę. Sidebar tekstas pakeičiamas į "unable receive message".
// @author       Jūs
// @match        https://www.messenger.com/*
// @match        https://www.facebook.com/messages/*
// @match        https://www.facebook.com/*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    console.log("Messenger Cleaner V17.0: Startuoja (Text Replacement)...");

    // --- 1. CSS INJEKCIJA ---
    const style = document.createElement('style');
    style.innerHTML = `
        a[href*="tiktok.com"],
        a[href*="/reel/"],
        a[href*="/shorts/"],
        a[href*="fb.watch"],
        a[href*="/videos/"] {
            display: none !important;
        }

        [data-v17-cleaned="true"] {
            display: none !important;
        }

        .v17-replaced-text {
            color: #888 !important;
            font-style: italic !important;
            font-size: 0.9em !important;
        }
    `;
    document.head.appendChild(style);

    // --- 2. JS LOGIKA ---

    const blockedPhrases = [
        "Tadas atsiuntė priedą", "Mindaugas atsiuntė priedą",
        "Ramūnas atsiuntė priedą", "sent an attachment",
        "shared a reel", "pasidalijo ritiniu",
        "atsiuntė ritinį", "atsiuntė nuorodą", "sent a link"
    ];

    const blockedDomains = [
        "tiktok.com", "instagram.com/reel", "youtube.com/shorts", "youtu.be/shorts",
        "facebook.com/reel", "fb.watch", "facebook.com/share", "facebook.com/videos"
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
        if (element.getAttribute('data-v17-cleaned') === 'true') return;
        element.setAttribute('data-v17-cleaned', 'true');
        element.style.display = 'none';
    }

    function isBadUrl(url) {
        if (!url) return false;
        if (url.includes('tiktok.com')) return true;
        if (url.includes('instagram.com') && url.includes('/reel/')) return true;
        if ((url.includes('youtube.com') || url.includes('youtu.be')) && url.includes('/shorts/')) return true;
        if ((url.includes('facebook.') || url.includes('fb.watch')) && !isSafeNavigation(url)) {
            if (url.includes('/reel/') || url.includes('fb.watch') || url.includes('/share/') || url.includes('/videos/')) {
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
        // Jei jau pakeitėme, nieko nedarome
        if (node.classList.contains('v17-replaced-text')) return;

        const text = node.innerText || "";
        // Jei tekstas jau yra "unable receive message", praleidžiam
        if (text === "unable receive message") return;

        let isBad = false;

        // Tikriname domenus
        for (let domain of blockedDomains) {
             if (text.includes(domain)) {
                 isBad = true;
                 break;
             }
        }

        // Tikriname frazes
        if (!isBad) {
            for (let phrase of blockedPhrases) {
                if (text.toLowerCase().includes(phrase.toLowerCase())) {
                    isBad = true;
                    break;
                }
            }
        }

        if (isBad) {
            // VIETOJE SLĖPIMO - PAKEIČIAME TEKSTĄ
            node.innerText = "unable receive message";
            node.classList.add('v17-replaced-text');

            // Užtikriname, kad tėvinis elementas būtų matomas (jei anksčiau buvo paslėptas)
            let container = node.closest('div[role="gridcell"]') || node.closest('div[data-testid="mwthreadlist-item"]');
            if (container) {
                container.style.display = '';
                container.removeAttribute('data-v17-cleaned');
            }
        }
    }

    function cleanMess() {
        // 1. NUORODŲ VALYMAS (CHAT WINDOW - STRICT HIDE)
        const links = document.querySelectorAll('a:not([data-v17-processed])');
        links.forEach(link => {
            const href = link.getAttribute('href');
            if (isBadUrl(href)) {
                let container = getContainer(link);
                cleanElement(container);
            }
            link.setAttribute('data-v17-processed', 'true');
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

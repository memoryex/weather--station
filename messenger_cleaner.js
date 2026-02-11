// ==UserScript==
// @name         Messenger Cleaner V14.0 (Full Hide - No Trace)
// @namespace    http://tampermonkey.net/
// @version      14.0
// @description  Blokuoja Shorts/Reels/TikTok ir paslepia VISĄ žinutės eilutę (įskaitant avatarą ir laiką).
// @author       Jūs
// @match        https://www.messenger.com/*
// @match        https://www.facebook.com/messages/*
// @match        https://www.facebook.com/*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    console.log("Messenger Cleaner V14.0: Startuoja (Full Hide)...");

    // --- 1. CSS INJEKCIJA ---
    // Šį kartą tikslas - visiškai paslėpti (display: none), be jokių tarpų.
    const style = document.createElement('style');
    style.innerHTML = `
        /* Paslepia konkrečias nuorodas iškart (prevencija) */
        a[href*="tiktok.com"],
        a[href*="/reel/"],
        a[href*="/shorts/"],
        a[href*="fb.watch"],
        a[href*="/videos/"] {
            display: none !important;
        }

        /* Visiškai paslepiame elementą, kurį pažymėjo JS (eilutę arba žinutę) */
        [data-v14-cleaned="true"] {
            display: none !important;
        }
    `;
    document.head.appendChild(style);

    // --- 2. JS LOGIKA ---
    let spamProtectionUntil = 0;
    const SPAM_WINDOW_MS = 10000;
    let lastBadLinkElement = null;

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
        if (element.getAttribute('data-v14-cleaned') === 'true') return;

        // Pažymime elementą paslėpimui
        element.setAttribute('data-v14-cleaned', 'true');

        // JS Fallback: tiesioginis stiliaus nustatymas
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
        // Bandome rasti visą eilutę (su avataru ir laiku)
        // Messenger naudoja role="row" arba specifines klases
        let row = node.closest('div[role="row"]');
        if (row) return row;

        // Jei nerandame row, bandome rasti pagrindinį žinutės konteinerį
        let msgContainer = node.closest('div[data-testid="message-container"]');
        if (msgContainer) return msgContainer;

        // Fallback: tiesiog tėvinis elementas (burbulas)
        let bubble = node.closest('div[dir="auto"]');
        if (bubble) return bubble;

        return node.parentElement;
    }

    function cleanMess() {
        const currentTime = Date.now();
        const isInSpamMode = currentTime < spamProtectionUntil;

        // 1. NUORODŲ VALYMAS
        const links = document.querySelectorAll('a:not([data-v14-processed])');
        links.forEach(link => {
            const href = link.getAttribute('href');
            if (isBadUrl(href)) {
                spamProtectionUntil = Date.now() + SPAM_WINDOW_MS;

                // Čia pagrindinis pakeitimas: ieškome VISOS EILUTĖS
                let container = getContainer(link);

                lastBadLinkElement = container || link;
                cleanElement(lastBadLinkElement);
            }
            link.setAttribute('data-v14-processed', 'true');
        });

        // 2. APSAUGA NUO SEKIMO (Grandininė reakcija)
        // Pastaba: Jei paslėpėme eilutę, ji vis tiek yra DOM, tad compareDocumentPosition veikia
        if (isInSpamMode && lastBadLinkElement && lastBadLinkElement.isConnected) {
             // Čia taip pat norime slėpti VISĄ eilutę, ne tik burbulą
             // Todėl ieškome žinučių burbulų, bet slepiame jų konteinerius
             const messageBubbles = document.querySelectorAll('div[dir="auto"]:not([data-v14-cleaned])');

             messageBubbles.forEach(msg => {
                 if (msg.innerText && msg.innerText.length > 0) {
                      if (lastBadLinkElement.compareDocumentPosition(msg) & Node.DOCUMENT_POSITION_FOLLOWING) {
                           let container = getContainer(msg);
                           cleanElement(container);
                      }
                 }
             });
        }

        // 3. TEKSTO/SIDEBARO VALYMAS
        const potentialTextNodes = document.querySelectorAll('div[role="gridcell"] span:not([data-v14-cleaned]), div[data-testid="mwthreadlist-item"] span:not([data-v14-cleaned])');

        potentialTextNodes.forEach(node => {
            const text = node.innerText || "";
            let shouldClean = false;

            for (let domain of blockedDomains) {
                 if (text.includes(domain)) {
                     shouldClean = true;
                     break;
                 }
            }

            if (!shouldClean) {
                for (let phrase of blockedPhrases) {
                    if (text.toLowerCase().includes(phrase.toLowerCase())) {
                        shouldClean = true;
                        break;
                    }
                }
            }

            if (shouldClean) {
                 // Sidebar atveju irgi bandome rasti visą elementą
                 let container = node.closest('div[role="gridcell"]') || node.closest('div[data-testid="mwthreadlist-item"]') || node;
                 cleanElement(container);
            }
        });
    }

    const observer = new MutationObserver((mutations) => {
        cleanMess();
    });

    observer.observe(document.body, {
        childList: true,
        subtree: true
    });

    cleanMess();

})();

// ==UserScript==
// @name         Messenger Cleaner V15.0 (Critical Fix - No Message Loss)
// @namespace    http://tampermonkey.net/
// @version      15.0
// @description  Blokuoja Shorts/Reels/TikTok ir paslepia VISĄ žinutės eilutę.
// @author       Jūs
// @match        https://www.messenger.com/*
// @match        https://www.facebook.com/messages/*
// @match        https://www.facebook.com/*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    console.log("Messenger Cleaner V15.0: Startuoja (Critical Fix)...");

    // --- 1. CSS INJEKCIJA ---
    // Paslepia visiškai (display: none), be jokių tarpų.
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
        [data-v15-cleaned="true"] {
            display: none !important;
        }
    `;
    document.head.appendChild(style);

    // --- 2. JS LOGIKA ---
    // Pastaba: "10s grandininė reakcija" pašalinta, nes ji slėpė geras žinutes
    // kai buvo užkraunama sena pokalbių istorija (scrollinant).

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
        if (element.getAttribute('data-v15-cleaned') === 'true') return;

        // Pažymime elementą paslėpimui
        element.setAttribute('data-v15-cleaned', 'true');

        // JS Fallback
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
        let row = node.closest('div[role="row"]');
        if (row) return row;

        // Jei nerandame row, bandome rasti pagrindinį žinutės konteinerį
        let msgContainer = node.closest('div[data-testid="message-container"]');
        if (msgContainer) return msgContainer;

        // Griežtesnis fallback: tikrai nenorime imti body ar main
        if (node.tagName !== 'A' && node.tagName !== 'SPAN') {
             // Jei tai jau didelis konteineris, galbūt jo tėvas
             if (node.parentElement && node.parentElement.tagName === 'DIV') {
                 return node.parentElement;
             }
        }

        return node; // Kraštutiniu atveju slepiame patį elementą
    }

    function cleanMess() {
        // 1. NUORODŲ VALYMAS
        const links = document.querySelectorAll('a:not([data-v15-processed])');
        links.forEach(link => {
            const href = link.getAttribute('href');
            if (isBadUrl(href)) {
                // Surandame konteinerį ir paslepiame
                let container = getContainer(link);
                cleanElement(container);
            }
            link.setAttribute('data-v15-processed', 'true');
        });

        // 2. TEKSTO/SIDEBARO VALYMAS
        const potentialTextNodes = document.querySelectorAll('div[role="gridcell"] span:not([data-v15-cleaned]), div[data-testid="mwthreadlist-item"] span:not([data-v15-cleaned])');

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

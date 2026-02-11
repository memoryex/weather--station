// ==UserScript==
// @name         Messenger Cleaner V11.0 (Su Šluotele 🧹)
// @namespace    http://tampermonkey.net/
// @version      11.2
// @description  Blokuoja Shorts/Reels ir pakeičia juos į 🧹. Taip pat blokuoja 10 sek. po jų einančias žinutes.
// @author       Jūs
// @match        https://www.messenger.com/*
// @match        https://www.facebook.com/messages/*
// @match        https://www.facebook.com/*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    console.log("Messenger Cleaner V11.2: Startuoja su CSS-based valymu...");

    // 1. Įterpiame CSS stilių
    const style = document.createElement('style');
    style.innerHTML = `
        .v11-cleaned {
            visibility: hidden !important;
            position: relative !important;
            min-height: 20px;
        }
        .v11-cleaned::after {
            content: '🧹 ' attr(data-v11-reason);
            visibility: visible !important;
            position: absolute !important;
            top: 5px;
            left: 5px;
            display: block;
            color: #bbb;
            font-size: 12px;
            font-family: sans-serif;
            z-index: 999;
            white-space: nowrap;
        }
    `;
    document.head.appendChild(style);


    // Konfigūracija
    const SPAM_WINDOW_MS = 10000; // 10 sekundžių blokavimo langas

    // Frazės, kurias naikiname
    const blockedPhrases = [
        "Tadas atsiuntė priedą", "Mindaugas atsiuntė priedą",
        "Ramūnas atsiuntė priedą", "sent an attachment",
        "shared a reel", "pasidalijo ritiniu",
        "atsiuntė ritinį", "atsiuntė nuorodą", "sent a link"
    ];

    function isSafeNavigation(href) {
        if (!href) return true;
        if (href.includes('/messages/t/')) return true;
        if (href.includes('/t/')) return true;
        if (href.includes('/active_status/')) return true;
        if (href.startsWith('#') || href === '') return true;
        if (href.includes('messenger.com') && !href.includes('l.messenger.com')) return true;
        return false;
    }

    // Pagalbinė funkcija - PAKEISTI elementą į šluotelę (CSS būdu)
    // Svarbu: Niekada nenaudoti innerHTML, nes tai sugadina React aplikaciją.
    function cleanElement(element, reason) {
        if (!element) return;

        // Jei jau išvalytas, nieko nedarom
        if (element.classList.contains('v11-cleaned')) return;

        // Naudojame CSS klases ir atributus - tai mažiausiai invazyvus būdas
        element.setAttribute('data-v11-reason', reason);
        element.setAttribute('data-v11-cleaned-time', Date.now().toString());
        element.classList.add('v11-cleaned');
    }

    let isRunning = false;

    function cleanMess() {
        if (isRunning) return;
        isRunning = true;

        requestAnimationFrame(() => {
            try {
                processCleaning();
            } catch (e) {
                console.error("Messenger Cleaner Error:", e);
            } finally {
                isRunning = false;
            }
        });
    }

    function processCleaning() {
        const currentTime = Date.now();

        // Bandome surasti visus pagrindinius žinučių blokus (eilutes)
        let messageRows = document.querySelectorAll('div[role="row"], div[data-testid="message-container"], div.x1n2onr6');

        if (messageRows.length === 0) {
            const articles = document.querySelectorAll('div[role="article"]');
            if (articles.length > 0) messageRows = articles;
            else messageRows = document.querySelectorAll('div[dir="auto"]');
        }

        // --- 1. NUORODŲ VALYMAS ---
        const links = document.querySelectorAll('a');
        links.forEach(link => {
            // Tikriname tik tas, kurios dar neapdorotos
            if (link.getAttribute('data-v11-processed') === 'true') return;

            const href = link.getAttribute('href');
            if (!href) return;

            let isBadLink = false;
            let reason = "";
            const lowerHref = href.toLowerCase();

            // --- TIKRINIMO LOGIKA ---
            if (lowerHref.includes('tiktok.com')) {
                isBadLink = true; reason = "TikTok";
            }
            else if (lowerHref.includes('instagram.com') && lowerHref.includes('/reel/')) {
                isBadLink = true; reason = "Insta Reel";
            }
            else if ((lowerHref.includes('youtube.com') || lowerHref.includes('youtu.be')) && lowerHref.includes('/shorts/')) {
                isBadLink = true; reason = "YT Shorts";
            }
            else if ((lowerHref.includes('facebook.com') || lowerHref.includes('fb.watch')) && !isSafeNavigation(href)) {
                isBadLink = true; reason = "Facebook";
            }

            if (isBadLink) {
                let container = link.closest('div[role="row"]');
                if (!container) container = link.closest('.x1n2onr6');
                if (!container) container = link.closest('div[dir="auto"]');
                if (!container) container = link.parentElement;

                cleanElement(container || link, reason);
            }

            link.setAttribute('data-v11-processed', 'true');
        });

        // --- 2. APSAUGA NUO SEKIMO (Grandininė reakcija) ---
        let blockUntil = 0;

        if (messageRows.length > 0) {
            messageRows.forEach(row => {
                // Ar šis elementas jau išvalytas?
                const isCleaned = row.classList.contains('v11-cleaned') || row.querySelector('.v11-cleaned');

                if (isCleaned) {
                    // Randame priežastį
                    let cleanedEl = row.classList.contains('v11-cleaned') ? row : row.querySelector('.v11-cleaned');
                    let reasonText = cleanedEl.getAttribute('data-v11-reason') || "";

                    if (reasonText.includes('TikTok') ||
                        reasonText.includes('Facebook') ||
                        reasonText.includes('Shorts') ||
                        reasonText.includes('Reel') ||
                        reasonText.includes('Spam Link')) {

                        const cleanedTime = parseInt(cleanedEl.getAttribute('data-v11-cleaned-time') || "0");
                        blockUntil = Math.max(blockUntil, cleanedTime + SPAM_WINDOW_MS);
                    }
                } else {
                    // Jei blokavimas aktyvus -> valome šitą žinutę
                    if (currentTime < blockUntil) {
                        if (row.innerText && row.innerText.trim().length > 0) {
                             // Svarbu: valome patį konteinerį, ne vidinį tekstą, kad struktūra išliktų
                             cleanElement(row, "Sekanti žinutė (10s)");
                        }
                    }
                }
            });
        }

        // --- 3. FRAZIŲ VALYMAS ---
        // Naudojame atsargiau
        const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null, false);
        let node;
        while (node = walker.nextNode()) {
            const text = node.nodeValue;
            if (!text) continue;

            for (let phrase of blockedPhrases) {
                if (text.toLowerCase().includes(phrase.toLowerCase())) {
                    if (node.parentElement && !node.parentElement.classList.contains('v11-cleaned')) {
                         cleanElement(node.parentElement, `Frazė: ${phrase}`);
                    }
                }
            }
        }
    }

    // Stebėtojas
    const observer = new MutationObserver((mutations) => {
        if (!isRunning) cleanMess();
    });

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
             observer.observe(document.body, { childList: true, subtree: true });
        });
    } else {
        observer.observe(document.body, { childList: true, subtree: true });
    }

    setInterval(cleanMess, 2000);

})();
